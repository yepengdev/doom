#ifndef NOTIFY_H
#define NOTIFY_H

int notify_init_app(void);
void notify_send(const char *title, const char *body);
void notify_cleanup(void);

#endif
