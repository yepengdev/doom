;;; $DOOMDIR/config/editor.el -*- lexical-binding: t; -*-

;; ─── Basics ──────────────────────────────────────────────────────────────────
(setq confirm-kill-emacs nil)
(setq shell-file-name (executable-find "bash"))
(setq-default vterm-shell "/usr/bin/fish")
(setq-default explicit-shell-file-name "/usr/bin/fish")

;; ─── Magit ───────────────────────────────────────────────────────────────────
(after! magit
  (setq magit-diff-refine-hunk nil))

;; ─── Writing tools ───────────────────────────────────────────────────────────
(use-package! olivetti
  :hook (org-mode . olivetti-mode)
  :custom
  (olivetti-body-width 100)
  (olivetti-hide-mode-line t)
  :config
  (define-key olivetti-mode-map (kbd "C-c |") nil)
  (defun +olivetti-hide-line-numbers-h ()
    (display-line-numbers-mode -1))
  (defun +olivetti-show-line-numbers-h ()
    (display-line-numbers-mode 1))
  (add-hook 'olivetti-mode-on-hook #'+olivetti-hide-line-numbers-h)
  (add-hook 'olivetti-mode-off-hook #'+olivetti-show-line-numbers-h))

(use-package! super-save
  :hook (doom-first-file . super-save-mode)
  :custom
  (super-save-auto-save-when-idle t)
  (super-save-silent t)
  (super-save-when-focus-lost nil)
  (super-save-when-buffer-switched nil)
  (super-save-delete-trailing-whitespace 'except-current-line)
  :config
  (add-to-list 'super-save-predicates
               (lambda () (not buffer-read-only))))

;; ─── Emacs state replaces Insert state ──────────────────────────────────────
(after! evil
  (defalias 'evil-insert-state 'evil-emacs-state)
  (setq evil-emacs-state-cursor 'bar)
  (define-key evil-emacs-state-map (kbd "<escape>") 'evil-normal-state))

;; ─── Global keybindings ─────────────────────────────────────────────────────
(map! :g "M-!" #'eshell-command)
