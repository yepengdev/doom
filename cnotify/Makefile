CC = gcc
CFLAGS = -Wall -Wextra -std=c99 -O2 -fPIC
LIBS = $(shell pkg-config --cflags --libs libnotify glib-2.0) -lpthread

all: cnotify-module.so

cnotify-module.so: cnotify-module.c
	$(CC) $(CFLAGS) -shared -o $@ $^ $(LIBS)

clean:
	rm -f cnotify-module.so

.PHONY: all clean
