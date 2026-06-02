/* cnotify-module.c — Emacs dynamic module (.so)
 *
 * Provides desktop notifications (libnotify), countdown timer, and
 * pomodoro clock — all running in background threads, no Emacs blocking.
 *
 * API (loaded via (module-load "cnotify-module.so")):
 *   (cnotify-notify TITLE BODY)          → t
 *   (cnotify-timer-start SECONDS MSG)    → t
 *   (cnotify-timer-stop)                 → t
 *   (cnotify-pomodoro-start WORK-MIN BREAK-MIN)  → t
 *   (cnotify-pomodoro-stop)              → t
 */

#include <emacs-module.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <signal.h>
#include <pthread.h>
#include <libnotify/notify.h>
#include <stdio.h>

int plugin_is_GPL_compatible;

/* ── Thread state ────────────────────────────────────────── */
static volatile sig_atomic_t timer_stop  = 0;
static volatile sig_atomic_t pomodoro_stop = 0;
static pthread_t timer_tid     = 0;
static pthread_t pomodoro_tid  = 0;

/* ── Helpers ─────────────────────────────────────────────── */

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
intern_t(emacs_env *env)
{
    return env->intern(env, "t");
}

static void
notify_send(const char *title, const char *body)
{
    NotifyNotification *n = notify_notification_new(title, body, NULL);
    notify_notification_set_timeout(n, 5000);
    notify_notification_show(n, NULL);
    g_object_unref(G_OBJECT(n));
}

/* ── Timer thread ────────────────────────────────────────── */

struct timer_arg {
    int seconds;
    char *message;
};

static void *
timer_thread(void *arg)
{
    struct timer_arg *ta = arg;
    int sec = ta->seconds;
    char *msg = ta->message;

    for (int i = 0; i < sec; i++) {
        if (timer_stop) goto done;
        sleep(1);
    }
    if (!timer_stop)
        notify_send("⏱ Timer", msg);

done:
    free(msg);
    free(ta);
    return NULL;
}

/* ── Pomodoro thread ─────────────────────────────────────── */

struct pomodoro_arg {
    int work_sec;
    int break_sec;
};

static void *
pomodoro_thread(void *arg)
{
    struct pomodoro_arg *pa = arg;
    int cycle = 0;

    while (!pomodoro_stop) {
        cycle++;
        notify_send("🍅 Pomodoro", "Work phase started");
        for (int i = 0; i < pa->work_sec; i++) {
            if (pomodoro_stop) goto done;
            sleep(1);
        }
        if (pomodoro_stop) break;
        notify_send("🍅 Pomodoro", "Work finished — take a break!");

        for (int i = 0; i < pa->break_sec; i++) {
            if (pomodoro_stop) goto done;
            sleep(1);
        }
        if (pomodoro_stop) break;
        notify_send("🍅 Pomodoro", "Break finished — back to work!");
    }

done:
    free(pa);
    return NULL;
}

/* ── Emacs-callable functions ────────────────────────────── */

static emacs_value
Fnotify_notify(emacs_env *env, ptrdiff_t nargs,
               emacs_value args[], void *data)
{
    (void)nargs; (void)data;
    char *title = extract_string(env, args[0]);
    char *body  = extract_string(env, args[1]);
    if (title && body)
        notify_send(title, body);
    free(title);
    free(body);
    return intern_t(env);
}

static emacs_value
Ftimer_start(emacs_env *env, ptrdiff_t nargs,
             emacs_value args[], void *data)
{
    (void)nargs; (void)data;
    /* Cancel any running timer first */
    timer_stop = 1;
    if (timer_tid) {
        pthread_join(timer_tid, NULL);
        timer_tid = 0;
    }
    timer_stop = 0;

    struct timer_arg *ta = malloc(sizeof(*ta));
    if (!ta) return env->intern(env, "nil");
    ta->seconds = env->extract_integer(env, args[0]);
    ta->message = extract_string(env, args[1]);
    if (!ta->message) { free(ta); return env->intern(env, "nil"); }

    if (pthread_create(&timer_tid, NULL, timer_thread, ta) != 0) {
        free(ta->message);
        free(ta);
        return env->intern(env, "nil");
    }
    pthread_detach(timer_tid);
    return intern_t(env);
}

static emacs_value
Ftimer_stop(emacs_env *env, ptrdiff_t nargs,
            emacs_value args[], void *data)
{
    (void)nargs; (void)args; (void)data;
    timer_stop = 1;
    if (timer_tid) {
        pthread_join(timer_tid, NULL);
        timer_tid = 0;
    }
    notify_send("⏱ Timer", "Cancelled");
    return intern_t(env);
}

static emacs_value
Fpomodoro_start(emacs_env *env, ptrdiff_t nargs,
                emacs_value args[], void *data)
{
    (void)nargs; (void)data;
    /* Cancel any running pomodoro first */
    pomodoro_stop = 1;
    if (pomodoro_tid) {
        pthread_join(pomodoro_tid, NULL);
        pomodoro_tid = 0;
    }
    pomodoro_stop = 0;

    struct pomodoro_arg *pa = malloc(sizeof(*pa));
    if (!pa) return env->intern(env, "nil");
    pa->work_sec  = env->extract_integer(env, args[0]) * 60;
    pa->break_sec = env->extract_integer(env, args[1]) * 60;

    if (pthread_create(&pomodoro_tid, NULL, pomodoro_thread, pa) != 0) {
        free(pa);
        return env->intern(env, "nil");
    }
    pthread_detach(pomodoro_tid);
    return intern_t(env);
}

static emacs_value
Fpomodoro_stop(emacs_env *env, ptrdiff_t nargs,
               emacs_value args[], void *data)
{
    (void)nargs; (void)args; (void)data;
    pomodoro_stop = 1;
    if (pomodoro_tid) {
        pthread_join(pomodoro_tid, NULL);
        pomodoro_tid = 0;
    }
    notify_send("🍅 Pomodoro", "Stopped");
    return intern_t(env);
}

/* ── Module entry point ──────────────────────────────────── */

int
emacs_module_init(struct emacs_runtime *ert)
{
    emacs_env *env = ert->get_environment(ert);
    if (!env) return 1;

    /* Initialise libnotify once */
    if (!notify_init("cnotify"))
        return 1;

    /* Register functions under "cnotify-" prefix */
    env->make_function(env, 2, 2, Fnotify_notify,
                       "Send a desktop notification.", NULL);
    env->funcall(env, env->intern(env, "defalias"), 2,
                 (emacs_value[]){
                     env->intern(env, "cnotify-notify"),
                     env->intern(env, "Fnotify_notify")
                 });

    env->make_function(env, 2, 2, Ftimer_start,
                       "Start countdown: (cnotify-timer-start SECONDS MSG).", NULL);
    env->funcall(env, env->intern(env, "defalias"), 2,
                 (emacs_value[]){
                     env->intern(env, "cnotify-timer-start"),
                     env->intern(env, "Ftimer_start")
                 });

    env->make_function(env, 0, 0, Ftimer_stop,
                       "Stop running timer.", NULL);
    env->funcall(env, env->intern(env, "defalias"), 2,
                 (emacs_value[]){
                     env->intern(env, "cnotify-timer-stop"),
                     env->intern(env, "Ftimer_stop")
                 });

    env->make_function(env, 2, 2, Fpomodoro_start,
                       "Start pomodoro: (cnotify-pomodoro-start WORK-MIN BREAK-MIN).", NULL);
    env->funcall(env, env->intern(env, "defalias"), 2,
                 (emacs_value[]){
                     env->intern(env, "cnotify-pomodoro-start"),
                     env->intern(env, "Fpomodoro_start")
                 });

    env->make_function(env, 0, 0, Fpomodoro_stop,
                       "Stop running pomodoro.", NULL);
    env->funcall(env, env->intern(env, "defalias"), 2,
                 (emacs_value[]){
                     env->intern(env, "cnotify-pomodoro-stop"),
                     env->intern(env, "Fpomodoro_stop")
                 });

    /* Also create a single alias for the whole module namespace */
    env->funcall(env, env->intern(env, "provide"), 1,
                 (emacs_value[]){ env->intern(env, "cnotify-module") });

    return 0;
}
