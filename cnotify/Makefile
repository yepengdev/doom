CC = gcc
CFLAGS = -Wall -Wextra -std=c99 -O2
LIBS = $(shell pkg-config --cflags --libs libnotify glib-2.0)

all: cnotify

cnotify: cnotify.c notify.c timer.c pomodoro.c notify.h timer.h pomodoro.h
	$(CC) $(CFLAGS) -o $@ cnotify.c notify.c timer.c pomodoro.c $(LIBS)

clean:
	rm -f cnotify

.PHONY: all clean
