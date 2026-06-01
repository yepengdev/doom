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

;; ─── Chinese character count ─────────────────────────────────────────────────
(defvar my/cjk-regexp "\\(?:[一-鿿㐀-䶵𠀀-𪛟𪜀-𫜸𫝀-𫠝𫠠-𬺡𬺰-𮯠丽-𪘀]\\)"
  "Regexp matching CJK Unified Ideographs (including Ext B-H).")

(defvar my/cjk-punct-regexp "\\(?:[。，、；：？！“”‘’（）【】《》—…～·『』〔〕〖〗〘〙〚〛〜　]\\)"
  "Regexp matching common CJK punctuation.")

;;;###autoload
(defun my/count-chinese-chars (&optional beg end)
  "Count Chinese characters in region or whole buffer.
If region is active, use it; otherwise count the entire buffer.
Shows a summary with Chinese char count (with & without punctuation),
total char count, and percentage."
  (interactive)
  (let* ((beg (or beg (if (use-region-p) (region-beginning) (point-min))))
         (end (or end (if (use-region-p) (region-end) (point-max))))
         (text (buffer-substring-no-properties beg end))
         (total (length text))
         (cn-chars (with-temp-buffer
                     (insert text)
                     (goto-char (point-min))
                     (let ((count 0))
                       (while (re-search-forward my/cjk-regexp nil t)
                         (cl-incf count))
                       count)))
         (cn-punct (with-temp-buffer
                     (insert text)
                     (goto-char (point-min))
                     (let ((count 0))
                       (while (re-search-forward my/cjk-punct-regexp nil t)
                         (cl-incf count))
                       count)))
         (total-cn (+ cn-chars cn-punct))
         (pct (if (> total 0) (/ (* total-cn 100.0) total) 0.0)))
    (message (concat "字:%d  含标点:%d  总:%d  %.1f%%"
                     (if (use-region-p) " (选中)" ""))
             cn-chars total-cn total pct)))

(map! :leader
      :desc "Count Chinese chars" "n c" #'my/count-chinese-chars)
