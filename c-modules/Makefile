CC = gcc
CXX = g++
CFLAGS = -Wall -Wextra -std=gnu11 -O2 -fPIC
CXXFLAGS = -Wall -Wextra -std=c++11 -O2 -fPIC -DLOGGING_LEVEL=LL_WARNING
NOTIFY_LIBS = $(shell pkg-config --cflags --libs libnotify glib-2.0) -lpthread
FFI_CFLAGS = $(shell pkg-config --cflags libffi)
FFI_LIBS   = $(shell pkg-config --libs libffi)
JIEBA_DIR  = cjieba

all: cnotify-module.so count-cjk.so random.so dyncall.so jieba-module.so

cnotify-module.so: cnotify-module.c
	$(CC) $(CFLAGS) -shared -o $@ $^ $(NOTIFY_LIBS)

count-cjk.so: count-cjk.c
	$(CC) $(CFLAGS) -shared -o $@ $^

random.so: random.c
	$(CC) $(CFLAGS) -shared -o $@ $^

dyncall.so: dyncall.c
	$(CC) $(CFLAGS) $(FFI_CFLAGS) -shared -o $@ $^ $(FFI_LIBS) -ldl

jieba-module.so: jieba-module.o $(JIEBA_DIR)/libjieba.a
	$(CC) $(CFLAGS) -shared -o $@ jieba-module.o \
		-L./$(JIEBA_DIR) -ljieba -lstdc++ -lm

jieba-module.o: jieba-module.c $(JIEBA_DIR)/lib/jieba.h
	$(CC) $(CFLAGS) -I. -o $@ -c $<

$(JIEBA_DIR)/libjieba.a: $(JIEBA_DIR)/lib/jieba.cpp $(JIEBA_DIR)/lib/jieba.h
	$(MAKE) -C $(JIEBA_DIR) \
		CXX='$(CXX)' CXXFLAGS='$(CXXFLAGS)' CPPFLAGS='-DLOGGING_LEVEL=LL_WARNING -I./deps'

clean:
	rm -f cnotify-module.so count-cjk.so random.so dyncall.so jieba-module.so

.PHONY: all clean jieba
