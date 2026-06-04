# REASONIX.md

## Stack
- **Doom Emacs** — Emacs framework; config lives in `~/.config/doom/`
- **Emacs Lisp** — all config files (`*.el`)
- **Org mode** — note-taking, journal, roam, noter, LaTeX export (via `ox-latex`)
- **Corfu + Orderless** — completion backend (replaced company/ivy)
- **Vertico** — search/find UI
- **Evil** — Vim emulation everywhere
- **Magit** — Git porcelain
- **Denote** — file-naming note system with sequences & explore
- **CJK tools** — C module for Chinese/English text counting; offline dictionary (萌典 + mapull) integrated into SPC o d

## Layout
- `init.el` — Doom module list (`doom!` block); enable/disable features
- `config.el` — user customizations: fonts, package config, keybindings, hooks
- `packages.el` — third-party package declarations via `package!` macro

## Commands
- `doom sync` — required after editing `init.el` or `packages.el` (regenerates autoloads)
- `doom upgrade` — update Doom framework and pinned packages
- `doom doctor` — check for common configuration issues
- `doom env` — generate environment variables file for GUI Emacs

## Conventions
- **`use-package!`** (Doom's macro) for all package configuration
- **`map!`** macro for keybindings; leader key menu maps with `:prefix-map`
- **`after!`** / `(with-eval-after-load ...)` for deferred config
- Lexical-binding enabled: `-*- lexical-binding: t; -*-` on first line
- Packages declared via `package!` at top level in `packages.el`
- `config.el` changes do NOT need `doom sync`; `init.el` / `packages.el` changes do

## Watch out for
- **`doom sync` must be run** after touching `init.el` or `packages.el` — edits won't take effect until then
- **Font changes** need `(doom/reload-font)` — apply via `my/apply-fonts` hook; if font isn't found, use `M-x describe-font` to locate the correct name
- **Doom may override your setting** unless wrapped in `(with-eval-load-after 'PACKAGE ...)` or prefixed `doom-`/`+`
- **Daemon-aware patterns** — some hooks (`server-after-make-frame-hook` vs `after-init-hook`) are fragile; graphical-only config should check `(display-graphic-p frame)`
- **`user-emacs-directory` redirect** — Doom 3 points it to `.local/cache/`; persistent data paths must use `doom-local-dir` instead (e.g., dict data at `(expand-file-name "dict" doom-local-dir)`)
