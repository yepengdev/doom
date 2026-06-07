# REASONIX.md

## Stack

- **Doom Emacs** — Emacs framework; config lives in `~/.config/doom/`
- **Emacs Lisp** — all config files (`*.el`)
- **Org mode** — note-taking, journal, noter, LaTeX/docx/HTML export
- **Corfu + Orderless** — inline completion (replaced company/ivy)
- **Vertico** — search/find UI (with childframe + icons)
- **Evil** — Vim emulation everywhere (insert-state-map cleared, hybrid mode)
- **Magit** — Git porcelain
- **Denote** — file-naming note system with journal, sequence, explore, menu
- **CJK tools** — C module for Chinese/English text counting; offline dictionary (moedict + mapull)
- **LSP** — Eglot client (minimal, fast)
- **Tree-sitter** — syntax parsing
- **Jieba** — Chinese word segmentation + TF-IDF keyword extraction

## Layout

| Path | Purpose | `doom sync`? |
|------|---------|-------------|
| `init.el` | Doom module list (`doom!` block) | **yes** |
| `packages.el` | Third-party `package!` declarations | **yes** |
| `config.el` | Single-file user config (UI, editor, Org, LaTeX, reading, i18n, tools) | no |
| `cli.el` | CLI hooks for `doom sync` | no |
| `modules/` | Custom Doom modules (notes, cjk, pomodoro, jieba, dyncall) | no |
| `c-modules/` | C dynamic modules (count-cjk, cnotify, random, dyncall, jieba) | no |

## Commands

- `doom sync` — required after editing `init.el` or `packages.el`
- `doom upgrade` — update Doom framework and pinned packages
- `doom doctor` — check for common configuration issues
- `doom env` — generate environment variables file for GUI Emacs
- `doom build` — rebuild Doom packages
- `make -C c-modules/` — build all C modules
- `M-x my/byte-compile-config` — byte-compile user config for faster startup

## Conventions

- **`use-package!`** (Doom's macro) for all package configuration
- **`map!`** macro for keybindings; leader key menu maps with `:prefix-map`
- **`after!`** / `(with-eval-after-load ...)` for deferred config
- Lexical-binding enabled: `-*- lexical-binding: t; -*-` on first line
- `config.el` changes do NOT need `doom sync`; `init.el` / `packages.el` changes do
- Custom Doom modules use the standard Doom module structure: `modules/<category>/<name>/{config,autoload}.el`
- C modules are lazy-loaded by `my/*--ensure` functions; built on first use via `make(1)`

## Watch out for

- **`doom sync` must be run** after touching `init.el` or `packages.el`
- **Font changes** need `M-x doom/reload-font` — use `fc-list :lang=zh` to check CJK fonts
- **Doom may override your setting** unless wrapped in `after!` or using `setq` after `(after! PACKAGE ...)`
- **Daemon-aware patterns** — use `doom-switch-frame-hook` + `display-graphic-p` guards, not `after-init-hook`
- **`user-emacs-directory` redirect** — use `doom-local-dir` for persistent data (e.g., dict data at `(expand-file-name "dict" doom-local-dir)`)
- **nginx unit docs serving** — `org.ffi` unit (UDS to port 8088, SELF start), nginx resolves via `http://localhost:8088/`
- **LLM temperature** — 0.5 sweet spot for story editing; 0.8+ for creative writing
