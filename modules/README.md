# Emacs C 动态模块

Elisp 到 C 的桥梁。每个模块定义一个或多个 `emacs_module_init` 导出的 Lisp 函数，
通过 `module-load` 加载后在 Lisp 侧直接调用。

## 模块列表

| 模块 | 源文件 | 功能 |
|------|--------|------|
| `count-cjk.so` | `count-cjk.c` | UTF-8 安全的 CJK + 英文混合计数 |
| `random.so` | `random.c` | 加密级真随机数（`getrandom(2)` 内核熵池） |
| `cnotify-module.so` | `cnotify-module.c` | 桌面通知（libnotify）+ 番茄钟 + 倒计时器 |
| `dyncall.so` | `dyncall.c` | libffi 动态 FFI：运行时调用任意 C 函数 |

## 编译

```sh
make -C c-modules/             # 全部编译
make -C c-modules/ dyncall.so  # 单个编译
make -C c-modules/ clean       # 清理
```

依赖：`gcc`、`emacs-module.h`（Emacs 30）、`libffi`、`libnotify`。

## 各模块使用

### count-cjk

```elisp
(my/count-cjk "你好世界 hello")  → (4 . 0)
(my/count-text "你好 world")     → [2 0 1 5 8]
;;              [CJK 标点 英文词 英文字符 总码点]
```

### random

```elisp
(my/random-bytes 16)        → "\xf3\x1a..."  (16 字节加密随机)
(my/random-int 100)         → 42             ([0, 99])
(my/random-in-range 10 20)  → 15             ([10, 20])
(my/random-password 32)     → "aB3$..."      (随机密码)
```

### cnotify

```elisp
(cnotify-notify "标题" "正文" CALLBACK)    ;; 通知，点击调 CALLBACK
(cnotify-timer-start 5 "时间到")           ;; 5 分钟倒计时
(cnotify-pomodoro-start 25 5)              ;; 25 分工作 / 5 分休息
(cnotify-status)                           ;; (剩余秒数 . 阶段)
(cnotify-poll-action)                      ;; 处理点击回调（每帧调一次）
```

### dyncall — 动态 FFI

```elisp
;; 一步调用
(dyncall "libm.so.6" "sqrt" :double :double 4.0)  → 2.0
(dyncall nil "getpid" :int)                         → 12345
(dyncall nil "strcmp" :int :string "a" :string "b") → -1

;; 三步模式（重复调用时避免 dlsym 开销）
(let ((lib (dyncall-load "libm.so.6"))
      (fn  (dyncall-sym  lib "tgamma")))
  (dyncall-call fn :double :double 5.0)  → 24.0
  (dyncall-close lib))
```

支持的类型：`:void` `:int` `:uint` `:long` `:ulong` `:int64` `:float` `:double` `:string` `:pointer`

## 测试

```sh
emacs -Q --batch -l tests-bench/dyncall-test.el
```

## 架构说明

所有模块编译为 `.so`，由 `config.el` 通过 `module-load` 延迟加载（首次调用对应的
Lisp 符号时才触发）。每个模块的 `emacs_module_init` 注册函数并 `provide` 一个
feature，`my/XXX--ensure` 函数检查该 feature 后再加载，避免重复加载和启动阻塞。
