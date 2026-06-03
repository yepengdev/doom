/* random.c — Emacs 动态模块：真随机数生成器
 *
 * 熵源：getrandom(2) 系统调用（Linux 内核熵池），
 * 编译时不依赖外部库，仅需标准 C + emacs-module.h。
 *
 * 导出函数：
 *   (my/random-bytes N)          → 包含 N 个随机字节的字符串
 *   (my/random-int N)            → [0, N-1] 范围内的随机整数
 *   (my/random-in-range MIN MAX) → [MIN, MAX] 范围内的随机整数
 *   (my/random-password &optional LENGTH) → 随机密码字符串
 *
 * 安全性：getrandom() 从内核熵池读取，不经过用户空间 PRNG。
 * 适用于密钥生成、密码、Token 等安全敏感场景。
 * 如果 getrandom() 不可用，自动回退到 /dev/urandom。
 */

#define _GNU_SOURCE
#include <sys/random.h>
#include <emacs-module.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <fcntl.h>
#include <errno.h>

int plugin_is_GPL_compatible;

/* ── 熵源层 ───────────────────────────────────────────── */

/* 尝试用 getrandom(2) 填充 buf，失败时返回 -1。 */
static int fill_from_getrandom(void *buf, size_t len) {
    size_t total = 0;
    uint8_t *p = (uint8_t *)buf;
    while (total < len) {
        ssize_t r = getrandom(p + total, len - total, 0);
        if (r < 0) {
            if (errno == EINTR) continue;
            return -1;
        }
        total += r;
    }
    return 0;
}

/* 用 /dev/urandom 填充 buf，失败时返回 -1。 */
static int fill_from_urandom(void *buf, size_t len) {
    int fd = open("/dev/urandom", O_RDONLY);
    if (fd < 0) return -1;

    size_t total = 0;
    uint8_t *p = (uint8_t *)buf;
    while (total < len) {
        ssize_t r = read(fd, p + total, len - total);
        if (r < 0) {
            if (errno == EINTR) continue;
            close(fd);
            return -1;
        }
        total += r;
    }
    close(fd);
    return 0;
}

/* 填充随机字节：优先 getrandom，失败则回退 urandom。 */
static int fill_random(void *buf, size_t len) {
    if (fill_from_getrandom(buf, len) == 0)
        return 0;
    return fill_from_urandom(buf, len);
}

/* ── Emacs 辅助 ──────────────────────────────────────── */

static emacs_value intern_nil(emacs_env *env) {
    return env->intern(env, "nil");
}

static void signal_error(emacs_env *env, const char *msg) {
    env->non_local_exit_signal(
        env, env->intern(env, "error"),
        env->make_string(env, msg, strlen(msg)));
}

/* ═══════════════════════════════════════════════════════════════════
 * 导出函数
 * ═══════════════════════════════════════════════════════════════════ */

/* (my/random-bytes N) → 包含 N 个随机字节的字符串 */
static emacs_value
Frandom_bytes(emacs_env *env, ptrdiff_t nargs,
              emacs_value args[], void *data) {
    (void)nargs; (void)data;
    intmax_t n = env->extract_integer(env, args[0]);
    if (n <= 0) return intern_nil(env);
    if (n > 65536) n = 65536;

    uint8_t *buf = (uint8_t *)malloc((size_t)n);
    if (!buf) { signal_error(env, "random-bytes: memory allocation failed"); return intern_nil(env); }

    if (fill_random(buf, (size_t)n) != 0) {
        free(buf);
        signal_error(env, "random-bytes: entropy source unavailable");
        return intern_nil(env);
    }

    emacs_value result = env->make_string(env, (char *)buf, (ptrdiff_t)n);
    free(buf);
    return result;
}

/* (my/random-int N) → [0, N-1] 范围内的随机整数 */
static emacs_value
Frandom_int(emacs_env *env, ptrdiff_t nargs,
            emacs_value args[], void *data) {
    (void)nargs; (void)data;
    intmax_t range = env->extract_integer(env, args[0]);
    if (range <= 0) { signal_error(env, "random-int: N must be positive"); return intern_nil(env); }

    uint64_t val;
    if (fill_random(&val, sizeof(val)) != 0) {
        signal_error(env, "random-int: entropy source unavailable");
        return intern_nil(env);
    }
    return env->make_integer(env, (intmax_t)(val % (uint64_t)range));
}

/* (my/random-in-range MIN MAX) → [MIN, MAX] 范围内的随机整数 */
static emacs_value
Frandom_in_range(emacs_env *env, ptrdiff_t nargs,
                 emacs_value args[], void *data) {
    (void)nargs; (void)data;
    intmax_t min = env->extract_integer(env, args[0]);
    intmax_t max = env->extract_integer(env, args[1]);
    if (min > max) { signal_error(env, "random-in-range: MIN must be <= MAX"); return intern_nil(env); }

    uint64_t range = (uint64_t)(max - min + 1);
    uint64_t val;
    if (fill_random(&val, sizeof(val)) != 0) {
        signal_error(env, "random-in-range: entropy source unavailable");
        return intern_nil(env);
    }
    return env->make_integer(env, (intmax_t)(min + (intmax_t)(val % range)));
}

/* (my/random-password &optional LENGTH) → 随机密码字符串 */
static const char pw_chars[] =
    "abcdefghijklmnopqrstuvwxyz"
    "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
    "0123456789"
    "!@#$%^&*()-_=+[]{}|;:,.<>?";
static const int pw_chars_len = sizeof(pw_chars) - 1;

static emacs_value
Frandom_password(emacs_env *env, ptrdiff_t nargs,
                 emacs_value args[], void *data) {
    (void)data;
    int len = 24;
    if (nargs >= 1)
        len = (int)env->extract_integer(env, args[0]);
    if (len < 4) len = 4;
    if (len > 256) len = 256;

    char *buf = (char *)malloc((size_t)len + 1);
    if (!buf) { signal_error(env, "random-password: memory allocation failed"); return intern_nil(env); }

    /* 一次性读取足够多的随机字节 */
    size_t rand_size = (size_t)len * 2;
    uint8_t *rand_buf = (uint8_t *)malloc(rand_size);
    if (!rand_buf) { free(buf); signal_error(env, "random-password: memory allocation failed"); return intern_nil(env); }

    if (fill_random(rand_buf, rand_size) != 0) {
        free(rand_buf); free(buf);
        signal_error(env, "random-password: entropy source unavailable");
        return intern_nil(env);
    }

    for (int i = 0; i < len; i++)
        buf[i] = pw_chars[rand_buf[i] % pw_chars_len];
    buf[len] = '\0';

    free(rand_buf);
    emacs_value result = env->make_string(env, buf, (ptrdiff_t)len);
    free(buf);
    return result;
}

/* ═══════════════════════════════════════════════════════════════════
 * 模块入口
 * ═══════════════════════════════════════════════════════════════════ */

int
emacs_module_init(struct emacs_runtime *ert) {
    emacs_env *env = ert->get_environment(ert);
    if (!env) return 1;

    /* my/random-bytes */
    {
        emacs_value fn = env->make_function(
            env, 1, 1, Frandom_bytes,
            "返回 N 个随机字节的字符串。\n"
            "(my/random-bytes N)\n"
            "熵源：getrandom(2)，回退 /dev/urandom。最大 65536 字节。",
            NULL);
        env->funcall(env, env->intern(env, "defalias"), 2,
            (emacs_value[]){ env->intern(env, "my/random-bytes"), fn });
    }

    /* my/random-int */
    {
        emacs_value fn = env->make_function(
            env, 1, 1, Frandom_int,
            "返回 [0, N-1] 范围内的随机整数。\n"
            "(my/random-int N)",
            NULL);
        env->funcall(env, env->intern(env, "defalias"), 2,
            (emacs_value[]){ env->intern(env, "my/random-int"), fn });
    }

    /* my/random-in-range */
    {
        emacs_value fn = env->make_function(
            env, 2, 2, Frandom_in_range,
            "返回 [MIN, MAX] 范围内的随机整数。\n"
            "(my/random-in-range MIN MAX)",
            NULL);
        env->funcall(env, env->intern(env, "defalias"), 2,
            (emacs_value[]){ env->intern(env, "my/random-in-range"), fn });
    }

    /* my/random-password */
    {
        emacs_value fn = env->make_function(
            env, 0, 1, Frandom_password,
            "生成随机密码字符串。\n"
            "(random-password &optional LENGTH)\n"
            "默认长度 24，范围 4-256。字符集：a-zA-Z0-9 + 符号。",
            NULL);
        env->funcall(env, env->intern(env, "defalias"), 2,
            (emacs_value[]){ env->intern(env, "random-password"), fn });
    }

    env->funcall(env, env->intern(env, "provide"), 1,
        (emacs_value[]){ env->intern(env, "random-module") });

    return 0;
}
