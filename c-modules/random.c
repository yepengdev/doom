/* random.c — Emacs 动态模块：真随机数生成器
 *
 * 熵源：getrandom(2) 系统调用（Linux 内核熵池），
 * 编译时不依赖外部库，仅需标准 C + emacs-module.h。
 *
 * 导出函数：
 *   (random-password &optional LENGTH) → 随机密码字符串
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

/* (random-password &optional LENGTH) → 随机密码字符串 */
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

    /* 拒绝采样消除模偏置：只接受 idx < reject_threshold 的值 */
    size_t pos = 0;
    size_t rand_size = (size_t)len * 4;
    uint8_t *rand_buf = (uint8_t *)malloc(rand_size);
    if (!rand_buf) { free(buf); signal_error(env, "random-password: memory allocation failed"); return intern_nil(env); }

    if (fill_random(rand_buf, rand_size) != 0) {
        free(rand_buf); free(buf);
        signal_error(env, "random-password: entropy source unavailable");
        return intern_nil(env);
    }

    uint8_t reject_threshold = (256 / pw_chars_len) * pw_chars_len;
    for (int i = 0; i < len; i++) {
        uint8_t idx;
        do {
            if (pos >= rand_size) {
                free(rand_buf);
                rand_size = (size_t)len * 4;
                rand_buf = (uint8_t *)malloc(rand_size);
                if (!rand_buf) { free(buf); signal_error(env, "random-password: memory allocation failed"); return intern_nil(env); }
                if (fill_random(rand_buf, rand_size) != 0) {
                    free(rand_buf); free(buf);
                    signal_error(env, "random-password: entropy source unavailable");
                    return intern_nil(env);
                }
                pos = 0;
            }
            idx = rand_buf[pos++];
        } while (idx >= reject_threshold);
        buf[i] = pw_chars[idx % pw_chars_len];
    }
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

    /* random-password */
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
