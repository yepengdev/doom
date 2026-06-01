;;; $DOOMDIR/config/ui.el -*- lexical-binding: t; -*-

;; ─── Fonts ───────────────────────────────────────────────────────────────────
(after! doom-ui
  (setq doom-font (font-spec :family "Monaspace Neon" :size 15)
        doom-variable-pitch-font (font-spec :family "Monaspace Neon" :size 15))
  (set-fontset-font t 'han (font-spec :family "LXGW WenKai Mono Screen" :size 15)))

;; ─── Theme & UI ──────────────────────────────────────────────────────────────
(defconst my/theme-day 'doom-one-light
  "Light theme used during daytime.")
(defconst my/theme-night 'doom-tokyo-night
  "Dark theme used at night.")
(defconst my/theme-day-start 7
  "Hour (0-23) when day theme activates.")
(defconst my/theme-night-start 19
  "Hour (0-23) when night theme activates.")

(defun my/theme-for-hour (&optional hour)
  "Return the theme appropriate for HOUR (default: current hour)."
  (let ((h (or hour (string-to-number (format-time-string "%H")))))
    (if (and (>= h my/theme-day-start) (< h my/theme-night-start))
        my/theme-day
      my/theme-night)))

(defun my/theme-apply (theme)
  "Apply THEME using Doom's theme reload."
  (setq doom-theme theme)
  (doom/reload-theme))

(defun my/theme-switch-maybe ()
  "Check hour and switch theme if needed.
After applying once, removes itself from the hook.
Relies on `doom-switch-frame-hook' being called at least once per session."
  (let ((theme (my/theme-for-hour)))
    (unless (eq doom-theme theme)
      (my/theme-apply theme)
      (remove-hook 'doom-switch-frame-hook #'my/theme-switch-maybe))))

(setq doom-theme (my/theme-for-hour))

;; Check theme on first frame switch (once only, then unhooks)
(add-hook 'doom-switch-frame-hook #'my/theme-switch-maybe 'append)

(setq display-line-numbers-type 'relative)
(setq auto-save-timeout 30
      auto-save-interval 300)

;; ─── UI spacing ──────────────────────────────────────────────────────────────
(defvar my/enable-spacious-padding--done nil
  "Whether spacious-padding has been enabled.")

(defun my/enable-spacious-padding--fn (&optional _frame)
  "Enable spacious-padding on the first graphical frame, then unhook."
  (when (and (display-graphic-p)
             (not my/enable-spacious-padding--done))
    (setq my/enable-spacious-padding--done t)
    (remove-hook 'doom-switch-frame-hook #'my/enable-spacious-padding--fn)
    (spacious-padding-mode 1)))

(use-package! spacious-padding
  :commands spacious-padding-mode
  :init
  (setq-default line-spacing 3)
  (add-hook 'doom-switch-frame-hook #'my/enable-spacious-padding--fn))
