;;; $DOOMDIR/config.el -*- lexical-binding: t; -*-
;;;
;;; Doom Emacs personal configuration — loaded after modules (autoloads +
;;; packages) are ready.  All changes here require only `M-x doom/reload`
;;; (or `M-x my/doom-full-reload` for autoloads/packages/theme/font too);
;;; no `doom sync` needed unless `packages.el` or `init.el` was touched.
;;;

;; ═══════════════════════════════════════════════════════════════════════════
;; Git proxy for restrictive networks
;; ═══════════════════════════════════════════════════════════════════════════
;;
;; `doom-gitconfig` wraps git(1) to route all GitHub HTTPS fetches through
;; gh-proxy.com.  Needed behind the GFW or any firewall that blocks raw
;; github.com.  The env var is sourced by Doom's git wrapper; the actual
;; gitconfig lives in `doom-gitconfig` in this directory.
;;
(setenv "DOOMGITCONFIG"
        (expand-file-name "doom-gitconfig" doom-user-dir))


;; ═══════════════════════════════════════════════════════════════════════════
;; UI
;; ═══════════════════════════════════════════════════════════════════════════

;; ─── Fonts ────────────────────────────────────────────────────────────────
;;
;; Primary: Monaspace Neon 16pt — designed for code readability with
;; distinct letterforms (no ambiguous 1/l/I).  Same face for variable-pitch
;; (Monaspace has a well-tuned italic/roman pair) so prose doesn't visually
;; clash with code.
;;
;; CJK fallback: LXGW WenKai Mono Screen — a monospaced Chinese font whose
;; x-height and weight approximate Monaspace Neon, keeping the visual rhythm
;; when Latin and CJK glyphs interleave.
;;
;; Size 16 balances modern high-DPI displays (14pt feels cramped) against
;; screen real-estate (18pt wastes horizontal space).
;;
(after! doom-ui
  (setq doom-font (font-spec :family "Monaspace Neon" :size 15)
        doom-variable-pitch-font (font-spec :family "Monaspace Neon" :size 15))
  (set-fontset-font t 'han (font-spec :family "LXGW WenKai Mono Screen" :size 15)))

;; ─── Auto theme switch (day/night) ────────────────────────────────────────
;;
;; Switches between doom-one-light (day) and doom-tokyo-night (night) based
;; on the current hour.  Why hours instead of sunrise/sunset:
;;   - sunrise APIs require network + geolocation config; brittle for a
;;     config file that must work everywhere.
;;   - A developer's schedule is anchored to the desk; 7–19 covers the
;;     typical workday.  Adjust the constants for your latitude / preference.
;;
;; The switch runs on every frame switch, but the `unless (eq doom-theme ...)`
;; guard makes it a near-zero-cost no-op outside transition hours (7:00/19:00).
;; Persisting on the hook ensures the theme updates even during long-running
;; sessions that cross the day/night boundary.
;;
(defconst my/theme-day 'doom-one-light
  "Day theme (7:00–18:59, inclusive of start, exclusive of end).")

(defconst my/theme-night 'doom-tokyo-night
  "Night theme (19:00–6:59).  Dark-on-light switch reduces eye strain in
low-ambient-light environments.")

(defconst my/theme-day-start 7
  "Hour (0–23) when day theme begins.  Tuned to a typical desk schedule.")

(defconst my/theme-night-start 19
  "Hour (0–23) when night theme begins.  7–19 covers the common workday.")

(defun my/theme-for-hour (&optional hour)
  "Return the theme constant for the given HOUR (0–23, default: current local time).

Pure function — no state, no side effects.  Extracted from
`my/theme-switch-maybe' so callers can preview without applying."
  (let ((h (or hour (string-to-number (format-time-string "%H")))))
    (if (and (>= h my/theme-day-start) (< h my/theme-night-start))
        my/theme-day
      my/theme-night)))

(defun my/theme-apply (theme)
  "Switch `doom-theme' to THEME immediately, triggering a full UI redraw.
Side effect: modifies the global `doom-theme' variable and calls
`doom/reload-theme', which affects all frames."
  (setq doom-theme theme)
  (doom/reload-theme))

(defun my/theme-switch-maybe ()
  "Check the hour and apply day/night theme if different from current.
Persists on `doom-switch-frame-hook' so transitions (7:00/19:00) are
picked up even during long-running sessions.  No-op if already correct."
  (let ((theme (my/theme-for-hour)))
    (unless (eq doom-theme theme)
      (my/theme-apply theme))))

(setq doom-theme (my/theme-for-hour))
(add-hook 'doom-switch-frame-hook #'my/theme-switch-maybe 'append)

;; ─── Line numbers & auto-save ─────────────────────────────────────────────
;; Relative numbers are the Evil/Vim convention — `j`/`k` movement counts are
;; visible at a glance.  Absolute on current line, relative on others is the
;; Doom default; `'relative` keeps it.  For prose-heavy buffers, olivetti
;; disables line-numbers entirely (see olivetti config below).
(setq display-line-numbers-type 'relative)

;; auto-save-timeout: seconds of idle activity before saving.  30s is short
;; enough to not lose much work on crash, long enough to batch rapid edits.
;; auto-save-interval: key presses between saves (belt-and-suspenders).
(setq auto-save-timeout 30
      auto-save-interval 300)

;; ─── Spacious padding (UI breathing room) ─────────────────────────────────
;;
;; Enables `spacious-padding-mode` on the first graphical frame only.
;; The `doom-switch-frame-hook` + guard variable pattern ensures this works
;; safely with the Emacs daemon: if Emacs starts in terminal, padding mode
;; is never activated until a GUI frame appears.
;;
(defvar my/enable-spacious-padding--done nil)

(defun my/enable-spacious-padding--fn (&optional _frame)
  "Enable `spacious-padding-mode' on the first graphical frame only.
Self-removes from `doom-switch-frame-hook' after activation.  No-op if
Emacs is in terminal mode (daemon started with emacsclient -t)."
  (when (and (display-graphic-p)
             (not my/enable-spacious-padding--done))
    (setq my/enable-spacious-padding--done t)
    (remove-hook 'doom-switch-frame-hook #'my/enable-spacious-padding--fn)
    (spacious-padding-mode 1)))

(use-package! spacious-padding
  :commands spacious-padding-mode
  :init
  ;; line-spacing 3pt: enough visual breathing room on modern high-DPI LCDs
  ;; without wasting vertical space (1pt looks cramped, 5pt+ wastes space).
  (setq-default line-spacing 3)
  (add-hook 'doom-switch-frame-hook #'my/enable-spacious-padding--fn))


;; ═══════════════════════════════════════════════════════════════════════════
;; Editor
;; ═══════════════════════════════════════════════════════════════════════════

;; ─── Shell & server basics ────────────────────────────────────────────────
;;
;; `shell-file-name` → bash (not the user's interactive shell, which may be
;; zsh/fish).  Emacs `shell-command' and compile modes rely on POSIX sh
;; syntax; fish in particular is incompatible.  By contrast `vterm-shell`
;; and `explicit-shell-file-name' deliberately use fish — those are
;; interactive and user-facing.
;;
;; `confirm-kill-emacs`: In daemon mode `kill-emacs' just stops the daemon
;; with no visible feedback to clients.  Users interact via `emacsclient`
;; and should use `save-buffers-kill-emacs' (`C-x C-c') which prompts for
;; unsaved buffers.  Nil is safe because the daemon's `kill-emacs' is rarely
;; called directly in normal use.
;;
;; `server-raise-frame t': `emacsclient' frames raise the Emacs frame to the
;; top of the window stack.  Without this, the frame is created but may
;; remain *behind* other windows, causing confusion.
;; `server-client-instructions nil': suppress the "When done, type C-x #"
;; echo — noise for experienced users.
;;
(setq confirm-kill-emacs nil)
(setq shell-file-name (executable-find "bash"))
(setq-default vterm-shell "/usr/bin/fish")
(setq-default explicit-shell-file-name "/usr/bin/fish")
(setq server-raise-frame t
      server-client-instructions nil)

;; ─── Magit ────────────────────────────────────────────────────────────────
;;
;; Disable hunk refinement: for large diffs it adds noticeable latency with
;; little practical benefit (word-level diff highlighting).
;;
;; magit-diff-highlight-trailing t is Doom's default; keep it (trailing
;; whitespace is context-insensitive and cheap to highlight).
;;
(after! magit
  (setq magit-diff-refine-hunk nil))

;; ─── Writing tools ────────────────────────────────────────────────────────
;;
;; Olivetti: centered writing with org-mode.  Width 100 (chars) keeps lines
;; short enough for comfortable reading on a widescreen monitor.  Hide the
;; mode-line to reduce visual noise in prose buffers.
;;
(use-package! olivetti
  :hook (org-mode . olivetti-mode)
  :custom
  (olivetti-body-width 100)
  (olivetti-hide-mode-line t)
  :config
  (define-key olivetti-mode-map (kbd "C-c |") nil)
  (defvar-local my/olivetti--line-numbers-p nil
    "Non-nil if line numbers were enabled before olivetti turned on.")

  (defun my/olivetti-toggle-line-numbers-h ()
    "Disable line numbers in olivetti-mode; restore original state on exit.
Save original state in `my/olivetti--line-numbers-p' on entry, restore on exit."
    (if olivetti-mode
        (setq my/olivetti--line-numbers-p (display-line-numbers-mode -1))
      (when my/olivetti--line-numbers-p
        (display-line-numbers-mode 1))))
  (add-hook 'olivetti-mode-hook #'my/olivetti-toggle-line-numbers-h))

;;
;; Super-save: auto-saves on idle rather than on focus/window-switch events,
;; which is less jarring during flow.  Trims trailing whitespace on save
;; (except current line — prevents fighting with point).  Silent mode avoids
;; mini-buffer chatter.
;;
(use-package! super-save
  :hook (doom-first-file . super-save-mode)
  :custom
  (super-save-auto-save-when-idle t)
  (super-save-silent t)
  (super-save-when-focus-lost nil)
  (super-save-when-buffer-switched nil)
  (super-save-delete-trailing-whitespace 'except-current-line)
  :config
  (add-to-list 'super-save-predicates
               (lambda () (not buffer-read-only))))

;; ─── Palimpsest (move text without deleting) ──────────────────────────────
;;
;; Moving text vs deleting: during drafting, text often needs to be set aside
;; rather than discarded.  Palimpsest moves the region to top/bottom of buffer
;; (out of sight, but still in context) or to a per-file trash file.
;;
;; Bound under SPC m P in org-mode (P = Palimpsest):
;;   t — move to top of buffer
;;   b — move to bottom
;;   T — move to trash file (<basename>.trash.<ext>)
;;
(use-package! palimpsest
  :hook (org-mode . palimpsest-mode)
  :config
  (map! :localleader
        :map org-mode-map
        :prefix ("P" . "Palimpsest")
        :desc "Move to top"    "t" #'palimpsest-move-region-to-top
        :desc "Move to bottom" "b" #'palimpsest-move-region-to-bottom
        :desc "Move to trash"  "T" #'palimpsest-move-region-to-trash))

;; ─── Evil Insert → hybrid (Emacs keys + bar cursor) ──────────────────────
;;
;; Goal: `i` enters insert state with bar cursor and *Emacs native keybindings*
;; (C-w, C-a, C-e, etc.), while preserving `evil-insert-state-map` so that
;; third-party packages (evil-surround, evil-commentary, etc.) can still
;; register insert-mode bindings normally.
;;
;; Mechanism: replace `evil-insert-state-map` with a sparse keymap containing
;; only `<escape>` → normal state.  Every other key falls through to Emacs's
;; global keybinding system.  This produces the same user experience as
;; `evil-emacs-state` but keeps the `evil-insert-state` identity intact.
;;
(after! evil
  (setq evil-insert-state-cursor 'bar)
  (setcdr evil-insert-state-map nil)
  (define-key evil-insert-state-map (kbd "<escape>") 'evil-normal-state))

;; ─── Global keybindings ──────────────────────────────────────────────────
(map! :g "M-!" #'eshell-command)


;; ═══════════════════════════════════════════════════════════════════════════
;; Org mode
;; ═══════════════════════════════════════════════════════════════════════════

;; All org-related content lives under a single top-level directory.
;; This anchors org-capture, org-agenda, denote, deft, and org-noter —
;; changing it requires updating all consumers.
(setq org-directory "~/org/")

;; org-noter searches this path for annotation notes associated with PDF/DJVU
;; documents.  Keeping annotations in a dedicated subdirectory avoids clutter
;; in the main note pool.
(setq org-noter-notes-search-path '("~/org/deft/annotations"))

(after! org
  ;; Custom TODO workflow: DRAFT (write) → REVIEW (edit) → DONE / CANCELLED.
  ;; The third pipe segment `|` separates active vs inactive keywords.
  (add-to-list 'org-todo-keywords
               '(sequence "DRAFT(R)" "REVIEW(r)" "|" "CANCELLED(C)") t)

  ;; Capture template for novel ideas — metadata-rich entry with character,
  ;; mood, and source tracking.  Prepend so newest are first.
  (add-to-list 'org-capture-templates
               '("w" "Novel idea" entry
                 (file+headline "~/org/novel-inbox.org" "Inspiration inbox")
                 "* %^{Title} :%^g\n  :PROPERTIES:\n  :CREATED: %U\n  :Source: %^{Source}\n  :Character: %^{Character}\n  :Mood: %^{Mood}\n  :Notes: %^{Notes}\n  :END:\n\n  %?\n  - From: %a"
                 :prepend t
                 :empty-lines 1))

  ;; Hide markers like `=`, `*`, `~` around text — the visual result reads like
  ;; rendered markup, eliminating visual noise while composing.  Fontification
  ;; (italic/bold/monospace) still applies, so the formatting remains visible.
  (setq org-hide-emphasis-markers t)
  ;; Open `.html` / `.xhtml` files externally via the OS handler, not inside
  ;; Emacs (shr/eww).  HTML content is read in a browser for proper CSS/JS.
  (add-to-list 'org-file-apps '("\\.x?html?\\'" . "xdg-open %s")))

;; ─── Org capture helper ───────────────────────────────────────────────────
(defun org-capture-goto-target (&optional template-key)
  "Jump to the target location of a capture template without actually capturing.
Useful for preview where a capture would land before committing to it."
  (interactive)
  (require 'org-capture)
  (let ((entry (org-capture-select-template template-key)))
    (unless entry (error "No capture template selected — use C-u to specify a template key"))
    (org-capture-set-plist entry)
    (org-capture-set-target-location)
    (pop-to-buffer-same-window (org-capture-get :buffer))
    (goto-char (org-capture-get :pos))))

;; ─── Pandoc docx export ───────────────────────────────────────────────────
(defvar my/pandoc-dir (expand-file-name "pandoc" doom-user-dir)
  "Directory holding pandoc reference docx and Lua filters.")

(after! ox-pandoc
  (setq org-pandoc-options-for-docx
        `((reference-doc . ,(expand-file-name
                             "templates/template_标题不编号-列表第二行顶格.docx"
                             my/pandoc-dir))
          (lua-filter . ,(expand-file-name "markdown-to-docx.lua" my/pandoc-dir)))))

;; ─── Org HTML export (local minimal theme) ────────────────────────────────
;;
;; Custom CSS only — no default style include and zero JS.  The CSS files
;; live in `org-export/minimal/css/` and provide a clean print-like layout.
;; Rationale: the default org export HTML includes full-page styling geared
;; toward printing — for screen viewing it's heavy and hard to theme.
;;
(defvar my/org-export-assets-dir
  (expand-file-name "org-export/minimal" doom-user-dir)
  "Directory containing Org HTML export assets (CSS, no JS).
Referenced by `ox-html' configuration below.  Structure:
  org-export/minimal/css/org.css
  org-export/minimal/css/htmlize.css")

(after! ox-html
  (setq org-html-head-include-default-style nil)
  (let ((css-dir (expand-file-name "css" my/org-export-assets-dir)))
    (setq org-html-head
          (concat
           "<link rel=\"stylesheet\" type=\"text/css\" href=\"" css-dir "/org.css\"/>\n"
           "<link rel=\"stylesheet\" type=\"text/css\" href=\"" css-dir "/htmlize.css\"/>"))
    (setq org-html-head-extra "")))

;; ─── External browser for links ──────────────────────────────────────────
;; xdg-open delegates to the desktop environment's default handler
;; (Firefox/Chrome/whatever the user configured system-wide).  Hard-coding
;; a specific browser would break on headless terminals or non-XDG desktops.
(setq browse-url-browser-function #'browse-url-xdg-open)

;; ─── Large Org file handling (≥1 MiB) ────────────────────────────────────
;;
;; Org-mode prettification (org-modern, org-appear, org-indent, fontification,
;; prettify-symbols, variable-pitch) causes noticeable UI lag in files larger
;; than ~1 MiB.  This hook detects oversized buffers at open time and strips
;; all decoration — trading aesthetics for responsiveness.  The threshold is
;; a heuristic; adjust MY/ORG-LARGE-FILE-SIZE-THRESHOLD for your machine.
;;
(defvar my/org-large-file-size-threshold (* 1024 1024)
  "Files >= 1 MiB trigger `my/org-maybe-disable-prettification' to strip
decoration.  1 MiB is a heuristic — Org's redisplay cost scales with file
size and prettification complexity.  Adjust per-machine.

Reference: a ~600 KiB Org file with ~5000 lines and ~50 headings can
already show multi-second font-lock pauses on a 2022 laptop CPU.")

(defun my/org-maybe-disable-prettification ()
  "Disable Org decorative modes for buffers >= `my/org-large-file-size-threshold'.

Called from `org-mode-hook'.  Trading aesthetics for responsive scrolling
and typing.  The following are disabled unconditionally when the threshold
is exceeded:
  - org-modern, org-appear, org-indent (structural overlays)
  - prettify-symbols (composition regex on every insert)
  - variable-pitch (slows redisplay with mixed fonts)
  - Fontification extras (TODO faces, priority faces, emphasis markers)"
  (when-let ((attrs (and buffer-file-name
                         (not (file-remote-p buffer-file-name))
                         (file-attributes buffer-file-name))))
    (when (> (file-attribute-size attrs) my/org-large-file-size-threshold)
      (when (bound-and-true-p org-modern-mode) (org-modern-mode -1))
      (when (bound-and-true-p org-appear-mode) (org-appear-mode -1))
      (when (bound-and-true-p org-indent-mode) (org-indent-mode -1))
      (setq-local org-hide-leading-stars nil
                  org-fontify-done-headline nil
                  org-fontify-quote-and-verse-blocks nil
                  org-fontify-whole-heading-line nil
                  org-priority-faces nil
                  org-todo-keyword-faces nil
                  org-pretty-entities nil
                  org-hide-emphasis-markers nil
                  org-ellipsis "...")
      (when (bound-and-true-p prettify-symbols-mode) (prettify-symbols-mode -1))
      (setq-local prettify-symbols-alist nil)
      (when (bound-and-true-p variable-pitch-mode) (variable-pitch-mode -1))
      (font-lock-flush))))

(add-hook 'org-mode-hook #'my/org-maybe-disable-prettification)

;; Don't let so-long hijack org-mode (it has its own large-file handler above).
(after! so-long
  (setq so-long-predicate
        (lambda () (and (not (derived-mode-p 'org-mode))
                        (doom-so-long-p)))))


;; ═══════════════════════════════════════════════════════════════════════════
;; LaTeX (AUCTeX + Org → LaTeX export)
;; ═══════════════════════════════════════════════════════════════════════════

;; XeLaTeX as default engine — required for Chinese / OpenType font support.
;; PDFTeX cannot handle CJK characters without intrusive packages (CJKutf8);
;; LuaLaTeX is another option but slower for small docs.
;;
(setq-default TeX-engine 'xetex)

;; ─── Org → LaTeX headline formatting ──────────────────────────────────────
;;
;; Custom `org-latex-format-headline-function` that wraps TODO keywords,
;; priorities, and tags in `\texorpdfstring{}{}` so that PDF bookmarks
;; (which cannot handle LaTeX color commands) get a plain-text fallback.
;; Without this, bookmarks show raw code like `{\color{red!65!black}...}`.
;;
(defun my/org-latex-format-headline (todo todo-type priority text tags _info)
  (concat
   (and todo
        (let ((fmt (pcase todo-type
                     ('todo "{\\color{red!65!black}\\bfseries\\sffamily %s}")
                     ('done "{\\color{green!45!black}\\bfseries\\sffamily %s}")
                     (_ "{\\bfseries\\sffamily %s}"))))
          (format "\\texorpdfstring{%s }{%s }" (format fmt todo) todo)))
   (and priority
        (let* ((pri-str (org-priority-to-string priority))
               (colored (format "{\\color{orange!60!black}\\small\\sffamily [\\#%s]}" pri-str)))
          (format "\\texorpdfstring{%s }{%s }" colored (format "[\\#%s]" pri-str))))
   text
   (and tags
        (let ((tag-text (mapconcat #'org-latex--protect-text tags ":")))
          (format "\\texorpdfstring{\\hfill{}{\\color{gray!50!black}\\small %s}}{}" tag-text)))))

(use-package! ox-latex
  :defer t
  :after ox
  :custom
  (org-latex-format-headline-function #'my/org-latex-format-headline)

  (org-latex-logfiles-extensions
   '("lof" "lot" "tex~" "aux" "idx" "log" "out" "toc" "nav" "snm"
     "vrb" "dvi" "fdb_latexmk" "blg" "brf" "fls" "entoc" "ps" "spl" "bbl" "tex" "bcf"))

  :config
  ;; LaTeX compilation with TEXINPUTS to find ctexbook-org.cls
  ;; in the modules/ directory.
  (let* ((modules-dir (expand-file-name "modules" doom-user-dir))
         (cmd (format "env TEXINPUTS=%s//: latexmk -xelatex -shell-escape -interaction=nonstopmode -f -output-directory=%%o %%f"
                      modules-dir)))
    (setq org-latex-pdf-process (list cmd)))

  ;; Custom LaTeX class for Chinese typesetting, based on ctexbook.
  ;; All packages are loaded from modules/ctexbook-org.cls.
  (add-to-list 'org-latex-classes
               '("ctexbook"
                 "\\documentclass{ctexbook-org}
[PACKAGES]
[EXTRA]"
                 ("\\chapter{%s}" . "\\chapter*{%s}")
                 ("\\section{%s}" . "\\section*{%s}")
                 ("\\subsection{%s}" . "\\subsection*{%s}")))
  (setq org-latex-default-class "ctexbook"))


;; ═══════════════════════════════════════════════════════════════════════════
;; Notes (Deft + Denote + Consult-notes)
;; ═══════════════════════════════════════════════════════════════════════════

;; ─── Deft (file-browsing for plain-text notes) ────────────────────────────
;;
;; Override `deft-parse-title': the default expects an org-mode #+TITLE;
;; but Deft also picks up non-org files where we still want title extraction.
;; The custom regex matches both `#+title:` and Org `#+TITLE:` variants.
;;
;; deft-strip-summary-regexp: removes metadata lines from the preview
;; snippet shown in Deft's file list.  Without this, every file shows a
;; wall of #+KEYWORD: ... and :PROPERTIES: drawers instead of the actual
;; prose first paragraph.
;;
(after! deft
  (setq deft-directory "~/org/deft"
        deft-recursive t)
  (defun my/deft-parse-title (file contents)
    "Override `deft-parse-title' to accept case-insensitive #+TITLE lines.
Default only matches `#+title' (lowercase); our Convention Capitalizes
Org Keywords."
    (if (string-match "^#\\+[tT][iI][tT][lL][Ee]:\\s-*\\(.*\\)" contents)
        (match-string 1 contents)
      (deft-base-filename file)))
  (advice-add 'deft-parse-title :override #'my/deft-parse-title)
  (setq deft-strip-summary-regexp
        (concat "\\("
                "[\n\t]"
                "\\|^#\\+[[:alpha:]_]+:.*$"
                "\\|^:PROPERTIES:\n\\(.+\n\\)+:END:\n"
                "\\)")))

;; ─── Denote (file-naming Zettelkasten) ────────────────────────────────────
;;
;; Denote generates file names from a timestamp + title + keywords, enabling
;; discovery without a database.  Everything is plain files in
;; `~/Documents/notes/`.
;;
;; `:after-call doom-first-buffer-hook` defers loading until Emacs is idle
;; after startup — faster boot than `:defer t` (which blocks on first
;; interactive command that triggers autoload).
;;
(use-package! denote
  :after-call doom-first-buffer-hook
  :hook
  (dired-mode . denote-dired-mode-in-directories)
  (text-mode . denote-fontify-links-mode)
  :custom
  (denote-directory "~/org/denote")
  (denote-dired-directories (list denote-directory))
  (denote-dired-directories-include-subdirectories t)
  ;; Personal keyword taxonomy — adjust to your domain.
  (denote-known-keywords '("创作" "学习" "工作" "生活" "技术" "思考" "索引"))
  (denote-infer-keywords t)
  (denote-sort-keywords t)
  (denote-prompts '(title keywords))
  (denote-date-prompt-use-org-read-date t)
  (denote-save-buffers nil)
  (denote-rename-confirmations '(rewrite-front-matter modify-file-name))
  (denote-link-description-format "%t")
  :init
  (map! :leader
        (:prefix-map ("r d" . "Denote")
         :desc "New note"                "n" #'denote
         :desc "Date note"               "d" #'denote-date
         :desc "Select type"             "t" #'denote-type
         :desc "Open or create"          "o" #'denote-open-or-create
         :desc "Find link"               "l" #'denote-find-link
         :desc "Link or create"          "i" #'denote-link-or-create
         :desc "New sequence"            "s" #'denote-sequence
         :desc "Rename keywords"         "k" #'denote-rename-file-keywords
         :desc "Rename file"             "r" #'denote-rename-file
         :desc "Rename front matter"     "R" #'denote-rename-file-using-front-matter
         :desc "Search notes"            "f" #'consult-notes
         :desc "Find backlinks"          "b" #'denote-find-backlink
         :desc "Dired notes"             "D" #'denote-dired
         :desc "Grep notes"              "g" #'denote-grep
         (:prefix-map ("e" . "Explore")
          :desc "Count notes"         "c" #'denote-explore-count-notes
          :desc "Count keywords"      "C" #'denote-explore-count-keywords
          :desc "Random note"         "r" #'denote-explore-random-note
          :desc "Random link"         "l" #'denote-explore-random-link
          :desc "Knowledge network"   "n" #'denote-explore-network)))
  :config
  (denote-rename-buffer-mode 1)

  ;; Auto-commit notes to git after every new note.
  ;; This is a simple safety net, not a full VCS workflow.
  ;; If the notes directory isn't a git repo, this silently does nothing.
  (defun my/denote-git-auto-commit ()
    "Auto-add and commit all changes to the Denote directory via git.
Silent no-op if the directory is not a git repository (no error signaled)."
    (when-let ((dir (denote-directory)))
      (let ((git-dir (expand-file-name ".git" dir)))
        (when (file-exists-p git-dir)
          (let ((default-directory dir))
            (unless (zerop (call-process "git" nil nil nil "add" "-A"))
              (message "WARN: denote git add failed"))
            (unless (zerop (call-process "git" nil nil nil
                                         "commit" "--allow-empty"
                                         "-m" "auto: note saved"))
              (message "WARN: denote git commit failed")))))))
  (add-hook 'denote-after-new-note-hook #'my/denote-git-auto-commit))

(use-package! denote-journal
  :after denote
  :hook (calendar-mode . denote-journal-calendar-mode)
  :custom
  (denote-journal-directory "journal")
  (denote-journal-keyword '("日记"))
  (denote-journal-title-format 'day-date-month-year)
  :init
  (map! :leader
        (:prefix-map ("r d" . "Denote")
         :desc "Journal entry" "j" #'denote-journal-new-or-existing-entry)))

(use-package! denote-menu
  :after denote
  :custom
  (denote-menu-show-file-type t)
  (denote-menu-show-file-signature t)
  :init
  (map! :leader
        (:prefix-map ("r d" . "Denote")
         :desc "List notes (menu)" "m" #'list-denotes))
  :config
  (define-key denote-menu-mode-map (kbd "c")   #'denote-menu-clear-filters)
  (define-key denote-menu-mode-map (kbd "/ r") #'denote-menu-filter)
  (define-key denote-menu-mode-map (kbd "/ k") #'denote-menu-filter-by-keyword)
  (define-key denote-menu-mode-map (kbd "/ o") #'denote-menu-filter-out-keyword)
  (define-key denote-menu-mode-map (kbd "e")   #'denote-menu-export-to-dired))

(use-package! denote-org
  :after denote
  :commands
  (denote-org-link-to-heading
   denote-org-backlinks-for-heading
   denote-org-extract-org-subtree
   denote-org-convert-links-to-file-type
   denote-org-convert-links-to-denote-type)
  :init
  (map! :leader
        (:prefix-map ("r d" . "Denote")
         :desc "Link to heading"     "h" #'denote-org-link-to-heading
         :desc "Heading backlinks"   "H" #'denote-org-backlinks-for-heading
         :desc "Extract subtree"    "x" #'denote-org-extract-org-subtree))
  (map! :localleader
        :map org-mode-map
        :prefix ("D" . "Denote")
        :desc "Link to heading"     "h" #'denote-org-link-to-heading
        :desc "Heading backlinks"   "b" #'denote-org-backlinks-for-heading
        :desc "Extract subtree"     "x" #'denote-org-extract-org-subtree))

(use-package! consult-notes
  :after denote
  :custom
  (consult-notes-denote-display-keywords-indicator "_")
  :config
  (consult-notes-denote-mode))


;; ═══════════════════════════════════════════════════════════════════════════
;; Reading (Dired, EPUB, PDF)
;; ═══════════════════════════════════════════════════════════════════════════

;; ─── Dired: open files externally ─────────────────────────────────────────
;;
;; `E` key in dired to open marked files with the OS handler (xdg-open on
;; Linux, open on macOS, start on Windows).  Why `E` (uppercase): Doom's
;; dired uses `e` for `dired-find-file` (inline), and `E` is mnemonic
;; for "External".  Uses `start-process` (async, no waiting).
;;
(after! dired
  (defun my/dired-open-externally ()
    "Open each marked file with the OS default application (async).
Uses `xdg-open` (Linux), `open` (macOS), or `start` (Windows).  Returns
immediately without waiting for the child process — suitable for bulk
open from Dired."
    (interactive)
    (let* ((files (dired-get-marked-files))
           (cmd (pcase system-type
                  ('darwin "open")
                  ('windows-nt "start")
                  (_ "xdg-open"))))
      (dolist (f files)
        (start-process cmd nil cmd f))))
  (map! :map dired-mode-map
        :n "E" #'my/dired-open-externally))

;; ─── EPUB (nov.el) ────────────────────────────────────────────────────────
;;
;; nov.el renders EPUB as styled HTML in an Emacs buffer.  Enable
;; visual-line-mode + variable-pitch-mode for a book-like reading experience.
;; olivetti-mode centers text.  Disable hl-line (distracting for reading).
;; Save place between sessions via `nov-save-place-file`.
;;
(use-package! nov
  :mode ("\\.epub\\'" . nov-mode)
  :hook ((nov-mode . visual-line-mode)
         (nov-mode . variable-pitch-mode)
         (nov-mode . (lambda () (hl-line-mode -1))))
  :custom
  (nov-text-width t)
  (nov-variable-pitch-mode t)
  (nov-save-place-file (concat doom-cache-dir "nov-places"))
  :config
  (add-hook 'nov-mode-hook #'olivetti-mode)
  (defun my/nov-disable-adaptive-fill ()
    (setq-local adaptive-fill-mode nil))
  (add-hook 'nov-mode-hook #'my/nov-disable-adaptive-fill))

;; ─── PDF (pdf-tools) ──────────────────────────────────────────────────────
;;
;; `fit-page` for whole-page view (like a real PDF reader).  Roll minor mode
;; gives smooth scrolling.  The org-noter-pdf advice suppresses arrow-timer
;; errors (a known bug when roll-mode and org-noter interact).
;;
;; pdf-view-resize-factor 1.1: zoom in/out steps (smaller than default 1.2
;; for finer control).  pdf-view-selection-style 'glyph: select text by glyph
;; boundaries rather than pixel — more accurate for copy-paste.
;;
(after! pdf-tools
  (setq pdf-view-display-size 'fit-page
        pdf-view-resize-factor 1.1
        pdf-annot-activate-created-annotations t
        pdf-view-use-scaling nil
        pdf-view-use-imagemagick nil
        pdf-view-selection-style 'glyph)
  (add-hook! 'pdf-view-mode-hook #'pdf-view-roll-minor-mode #'evil-emacs-state))

;; FIXME: workaround for `org-noter-pdf--show-arrow` error triggered when
;; `pdf-view-roll-minor-mode` is active.  The error is non-fatal (the arrow
;; simply doesn't show on rolled pages) but it pollutes `*Messages*`.
;; Remove when org-noter-pdf upstream fixes the roll-mode interaction.
(after! org-noter-pdf
  (defun pdf-view-current-overlay (&optional window)
    (or (image-mode-window-get 'overlay window)
        (when (and (bound-and-true-p pdf-view-roll-minor-mode)
                   (fboundp 'pdf-roll-page-overlay))
          (condition-case nil
              (pdf-roll-page-overlay (pdf-view-current-page) window)
            (error nil)))))
  (defadvice! +org-noter-pdf--show-arrow-a (orig-fn)
    :around #'org-noter-pdf--show-arrow
    (condition-case nil (funcall orig-fn) (error nil))))

(use-package! org-pdftools
  :defer t
  :commands org-pdftools-setup-link
  :hook (org-load . org-pdftools-setup-link))

;; Open current PDF in Zathura (external viewer) via `g z`.
;; Useful when pdf-tools can't render something or you need Annotator.
(map! :map pdf-view-mode-map
      :n "g z" (cmd! (when-let ((f (buffer-file-name)))
                       (start-process "zathura" nil "zathura" f))))


;; ═══════════════════════════════════════════════════════════════════════════
;; i18n / Chinese support
;; ═══════════════════════════════════════════════════════════════════════════

;; ─── Chinese input method (fcitx5) ────────────────────────────────────────
;;
;; `doom-first-input-hook` defers loading until the user actually types —
;; avoids starting fcitx5 at Emacs launch.  fcitx5-remote toggles the IME
;; on Evil mode transitions; without this, you'd be stuck in Chinese input
;; in normal state or unable to type Chinese in insert state.
;;
(add-transient-hook! 'doom-first-input-hook
  (when-let ((cmd (or (executable-find "fcitx5-remote")
                      (executable-find "fcitx-remote"))))
    (setq fcitx-remote-command cmd)
    (require 'fcitx)
    (fcitx-evil-turn-on)))

;; ─── Pinyin fuzzy matching (search + navigation) ──────────────────────────
;;
;; Two complementary packages:
;;   - evil-pinyin: advises `orderless-regexp` to return a pinyin-fuzzy regex
;;     so that `M-x` / `consult` / `vertico` searches match Chinese via
;;     pinyin initials (e.g. "xie" → "写作", "xiexie", etc.).
;;   - ace-pinyin: extends Avy (character-jump) to accept pinyin input for
;;     Chinese characters, so you can `avy-goto-char-timer` with pinyin.
;;
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

;; ─── Text statistics (CJK + English, all-C module) ─────────────────────────
;;
;; C module (modules/count-cjk.so) does all counting in a single UTF-8
;; scan.  The loader auto-detects stale/missing .so and runs make(1);
;; commands try on-demand rebuild if the module is absent at call time.
;;
;; Exported C functions:
;;   my/count-cjk  (STRING) → cons (CHARS . PUNCT)
;;   my/count-text (STRING) → vector [cjk punct en-words en-chars total-cp]
;;
;; Bindings:
;;   M-=         — my/count-words (replaces `count-words-region')
;;   SPC r n c   — my/count-chinese-chars (legacy CJK counter)
;;   SPC r n b   — my/build-cjk-module (rebuild & reload)
;;
;; Benchmark (Emacs 30, GCC 15, ~50/50 CJK/ASCII mix):
;;   Size    Original (Elisp)  C module  Speedup
;;   1 KB        28 ms          0.7 ms    42×
;;   10 KB      211 ms         21 ms      10×
;;   100 KB   1926 ms         162 ms      12×
;;   500 KB   9376 ms         613 ms      15×

;; ─── C module loader ─────────────────────────────────────────────────────

(defvar my/cjk-so (expand-file-name "modules/count-cjk.so" doom-user-dir))
(defvar my/cjk-src (expand-file-name "modules/count-cjk.c" doom-user-dir))

(defun my/cjk-module-outdated-p ()
  "Return t if .so is missing or older than .c source."
  (let ((c-attrs (file-attributes my/cjk-src)))
    (and c-attrs
         (or (not (file-exists-p my/cjk-so))
             (time-less-p (file-attribute-modification-time
                           (file-attributes my/cjk-so))
                          (file-attribute-modification-time c-attrs))))))

(defun my/build-cjk-module ()
  "Build count-cjk.so by running `make -C modules/'.
Shows build log buffer on failure."
  (interactive)
  (let* ((build-dir (expand-file-name "modules" doom-user-dir))
         (buf (get-buffer-create "*cjk-build*")))
    (with-current-buffer buf (view-mode -1) (erase-buffer))
    (if (zerop (call-process "make" nil buf nil "-C" build-dir))
        (progn (message "count-cjk.so rebuilt") t)
      (display-buffer buf)
      (error "count-cjk.so build failed — see *cjk-build* buffer"))))

(defun my/load-cjk-module ()
  "Load CJK C module; auto-build if missing or stale.
Safe no-op if module-load is unavailable."
  (interactive)
  (when (fboundp 'module-load)
    (when (my/cjk-module-outdated-p)
      (ignore-errors (my/build-cjk-module)))
    (when (file-exists-p my/cjk-so)
      (with-demoted-errors "count-cjk.so load: %s"
        (module-load my/cjk-so)))))

(my/load-cjk-module)

;; ─── Helper ──────────────────────────────────────────────────────────────

(defun my/ensure-cjk-module ()
  "Ensure C module is loaded; build on demand if missing.
Signals error if the module cannot be made available."
  (unless (fboundp 'my/count-text)
    (my/build-cjk-module)
    (when (file-exists-p my/cjk-so)
      (module-load my/cjk-so))
    (unless (fboundp 'my/count-text)
      (error "count-cjk.so still unavailable after rebuild"))))

;; ─── Commands ────────────────────────────────────────────────────────────

;;;###autoload
(defun my/count-chinese-chars (&optional beg end)
  "CJK char count (legacy).  Bound to `SPC r n c'."
  (interactive)
  (my/ensure-cjk-module)
  (let* ((beg (or beg (if (use-region-p) (region-beginning) (point-min))))
         (end (or end (if (use-region-p) (region-end) (point-max))))
         (result (my/count-cjk (buffer-substring-no-properties beg end)))
         (cn-chars (car result))
         (cn-punct (cdr result))
         (total (- end beg))
         (pct (if (> total 0) (/ (* (+ cn-chars cn-punct) 100.0) total) 0.0)))
    (message (concat "字:%d  含标点:%d  总:%d  %.1f%%"
                     (if (use-region-p) " (选中)" ""))
             cn-chars (+ cn-chars cn-punct) total pct)))

;;;###autoload
(defun my/count-words (&optional beg end)
  "Count CJK chars, English words, and punctuation in region or buffer.

Replaces `count-words-region' (M-=).  Uses C module for all counting.

Output:  中:42  英:18  标点:7  总:67

   中       CJK ideographs (word-count equivalent for Chinese)
   英       English words (letter/digit/apostrophe runs)
   标点     CJK punctuation marks
   总       total Unicode codepoints in the region"
  (interactive)
  (my/ensure-cjk-module)
  (let* ((beg (or beg (if (use-region-p) (region-beginning) (point-min))))
         (end (or end (if (use-region-p) (region-end) (point-max))))
         (v (my/count-text (buffer-substring-no-properties beg end)))
         (cjk (aref v 0))
         (punct (aref v 1))
         (en-words (aref v 2))
         (total (aref v 4)))
    (message "中:%d  英:%d  标点:%d  总:%d" cjk en-words punct total)))

;; ─── Bindings ────────────────────────────────────────────────────────────

(map! :leader
      (:prefix-map ("r n" . "Count")
       :desc "Chinese chars"  "c" #'my/count-chinese-chars
       :desc "Rebuild module" "b" #'my/build-cjk-module))

(map! :g "M-=" #'my/count-words)





;; ═══════════════════════════════════════════════════════════════════════════
;; Tools
;; ═══════════════════════════════════════════════════════════════════════════

;; ─── Full reload (config + autoloads + packages + theme + font + frames) ──
;;
;; Doom's built-in `doom/reload` only re-evaluates config files.  This
;; custom command does a more thorough job for when you change theme, font,
;; packages, or autoloaded files:
;;   1. `doom/reload-autoloads` — re-scans autoloads (no `doom sync`)
;;   2. `doom/reload-packages` — re-evaluates `packages.el`
;;   3. `doom/reload` — re-evaluates `config.el` (core)
;;   4. After reload: re-apply theme, font, and re-run frame hooks
;;      (needed because `doom/reload` resets but doesn't re-trigger them).
;;
;; Bound to `SPC h r R` (uppercase R = Full reload vs lowercase r = reload).
;;
(defun my/doom-full-reload--apply (&rest _)
  "Re-apply theme and font after `doom/reload'.

Only reapplies theme + font — does NOT re-run `server-after-make-frame-hook'
or other non-idempotent frame hooks.  Runs via `doom-after-reload-hook'."
  (my/theme-apply (my/theme-for-hour))
  (when (fboundp 'doom/reload-font)
    (doom/reload-font))
  (message "Full reload complete (config + theme + font)"))

;; Register once at top level (not inside `my/doom-full-reload') to prevent
;; hook accumulation on repeated calls.
(after! doom
  (add-hook 'doom-after-reload-hook #'my/doom-full-reload--apply))

(defun my/doom-full-reload ()
  "Reload autoloads, packages and config.

Steps:
1. `doom/reload-autoloads` — pick up new autoloaded commands/faces.
2. `doom/reload-packages` — re-evaluate `packages.el` without `doom sync`.
3. `doom/reload` — re-evaluate `config.el` (core).
4. `doom-after-reload-hook` fires automatically, re-applying theme and font
   via `my/doom-full-reload--apply` (registered at top level).

Each step guards against missing fboundp (safe when called before Doom's
reload machinery is fully initialized).

Bound to `SPC h r R`."
  (interactive)
  (when (fboundp 'doom/reload-autoloads)
    (ignore-errors (doom/reload-autoloads)))
  (when (fboundp 'doom/reload-packages)
    (ignore-errors (doom/reload-packages)))
  (when (fboundp 'doom/reload)
    (ignore-errors
      (doom/reload))))

(map! :leader
      :desc "Full reload" "h r R" #'my/doom-full-reload)

;; ── C dynamic modules ─────────────────────────────────────────────────────
(module-load (expand-file-name "modules/cnotify-module.so" doom-user-dir))
(module-load (expand-file-name "modules/count-cjk.so" doom-user-dir))

;; Wayland clipboard (transparent — hooks into Emacs copy/paste)
(when (and (getenv "WAYLAND_DISPLAY")
           (file-exists-p (expand-file-name "modules/clipboard-wl.so" doom-user-dir)))
  (module-load (expand-file-name "modules/clipboard-wl.so" doom-user-dir))

  ;; Copy: M-w / C-w also set Wayland clipboard
  (setq interprogram-cut-function
        (lambda (text &optional push)
          (ignore push)
          (when (fboundp 'clipboard-set)
            (condition-case nil
                (clipboard-set "text/plain" text)
              (error nil)))))

  ;; Paste: C-y gets text from Wayland clipboard first
  (setq interprogram-paste-function
        (lambda ()
          (when (fboundp 'clipboard-get)
            (condition-case nil
                (clipboard-get "text/plain")
              (error nil)))))

  (message "🔧 Wayland clipboard: loaded (multi-window copy/paste)"))

;; ─── Pomodoro log ────────────────────────────────────────────────────────
(defvar my/pomodoro-log-file
  (expand-file-name "pomodoro.log.el" doom-user-dir)
  "Sexp log of completed pomodoro cycles.")

(defvar my/pomodoro-default-task "专注"
  "Default task name when none provided at prompt.")

(defun my/pomodoro-log-read ()
  "Read all log entries, returns list of plists."
  (when (file-exists-p my/pomodoro-log-file)
    (with-temp-buffer
      (insert-file-contents my/pomodoro-log-file)
      (goto-char (point-min))
      (read (current-buffer)))))

(defun my/pomodoro-log-write (entry)
  "Append ENTRY (plist) to log file."
  (with-temp-file my/pomodoro-log-file
    (when (file-exists-p my/pomodoro-log-file)
      (insert-file-contents my/pomodoro-log-file))
    (goto-char (point-max))
    (insert (prin1-to-string entry) "\n")))

(defun my/pomodoro-log-entry (task minutes)
  "Write a completed pomodoro entry."
  (my/pomodoro-log-write
   `(:time ,(format-time-string "%Y-%m-%d %H:%M")
     :task ,task :work ,minutes :break 5)))

(defun my/pomodoro-show-stats ()
  "Show pomodoro statistics: today, week, total."
  (interactive)
  (let* ((entries (my/pomodoro-log-read))
         (today (format-time-string "%Y-%m-%d"))
         (week-start (format-time-string "%Y-%m-%d"
                      (time-subtract (current-time)
                       (* (1- (string-to-number (format-time-string "%u"))) 86400))))
         (today-entries (seq-filter
                         (lambda (e) (string-prefix-p today (plist-get e :time)))
                         entries))
         (week-entries (seq-filter
                        (lambda (e) (not (string< (substring (plist-get e :time) 0 10) week-start)))
                        entries))
         (today-cycles (length today-entries))
         (today-minutes (apply #'+ (mapcar (lambda (e) (plist-get e :work)) today-entries)))
         (week-cycles (length week-entries))
         (week-minutes (apply #'+ (mapcar (lambda (e) (plist-get e :work)) week-entries)))
         (total-cycles (length entries))
         (total-minutes (apply #'+ (mapcar (lambda (e) (plist-get e :work)) entries)))
         (buf (get-buffer-create "*Pomodoro Stats*")))
    (with-current-buffer buf
      (erase-buffer)
      (insert (format "🍅 Pomodoro Statistics\n\n"))
      (insert (format "Today:  %d cycles, %d min\n" today-cycles today-minutes))
      (insert (format "Week:   %d cycles, %d min\n" week-cycles week-minutes))
      (insert (format "Total:  %d cycles, %d min (%.1f hours)\n\n"
                      total-cycles total-minutes (/ total-minutes 60.0)))
      (insert "Recent:\n")
      (dolist (e (reverse (seq-take (reverse entries) 10)))
        (insert (format "  %s  %s  %dmin\n"
                        (plist-get e :time) (plist-get e :task) (plist-get e :work))))
      (special-mode)
      (goto-char (point-min)))
    (switch-to-buffer buf)))

;; ─── Pomodoro tracking (phase transitions) ────────────────────────────────
(defvar my/pomodoro--prev-phase 0 "Previous pomodoro phase, for detecting cycle completion.")
(defvar my/pomodoro--current-task nil "Task name for current pomodoro session.")
(defvar my/pomodoro--current-work-min 25 "Work minutes for current session.")

(defun my/pomodoro-start (&optional task work-min break-min)
  "Start pomodoro with TASK name (default \"专注\")."
  (interactive)
  (let ((tname (or task
                   (let ((s (read-string "Task: " nil nil my/pomodoro-default-task)))
                     (if (string= s "") my/pomodoro-default-task s))))
        (w (or work-min 25))
        (b (or break-min 5)))
    (setq my/pomodoro--current-task tname
          my/pomodoro--current-work-min w
          my/pomodoro--prev-phase 0)
    (cnotify-pomodoro-start w b)
    (message "🍅 %s — %d min" tname w)))

(defun my/pomodoro-stop ()
  "Stop running pomodoro (incomplete — not logged)."
  (interactive)
  (cnotify-pomodoro-stop)
  (setq my/pomodoro--prev-phase 0)
  (message "🍅 Pomodoro stopped — not logged"))

(defun my/timer-start (minutes &optional message)
  "Start countdown timer for MINUTES, notify with MESSAGE."
  (interactive "nMinutes: \nsMessage: ")
  (cnotify-timer-start (* minutes 60) (or message "Timer finished")))

(defun my/timer-stop ()
  "Stop running timer."
  (interactive)
  (cnotify-timer-stop))

(defun my/password-gen (&optional length)
  "Generate a strong password and copy to clipboard."
  (interactive "P")
  (let* ((len (or length 24))
         (pw (password-gen len)))
    (if (fboundp 'clipboard-set)
        (clipboard-set "text/plain" pw)
      (kill-new pw))
    (message "🔑 Password (%d chars) copied to clipboard" len)))

(defun my/word-count (&optional beg end)
  "Count CJK/English chars and words in region (or whole buffer)."
  (interactive "r")
  (let* ((text (if (use-region-p)
                   (buffer-substring-no-properties beg end)
                 (buffer-substring-no-properties (point-min) (point-max))))
         (label (if (use-region-p) "Region" "Buffer"))
         (v    (my/count-text text)))
    (message "%s: %d CJK, %d punct, %d EN words (%d EN chars), %d total cp"
             label (aref v 0) (aref v 1) (aref v 2) (aref v 3) (aref v 4))))

(map! :leader
      (:prefix-map ("r t" . "Tools")
       :desc "Start timer"              "t" #'my/timer-start
       :desc "Stop timer"               "T" #'my/timer-stop
       :desc "Start pomodoro"           "s" #'my/pomodoro-start
       :desc "Stop pomodoro"            "S" #'my/pomodoro-stop
       :desc "Word count"               "w" #'my/word-count
       :desc "Pomodoro stats"           "v" #'my/pomodoro-show-stats
       :desc "Generate password"         "p" #'my/password-gen))

;; ── Modeline: timer / pomodoro countdown ───────────────────────
(defvar my/cnotify-indicator nil "Mode-line string for timer/pomodoro.")
(defvar my/cnotify-update-timer nil "Internal 1s timer for modeline refresh.")

(defun my/cnotify-refresh ()
  "Refresh modeline from C module status. Called every 1s."
  ;; Handle notification clicks — focus Emacs if user clicked a popup
  (when (cnotify-poll-action)
    (select-frame-set-input-focus (selected-frame)))

  ;; Detect pomodoro cycle completion (phase 1→2 = work finished)
  (pcase-let ((`(,remaining . ,phase) (cnotify-status)))
    (when (and (= my/pomodoro--prev-phase 1) (= phase 2)
               my/pomodoro--current-task)
      (my/pomodoro-log-entry my/pomodoro--current-task
                             my/pomodoro--current-work-min)
      (message "🍅 %s — %d min ✓" my/pomodoro--current-task
               my/pomodoro--current-work-min))
    (setq my/pomodoro--prev-phase phase)

    ;; Update modeline indicator
    (if (and (= remaining 0) (= phase 0))
        (progn (setq my/cnotify-indicator nil)
               (when my/cnotify-update-timer
                 (cancel-timer my/cnotify-update-timer)
                 (setq my/cnotify-update-timer nil)))
      (setq my/cnotify-indicator
            (cond
             ((= phase 1) (format " 🍅 %d:%02d" (/ remaining 60) (% remaining 60)))
             ((= phase 2) (format " ☕ %d:%02d" (/ remaining 60) (% remaining 60)))
             (t           (format " ⏱ %d:%02d" (/ remaining 60) (% remaining 60))))))
    (force-mode-line-update)))

;; Start 1s poll when timer/pomodoro starts
(defun my/cnotify-start-poll ()
  (my/cnotify-refresh)
  (unless my/cnotify-update-timer
    (setq my/cnotify-update-timer (run-with-timer 1 1 #'my/cnotify-refresh))))

(add-to-list 'mode-line-misc-info '("" my/cnotify-indicator ""))

(advice-add 'cnotify-timer-start    :after (lambda (&rest _) (my/cnotify-start-poll)))
(advice-add 'cnotify-pomodoro-start :after (lambda (&rest _) (my/cnotify-start-poll)))
(advice-add 'cnotify-timer-stop     :after (lambda (&rest _) (my/cnotify-refresh)))
(advice-add 'cnotify-pomodoro-stop  :after (lambda (&rest _) (my/cnotify-refresh)))
