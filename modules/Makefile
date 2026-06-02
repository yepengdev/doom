# Makefile for Doom Emacs dynamic C modules
# Usage:  make          # build all .so files
#         make clean    # remove all .so files

EMACS_MODULE_INC = /usr/include/emacs-30
CC = gcc
CFLAGS = -shared -fPIC -O2 -Wall -Wextra -I$(EMACS_MODULE_INC)

MODULES = count-cjk.so

.PHONY: all clean

all: $(MODULES)

count-cjk.so: count-cjk.c
	$(CC) $(CFLAGS) $< -o $@

clean:
	rm -f $(MODULES)
