CC = gcc
CFLAGS = -Wall -Wextra -std=c99 -O2 -fPIC
NOTIFY_LIBS = $(shell pkg-config --cflags --libs libnotify glib-2.0) -lpthread
WAYLAND_LIBS = $(shell pkg-config --cflags --libs wayland-client) -lpthread

all: cnotify-module.so count-cjk.so clipboard-wl.so

cnotify-module.so: cnotify-module.c
	$(CC) $(CFLAGS) -shared -o $@ $^ $(NOTIFY_LIBS)

count-cjk.so: count-cjk.c
	$(CC) $(CFLAGS) -shared -o $@ $^

clipboard-wl.so: clipboard-wl.c
	$(CC) $(CFLAGS) -shared -o $@ $^ $(WAYLAND_LIBS)

clean:
	rm -f cnotify-module.so count-cjk.so clipboard-wl.so

.PHONY: all clean
