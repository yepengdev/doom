# Makefile for Doom Emacs dynamic C modules
# Usage:  make          # build all .so files
#         make clean    # remove all .so files

EMACS_MODULE_INC = $(shell pkg-config --cflags emacs 2>/dev/null \
  || echo "-I/usr/include/emacs-$(shell emacs --version | head -1 | sed 's/.*Emacs //; s/\..*//')")
CC = gcc
CFLAGS = -shared -fPIC -O2 -Wall -Wextra -fstack-protector-strong -D_FORTIFY_SOURCE=2 $(EMACS_MODULE_INC)

MODULES = count-cjk.so

.PHONY: all clean

all: $(MODULES)

count-cjk.so: count-cjk.c
	$(CC) $(CFLAGS) $< -o $@

clean:
	rm -f $(MODULES)
