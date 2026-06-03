/* cnotify-module.c — Emacs 动态模块 (.so)
 *
 * 提供：
 *   桌面通知（libnotify），支持点击回调
 *   倒计时器 + 番茄钟（pthread 后台线程）
 *
 * API：
 *   (cnotify-notify TITLE BODY &optional CALLBACK)
 *                  → t  （点击时在主线程中调用 CALLBACK）
 *   (cnotify-timer-start MINUTES MSG)                → t
 *   (cnotify-timer-stop)                             → t
 *   (cnotify-pomodoro-start WORK-MIN BREAK-MIN)      → t
 *   (cnotify-pomodoro-stop)                          → t
 *   (cnotify-status)  → (TIMER-REMAINING . POMODORO-PHASE)
 *   (cnotify-poll-action) → t 表示通知被点击，否则返回 nil
 */

#include <emacs-module.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <signal.h>
#include <pthread.h>
#include <libnotify/notify.h>
#include <stdio.h>
#include <stdatomic.h>

int plugin_is_GPL_compatible;

/* ── 共享状态 ───────────────────────────────────────── */
static atomic_int timer_remaining;                  /* 倒计时剩余秒数 */
static atomic_int pomodoro_phase;                   /* 0=空闲, 1=工作, 2=休息 */
static atomic_bool timer_stop;                      /* 请求停止计时器 */
static atomic_bool pomodoro_stop;                   /* 请求停止番茄钟 */
static atomic_bool callback_pending;                /* 是否有待处理的通知点击 */
static emacs_value callback_fn        = NULL;       /* Emacs lambda 的全局引用 */
static pthread_t timer_tid    = 0;                  /* 计时器线程 ID */
static pthread_t pomodoro_tid = 0;                  /* 番茄钟线程 ID */

/* ── 辅助函数 ─────────────────────────────────────────────── */

/* 从 emacs_value 中提取 C 字符串 */
static char *
extract_string(emacs_env *env, emacs_value val)
{
    ptrdiff_t len = 0;
    env->copy_string_contents(env, val, NULL, &len);
    char *buf = malloc(len);
    if (!buf) return NULL;
    env->copy_string_contents(env, val, buf, &len);
    return buf;
}

static emacs_value
intern_t(emacs_env *env) { return env->intern(env, "t"); }

/* 向 Emacs 注册一个可调用函数 */
static void
register_fn(emacs_env *env, const char *name,
            emacs_value (*fn)(emacs_env *, ptrdiff_t, emacs_value[], void *),
            ptrdiff_t min, ptrdiff_t max, const char *doc)
{
    emacs_value fval = env->make_function(env, min, max, fn, doc, NULL);
    emacs_value sym  = env->intern(env, name);
    env->funcall(env, env->intern(env, "defalias"), 2,
                 (emacs_value[]){ sym, fval });
}

/* ── 带点击处理的通知 ──────────────────────────────────── */

/* 超时回调：退出 GLib 主循环 */
static gboolean click_timeout_cb(gpointer loop)
{
    g_main_loop_quit((GMainLoop *)loop);
    return G_SOURCE_REMOVE;
}

/* 通知点击动作回调：标记待处理状态并退出主循环 */
static void click_action_cb(NotifyNotification *n, char *action, gpointer data)
{
    (void)n; (void)action;
    callback_pending = 1;
    g_main_loop_quit((GMainLoop *)data);
}

/* 发送带动作按钮的通知。在 GLib 主循环中最多阻塞 5 秒。
   如果用户点击，设置 callback_pending 标志（由 Emacs 主线程中
   的 poll-action 消费）。运行在后台线程中。 */
static void notify_send_clickable(const char *title, const char *body)
{
    GMainContext *ctx = g_main_context_new();
    g_main_context_push_thread_default(ctx);
    GMainLoop *loop = g_main_loop_new(ctx, FALSE);

    NotifyNotification *n = notify_notification_new(title, body, NULL);
    notify_notification_set_timeout(n, 5000);
    notify_notification_add_action(n, "default", "Focus Emacs",
                                   click_action_cb, loop, NULL);
    notify_notification_show(n, NULL);

    GSource *src = g_timeout_source_new(5000);
    g_source_set_callback(src, click_timeout_cb, loop, NULL);
    g_source_attach(src, ctx);
    g_source_unref(src);

    g_main_loop_run(loop);

    g_main_loop_unref(loop);
    g_main_context_pop_thread_default(ctx);
    g_main_context_unref(ctx);
    g_object_unref(G_OBJECT(n));
}

/* ── 计时器线程 ────────────────────────────────────────── */

/* 计时器线程参数：秒数和完成时显示的消息 */
struct timer_arg { int seconds; char *message; };

/* 后台计时器线程：每秒递减，结束时发送通知 */
static void *
timer_thread(void *arg)
{
    struct timer_arg *ta = arg;
    timer_remaining = ta->seconds;

    for (int i = 0; i < ta->seconds; i++) {
        if (timer_stop) goto done;
        { int r = 1; while (r > 0) r = sleep(r); }
        timer_remaining = ta->seconds - i - 1;
    }
    if (!timer_stop)
        notify_send_clickable("⏱ Timer finished", ta->message);

done:
    timer_remaining = 0;
    free(ta->message);
    free(ta);
    return NULL;
}

/* ── 番茄钟（Pomodoro）线程 ─────────────────────────────── */

/* 番茄钟参数：工作和休息时长（秒） */
struct pomodoro_arg { int work_sec; int break_sec; };

/* 后台番茄钟线程：交替工作/休息阶段，直到被停止 */
static void *
pomodoro_thread(void *arg)
{
    struct pomodoro_arg *pa = arg;

    while (!pomodoro_stop) {
        pomodoro_phase = 1;
        timer_remaining = pa->work_sec;
        notify_send_clickable("🍅 Pomodoro", "Work phase started");
        for (int i = 0; i < pa->work_sec; i++) {
            if (pomodoro_stop) goto done;
            { int r = 1; while (r > 0) r = sleep(r); }
            timer_remaining = pa->work_sec - i - 1;
        }
        if (pomodoro_stop) break;
        notify_send_clickable("🍅 Pomodoro", "Work finished — take a break!");

        pomodoro_phase = 2;
        timer_remaining = pa->break_sec;
        for (int i = 0; i < pa->break_sec; i++) {
            if (pomodoro_stop) goto done;
            { int r = 1; while (r > 0) r = sleep(r); }
            timer_remaining = pa->break_sec - i - 1;
        }
        if (pomodoro_stop) break;
        notify_send_clickable("🍅 Pomodoro", "Break finished — back to work!");
    }

done:
    pomodoro_phase = 0;
    timer_remaining = 0;
    free(pa);
    return NULL;
}

/* ── Emacs 可调用函数 ─────────────────────────────────── */

/* 通知线程包装器，避免在主线程中阻塞 */
struct notify_arg { char *title; char *body; };

/* 通知线程入口：调用 notify_send_clickable 后清理资源 */
static void *
notify_thread(void *arg)
{
    struct notify_arg *na = arg;
    notify_send_clickable(na->title, na->body);
    free(na->title);
    free(na->body);
    free(na);
    return NULL;
}

/* (cnotify-notify TITLE BODY &optional CALLBACK) */
static emacs_value
Fnotify_notify(emacs_env *env, ptrdiff_t nargs,
               emacs_value args[], void *data)
{
    (void)data;
    char *title = extract_string(env, args[0]);
    char *body  = extract_string(env, args[1]);
    if (!title || !body) { free(title); free(body); return env->intern(env, "nil"); }

    /* 清除之前的回调 */
    if (callback_fn) {
        env->free_global_ref(env, callback_fn);
        callback_fn = NULL;
    }
    callback_pending = 0;

    /* 存储可选的第三个参数（lambda 回调） */
    if (nargs >= 3)
        callback_fn = env->make_global_ref(env, args[2]);

    /* 在后台线程中发送通知——不阻塞 Emacs */
    struct notify_arg *na = malloc(sizeof(*na));
    if (na) {
        na->title = title;
        na->body  = body;
        pthread_t tid;
        if (pthread_create(&tid, NULL, notify_thread, na) == 0)
            pthread_detach(tid);
        else
            { free(title); free(body); free(na); }
    } else {
        free(title); free(body);
    }

    return intern_t(env);
}

/* (cnotify-poll-action) —— 检查是否有待处理的点击事件 */
static emacs_value
Fpoll_action(emacs_env *env, ptrdiff_t nargs,
             emacs_value args[], void *data)
{
    (void)nargs; (void)args; (void)data;
    if (callback_pending && callback_fn) {
        callback_pending = 0;
        /* 执行存储的 lambda。运行在 Emacs 主线程中——安全。 */
        env->funcall(env, callback_fn, 0, NULL);
        env->free_global_ref(env, callback_fn);
        callback_fn = NULL;
        return intern_t(env);
    }
    return env->intern(env, "nil");
}

/* (cnotify-timer-start MINUTES MSG) —— 启动倒计时 */
static emacs_value
Ftimer_start(emacs_env *env, ptrdiff_t nargs,
             emacs_value args[], void *data)
{
    (void)nargs; (void)data;
    timer_stop = 1;
    if (timer_tid) { pthread_join(timer_tid, NULL); timer_tid = 0; }
    timer_stop = 0;

    struct timer_arg *ta = malloc(sizeof(*ta));
    if (!ta) return env->intern(env, "nil");
    ta->seconds = env->extract_integer(env, args[0]) * 60;
    ta->message = extract_string(env, args[1]);
    if (!ta->message) { free(ta); return env->intern(env, "nil"); }

    if (pthread_create(&timer_tid, NULL, timer_thread, ta) != 0) {
        free(ta->message); free(ta);
        return env->intern(env, "nil");
    }
    return intern_t(env);
}

/* (cnotify-timer-stop) —— 停止计时器 */
static emacs_value
Ftimer_stop(emacs_env *env, ptrdiff_t nargs,
            emacs_value args[], void *data)
{
    (void)nargs; (void)args; (void)data;
    timer_stop = 1;
    if (timer_tid) { pthread_join(timer_tid, NULL); timer_tid = 0; }
    timer_remaining = 0;
    return intern_t(env);
}

/* (cnotify-pomodoro-start WORK-MIN BREAK-MIN) —— 启动番茄钟 */
static emacs_value
Fpomodoro_start(emacs_env *env, ptrdiff_t nargs,
                emacs_value args[], void *data)
{
    (void)nargs; (void)data;
    pomodoro_stop = 1;
    if (pomodoro_tid) { pthread_join(pomodoro_tid, NULL); pomodoro_tid = 0; }
    pomodoro_stop = 0;

    struct pomodoro_arg *pa = malloc(sizeof(*pa));
    if (!pa) return env->intern(env, "nil");
    pa->work_sec  = env->extract_integer(env, args[0]) * 60;
    pa->break_sec = env->extract_integer(env, args[1]) * 60;

    if (pthread_create(&pomodoro_tid, NULL, pomodoro_thread, pa) != 0) {
        free(pa);
        return env->intern(env, "nil");
    }
    return intern_t(env);
}

/* (cnotify-pomodoro-stop) —— 停止番茄钟 */
static emacs_value
Fpomodoro_stop(emacs_env *env, ptrdiff_t nargs,
               emacs_value args[], void *data)
{
    (void)nargs; (void)args; (void)data;
    pomodoro_stop = 1;
    if (pomodoro_tid) { pthread_join(pomodoro_tid, NULL); pomodoro_tid = 0; }
    pomodoro_phase = 0;
    timer_remaining = 0;
    return intern_t(env);
}

/* (cnotify-status) —— 返回 (TIMER-REMAINING . POMODORO-PHASE) */
static emacs_value
Fstatus(emacs_env *env, ptrdiff_t nargs,
        emacs_value args[], void *data)
{
    (void)nargs; (void)args; (void)data;
    emacs_value cons_fn = env->intern(env, "cons");
    return env->funcall(env, cons_fn, 2,
           (emacs_value[]){
               env->make_integer(env, timer_remaining),
               env->make_integer(env, pomodoro_phase)
           });
}

/* ── 模块入口点 ──────────────────────────────────────── */

int
emacs_module_init(struct emacs_runtime *ert)
{
    emacs_env *env = ert->get_environment(ert);
    if (!env) return 1;

    if (!notify_init("cnotify"))
        return 1;

    /* 清理潜在残留线程（模块重载场景） */
    timer_stop = 1;
    pomodoro_stop = 1;
    if (timer_tid) { pthread_join(timer_tid, NULL); timer_tid = 0; }
    if (pomodoro_tid) { pthread_join(pomodoro_tid, NULL); pomodoro_tid = 0; }
    timer_stop = 0;
    pomodoro_stop = 0;
    timer_remaining = 0;
    pomodoro_phase = 0;
    callback_pending = 0;
    callback_fn = NULL;

    register_fn(env, "cnotify-notify",
                Fnotify_notify, 2, 3,
                "Send a clickable notification.\n"
                "(cnotify-notify TITLE BODY &optional CALLBACK)\n"
                "CALLBACK is a function (no args) called on click, from\n"
                "the Emacs main thread (via poll-action).");
    register_fn(env, "cnotify-timer-start",
                Ftimer_start, 2, 2,
                "Start countdown: (cnotify-timer-start MINUTES MSG).");
    register_fn(env, "cnotify-timer-stop",
                Ftimer_stop, 0, 0,
                "Stop running timer.");
    register_fn(env, "cnotify-pomodoro-start",
                Fpomodoro_start, 2, 2,
                "Start pomodoro: WORK-MIN / BREAK-MIN cycles.");
    register_fn(env, "cnotify-pomodoro-stop",
                Fpomodoro_stop, 0, 0,
                "Stop running pomodoro.");
    register_fn(env, "cnotify-status",
                Fstatus, 0, 0,
                "Return (TIMER-REMAINING . POMODORO-PHASE).");
    register_fn(env, "cnotify-poll-action",
                Fpoll_action, 0, 0,
                "Return t if notification clicked since last poll.\n"
                "Also invokes the stored callback lambda.  Call once per frame.");

    env->funcall(env, env->intern(env, "provide"), 1,
                 (emacs_value[]){ env->intern(env, "cnotify-module") });

    return 0;
}
