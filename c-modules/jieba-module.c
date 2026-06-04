/* jieba-module.c — Emacs 动态模块：结巴中文分词 + 关键词提取 */

#include <emacs-module.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "cjieba/lib/jieba.h"

int plugin_is_GPL_compatible;

static Jieba g_jieba = NULL;
static Extractor g_extractor = NULL;

static int ensure_initialized(const char* dict_dir) {
  if (g_jieba && g_extractor) return 1;
  if (!dict_dir) return 0;

  size_t dlen = strlen(dict_dir);
  int has_slash = (dlen > 0 && dict_dir[dlen-1] == '/');

  char dict_path[1024], hmm_path[1024], user_path[1024];
  char idf_path[1024], stop_path[1024];

  snprintf(dict_path, sizeof(dict_path), "%s%sjieba.dict.utf8",
           dict_dir, has_slash ? "" : "/");
  snprintf(hmm_path,  sizeof(hmm_path),  "%s%shmm_model.utf8",
           dict_dir, has_slash ? "" : "/");
  snprintf(user_path, sizeof(user_path), "%s%suser.dict.utf8",
           dict_dir, has_slash ? "" : "/");
  snprintf(idf_path,  sizeof(idf_path),  "%s%sidf.utf8",
           dict_dir, has_slash ? "" : "/");
  snprintf(stop_path, sizeof(stop_path), "%s%sstop_words.utf8",
           dict_dir, has_slash ? "" : "/");

  g_jieba     = NewJieba(dict_path, hmm_path, user_path, idf_path, stop_path);
  g_extractor = NewExtractor(dict_path, hmm_path, idf_path, stop_path, user_path);

  return (g_jieba && g_extractor) ? 1 : 0;
}

static char* copy_string(emacs_env* env, emacs_value val, ptrdiff_t* out_len) {
  ptrdiff_t buf_size = 0;
  if (!env->copy_string_contents(env, val, NULL, &buf_size))
    return NULL;
  char* buf = (char*)malloc(buf_size);
  if (!buf) return NULL;
  env->copy_string_contents(env, val, buf, &buf_size);
  *out_len = buf_size - 1;
  return buf;
}

static emacs_value Fjieba_init(emacs_env* env, ptrdiff_t nargs,
                               emacs_value args[], void* data) {
  (void)nargs; (void)data;
  const char* dict_dir = NULL;
  char user_dir[1024];

  if (nargs > 0 && env->is_not_nil(env, args[0])) {
    ptrdiff_t len = 0;
    env->copy_string_contents(env, args[0], NULL, &len);
    if (len > 0 && len <= (ptrdiff_t)sizeof(user_dir)) {
      env->copy_string_contents(env, args[0], user_dir, &len);
      dict_dir = user_dir;
    }
  }

  if (!ensure_initialized(dict_dir))
    return env->intern(env, "nil");
  return env->intern(env, "t");
}

static emacs_value Fjieba_cut(emacs_env* env, ptrdiff_t nargs,
                              emacs_value args[], void* data) {
  (void)nargs; (void)data;
  if (!g_jieba) return env->intern(env, "nil");

  ptrdiff_t len;
  char* buf = copy_string(env, args[0], &len);
  if (!buf) return env->intern(env, "nil");

  CJiebaWord* words = Cut(g_jieba, buf, (size_t)len);
  if (!words) { free(buf); return env->intern(env, "nil"); }

  int count = 0;
  for (CJiebaWord* w = words; w->word; w++) count++;

  emacs_value nil = env->intern(env, "nil");
  emacs_value tail = nil;
  for (int i = count - 1; i >= 0; i--) {
    emacs_value s = env->make_string(env, words[i].word, (ptrdiff_t)words[i].len);
    tail = env->funcall(env, env->intern(env, "cons"), 2,
                        (emacs_value[]){ s, tail });
  }

  FreeWords(words);
  free(buf);
  return tail;
}

static emacs_value Fjieba_extract(emacs_env* env, ptrdiff_t nargs,
                                  emacs_value args[], void* data) {
  (void)nargs; (void)data;
  if (!g_extractor) return env->intern(env, "nil");

  ptrdiff_t len;
  char* buf = copy_string(env, args[0], &len);
  if (!buf) return env->intern(env, "nil");

  intmax_t topn = env->extract_integer(env, args[1]);
  if (topn <= 0) topn = 10;

  CJiebaWordWithWeight* words = ExtractWithWeight(g_extractor, buf, (size_t)len, (size_t)topn);
  if (!words) { free(buf); return env->intern(env, "nil"); }

  int count = 0;
  for (CJiebaWordWithWeight* w = words; w->word; w++) count++;

  emacs_value nil = env->intern(env, "nil");
  emacs_value tail = nil;
  for (int i = count - 1; i >= 0; i--) {
    emacs_value s = env->make_string(env, words[i].word, (ptrdiff_t)words[i].len);
    emacs_value wval = env->make_float(env, words[i].weight);
    emacs_value pair = env->funcall(env, env->intern(env, "cons"), 2,
                                    (emacs_value[]){ s, wval });
    tail = env->funcall(env, env->intern(env, "cons"), 2,
                        (emacs_value[]){ pair, tail });
  }

  FreeWordsWithWeight(words);
  free(buf);
  return tail;
}

static emacs_value Fjieba_tag(emacs_env* env, ptrdiff_t nargs,
                              emacs_value args[], void* data) {
  (void)nargs; (void)data;
  if (!g_jieba) return env->intern(env, "nil");

  ptrdiff_t len;
  char* buf = copy_string(env, args[0], &len);
  if (!buf) return env->intern(env, "nil");

  CJiebaWordWithTag* words = CutWithTag(g_jieba, buf, (size_t)len);
  if (!words) { free(buf); return env->intern(env, "nil"); }

  int count = 0;
  CJiebaWordWithTag** entries = NULL;
  {
    CJiebaWordWithTag* p = words;
    while (p->word) {
      count++;
      ptrdiff_t tag_len = strlen(p->tag);
      p = (CJiebaWordWithTag*)((char*)p + sizeof(CJiebaWordWithTag) + tag_len + 1);
    }
    entries = (CJiebaWordWithTag**)malloc((size_t)count * sizeof(CJiebaWordWithTag*));
    if (!entries) { FreeWordTag(words); free(buf); return env->intern(env, "nil"); }
    p = words;
    for (int i = 0; i < count; i++) {
      entries[i] = p;
      ptrdiff_t tag_len = strlen(p->tag);
      p = (CJiebaWordWithTag*)((char*)p + sizeof(CJiebaWordWithTag) + tag_len + 1);
    }
  }

  emacs_value nil = env->intern(env, "nil");
  emacs_value tail = nil;

  for (int i = count - 1; i >= 0; i--) {
    CJiebaWordWithTag* p = entries[i];
    ptrdiff_t tag_len = strlen(p->tag);
    emacs_value word_s = env->make_string(env, p->word, (ptrdiff_t)p->len);
    emacs_value tag_s  = env->make_string(env, p->tag, tag_len);
    emacs_value pair = env->funcall(env, env->intern(env, "cons"), 2,
                                    (emacs_value[]){ word_s, tag_s });
    tail = env->funcall(env, env->intern(env, "cons"), 2,
                        (emacs_value[]){ pair, tail });
  }
  free(entries);

  FreeWordTag(words);
  free(buf);
  return tail;
}

int emacs_module_init(struct emacs_runtime* ert) {
  emacs_env* env = ert->get_environment(ert);
  if (!env) return 1;

  {
    emacs_value func = env->make_function(
        env, 0, 1, Fjieba_init,
        "Initialize jieba with dicts from DICT-DIR.\n"
        "If omitted, uses default path relative to doom-user-dir.",
        NULL);
    env->funcall(env, env->intern(env, "defalias"), 2,
                 (emacs_value[]){ env->intern(env, "my/jieba-init"), func });
  }
  {
    emacs_value func = env->make_function(
        env, 1, 1, Fjieba_cut,
        "Cut TEXT into a list of words using jieba segmentation.",
        NULL);
    env->funcall(env, env->intern(env, "defalias"), 2,
                 (emacs_value[]){ env->intern(env, "my/jieba-cut"), func });
  }
  {
    emacs_value func = env->make_function(
        env, 2, 2, Fjieba_extract,
        "Extract TOP-N keywords from TEXT using TF-IDF.\n"
        "Returns alist of (WORD . WEIGHT).",
        NULL);
    env->funcall(env, env->intern(env, "defalias"), 2,
                 (emacs_value[]){ env->intern(env, "my/jieba-extract"), func });
  }
  {
    emacs_value func = env->make_function(
        env, 1, 1, Fjieba_tag,
        "Tag each word in TEXT with its part-of-speech.\n"
        "Returns alist of (WORD . TAG).",
        NULL);
    env->funcall(env, env->intern(env, "defalias"), 2,
                 (emacs_value[]){ env->intern(env, "my/jieba-tag"), func });
  }

  env->funcall(env, env->intern(env, "provide"), 1,
               (emacs_value[]){ env->intern(env, "jieba-module") });

  return env->non_local_exit_check(env) == emacs_funcall_exit_return ? 0 : 1;
}
