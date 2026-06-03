;;; modules/ffi/dyncall/config.el -*- lexical-binding: t; -*-

;; ─── 加载 C 模块 ─────────────────────────────────────────
;; dyncall.so 在 module-init 阶段加载（与 count-cjk / random 一致）。

(defvar +dyncall--so
  (expand-file-name "c-modules/dyncall.so" doom-user-dir))

(when (file-exists-p +dyncall--so)
  (module-load +dyncall--so))
