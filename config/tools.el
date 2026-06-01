;;; $DOOMDIR/config/tools.el -*- lexical-binding: t; -*-

;; ─── Full reload ─────────────────────────────────────────────────────────────
(defun my/doom-full-reload--apply (&rest _)
  "Apply theme, font & frame settings after config reload.
Intended for `doom-after-reload-hook'."
  (my/theme-apply (my/theme-for-hour))
  (when (fboundp 'doom/reload-font)
    (doom/reload-font))
  (when (daemonp)
    (dolist (frame (frame-list))
      (when (display-graphic-p frame)
        (with-selected-frame frame
          (run-hooks 'server-after-make-frame-hook)))))
  (message "Full reload complete (config + theme + font + frames)"))

(defun my/doom-full-reload ()
  "Reload config, theme, fonts, frames, packages & autoloads.

Replaces `doom/reload' for a more thorough reload.  NOTE:
changes to `packages.el' still require `doom sync' first."
  (interactive)
  (when (fboundp 'doom/reload-autoloads)
    (ignore-errors (doom/reload-autoloads)))
  (when (fboundp 'doom/reload-packages)
    (ignore-errors (doom/reload-packages)))
  (when (fboundp 'doom/reload)
    (ignore-errors
      (add-hook 'doom-after-reload-hook #'my/doom-full-reload--apply)
      (doom/reload))))

(map! :leader
      :desc "Full reload" "h r R" #'my/doom-full-reload)
