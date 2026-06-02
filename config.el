;;; $DOOMDIR/config.el -*- lexical-binding: t; -*-

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
  (setq doom-font (font-spec :family "Monaspace Neon" :size 16)
        doom-variable-pitch-font (font-spec :family "Monaspace Neon" :size 16))
  (set-fontset-font t 'han (font-spec :family "LXGW WenKai Mono Screen" :size 16)))

;; ─── Auto theme switch (day/night) ────────────────────────────────────────
;;
;; Switches between doom-one-light (day) and doom-tokyo-night (night) based
;; on the current hour.  Why hours instead of sunrise/sunset:
;;   - sunrise APIs require network + geolocation config; brittle for a
;;     config file that must work everywhere.
;;   - A developer's schedule is anchored to the desk; 7–19 covers the
;;     typical workday.  Adjust the constants for your latitude / preference.
;;
;; The switch happens on the first `doom-switch-frame-hook` invocation (which
;; fires once per daemon session) then unhooks itself — we don't need to
;; re-check every frame switch.
;;
(defconst my/theme-day 'doom-one-light)
(defconst my/theme-night 'doom-tokyo-night)
(defconst my/theme-day-start 7)
(defconst my/theme-night-start 19)

(defun my/theme-for-hour (&optional hour)
  (let ((h (or hour (string-to-number (format-time-string "%H")))))
    (if (and (>= h my/theme-day-start) (< h my/theme-night-start))
        my/theme-day
      my/theme-night)))

(defun my/theme-apply (theme)
  (setq doom-theme theme)
  (doom/reload-theme))

(defun my/theme-switch-maybe ()
  (let ((theme (my/theme-for-hour)))
    (unless (eq doom-theme theme)
      (my/theme-apply theme)
      (remove-hook 'doom-switch-frame-hook #'my/theme-switch-maybe))))

(setq doom-theme (my/theme-for-hour))
(add-hook 'doom-switch-frame-hook #'my/theme-switch-maybe 'append)

;; ─── Line numbers & auto-save ─────────────────────────────────────────────
(setq display-line-numbers-type 'relative)
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


;; ═══════════════════════════════════════════════════════════════════════════
;; Editor
;; ═══════════════════════════════════════════════════════════════════════════

;; ─── Shell & server basics ────────────────────────────────────────────────
;;
;; `shell-file-name` → bash (not the user's interactive shell, which may be
;; zsh/fish).  Emacs `shell-command` and compile modes rely on POSIX sh
;; syntax; fish in particular is incompatible.  By contrast `vterm-shell`
;; and `explicit-shell-file-name` deliberately use fish — those are
;; interactive and user-facing.
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
  (defun +olivetti-toggle-line-numbers-h ()
    (display-line-numbers-mode (if olivetti-mode -1 1)))
  (add-hook 'olivetti-mode-hook #'+olivetti-toggle-line-numbers-h))

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

;; ─── Evil: Emacs state replaces Insert state ──────────────────────────────
;;
;; Vim insert mode fundamentally conflicts with Chinese IMEs (fcitx5):
;;   - IME needs to track insertion state; Vim's mode transitions can leave
;;     it in the wrong input method.
;;   - Emacs state keeps the bar cursor (familiar to GUI users) while ESC
;;     still returns to normal state.
;;   - Trade-off: you lose Vim's insert-mode keybindings (C-w, C-h, etc.)
;;     — undo-able via `evil-insert-state-map` if needed later.
;;
;; This is NOT standard Doom — the `defalias` permanently hijacks insert state.
;;
(after! evil
  (defalias 'evil-insert-state 'evil-emacs-state)
  (setq evil-emacs-state-cursor 'bar)
  (define-key evil-emacs-state-map (kbd "<escape>") 'evil-normal-state))

;; ─── Global keybindings ──────────────────────────────────────────────────
(map! :g "M-!" #'eshell-command)


;; ═══════════════════════════════════════════════════════════════════════════
;; Org mode
;; ═══════════════════════════════════════════════════════════════════════════

(setq org-directory "~/org/")
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

  (setq org-hide-emphasis-markers t)
  (add-to-list 'org-file-apps '("\\.x?html?\\'" . "xdg-open %s")))

;; ─── Org capture helper ───────────────────────────────────────────────────
(defun org-capture-goto-target (&optional template-key)
  (interactive)
  (require 'org-capture)
  (let ((entry (org-capture-select-template template-key)))
    (unless entry (error "No capture template selected"))
    (org-capture-set-plist entry)
    (org-capture-set-target-location)
    (pop-to-buffer-same-window (org-capture-get :buffer))
    (goto-char (org-capture-get :pos))))

;; ─── Pandoc docx export ───────────────────────────────────────────────────
(defvar my/pandoc-dir (expand-file-name "pandoc" doom-user-dir))

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
;;
(defvar my/org-export-assets-dir
  (expand-file-name "org-export/minimal" doom-user-dir))

(after! ox-html
  (setq org-html-head-include-default-style nil)
  (let ((css-dir (expand-file-name "css" my/org-export-assets-dir)))
    (setq org-html-head
          (concat
           "<link rel=\"stylesheet\" type=\"text/css\" href=\"" css-dir "/org.css\"/>\n"
           "<link rel=\"stylesheet\" type=\"text/css\" href=\"" css-dir "/htmlize.css\"/>"))
    (setq org-html-head-extra "")))

;; ─── External browser for links ──────────────────────────────────────────
(setq browse-url-browser-function #'browse-url-xdg-open)

;; ─── Large Org file handling (≥1 MiB) ────────────────────────────────────
;;
;; Org-mode prettification (org-modern, org-appear, org-indent, fontification,
;; prettify-symbols, variable-pitch) causes noticeable UI lag in files larger
;; than ~1 MiB.  This hook detects oversized buffers at open time and strips
;; all decoration — trading aesthetics for responsiveness.  The threshold is
;; a heuristic; adjust MY/ORG-LARGE-FILE-SIZE-THRESHOLD for your machine.
;;
(defvar my/org-large-file-size-threshold (* 1024 1024))

(defun my/org-maybe-disable-prettification ()
  (when-let ((attrs (and buffer-file-name
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

  ;; Use latexmk (intelligent multi-pass) instead of the default 4-step
  ;; (latex → bibtex → latex → latex).  latexmk detects when it needs
  ;; additional runs and avoids wasted cycles.
  (org-latex-pdf-process
   '("latexmk -xelatex -shell-escape -interaction=nonstopmode -f -output-directory=%o %f"))

  (org-latex-logfiles-extensions
   '("lof" "lot" "tex~" "aux" "idx" "log" "out" "toc" "nav" "snm"
     "vrb" "dvi" "fdb_latexmk" "blg" "brf" "fls" "entoc" "ps" "spl" "bbl" "tex" "bcf"))

  ;; Remove default packages that conflict with XeLaTeX or are handled
  ;; differently in our custom class template:
  ;;   - inputenc / fontenc — XeLaTeX natively handles UTF-8 and OpenType;
  ;;     loading inputenc breaks XeLaTeX's encoding detection.
  ;;   - hyperref — loaded manually in the class template for precise
  ;;     placement (before metalink, after color definitions).
  (org-latex-default-packages-alist
   (cl-remove '("" "hyperref" t)
    (cl-remove '("T1" "fontenc" t)
     (cl-remove '("AUTO" "inputenc" t)
                org-latex-default-packages-alist
                :test #'equal)
              :test #'equal)
            :test #'equal))

  :config
  ;; Custom LaTeX class for Chinese typesetting, based on ctexbook.
  ;; Features: XeLaTeX-native CJK, no section numbering, minted code blocks,
  ;; booktabs tables, microtype, fancyhdr headers, hyperref with color links.
  (add-to-list 'org-latex-classes
               '("ctexbook"
                 "\\documentclass[UTF8,scheme=chinese,fontset=fandol,11pt,a4paper,twoside]{ctexbook}

%% ─── 全部不编号（保留目录/PDF 书签）─────────────
\\setcounter{secnumdepth}{0}

%% ─── 颜色（TODO 关键词着色）────────────────────
\\usepackage{xcolor}

%% ─── 微排版（XeLaTeX 下仅支持 protrusion）─────
\\usepackage[final]{microtype}

%% ─── 现代排版：句末单空格 ───────────────────────
\\frenchspacing

%% ─── 页面布局 ───────────────────────────────────
\\usepackage[top=2.5cm,bottom=2.5cm,inner=3cm,outer=2cm,headheight=14pt]{geometry}

%% ─── 页眉页脚 ───────────────────────────────────
\\usepackage{fancyhdr}
\\pagestyle{fancy}
\\fancyhf{}
\\fancyhead[LE]{\\leftmark}
\\fancyhead[RO]{\\rightmark}
\\fancyfoot[LE,RO]{\\thepage}
\\renewcommand{\\headrulewidth}{0.4pt}

%% ─── 章节标题 ───────────────────────────────────
\\ctexset{
  chapter={
    format={\\huge\\bfseries},
    name={},
    number={},
    beforeskip=1.5em,
    afterskip=1em,
    fixskip=true,
  },
  section={
    format={\\Large\\bfseries\\raggedright},
    beforeskip=1em plus .2em minus .1em,
    afterskip=.5em plus .1em,
  },
  subsection={
    format={\\large\\bfseries\\raggedright},
    beforeskip=.8em plus .2em minus .1em,
    afterskip=.4em plus .1em,
  },
}

[DEFAULT-PACKAGES]
[PACKAGES]

%% ─── 超链接 ─────────────────────────────────────
\\usepackage{hyperref}
\\hypersetup{
  colorlinks=true,
  linkcolor=blue!70!black,
  citecolor=teal!80!black,
  urlcolor=blue!70!black,
}
\\usepackage{xurl}

%% ─── 代码环境 ──────────────────────────────────
\\usepackage{fvextra}
\\DefineVerbatimEnvironment{verbatim}{Verbatim}{
  breaklines=true,
  breakanywhere=true,
  breaksymbol={},
  breakautoindent=false
}
\\usepackage{minted}
\\setminted{
  fontsize=\\footnotesize,
  linenos,
  breaklines,
  frame=leftline,
  framesep=2mm,
  bgcolor=lightgray!10,
}

%% ─── 表格 ───────────────────────────────────────
\\usepackage{booktabs}

%% ─── 图表标题 ───────────────────────────────────
\\usepackage[font=small,labelfont=bf]{caption}

%% ─── 列表间距 ──────────────────────────────────
\\usepackage{enumitem}
\\setlist{nosep}

%% ─── 行距 ──────────────────────────────────────
\\linespread{1.3}"
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
(after! deft
  (setq deft-directory "~/org/deft"
        deft-recursive t)
  (defun my/deft-parse-title (file contents)
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
  (denote-directory (expand-file-name "~/org/denote"))
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
    (when-let ((dir (denote-directory)))
      (let ((git-dir (expand-file-name ".git" dir)))
        (when (file-exists-p git-dir)
          (let ((default-directory dir))
            (call-process "git" nil nil nil "add" "-A")
            (call-process "git" nil nil nil "commit" "-m" "auto: note saved"))))))
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
(after! dired
  (defun my/dired-open-externally ()
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
  (add-hook 'nov-mode-hook #'(lambda () (setq-local adaptive-fill-mode nil))))

;; ─── PDF (pdf-tools) ──────────────────────────────────────────────────────
;;
;; `fit-page` for whole-page view (like a real PDF reader).  Roll minor mode
;; gives smooth scrolling.  The org-noter-pdf advice suppresses arrow-timer
;; errors (a known bug when roll-mode and org-noter interact).
;;
(after! pdf-tools
  (setq pdf-view-display-size 'fit-page
        pdf-view-resize-factor 1.1
        pdf-annot-activate-created-annotations t
        pdf-view-use-scaling nil
        pdf-view-use-imagemagick nil
        pdf-view-selection-style 'glyph)
  (add-hook! 'pdf-view-mode-hook #'pdf-view-roll-minor-mode #'evil-emacs-state))

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

;; ─── Immersive bilingual translation ──────────────────────────────────────
;;
;; Baidu backend is chosen for its strong Chinese-English pair quality.
;; API credentials come from the environment (not hardcoded).  Auto-idle
;; triggers translation after 0.5 s of inactivity — short enough to feel
;; responsive, long enough to batch edits.
;;
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

;; ─── Chinese character count utility ──────────────────────────────────────
;;
;; Counts CJK ideographs (including Extensions B-H) and punctuation in a
;; region or buffer.  Bound to `SPC r n c`.  Useful for writing Chinese prose
;; where you need to hit a word count.
;;
(defvar my/cjk-regexp "\\(?:[一-鿿㐀-䶵𠀀-𪛟𪜀-𫜸𫝀-𫠝𫠠-𬺡𬺰-𮯠丽-𪘀]\\)")
(defvar my/cjk-punct-regexp "\\(?:[。，、；：？！“”‘’（）【】《》—…～·『』〔〕〖〗〘〙〚〛〜　]\\)")

;;###autoload
(defun my/count-chinese-chars (&optional beg end)
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
      (:prefix-map ("r n" . "Count")
       :desc "Chinese chars" "c" #'my/count-chinese-chars))


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
;; Bound to `SPC h r R`.
;;
(defun my/doom-full-reload--apply (&rest _)
  (my/theme-apply (my/theme-for-hour))
  (when (fboundp 'doom/reload-font)
    (doom/reload-font))
  (when (daemonp)
    (dolist (frame (frame-list))
      (when (display-graphic-p frame)
        (with-selected-frame frame
          (run-hooks 'server-after-make-frame-hook)))))
  (when (fboundp 'doom--startup-loaddefs-doom)
    (ignore-errors (doom--startup-loaddefs-doom)))
  (message "Full reload complete (config + theme + font + frames)"))

(defun my/doom-full-reload ()
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
