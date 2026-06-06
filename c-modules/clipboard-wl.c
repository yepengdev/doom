/* clipboard-wl.c — Emacs module: Wayland clipboard integration
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
#include <unistd.h>
#include <fcntl.h>
#include <wayland-client.h>

int plugin_is_GPL_compatible;

static struct wl_display   *display   = NULL;
static struct wl_data_device_manager *ddm = NULL;
static struct wl_data_device         *data_device = NULL;
static struct wl_registry             *registry = NULL;
static struct wl_data_offer          *current_offer = NULL;
struct wl_seat *seat = NULL;
int init_done = 0;
int serial = 0;

/* Copy source state */
static struct wl_data_source *cur_src = NULL;
static char **s_mime = NULL, **s_data = NULL;
static size_t *s_len = NULL;
static int s_cnt = 0;

static void free_src(void) {
    for (int i = 0; i < s_cnt; i++) { free(s_mime[i]); free(s_data[i]); }
    free(s_mime); free(s_data); free(s_len);
    s_mime = NULL; s_data = NULL; s_len = NULL; s_cnt = 0;
}

/* ── Source listener ──────────────────────────── */
static void src_send(void *d, struct wl_data_source *s, const char *m, int32_t fd) {
    (void)d; (void)s;
    for (int i = 0; i < s_cnt; i++)
        if (strcmp(s_mime[i], m) == 0) {
            size_t rem = s_len[i]; char *p = s_data[i];
            while (rem > 0) { ssize_t r = write(fd, p, rem); if (r > 0) { p += r; rem -= r; } else break; }
            break;
        }
    close(fd);
}
static void src_cancel(void *d, struct wl_data_source *s) {
    (void)d; wl_data_source_destroy(s); if (cur_src == s) cur_src = NULL;
}
static const struct wl_data_source_listener src_listen = {
    .send = src_send, .cancelled = src_cancel,
};

/* ── Offer listener ───────────────────────────── */
struct mime_ctx { char **list; int cnt, cap; };
static void off_mime(void *d, struct wl_data_offer *o, const char *m) {
    (void)o; struct mime_ctx *c = d;
    if (c->cnt >= c->cap) c->list = realloc(c->list, sizeof(char*)*(c->cap = c->cap?c->cap*2:8));
    c->list[c->cnt] = strdup(m); c->cnt++;
}
static const struct wl_data_offer_listener off_listen = { .offer = off_mime, .source_actions = NULL, .action = NULL };

/* ── Device listener ──────────────────────────── */
static void dev_data_offer(void *d, struct wl_data_device *dev, struct wl_data_offer *o) { (void)d; (void)dev; (void)o; }
static void dev_selection(void *d, struct wl_data_device *dev, struct wl_data_offer *o) {
    (void)d; (void)dev;
    if (current_offer) wl_data_offer_destroy(current_offer);
    current_offer = o;
    if (o) wl_data_offer_add_listener(o, &off_listen, NULL);
}
static const struct wl_data_device_listener dev_listen = {
    .data_offer = dev_data_offer, .enter = NULL, .leave = NULL, .motion = NULL, .drop = NULL,
    .selection = dev_selection,
};

/* ── Seat listener ────────────────────────────── */
static void seat_caps(void *d, struct wl_seat *s, uint32_t caps) {
    (void)d;
    if ((caps & WL_SEAT_CAPABILITY_POINTER) && !data_device)
        data_device = wl_data_device_manager_get_data_device(ddm, s),
        wl_data_device_add_listener(data_device, &dev_listen, NULL);
}
static const struct wl_seat_listener seat_listen = { .capabilities = seat_caps, .name = NULL };

/* ── Registry listener ────────────────────────── */
static void reg_global(void *d, struct wl_registry *r, uint32_t n, const char *iface, uint32_t ver) {
    (void)d;
    if (strcmp(iface, "wl_seat") == 0)
        seat = wl_registry_bind(r, n, &wl_seat_interface, ver < 7 ? ver : 7),
        wl_seat_add_listener(seat, &seat_listen, NULL);
    else if (strcmp(iface, "wl_data_device_manager") == 0)
        ddm = wl_registry_bind(r, n, &wl_data_device_manager_interface, ver < 3 ? ver : 3);
}
static const struct wl_registry_listener reg_listen = { .global = reg_global, .global_remove = NULL };

static int ensure_wl(void) {
    if (init_done) return 0;
    if (!getenv("WAYLAND_DISPLAY")) return -1;
    display = wl_display_connect(NULL);
    if (!display) return -1;
    registry = wl_display_get_registry(display);
    wl_registry_add_listener(registry, &reg_listen, NULL);
    wl_display_roundtrip(display); wl_display_roundtrip(display);
    if (!ddm || !data_device) { wl_display_disconnect(display); display = NULL; return -1; }
    init_done = 1;
    return 0;
}

/* ═══════════════════════════════════════════════
 * Emacs Lisp functions
 * ═══════════════════════════════════════════════ */

static emacs_value Fset(emacs_env *e, ptrdiff_t n, emacs_value a[], void *d) {
    (void)d;
    if (ensure_wl() != 0 || n % 2 != 0) return e->intern(e, "nil");
    if (cur_src) { wl_data_source_destroy(cur_src); cur_src = NULL; }
    free_src();
    int c = n / 2;
    s_mime = calloc(c, sizeof(char*)); s_data = calloc(c, sizeof(char*)); s_len = calloc(c, sizeof(size_t));
    s_cnt = 0;
    cur_src = wl_data_device_manager_create_data_source(ddm);
    for (int i = 0; i < c; i++) {
        ptrdiff_t ml = 0, dl = 0;
        e->copy_string_contents(e, a[i*2],   NULL, &ml);
        e->copy_string_contents(e, a[i*2+1], NULL, &dl);
        char *mime = malloc(ml), *dbuf = malloc(dl);
        e->copy_string_contents(e, a[i*2],   mime, &ml);
        e->copy_string_contents(e, a[i*2+1], dbuf, &dl);
        wl_data_source_offer(cur_src, mime);
        s_mime[i] = mime; s_data[i] = dbuf; s_len[i] = dl - 1; s_cnt++;
    }
    wl_data_source_add_listener(cur_src, &src_listen, NULL);
    serial++; wl_data_device_set_selection(data_device, cur_src, serial);
    wl_display_flush(display);
    return e->intern(e, "t");
}

static emacs_value Fmime_types(emacs_env *e, ptrdiff_t n, emacs_value a[], void *d) {
    (void)n; (void)a; (void)d;
    if (ensure_wl() != 0) return e->intern(e, "nil");
    wl_display_roundtrip(display);
    if (!current_offer) return e->intern(e, "nil");
    struct mime_ctx ctx = {0};
    wl_data_offer_add_listener(current_offer, &off_listen, &ctx);
    wl_display_roundtrip(display);
    emacs_value nil = e->intern(e, "nil"), cons = e->intern(e, "cons"), r = nil;
    for (int i = ctx.cnt - 1; i >= 0; i--) {
        emacs_value s = e->make_string(e, ctx.list[i], strlen(ctx.list[i]));
        r = e->funcall(e, cons, 2, (emacs_value[]){ s, r });
        free(ctx.list[i]);
    }
    free(ctx.list);
    return r;
}

static emacs_value Fget(emacs_env *e, ptrdiff_t n, emacs_value a[], void *d) {
    (void)n; (void)d;
    if (ensure_wl() != 0) return e->intern(e, "nil");
    ptrdiff_t wl = 0;
    e->copy_string_contents(e, a[0], NULL, &wl);
    char *want = malloc(wl);
    e->copy_string_contents(e, a[0], want, &wl);
    wl_display_roundtrip(display);
    if (!current_offer) { free(want); return e->intern(e, "nil"); }
    int fds[2];
    if (pipe(fds) != 0) { free(want); return e->intern(e, "nil"); }
    fcntl(fds[0], F_SETFD, FD_CLOEXEC); fcntl(fds[1], F_SETFD, FD_CLOEXEC);
    wl_data_offer_receive(current_offer, want, fds[1]);
    close(fds[1]);
    wl_display_roundtrip(display);
    wl_display_flush(display);
    size_t cap = 4096, len = 0; char *buf = malloc(cap);
    while (1) {
        ssize_t r = read(fds[0], buf + len, cap - len);
        if (r > 0) { len += r; if (cap - len < 1024) { cap *= 2; buf = realloc(buf, cap); } }
        else break;
    }
    close(fds[0]); free(want);
    if (len == 0) { free(buf); return e->intern(e, "nil"); }
    emacs_value r = e->make_string(e, buf, len);
    free(buf); return r;
}

int emacs_module_init(struct emacs_runtime *ert) {
    emacs_env *e = ert->get_environment(ert);
    if (!e) return 1;
    {
        emacs_value fn = e->make_function(e, 2, 100, Fset, "Set clipboard: (clipboard-set MIME DATA ...).", NULL);
        e->funcall(e, e->intern(e, "defalias"), 2, (emacs_value[]){ e->intern(e, "clipboard-set"), fn });
    }
    {
        emacs_value fn = e->make_function(e, 1, 1, Fget, "Get clipboard data: (clipboard-get \"text/plain\")", NULL);
        e->funcall(e, e->intern(e, "defalias"), 2, (emacs_value[]){ e->intern(e, "clipboard-get"), fn });
    }
    {
        emacs_value fn = e->make_function(e, 0, 0, Fmime_types, "List MIME types on clipboard.", NULL);
        e->funcall(e, e->intern(e, "defalias"), 2, (emacs_value[]){ e->intern(e, "clipboard-mime-types"), fn });
    }
    e->funcall(e, e->intern(e, "provide"), 1, (emacs_value[]){ e->intern(e, "clipboard-wl") });
    return 0;
}
