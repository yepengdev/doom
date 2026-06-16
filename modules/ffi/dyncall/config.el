;;; modules/ffi/dyncall/config.el -*- lexical-binding: t; -*-

;; ─── 加载 C 模块 ─────────────────────────────────────────
;; 延迟到首次需要时加载，不拖慢 config 求值。
;; autoload.el 中的函数在调用前会调用 +dyncall--ensure。

(defvar +dyncall--so
  (expand-file-name "c-modules/dyncall.so" doom-user-dir))

(defvar +dyncall--loaded nil)

(defun +dyncall--ensure ()
  (unless +dyncall--loaded
    (when (file-exists-p +dyncall--so)
      (module-load +dyncall--so)
      (setq +dyncall--loaded t))))

;; 配置阶段不加载，空闲时再后台加载
(add-hook! 'doom-after-init-hook
  (run-with-idle-timer 3 nil #'+dyncall--ensure))
