/* cnotify-module.c — Emacs dynamic module (.so)
 *
 * Provides:
 *   Desktop notifications (libnotify)
 *   Countdown timer + pomodoro clock (pthread background)
 *
 * API (loaded via (module-load "cnotify-module.so")):
 *   (cnotify-notify TITLE BODY)                      → t
 *   (cnotify-timer-start SECONDS MSG)                → t
 *   (cnotify-timer-stop)                             → t
 *   (cnotify-pomodoro-start WORK-MIN BREAK-MIN)      → t
 *   (cnotify-pomodoro-stop)                          → t
 *   (cnotify-status)  → (TIMER-REMAINING POMODORO-PHASE)
 *     TIMER-REMAINING: seconds left (0 = not running)
 *     POMODORO-PHASE:  0=idle, 1=work, 2=break
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

/* ── Shared status (readable from Emacs main thread) ────── */
static volatile int timer_remaining   = 0;
static volatile int pomodoro_phase    = 0;  /* 0=idle, 1=work, 2=break */
static volatile int timer_stop        = 0;
static volatile int pomodoro_stop     = 0;
static pthread_t timer_tid    = 0;
static pthread_t pomodoro_tid = 0;

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

    timer_remaining = sec;

    for (int i = 0; i < sec; i++) {
        if (timer_stop) goto done;
        sleep(1);
        timer_remaining = sec - i - 1;
    }
    if (!timer_stop)
        notify_send("⏱ Timer", msg);

done:
    timer_remaining = 0;
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

    while (!pomodoro_stop) {
        /* Work phase */
        pomodoro_phase = 1;
        notify_send("🍅 Pomodoro", "Work phase started");
        for (int i = 0; i < pa->work_sec; i++) {
            if (pomodoro_stop) goto done;
            sleep(1);
        }
        if (pomodoro_stop) break;
        notify_send("🍅 Pomodoro", "Work finished — take a break!");

        /* Break phase */
        pomodoro_phase = 2;
        for (int i = 0; i < pa->break_sec; i++) {
            if (pomodoro_stop) goto done;
            sleep(1);
        }
        if (pomodoro_stop) break;
        notify_send("🍅 Pomodoro", "Break finished — back to work!");
    }

done:
    pomodoro_phase = 0;
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
    timer_remaining = 0;
    notify_send("⏱ Timer", "Cancelled");
    return intern_t(env);
}

static emacs_value
Fpomodoro_start(emacs_env *env, ptrdiff_t nargs,
                emacs_value args[], void *data)
{
    (void)nargs; (void)data;
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
    pomodoro_phase = 0;
    notify_send("🍅 Pomodoro", "Stopped");
    return intern_t(env);
}

static emacs_value
Fstatus(emacs_env *env, ptrdiff_t nargs,
        emacs_value args[], void *data)
{
    (void)nargs; (void)args; (void)data;
    /* Return cons (TIMER-REMAINING . POMODORO-PHASE) */
    emacs_value cons_fn = env->intern(env, "cons");
    return env->funcall(env, cons_fn, 2,
           (emacs_value[]){
               env->make_integer(env, timer_remaining),
               env->make_integer(env, pomodoro_phase)
           });
}

/* ── Module entry point ──────────────────────────────────── */

int
emacs_module_init(struct emacs_runtime *ert)
{
    emacs_env *env = ert->get_environment(ert);
    if (!env) return 1;

    if (!notify_init("cnotify"))
        return 1;

    register_fn(env, "cnotify-notify",
                Fnotify_notify, 2, 2,
                "Send a desktop notification with TITLE and BODY.");
    register_fn(env, "cnotify-timer-start",
                Ftimer_start, 2, 2,
                "Start a countdown timer for SECONDS, notify with MSG on finish.");
    register_fn(env, "cnotify-timer-stop",
                Ftimer_stop, 0, 0,
                "Stop the running countdown timer.");
    register_fn(env, "cnotify-pomodoro-start",
                Fpomodoro_start, 2, 2,
                "Start pomodoro: WORK-MIN focus / BREAK-MIN rest cycles.");
    register_fn(env, "cnotify-pomodoro-stop",
                Fpomodoro_stop, 0, 0,
                "Stop the running pomodoro.");
    register_fn(env, "cnotify-status",
                Fstatus, 0, 0,
                "Return (TIMER-REMAINING . POMODORO-PHASE).\n"
                "  TIMER-REMAINING: seconds left (0 = not running)\n"
                "  POMODORO-PHASE:  0=idle, 1=work, 2=break");

    env->funcall(env, env->intern(env, "provide"), 1,
                 (emacs_value[]){ env->intern(env, "cnotify-module") });

    return 0;
}
