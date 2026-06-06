;;; $DOOMDIR/cli.el -*- lexical-binding: t; -*-
;;;
;;; 在 `doom sync' 等 CLI 操作中被 Doom 自动加载。
;;; 在普通 Emacs 会话中不加载。

;; doom sync 后自动编译 C 模块
(add-hook 'doom-after-sync-hook
          (defun my/build-c-modules-after-sync ()
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
