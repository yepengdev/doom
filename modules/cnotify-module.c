/* cnotify-module.c — Emacs dynamic module (.so)
 *
 * Provides:
 *   Desktop notifications (libnotify) with click-to-callback
 *   Countdown timer + pomodoro clock (pthread background)
 *
 * API:
 *   (cnotify-notify TITLE BODY &optional CALLBACK)
 *                  → t  (CALLBACK is called on click, from Emacs main thread)
 *   (cnotify-timer-start MINUTES MSG)                → t
 *   (cnotify-timer-stop)                             → t
 *   (cnotify-pomodoro-start WORK-MIN BREAK-MIN)      → t
 *   (cnotify-pomodoro-stop)                          → t
 *   (cnotify-status)  → (TIMER-REMAINING . POMODORO-PHASE)
 *   (cnotify-poll-action) → t if notification was clicked, nil otherwise
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

/* ── Shared status ───────────────────────────────────────── */
static volatile int timer_remaining   = 0;
static volatile int pomodoro_phase    = 0;  /* 0=idle, 1=work, 2=break */
static volatile int timer_stop        = 0;
static volatile int pomodoro_stop     = 0;
static volatile int callback_pending  = 0;
static emacs_value callback_fn        = NULL;   /* global ref to Emacs lambda */
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
intern_t(emacs_env *env) { return env->intern(env, "t"); }

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

/* ── Notifications with click handling ───────────────────── */

static gboolean click_timeout_cb(gpointer loop)
{
    g_main_loop_quit((GMainLoop *)loop);
    return G_SOURCE_REMOVE;
}

static void click_action_cb(NotifyNotification *n, char *action, gpointer data)
{
    (void)n; (void)action;
    callback_pending = 1;
    g_main_loop_quit((GMainLoop *)data);
}

/* Send notification with action. Blocks up to 5s in GLib main loop.
   If the user clicks, callback_pending is set (consumed by poll-action
   in the Emacs main thread). Runs in background threads. */
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

/* ── Timer thread ────────────────────────────────────────── */

struct timer_arg { int seconds; char *message; };

static void *
timer_thread(void *arg)
{
    struct timer_arg *ta = arg;
    timer_remaining = ta->seconds;

    for (int i = 0; i < ta->seconds; i++) {
        if (timer_stop) goto done;
        sleep(1);
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

/* ── Pomodoro thread ─────────────────────────────────────── */

struct pomodoro_arg { int work_sec; int break_sec; };

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
            sleep(1);
            timer_remaining = pa->work_sec - i - 1;
        }
        if (pomodoro_stop) break;
        notify_send_clickable("🍅 Pomodoro", "Work finished — take a break!");

        pomodoro_phase = 2;
        timer_remaining = pa->break_sec;
        for (int i = 0; i < pa->break_sec; i++) {
            if (pomodoro_stop) goto done;
            sleep(1);
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

/* ── Emacs-callable functions ────────────────────────────── */

/* Thread wrapper for notify_send_clickable — prevents blocking Emacs */
struct notify_arg { char *title; char *body; };

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

static emacs_value
Fnotify_notify(emacs_env *env, ptrdiff_t nargs,
               emacs_value args[], void *data)
{
    (void)data;
    char *title = extract_string(env, args[0]);
    char *body  = extract_string(env, args[1]);
    if (!title || !body) { free(title); free(body); return env->intern(env, "nil"); }

    /* Clear previous callback */
    if (callback_fn) {
        env->free_global_ref(env, callback_fn);
        callback_fn = NULL;
    }
    callback_pending = 0;

    /* Store optional 3rd arg (lambda callback) */
    if (nargs >= 3)
        callback_fn = env->make_global_ref(env, args[2]);

    /* Launch notification in background thread — don't block Emacs */
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

static emacs_value
Fpoll_action(emacs_env *env, ptrdiff_t nargs,
             emacs_value args[], void *data)
{
    (void)nargs; (void)args; (void)data;
    if (callback_pending && callback_fn) {
        callback_pending = 0;
        /* Invoke the stored lambda. Runs in Emacs main thread — safe. */
        env->funcall(env, callback_fn, 0, NULL);
        env->free_global_ref(env, callback_fn);
        callback_fn = NULL;
        return intern_t(env);
    }
    return env->intern(env, "nil");
}

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
    pthread_detach(timer_tid);
    return intern_t(env);
}

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
    pthread_detach(pomodoro_tid);
    return intern_t(env);
}

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

/* ── Module entry point ──────────────────────────────────── */

int
emacs_module_init(struct emacs_runtime *ert)
{
    emacs_env *env = ert->get_environment(ert);
    if (!env) return 1;

    if (!notify_init("cnotify"))
        return 1;

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
