;;; $DOOMDIR/cli.el -*- lexical-binding: t; -*-
;;;
;;; 在 `doom sync' 等 CLI 操作中被 Doom 自动加载。
;;; 在普通 Emacs 会话中不加载。
;;;
;;; 注意：配置文件的 .elc 编译在交互式 Emacs 中手动执行
;;; `M-x my/byte-compile-config`，因为 CLI 环境缺少宏定义所需
;;; 的第三方包依赖（如 general 等 straight 包）。

;; ─── C 模块编译（doom sync 时编译 .so）────────────────────────────

(add-hook 'doom-before-sync-hook
          (defun my/build-c-modules-on-sync ()
            (when (file-directory-p (expand-file-name "c-modules" doom-user-dir))
              (print! (start "Building C modules..."))
              (let ((default-directory (expand-file-name "c-modules" doom-user-dir)))
                (call-process "make" nil nil nil)
                (print! (success "C modules built"))))))

;; ─── 自定义 CLI 命令 ─────────────────────────────────────────────

(defcli! (doom cbuild)
    ()
  "在 $DOOMDIR/c-modules/ 中手动编译 C 模块。"
  (let ((default-directory (expand-file-name "c-modules" doom-user-dir)))
    (print! (start "Building C modules..."))
    (call-process "make" nil nil nil)
    (print! (success "C modules built"))))
