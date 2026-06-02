/* count-cjk.c — Emacs dynamic module for mixed CJK + English counting
 *
 * Build:  make -C modules/
 *   (gcc -shared -fPIC -O2 -I/usr/include/emacs-30 ...)
 *
 * Load:   (module-load (expand-file-name "modules/count-cjk.so" doom-user-dir))
 *
 * Exported:
 *   my/count-cjk  (STRING) → cons (CHARS . PUNCT)
 *   my/count-text (STRING) → vector [cjk punct en-words en-chars total-cp]
 *
 * Safety:  bounds-checked UTF-8 decoder, validates continuation bytes,
 *          rejects overlong / surrogate / truncated sequences.
 */

#include <emacs-module.h>
#include <stdint.h>
#include <stdlib.h>

int plugin_is_GPL_compatible;

/* ═══════════════════════════════════════════════════════════════════
 * Character classification
 * ═══════════════════════════════════════════════════════════════════ */

static int is_cjk(uint32_t cp) {
  return (cp >= 0x4E00  && cp <= 0x9FFF)
      || (cp >= 0x3400  && cp <= 0x4DBF)
      || (cp >= 0x20000 && cp <= 0x2A6DF)
      || (cp >= 0x2A700 && cp <= 0x2B73F)
      || (cp >= 0x2B740 && cp <= 0x2B81F)
      || (cp >= 0x2B820 && cp <= 0x2CEAF)
      || (cp >= 0x2CEB0 && cp <= 0x2EBE0)
      || (cp >= 0x2F800 && cp <= 0x2FA1F);
}

static int is_cjk_punct(uint32_t cp) {
  return cp == 0x3001 || cp == 0x3002 || cp == 0xFF0C   /* 、。， */
      || cp == 0xFF1B || cp == 0xFF1A                   /* ；： */
      || cp == 0xFF01 || cp == 0xFF1F                   /* ！？ */
      || cp == 0x201C || cp == 0x201D                   /* “” */
      || cp == 0x2018 || cp == 0x2019                   /* ‘’ */
      || cp == 0xFF08 || cp == 0xFF09                   /* （） */
      || cp == 0x3010 || cp == 0x3011                   /* 【】 */
      || cp == 0x300A || cp == 0x300B                   /* 《》 */
      || cp == 0x2014 || cp == 0x2026                   /* —… */
      || cp == 0x00B7                                   /* · */
      || cp == 0x300C || cp == 0x300D                   /* 「」 */
      || cp == 0x300E || cp == 0x300F                   /* 『』 */
      || cp == 0x3014 || cp == 0x3015                   /* 〔〕 */
      || cp == 0x3016 || cp == 0x3017                   /* 〖〗 */
      || cp == 0x301A || cp == 0x301B                   /* 〚〛 */
      || cp == 0x3000                                   /* fullwidth space */
      || cp == 0xFFE5 || cp == 0x203B;                  /* ￥ ※ */
}

static int is_en_word_char(uint32_t cp) {
  return (cp >= 'a' && cp <= 'z')
      || (cp >= 'A' && cp <= 'Z')
      || (cp >= '0' && cp <= '9')
      || cp == '\'';
}

/* ═══════════════════════════════════════════════════════════════════
 * Bounds-checked UTF-8 decoder
 * ═══════════════════════════════════════════════════════════════════
 *
 * Reads one codepoint from *sp (must be < end).  Advances *sp past
 * the consumed bytes.  Returns the codepoint on success, or 0xFFFFFFFF
 * on invalid/truncated input (overlong, surrogate, missing continuation,
 * bad start byte).
 */

static uint32_t decode_utf8_safe(const uint8_t **sp, const uint8_t *end) {
  const uint8_t *s = *sp;
  if (s >= end) return 0xFFFFFFFF;

  uint32_t cp;
  unsigned int len;

  if (s[0] < 0x80) {
    cp  = s[0];
    len = 1;
  } else if ((s[0] & 0xE0) == 0xC0) {
    len = 2;
    if ((ptrdiff_t)(end - s) < 2) return 0xFFFFFFFF;
    if ((s[1] & 0xC0) != 0x80)    return 0xFFFFFFFF;
    cp = (s[0] & 0x1F) << 6;
    cp |= (s[1] & 0x3F);
    if (cp < 0x80) return 0xFFFFFFFF;         /* overlong */
  } else if ((s[0] & 0xF0) == 0xE0) {
    len = 3;
    if ((ptrdiff_t)(end - s) < 3) return 0xFFFFFFFF;
    if ((s[1] & 0xC0) != 0x80)    return 0xFFFFFFFF;
    if ((s[2] & 0xC0) != 0x80)    return 0xFFFFFFFF;
    cp = (s[0] & 0x0F) << 12;
    cp |= (s[1] & 0x3F) << 6;
    cp |= (s[2] & 0x3F);
    if (cp < 0x800)              return 0xFFFFFFFF;  /* overlong */
    if (cp >= 0xD800 && cp <= 0xDFFF) return 0xFFFFFFFF;  /* surrogate */
  } else if ((s[0] & 0xF8) == 0xF0) {
    len = 4;
    if ((ptrdiff_t)(end - s) < 4) return 0xFFFFFFFF;
    if ((s[1] & 0xC0) != 0x80)    return 0xFFFFFFFF;
    if ((s[2] & 0xC0) != 0x80)    return 0xFFFFFFFF;
    if ((s[3] & 0xC0) != 0x80)    return 0xFFFFFFFF;
    cp = (s[0] & 0x07) << 18;
    cp |= (s[1] & 0x3F) << 12;
    cp |= (s[2] & 0x3F) << 6;
    cp |= (s[3] & 0x3F);
    if (cp < 0x10000)             return 0xFFFFFFFF;  /* overlong */
    if (cp > 0x10FFFF)            return 0xFFFFFFFF;  /* exceeds Unicode max */
  } else {
    return 0xFFFFFFFF;             /* bad start byte */
  }

  *sp += len;
  return cp;
}

/* ═══════════════════════════════════════════════════════════════════
 * Single-pass scan (length-bounded, no strlen dependency)
 * ═══════════════════════════════════════════════════════════════════ */

static void scan_text(const uint8_t *data, size_t len,
                      intmax_t *cjk, intmax_t *punct,
                      intmax_t *en_words, intmax_t *en_chars,
                      intmax_t *total_cp) {
  *cjk = *punct = *en_words = *en_chars = *total_cp = 0;
  int in_word = 0;
  const uint8_t *p   = data;
  const uint8_t *end = data + len;

  while (p < end) {
    uint32_t cp = decode_utf8_safe(&p, end);
    if (cp == 0xFFFFFFFF) {
      /* Invalid byte — skip one byte to avoid infinite loop. */
      p = (p < end) ? p + 1 : end;
      continue;
    }

    (*total_cp)++;

    if (is_cjk(cp)) {
      (*cjk)++;
      in_word = 0;
    } else if (is_cjk_punct(cp)) {
      (*punct)++;
      in_word = 0;
    } else if (is_en_word_char(cp)) {
      if (!in_word) {
        (*en_words)++;
        in_word = 1;
      }
      (*en_chars)++;
    } else {
      in_word = 0;
    }
  }
}

/* ═══════════════════════════════════════════════════════════════════
 * Helper: extract string from Emacs, call scan_text
 * ═══════════════════════════════════════════════════════════════════ */

static int string_to_counts(emacs_env *env, emacs_value arg,
                            intmax_t *cjk, intmax_t *punct,
                            intmax_t *en_words, intmax_t *en_chars,
                            intmax_t *total_cp) {
  ptrdiff_t buf_size = 0;
  if (!env->copy_string_contents(env, arg, NULL, &buf_size))
    return -1;
  if (buf_size <= 1) {
    /* Empty string (just the null terminator). */
    *cjk = *punct = *en_words = *en_chars = *total_cp = 0;
    return 0;
  }

  char *buf = (char *)malloc(buf_size);
  if (!buf) return -1;

  if (!env->copy_string_contents(env, arg, buf, &buf_size)) {
    free(buf);
    return -1;
  }

  /* buf_size includes the null terminator; actual content is buf_size-1 bytes. */
  scan_text((const uint8_t *)buf, buf_size - 1,
            cjk, punct, en_words, en_chars, total_cp);

  free(buf);
  return 0;
}

/* ═══════════════════════════════════════════════════════════════════
 * Lisp function: my/count-cjk
 * ═══════════════════════════════════════════════════════════════════ */

static emacs_value Fcount_cjk(emacs_env *env, ptrdiff_t nargs,
                               emacs_value *args, void *data) {
  (void)nargs; (void)data;
  intmax_t cjk = 0, punct = 0, ew = 0, ec = 0, tc = 0;

  if (string_to_counts(env, args[0], &cjk, &punct, &ew, &ec, &tc)) {
    env->non_local_exit_signal(
        env, env->intern(env, "error"),
        env->make_string(env, "count-cjk: memory error",
                         sizeof("count-cjk: memory error") - 1));
    return env->intern(env, "nil");
  }

  emacs_value cons = env->funcall(
      env, env->intern(env, "cons"), 2,
      (emacs_value[]){ env->make_integer(env, cjk),
                       env->make_integer(env, punct) });

  return env->non_local_exit_check(env) == emacs_funcall_exit_return
         ? cons : env->intern(env, "nil");
}

/* ═══════════════════════════════════════════════════════════════════
 * Lisp function: my/count-text
 * ═══════════════════════════════════════════════════════════════════ */

static emacs_value Fcount_text(emacs_env *env, ptrdiff_t nargs,
                                emacs_value *args, void *data) {
  (void)nargs; (void)data;
  intmax_t cjk = 0, punct = 0, ew = 0, ec = 0, tc = 0;

  if (string_to_counts(env, args[0], &cjk, &punct, &ew, &ec, &tc)) {
    env->non_local_exit_signal(
        env, env->intern(env, "error"),
        env->make_string(env, "count-text: memory error",
                         sizeof("count-text: memory error") - 1));
    return env->intern(env, "nil");
  }

  emacs_value vec = env->funcall(
      env, env->intern(env, "vector"), 5,
      (emacs_value[]){ env->make_integer(env, cjk),
                       env->make_integer(env, punct),
                       env->make_integer(env, ew),
                       env->make_integer(env, ec),
                       env->make_integer(env, tc) });

  return env->non_local_exit_check(env) == emacs_funcall_exit_return
         ? vec : env->intern(env, "nil");
}

/* ═══════════════════════════════════════════════════════════════════
 * Module init
 * ═══════════════════════════════════════════════════════════════════ */

int emacs_module_init(struct emacs_runtime *ert) EMACS_NOEXCEPT {
  emacs_env *env = ert->get_environment(ert);

  {
    emacs_value func = env->make_function(
        env, 1, 1, Fcount_cjk,
        "Return cons (CHARS . PUNCT) of CJK ideographs and punctuation in STRING.",
        NULL);
    emacs_value sym = env->intern(env, "my/count-cjk");
    env->funcall(env, env->intern(env, "defalias"), 2,
                 (emacs_value[]){ sym, func });
  }

  {
    emacs_value func = env->make_function(
        env, 1, 1, Fcount_text,
        "Return vector [cjk punct en-words en-chars total-cp] for STRING.\n"
        "  cjk       — CJK Unified Ideographs (incl. Extensions A-F)\n"
        "  punct     — CJK punctuation\n"
        "  en-words  — English words (letters/digits/apostrophe runs)\n"
        "  en-chars  — English word characters\n"
        "  total-cp  — total Unicode codepoints in STRING",
        NULL);
    emacs_value sym = env->intern(env, "my/count-text");
    env->funcall(env, env->intern(env, "defalias"), 2,
                 (emacs_value[]){ sym, func });
  }

  env->funcall(env, env->intern(env, "provide"), 1,
               (emacs_value[]){ env->intern(env, "count-cjk") });

  return env->non_local_exit_check(env) == emacs_funcall_exit_return ? 0 : 1;
}
