# AGENTS.md

Doom Emacs personal config at `~/.config/doom/` — 3 active files + supporting assets.

## Files & `doom sync` rule
- `init.el` / `packages.el` — edit + `doom sync` (required)
- `config.el` — core config (UI, editor, org, LaTeX, i18n); edit only, no `doom sync`
- `modules/tools/` — Doom user modules split from main `config.el`

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
- `https://gh-proxy.com/github.com/` as insteadOf for GitHub — set via `DOOMGITCONFIG` env var (retired, config removed)
- Relevant for `doom sync` behind restrictive networks

## Active modules (from `init.el`, commented-out omitted)
corfu+orderless, vertico, deft, doom, hl-todo, modeline, popup+defaults, vc-gutter+pretty, workspaces,
evil+everywhere, file-templates, fold, format+onsave, multiple-cursors, snippets, whitespace+guess+trim,
dired, electric, tramp, undo, vc, eshell, vterm,
eval+overlay, lookup, magit, pdf,
cjk, notes, pomodoro,
ffi+dyncall,
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
- **`user-emacs-directory`** 陷阱: Doom 3 将其重定向到 `.local/cache/`。持久数据应使用 `doom-local-dir`（`~/.config/emacs/.local/`）而非 `user-emacs-directory`
- **词典数据**: 萌典 + mapull 离线词典数据目录 `~/.config/emacs/.local/dict/`（由 `doom-local-dir` 派生）；`SPC o d / K` 统一入口

## C dynamic modules

### `my/count-chinese-chars` / `my/count-words`
- Source: `c-modules/count-cjk.c`, compiled to `c-modules/count-cjk.so`
- Module: `modules/tools/cjk/` (Doom module, enabled via `:tools cjk` in init.el)
- Build: `make -C c-modules/` (requires `emacs-module.h` from Emacs 30)
- Doom module's `config.el` checks `.so` at init; errors with build instructions if missing
- Exports: `my/count-cjk` (CJK only), `my/count-text` (CJK + English words)
- `M-=` → `my/count-words` (replaces `count-words-region`), `SPC r n c` → `my/count-chinese-chars`
- Benchmark: `emacs -Q -batch -l tests-bench/count-cjk-bench.el`

### `dyncall` — libffi 动态 FFI
- Source: `c-modules/dyncall.c`, compiled to `c-modules/dyncall.so`
- Module: `modules/ffi/dyncall/` (Doom module, enabled via `:ffi dyncall` in init.el)
- `config.el` loads `.so` eagerly (same as other C modules)
- `autoload.el` provides wrapped functions (`+dyncall-pid`, `+dyncall-sqrt`, etc.)
- `doctor.el` checks for `libffi` and `dyncall.so` existence
- Build: `make -C c-modules/`
- Test: `emacs -Q --batch -l tests-bench/dyncall-test.el`

## Dict module (萌典 + mapull)
- 数据目录: `~/.config/emacs/.local/dict/`（由 `doom-local-dir` 确定）
- **萌典** (`dict.sqlite3`, 61MB): 官方 dict.concised.moe.edu.tw 台湾国语辞典离线版
- **mapull** (`mapull.db`, 43MB): 汉字档案(笔画/部首/结构/频次) + 词语(320k) + 成语(50k)
- 入口: `SPC o d / K` → `+lookup/dictionary-definition` 的 `:around` advice (`my/+lookup-dictionary-definition-a`)
- 单字 = 萌典释义 + 汉字档案 + 相关词语/成语; 多字 = 词语/成语
- 非中文回退到英语后端 (define-word)
- 首次使用自动下载 mapull JSON (~100MB) 并导入 sqlite

## Directory structure
- `config.el` / `init.el` / `packages.el` — core Doom config (root)
- `c-modules/` — C native modules + their Makefile
- `modules/` — Doom modules (e.g. `ffi/dyncall/`, `tools/{cjk,notes,pomodoro}/`)
- `tests-bench/` — benchmark / test scripts
- `pandoc/` — Pandoc reference docx + Lua filters
- `org-export/` — Org HTML CSS assets
- `snippets/` — Yasnippet snippets
- `docs/` / `wiki/` — supplementary docs

## Existing docs
- `REASONIX.md` — stack overview & general commands (reference, don't duplicate)
- `doom-handbook.org` — single-file comprehensive reference (replaces former `docs/` directory)
