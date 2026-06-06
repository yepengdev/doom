;;; $DOOMDIR/cli.el -*- lexical-binding: t; -*-
;;;
;;; 在 `doom sync' 等 CLI 操作中被 Doom 自动加载。
;;; 在普通 Emacs 会话中不加载。

;; ─── 编译私人配置（doom sync 时编译全部 .elc）──────────────────

(defun my/private-config--collect ()
  (let (files seen)
    (dolist (file (doom-module-locate-paths (doom-module-list) "config.el"))
      (when (and (file-in-directory-p file doom-user-dir)
                 (not (member file seen)))
        (push file seen)
        (push file files)))
    (nreverse files)))

(defun my/private-config--files-to-compile ()
  (let ((result (list)))
    (dolist (file (my/private-config--collect))
      (let ((elc (byte-compile-dest-file file)))
        (unless (and (file-exists-p elc)
                     (not (file-newer-than-file-p file elc)))
          (push file result))))
    (nreverse result)))

(add-hook 'doom-before-sync-hook
          (defun my/byte-compile-private-config-on-sync ()
            (let ((files (my/private-config--files-to-compile)))
              (when files
                (print! (start "Compiling %d private config file(s)..." (length files)))
                (dolist (file files)
                  (let ((byte-compile-warnings nil))
                    (condition-case e
                        (if (byte-compile-file file)
                            (print! (item "%s" (file-relative-name file doom-user-dir)))
                          (print! (warn "%s — compilation failed"
                                        (file-relative-name file doom-user-dir))))
                      (error
                       (print! (error "%s: %s" (file-relative-name file doom-user-dir) e))))))
                (print! (success "Private config compiled"))))))

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
