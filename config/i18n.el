;;; $DOOMDIR/config/i18n.el -*- lexical-binding: t; -*-

;; ─── Immersive bilingual translation ─────────────────────────────────────────
(use-package! immersive-translate
  :defer t
  :commands (immersive-translate-setup
             immersive-translate-buffer
             immersive-translate-paragraph
             immersive-translate-clear
             immersive-translate-auto-mode
             immersive-translate-abort)
  :custom
  (immersive-translate-backend 'baidu)
  (immersive-translate-baidu-appid (getenv "BAIDU_TRANSLATE_APPID"))
  (immersive-translate-auto-idle 0.5)
  :init
  (add-hook! 'doom-first-buffer-hook
    (add-hook 'nov-pre-html-render-hook #'immersive-translate-setup)
    (add-hook 'org-mode-hook #'immersive-translate-setup)))

;; ─── Chinese input ───────────────────────────────────────────────────────────
(add-transient-hook! 'doom-first-input-hook
  (when-let ((cmd (or (executable-find "fcitx5-remote")
                      (executable-find "fcitx-remote"))))
    (setq fcitx-remote-command cmd)
    (require 'fcitx)
    (fcitx-evil-turn-on)))

;; ─── Fuzzy matching with pinyin support ─────────────────────────────────────
(use-package! evil-pinyin
  :defer t
  :commands (evil-pinyin--build-regexp-string)
  :init
  (after! orderless
    (advice-add #'orderless-regexp :filter-return #'evil-pinyin--build-regexp-string))
  :config (evil-pinyin-mode 1))

(use-package! ace-pinyin
  :commands ace-pinyin-global-mode
  :after-call avy-goto-char-timer
  :init (setq ace-pinyin-use-avy t)
  :config (ace-pinyin-global-mode t))
