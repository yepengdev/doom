/* clipboard-wl.c — Emacs dynamic module: Wayland clipboard
 *
 * Direct Wayland protocol clipboard access (text, HTML, images).
 * No external binaries required.
 *
 * API:
 *   (clipboard-set MIME DATA [MIME DATA ...])  → t
 *   (clipboard-get MIME-TYPE)  → string or nil
 *   (clipboard-mime-types)     → ("text/plain" ...)
 */

#define _POSIX_C_SOURCE 200809L
#include <emacs-module.h>
#include <stdlib.h>
#include <string.h>
#include <stdio.h>
#include <unistd.h>
#include <fcntl.h>
#include <sys/stat.h>
#include <wayland-client.h>

int plugin_is_GPL_compatible;

/* ── Wayland globals ─────────────────────────────────────── */

static struct wl_display   *display    = NULL;
static struct wl_registry  *registry   = NULL;
static struct wl_seat      *seat       = NULL;
static struct wl_data_device_manager *ddm = NULL;
static struct wl_data_device         *data_device = NULL;
static struct wl_data_offer          *current_offer = NULL;
static int init_done = 0;
static int serial_counter = 0;  /* fallback serial for clipboard set */

/* ── Stored clipboard data (for copy source callbacks) ────── */

static struct wl_data_source *current_source = NULL;
static char  **src_mimes = NULL;
static char  **src_data  = NULL;
static size_t *src_lens  = NULL;
static int     src_count = 0;

static void free_src(void)
{
    for (int i = 0; i < src_count; i++)
        { free(src_mimes[i]); free(src_data[i]); }
    free(src_mimes); src_mimes = NULL;
    free(src_data);  src_data  = NULL;
    free(src_lens);  src_lens  = NULL;
    src_count = 0;
}

/* ── Offer listener (collects MIME types from clipboard) ──── */

struct mime_ctx { char **list; int count; int cap; };

static void offer_mime(void *d, struct wl_data_offer *o, const char *mime)
{
    (void)o;
    struct mime_ctx *c = d;
    if (c->count >= c->cap) {
        c->cap = c->cap ? c->cap * 2 : 8;
        c->list = realloc(c->list, sizeof(char *) * c->cap);
    }
    c->list[c->count] = malloc(strlen(mime) + 1);
    strcpy(c->list[c->count], mime);
    c->count++;
}

static const struct wl_data_offer_listener offer_listener = {
    .offer = offer_mime, .source_actions = NULL, .action = NULL,
};

/* ── Data device listener (captures clipboard selection) ──── */

static void dev_data_offer(void *d, struct wl_data_device *dev,
                            struct wl_data_offer *offer)
{
    (void)d; (void)dev; (void)offer;
}

static void dev_selection(void *d, struct wl_data_device *dev,
                           struct wl_data_offer *offer)
{
    (void)d; (void)dev;
    if (current_offer) wl_data_offer_destroy(current_offer);
    current_offer = offer;
    if (offer) wl_data_offer_add_listener(offer, &offer_listener, NULL);
}

static const struct wl_data_device_listener dev_listener = {
    .data_offer = dev_data_offer,
    .enter = NULL, .leave = NULL, .motion = NULL, .drop = NULL,
    .selection = dev_selection,
};

/* ── Data source listener (compositor pulls data when pasted) ── */

static void src_send(void *d, struct wl_data_source *s,
                      const char *mime, int32_t fd)
{
    (void)d; (void)s;
    for (int i = 0; i < src_count; i++) {
        if (strcmp(src_mimes[i], mime) == 0) {
            size_t rem = src_lens[i];
            char *p = src_data[i];
            while (rem > 0) {
                ssize_t r = write(fd, p, rem);
                if (r > 0) { p += r; rem -= r; }
                else break;
            }
            break;
        }
    }
    close(fd);
}

static void src_cancelled(void *d, struct wl_data_source *s)
{
    (void)d;
    wl_data_source_destroy(s);
    if (current_source == s) current_source = NULL;
}

static const struct wl_data_source_listener src_listener = {
    .send = src_send, .cancelled = src_cancelled,
};

/* ── Seat listener ────────────────────────────────────────── */

static void seat_caps(void *d, struct wl_seat *s, uint32_t caps)
{
    (void)d;
    if ((caps & WL_SEAT_CAPABILITY_POINTER) && !data_device) {
        data_device = wl_data_device_manager_get_data_device(ddm, s);
        wl_data_device_add_listener(data_device, &dev_listener, NULL);
    }
}

static const struct wl_seat_listener seat_listener = {
    .capabilities = seat_caps, .name = NULL,
};

/* ── Registry listener ────────────────────────────────────── */

static void reg_global(void *d, struct wl_registry *r, uint32_t n,
                        const char *iface, uint32_t ver)
{
    (void)d;
    if (strcmp(iface, "wl_seat") == 0) {
        seat = wl_registry_bind(r, n, &wl_seat_interface, ver < 7 ? ver : 7);
        wl_seat_add_listener(seat, &seat_listener, NULL);
    } else if (strcmp(iface, "wl_data_device_manager") == 0) {
        ddm = wl_registry_bind(r, n, &wl_data_device_manager_interface,
                               ver < 3 ? ver : 3);
    }
}

static const struct wl_registry_listener reg_listener = {
    .global = reg_global, .global_remove = NULL,
};

static int ensure_wl(void)
{
    if (init_done) return 0;
    if (!getenv("WAYLAND_DISPLAY")) return -1;

    display = wl_display_connect(NULL);
    if (!display) return -1;

    registry = wl_display_get_registry(display);
    wl_registry_add_listener(registry, &reg_listener, NULL);
    wl_display_roundtrip(display);
    wl_display_roundtrip(display);

    if (!ddm || !data_device) {
        wl_display_disconnect(display);
        display = NULL; return -1;
    }
    init_done = 1;
    return 0;
}

/* ════════════════════════════════════════════════════════════
 * Emacs-callable functions
 * ════════════════════════════════════════════════════════════ */

static emacs_value
Fset(emacs_env *env, ptrdiff_t nargs, emacs_value args[], void *data)
{
    (void)data;
    if (ensure_wl() != 0) return env->intern(env, "nil");
    if (nargs % 2 != 0) return env->intern(env, "nil");

    if (current_source) { wl_data_source_destroy(current_source); current_source = NULL; }
    free_src();

    int n = nargs / 2;
    src_mimes = calloc(n, sizeof(char *));
    src_data  = calloc(n, sizeof(char *));
    src_lens  = calloc(n, sizeof(size_t));
    src_count = 0;

    current_source = wl_data_device_manager_create_data_source(ddm);

    for (int i = 0; i < n; i++) {
        ptrdiff_t mlen = 0, dlen = 0;
        env->copy_string_contents(env, args[i*2],   NULL, &mlen);
        env->copy_string_contents(env, args[i*2+1], NULL, &dlen);
        char *mime = malloc(mlen);
        char *dbuf = malloc(dlen);
        env->copy_string_contents(env, args[i*2],   mime, &mlen);
        env->copy_string_contents(env, args[i*2+1], dbuf, &dlen);

        wl_data_source_offer(current_source, mime);
        src_mimes[i] = mime;
        src_data[i]  = dbuf;
        src_lens[i]  = dlen - 1;
        src_count++;
    }

    wl_data_source_add_listener(current_source, &src_listener, NULL);
    serial_counter++;
    wl_data_device_set_selection(data_device, current_source, serial_counter);
    wl_display_flush(display);
    return env->intern(env, "t");
}

static emacs_value
Fmime_types(emacs_env *env, ptrdiff_t nargs, emacs_value args[], void *data)
{
    (void)nargs; (void)args; (void)data;
    if (ensure_wl() != 0) return env->intern(env, "nil");

    wl_display_roundtrip(display);
    if (!current_offer) return env->intern(env, "nil");

    struct mime_ctx ctx = { .list = NULL, .count = 0, .cap = 0 };
    wl_data_offer_add_listener(current_offer, &offer_listener, &ctx);
    wl_display_roundtrip(display);

    emacs_value nil = env->intern(env, "nil");
    emacs_value cons = env->intern(env, "cons");
    emacs_value result = nil;
    for (int i = ctx.count - 1; i >= 0; i--) {
        emacs_value s = env->make_string(env, ctx.list[i], strlen(ctx.list[i]));
        result = env->funcall(env, cons, 2, (emacs_value[]){ s, result });
        free(ctx.list[i]);
    }
    free(ctx.list);
    return result;
}

static emacs_value
Fget(emacs_env *env, ptrdiff_t nargs, emacs_value args[], void *data)
{
    (void)nargs; (void)data;
    if (ensure_wl() != 0) return env->intern(env, "nil");

    ptrdiff_t want_len = 0;
    env->copy_string_contents(env, args[0], NULL, &want_len);
    char *want = malloc(want_len);
    env->copy_string_contents(env, args[0], want, &want_len);

    wl_display_roundtrip(display);
    if (!current_offer) { free(want); return env->intern(env, "nil"); }

    int fds[2];
    if (pipe(fds) != 0) { free(want); return env->intern(env, "nil"); }
    fcntl(fds[0], F_SETFD, FD_CLOEXEC);
    fcntl(fds[1], F_SETFD, FD_CLOEXEC);

    wl_data_offer_receive(current_offer, want, fds[1]);
    close(fds[1]);
    wl_display_roundtrip(display);
    wl_display_flush(display);

    size_t cap = 4096, len = 0;
    char *buf = malloc(cap);
    while (1) {
        ssize_t r = read(fds[0], buf + len, cap - len);
        if (r > 0) {
            len += r;
            if (cap - len < 1024) { cap *= 2; buf = realloc(buf, cap); }
        } else break;
    }
    close(fds[0]);
    free(want);

    if (len == 0) { free(buf); return env->intern(env, "nil"); }

    emacs_value result = env->make_string(env, buf, len);
    free(buf);
    return result;
}

/* ════════════════════════════════════════════════════════════
 * Module init
 * ════════════════════════════════════════════════════════════ */

int
emacs_module_init(struct emacs_runtime *ert)
{
    emacs_env *env = ert->get_environment(ert);
    if (!env) return 1;

    {
        emacs_value fn = env->make_function(env, 2, 100, Fset,
            "Set clipboard: (clipboard-set MIME DATA [MIME DATA ...])", NULL);
        env->funcall(env, env->intern(env, "defalias"), 2,
            (emacs_value[]){ env->intern(env, "clipboard-set"), fn });
    }
    {
        emacs_value fn = env->make_function(env, 1, 1, Fget,
            "Get clipboard data: (clipboard-get \"text/plain\").\n"
            "Returns unibyte string for non-text types.",
            NULL);
        env->funcall(env, env->intern(env, "defalias"), 2,
            (emacs_value[]){ env->intern(env, "clipboard-get"), fn });
    }
    {
        emacs_value fn = env->make_function(env, 0, 0, Fmime_types,
            "List MIME types on clipboard: (clipboard-mime-types)", NULL);
        env->funcall(env, env->intern(env, "defalias"), 2,
            (emacs_value[]){ env->intern(env, "clipboard-mime-types"), fn });
    }

    env->funcall(env, env->intern(env, "provide"), 1,
        (emacs_value[]){ env->intern(env, "clipboard-wl") });
    return 0;
}
