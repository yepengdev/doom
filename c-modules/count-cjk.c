/* count-cjk.c — Emacs 动态模块：混合 CJK（中日韩）与英文计数
 *
 * 编译：  make -C c-modules/
 *   (gcc -shared -fPIC -O2 -I/usr/include/emacs-30 ...)
 *
 * 加载： (module-load (expand-file-name "c-modules/count-cjk.so" doom-user-dir))
 *
 * 导出函数：
 *   my/count-cjk  (STRING) → cons (CHARS . PUNCT)
 *   my/count-text (STRING) → vector [cjk punct en-words en-chars total-cp]
 *
 * 安全性：边界检查的 UTF-8 解码器，验证后续字节，
 *         拒绝过长/代理项/截断序列。
 */

#include <emacs-module.h>
#include <stdint.h>
#include <stdlib.h>

int plugin_is_GPL_compatible;

/* ═══════════════════════════════════════════════════════════════════
 * 字符分类
 * ═══════════════════════════════════════════════════════════════════ */

static int is_cjk(uint32_t cp) {
  return (cp >= 0x4E00  && cp <= 0x9FFF)   /* CJK 统一表意文字（常用区） */
      || (cp >= 0x3400  && cp <= 0x4DBF)   /* CJK 统一表意文字扩展 A */
      || (cp >= 0x20000 && cp <= 0x2A6DF)  /* CJK 统一表意文字扩展 B */
      || (cp >= 0x2A700 && cp <= 0x2B73F)  /* CJK 统一表意文字扩展 C */
      || (cp >= 0x2B740 && cp <= 0x2B81F)  /* CJK 统一表意文字扩展 D */
      || (cp >= 0x2B820 && cp <= 0x2CEAF)  /* CJK 统一表意文字扩展 E */
      || (cp >= 0x2CEB0 && cp <= 0x2EBE0)  /* CJK 统一表意文字扩展 F */
      || (cp >= 0x2F800 && cp <= 0x2FA1F); /* CJK 兼容表意文字补充 */
}

/* CJK 标点符号（全角括号、引号、分隔符等） */
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
      || cp == 0x3000                                   /* 全角空格 */
      || cp == 0xFFE5 || cp == 0x203B;                  /* ￥ ※ */
}

static int is_en_word_char(uint32_t cp) {
  return (cp >= 'a' && cp <= 'z')
      || (cp >= 'A' && cp <= 'Z')
      || (cp >= '0' && cp <= '9')
      || cp == '\'';
}

/* ═══════════════════════════════════════════════════════════════════
 * 带边界检查的 UTF-8 解码器
 * ═══════════════════════════════════════════════════════════════════
 *
 * 从 *sp 位置读取一个码点（必须 < end）。将 *sp 向前移动到已消耗的字节之后。
 * 成功时返回码点，输入无效/截断时返回 0xFFFFFFFF
 * （包括过长编码、代理项、缺少后续字节、错误的起始字节）。
 */

static uint32_t decode_utf8_safe(const uint8_t **sp, const uint8_t *end) {
  const uint8_t *s = *sp;
  if (s >= end) return 0xFFFFFFFF;

  uint32_t cp;
  unsigned int len;

  if (s[0] < 0x80) {              /* 单字节 ASCII (0xxxxxxx) */
    cp  = s[0];
    len = 1;
  } else if ((s[0] & 0xE0) == 0xC0) {  /* 双字节起始 (110xxxxx) */
    len = 2;
    if ((ptrdiff_t)(end - s) < 2) return 0xFFFFFFFF;  /* 缺少后续字节 */
    if ((s[1] & 0xC0) != 0x80)    return 0xFFFFFFFF;  /* 后续字节须以 10xxxxxx 开头 */
    cp = (s[0] & 0x1F) << 6;
    cp |= (s[1] & 0x3F);
    if (cp < 0x80) return 0xFFFFFFFF;         /* 过长编码 */
  } else if ((s[0] & 0xF0) == 0xE0) {  /* 三字节起始 (1110xxxx) */
    len = 3;
    if ((ptrdiff_t)(end - s) < 3) return 0xFFFFFFFF;  /* 缺少后续字节 */
    if ((s[1] & 0xC0) != 0x80)    return 0xFFFFFFFF;  /* 后续字节须以 10xxxxxx 开头 */
    if ((s[2] & 0xC0) != 0x80)    return 0xFFFFFFFF;  /* 后续字节须以 10xxxxxx 开头 */
    cp = (s[0] & 0x0F) << 12;
    cp |= (s[1] & 0x3F) << 6;
    cp |= (s[2] & 0x3F);
    if (cp < 0x800)              return 0xFFFFFFFF;  /* 过长编码 */
    if (cp >= 0xD800 && cp <= 0xDFFF) return 0xFFFFFFFF;  /* 代理项 */
  } else if ((s[0] & 0xF8) == 0xF0) {  /* 四字节起始 (11110xxx) */
    len = 4;
    if ((ptrdiff_t)(end - s) < 4) return 0xFFFFFFFF;  /* 缺少后续字节 */
    if ((s[1] & 0xC0) != 0x80)    return 0xFFFFFFFF;  /* 后续字节须以 10xxxxxx 开头 */
    if ((s[2] & 0xC0) != 0x80)    return 0xFFFFFFFF;  /* 后续字节须以 10xxxxxx 开头 */
    if ((s[3] & 0xC0) != 0x80)    return 0xFFFFFFFF;  /* 后续字节须以 10xxxxxx 开头 */
    cp = (s[0] & 0x07) << 18;
    cp |= (s[1] & 0x3F) << 12;
    cp |= (s[2] & 0x3F) << 6;
    cp |= (s[3] & 0x3F);
    if (cp < 0x10000)             return 0xFFFFFFFF;  /* 过长编码 */
    if (cp > 0x10FFFF)            return 0xFFFFFFFF;  /* 超出 Unicode 最大值 */
  } else {
    return 0xFFFFFFFF;             /* 错误的起始字节 */
  }

  *sp += len;
  return cp;
}

/* ═══════════════════════════════════════════════════════════════════
 * 单次遍历扫描（基于长度边界，不依赖 strlen）
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
      /* 无效字节 — 跳过一字节以避免无限循环。 */
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
 * 辅助函数：从 Emacs 提取字符串，调用 scan_text
 * ═══════════════════════════════════════════════════════════════════ */

static int string_to_counts(emacs_env *env, emacs_value arg,
                            intmax_t *cjk, intmax_t *punct,
                            intmax_t *en_words, intmax_t *en_chars,
                            intmax_t *total_cp) {
  ptrdiff_t buf_size = 0;
  if (!env->copy_string_contents(env, arg, NULL, &buf_size))
    return -1;
  if (buf_size <= 1) {
    /* 空字符串（仅有空终止符）。 */
    *cjk = *punct = *en_words = *en_chars = *total_cp = 0;
    return 0;
  }

  char *buf = (char *)malloc(buf_size);
  if (!buf) return -1;

  if (!env->copy_string_contents(env, arg, buf, &buf_size)) {
    free(buf);
    return -1;
  }

  /* buf_size 包含空终止符；实际内容长度为 buf_size - 1 字节。 */
  scan_text((const uint8_t *)buf, buf_size - 1,
            cjk, punct, en_words, en_chars, total_cp);

  free(buf);
  return 0;
}

/* ═══════════════════════════════════════════════════════════════════
 * Lisp 函数：my/count-cjk
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
 * Lisp 函数：my/count-text
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
 * 模块初始化
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
