CC = gcc
CFLAGS = -Wall -Wextra -std=c99 -O2 -fPIC
NOTIFY_LIBS = $(shell pkg-config --cflags --libs libnotify glib-2.0) -lpthread

all: cnotify-module.so count-cjk.so

cnotify-module.so: cnotify-module.c
	$(CC) $(CFLAGS) -shared -o $@ $^ $(NOTIFY_LIBS)

count-cjk.so: count-cjk.c
	$(CC) $(CFLAGS) -shared -o $@ $^

clean:
	rm -f cnotify-module.so count-cjk.so

.PHONY: all clean
