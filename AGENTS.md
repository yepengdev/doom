# AGENTS.md

Doom Emacs personal config at `~/.config/doom/` — 3 files, simple.

## Files & `doom sync` rule
- `init.el` / `packages.el` — edit + `doom sync` (required)
- `config.el` — edit only, no `doom sync`

## Commands
`doom sync | doctor | upgrade | env`

## Doom-specific conventions (not standard Emacs)
- `use-package!` (not `use-package`); `package!` for deps in `packages.el`
- `map!` for keybindings; `after!` / `with-eval-after-load` for deferred config
- Wrap overridable settings in `with-eval-after-load` or use `doom-`/`+` prefix

## Active modules (rest in `init.el` are commented out)
corfu+orderless, vertico, evil+everywhere, format, snippets, whitespace+guess+trim,
emacs-lisp, markdown, org+journal+noter+pretty+pandoc+roam,
eval+overlay, lookup, magit, pdf, deft, modeline, workspaces, zen,
dired, tramp, vc-gutter+pretty

## Gotchas
- **Font**: daemon-aware — `my/apply-fonts` on `after-init-hook` + `server-after-make-frame-hook` with `(display-graphic-p frame)` guard
- **Chinese IM**: fcitx5-remote auto-integrates with Evil via `fcitx-evil-turn-on` on `find-file-hook`
- **LaTeX**: xelatex + elegantbook class for CJK; custom `org-latex-pdf-process` (bibtex + 2 xelatex passes); removes `inputenc` to avoid conflict
- **Denote notes**: bindings under `SPC r d`; `org-directory: ~/org/`; Denote dir: `~/Documents/notes/`
- **Writing**: olivetti auto-enables in org-mode; super-save trims trailing whitespace

## Existing docs
- `REASONIX.md` — stack overview & general commands (reference, don't duplicate)
