;;; $DOOMDIR/config.el -*- lexical-binding: t; -*-

;; ─── Git proxy ──────────────────────────────────────────────────────────────
(setenv "DOOMGITCONFIG"
        (expand-file-name "doom-gitconfig" doom-user-dir))

;; ─── Load modular config files ───────────────────────────────────────────────
(load! "config/ui")
(load! "config/editor")
(load! "config/org")
(load! "config/latex")
(load! "config/notes")
(load! "config/reading")
(load! "config/i18n")
(load! "config/tools")
