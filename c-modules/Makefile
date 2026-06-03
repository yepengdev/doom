CC = gcc
CFLAGS = -Wall -Wextra -std=gnu11 -O2 -fPIC
NOTIFY_LIBS = $(shell pkg-config --cflags --libs libnotify glib-2.0) -lpthread
FFI_CFLAGS = $(shell pkg-config --cflags libffi)
FFI_LIBS   = $(shell pkg-config --libs libffi)

all: cnotify-module.so count-cjk.so random.so dyncall.so

cnotify-module.so: cnotify-module.c
	$(CC) $(CFLAGS) -shared -o $@ $^ $(NOTIFY_LIBS)

count-cjk.so: count-cjk.c
	$(CC) $(CFLAGS) -shared -o $@ $^

random.so: random.c
	$(CC) $(CFLAGS) -shared -o $@ $^

dyncall.so: dyncall.c
	$(CC) $(CFLAGS) $(FFI_CFLAGS) -shared -o $@ $^ $(FFI_LIBS) -ldl

clean:
	rm -f cnotify-module.so count-cjk.so random.so dyncall.so

.PHONY: all clean
