#include "notify.h"
#include <libnotify/notify.h>
#include <string.h>

int notify_init_app(void)
{
    return notify_init("cnotify");
}

void notify_send(const char *title, const char *body)
{
    NotifyNotification *n = notify_notification_new(title, body, NULL);
    notify_notification_set_timeout(n, 5000);  /* 5s auto-close */
    notify_notification_show(n, NULL);
    g_object_unref(G_OBJECT(n));
}

void notify_cleanup(void)
{
    notify_uninit();
}
