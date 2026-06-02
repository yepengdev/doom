# AGENTS.md

Doom Emacs personal config at `~/.config/doom/` — 3 active files + supporting assets.

## Files & `doom sync` rule
- `init.el` / `packages.el` — edit + `doom sync` (required)
- `config.el` — single-file config (replaces former `config/*.el` split); edit only, no `doom sync`

## Commands
`doom sync | doctor | upgrade | env | clean`
- `doom sync` — after `init.el`/`packages.el` edits (regenerates autoloads)
- `M-x doom/reload-font` — re-apply font settings
- `M-x my/doom-full-reload` — custom: reloads autoloads + packages + config + theme + font + frames (bound to `SPC h r R`)

## Doom-specific conventions (not standard Emacs)
- `use-package!` (not `use-package`); `package!` for deps in `packages.el`
- `map!` for keybindings; `after!` / `with-eval-after-load` for deferred config
- Wrap overridable settings in `after!` or use `doom-`/`+` prefix

## Proxy
- `doom-gitconfig` sets `https://gh-proxy.com/github.com/` as insteadOf for GitHub — sourced via `DOOMGITCONFIG` env var in `config.el`
- Relevant for `doom sync` behind restrictive networks

## Active modules (from `init.el`, commented-out omitted)
corfu+orderless, vertico, deft, doom, hl-todo, modeline, popup+defaults, vc-gutter+pretty, workspaces,
evil+everywhere, file-templates, fold, format+onsave, multiple-cursors, snippets, whitespace+guess+trim,
dired, electric, tramp, undo, vc, eshell, vterm,
eval+overlay, lookup, magit, pdf,
emacs-lisp, markdown, org+journal+noter+pretty+pandoc

## Gotchas
- **Gitignore**: `.gitignore` ignores `*.md` — `AGENTS.md` and `REASONIX.md` won't appear in `git status`
- **Font**: declarative via `doom-font` + `doom-variable-pitch-font` (Monaspace Neon 16) + `set-fontset-font` for CJK (LXGW WenKai Mono Screen 16) inside `after! doom-ui`
- **Chinese IM**: fcitx5-remote auto-integrates with Evil via `add-transient-hook! 'doom-first-input-hook` (not `find-file-hook`)
- **Emacs state replaces Insert**: `evil-insert-state` aliased to `evil-emacs-state` (bar cursor, ESC → normal)
- **Pinyin fuzzy matching**: `evil-pinyin` advises `orderless-regexp`; `ace-pinyin` integrates with Avy for Chinese char jumps
- **Theme**: auto-switches `doom-one-light` (day, 7-19) / `doom-tokyo-night` (night), checked once on first frame switch
- **LaTeX**: xelatex + ctexbook class for CJK; custom `org-latex-pdf-process` (latexmk single-pass); removes `inputenc` to avoid conflict
- **Denote notes**: bindings under `SPC r d`; `org-directory: ~/org/`; Denote dir: `~/org/denote/`; Deft dir: `~/org/deft/`; org-noter: `~/org/deft/annotations/`
- **Search**: SPC n s → `+default/org-notes-search` searches `org-directory` (~/org/) via ripgrep; SPC n f → `+default/find-in-notes`; SPC n S → `+default/search-project-for-symbol-at-point`
- **Writing**: olivetti auto-enables in org-mode (width 100, hides mode-line + line numbers); super-save trims trailing whitespace on idle save
- **Large Org files** (≥1 MiB): disables all prettification (org-modern, org-appear, org-indent, prettify-symbols, variable-pitch, fontification)
- **Org HTML export**: local minimal theme from `org-export/minimal/` (CSS only, zero JS, no CDN)
- **Package `gcmh`**: declared in `packages.el` for dynamic runtime GC management
- **`so-long`**: disabled for Org mode via custom predicate in `after! so-long`

## C dynamic modules

### `my/count-chinese-chars` / `my/count-words`
- Source: `modules/count-cjk.c`, compiled to `modules/count-cjk.so`
- Build: `make -C modules/` (requires `emacs-module.h` from Emacs 30)
- `config.el` tries `module-load` at init; errors with build instructions if `.so` missing
- Exports: `my/count-cjk` (CJK only), `my/count-text` (CJK + English words)
- `M-=` → `my/count-words` (replaces `count-words-region`), `SPC r n c` → `my/count-chinese-chars`
- Benchmark: `emacs -Q -batch -l tests-bench/count-cjk-bench.el`

### `get-dir-size` (directory size via nftw)
- Source: `modules/dirsize.c`, compiled to `modules/dirsize.so`
- Exports: `get-dir-size` (PATH → bytes, integer)
- Auto-loaded at startup by `config.el` (same pattern as CJK module)
- Auto-displayed in Dired header line: `[/path]  total 42  [12.5M]`
- Uses POSIX `nftw(3)` at C level — near-instant even on 100K-file dirs
- Build as part of `make -C modules/` alongside count-cjk

## Directory structure
- `config.el` / `init.el` / `packages.el` — core Doom config (root)
- `modules/` — C native modules + their Makefile
- `tests-bench/` — benchmark / test scripts
- `pandoc/` — Pandoc reference docx + Lua filters
- `org-export/` — Org HTML CSS assets
- `snippets/` — Yasnippet snippets
- `docs/` / `wiki/` — supplementary docs

## Existing docs
- `REASONIX.md` — stack overview & general commands (reference, don't duplicate)
- `doom-handbook.org` — single-file comprehensive reference (replaces former `docs/` directory)
