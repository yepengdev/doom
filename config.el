;;; $DOOMDIR/config.el -*- lexical-binding: t; -*-

;; ─── Proxy for doom sync (gh-proxy.com) ──────────────────────────────────────
(setenv "DOOMGITCONFIG"
        (expand-file-name "doom-gitconfig" doom-user-dir))

;; ─── Basics ──────────────────────────────────────────────────────────────────
(setq confirm-kill-emacs nil)

;; ─── Fonts ───────────────────────────────────────────────────────────────────
(setq doom-font (font-spec :family "Monaspace Neon" :size 16)
      doom-variable-pitch-font (font-spec :family "Monaspace Neon" :size 16))
(after! doom-ui
  (set-fontset-font t 'han (font-spec :family "LXGW WenKai Mono Screen" :size 16)))

;; ─── Theme & UI ──────────────────────────────────────────────────────────────
(defvar my/theme-day 'doom-one-light
  "Light theme used during daytime.")
(defvar my/theme-night 'doom-tokyo-night
  "Dark theme used at night.")
(defvar my/theme-day-start 7
  "Hour (0-23) when day theme activates.")
(defvar my/theme-night-start 19
  "Hour (0-23) when night theme activates.")

(defun my/theme-for-hour (&optional hour)
  "Return the theme appropriate for HOUR (default: current hour)."
  (let ((h (or hour (string-to-number (format-time-string "%H")))))
    (if (or (< h my/theme-night-start) (>= h my/theme-day-start))
        my/theme-day
      my/theme-night)))

(defun my/theme-apply (theme)
  "Apply THEME unconditionally."
  (setq doom-theme theme)
  (mapc #'disable-theme custom-enabled-themes)
  (load-theme theme t))

(defun my/theme-switch-maybe ()
  "Check hour and switch theme if needed."
  (let ((theme (my/theme-for-hour)))
    (unless (eq doom-theme theme)
      (my/theme-apply theme))))

(setq doom-theme (my/theme-for-hour))

;; Check every 60 minutes for day/night transition
(run-with-timer 0 (* 60 60) #'my/theme-switch-maybe)

(setq display-line-numbers-type 'relative)
(setq auto-save-timeout 30
      auto-save-interval 300)

;; ─── Magit ───────────────────────────────────────────────────────────────────
(after! magit
  ;; Only refine diff hunk on demand, not all hunks (slow on large diffs)
  (setq magit-diff-refine-hunk nil))

;; ─── Org mode ────────────────────────────────────────────────────────────────
(setq org-directory "~/org/")
(setq org-noter-notes-search-path '("~/notes/annotations"))

(after! org
  (add-to-list 'org-todo-keywords
               '(sequence "DRAFT(R)" "REVIEW(r)" "|" "CANCELLED(C)") t)
  (add-to-list 'org-capture-templates
               '("w" "Novel idea" entry
                 (file+headline "~/org/novel-inbox.org" "Inspiration inbox")
                 "* %^{Title} :%^g\n  :PROPERTIES:\n  :CREATED: %U\n  :Source: %^{Source}\n  :Character: %^{Character}\n  :Mood: %^{Mood}\n  :Notes: %^{Notes}\n  :END:\n\n  %?\n  - From: %a"
                 :prepend t
                 :empty-lines 1))
  (setq org-hide-emphasis-markers t))

;; ─── LaTeX ───────────────────────────────────────────────────────────────────
(use-package! ox-latex
  :defer t
  :after ox
  :custom
  (org-latex-pdf-process
   '("xelatex -interaction nonstopmode -output-directory %o %f"
     "bibtex %b"
     "xelatex -shell-escape -interaction nonstopmode -output-directory %o %f"
     "xelatex -shell-escape -interaction nonstopmode -output-directory %o %f"))
  (org-latex-logfiles-extensions
   '("lof" "lot" "tex~" "aux" "idx" "log" "out" "toc" "nav" "snm"
     "vrb" "dvi" "fdb_latexmk" "blg" "brf" "fls" "entoc" "ps" "spl" "bbl" "tex" "bcf"))
  (org-latex-default-packages-alist
   (remove '("AUTO" "inputenc" t) org-latex-default-packages-alist))
  :config
  (add-to-list 'org-latex-classes
               '("elegantbook"
                 "\\documentclass[fontsize=10pt,paper=a4,twoside=true,lang=cn]{elegantbook}
\\usepackage{xeCJK}
\\hypersetup{colorlinks=true}
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
  framesep=2mm
}
[NO-DEFAULT-PACKAGES]
[NO-PACKAGES]"
                 ("\\chapter{%s}" . "\\chapter*{%s}")
                 ("\\section{%s}" . "\\section*{%s}")
                 ("\\subsection{%s}" . "\\subsection*{%s}")))
  (setq org-latex-default-class "elegantbook"))

;; ─── Full reload (config + theme + font + frames + packages) ─────────────────
(defun my/doom-full-reload--apply (&rest _)
  "Apply theme, font & frame settings after config reload.
Intended for `doom-after-reload-hook'."
  (my/theme-apply (my/theme-for-hour))
  ;; Reload fonts
  (when (fboundp 'doom/reload-font)
    (doom/reload-font))
  ;; Re-apply daemon-frame hooks for each existing frame
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
  ;; 1. Reload autoloads & package metadata (synchronous)
  (when (fboundp 'doom/reload-autoloads)
    (ignore-errors (doom/reload-autoloads)))
  (when (fboundp 'doom/reload-packages)
    (ignore-errors (doom/reload-packages)))
  ;; 2. Reload init.el + config.el (async — runs bin/doom sync then load init)
  (when (fboundp 'doom/reload)
    (ignore-errors
      (add-hook 'doom-after-reload-hook #'my/doom-full-reload--apply)
      (doom/reload))))

(map! :leader
      :desc "Full reload" "h r R" #'my/doom-full-reload)

;; ─── Dired: open file externally ──────────────────────────────────────────────
(after! dired
  (defun my/dired-open-externally ()
    "Open marked files or file at point with system default application."
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

;; ─── Use external browser (not ewww/lynx) for links ──────────────────────────
(setq browse-url-browser-function #'browse-url-xdg-open)
(after! org
  (add-to-list 'org-file-apps '("\\.x?html?\\'" . "xdg-open %s")))

;; ─── Org HTML export: ReadTheOrg theme (fully local) ────────────────────────
(defvar my/org-export-assets-dir
  (expand-file-name "org-export/readtheorg" doom-user-dir)
  "Local directory for Org HTML export assets (CSS, JS, fonts).")

(after! ox-html
  (setq org-html-head-include-default-style nil)
  (let ((css-dir (expand-file-name "css" my/org-export-assets-dir))
        (js-dir  (expand-file-name "js" my/org-export-assets-dir)))
    (setq org-html-head
          (concat
           "<link rel=\"stylesheet\" type=\"text/css\" href=\"" css-dir "/htmlize.css\"/>\n"
           "<link rel=\"stylesheet\" type=\"text/css\" href=\"" css-dir "/readtheorg.css\"/>\n"
           "<link rel=\"stylesheet\" type=\"text/css\" href=\"" css-dir "/code-copy.css\"/>"))
    (setq org-html-head-extra
          (concat
           "<script src=\"" js-dir "/jquery.min.js\"></script>\n"
           "<script src=\"" js-dir "/bootstrap.min.js\"></script>\n"
           "<script type=\"text/javascript\" src=\"" js-dir "/jquery.stickytableheaders.min.js\"></script>\n"
           "<script type=\"text/javascript\" src=\"" js-dir "/readtheorg.js\"></script>\n"
           "<script type=\"text/javascript\" src=\"" js-dir "/code-copy.js\"></script>"))))

;; ─── Deft (quick note search) ────────────────────────────────────────────────
;; 在 init.el 中启用 deft 模块后生效；用 :after-call 延迟加载
(after! deft
  (setq deft-directory "~/notes"
        deft-recursive t)
  (defun cm/deft-parse-title (file contents)
    (if (string-match "^#\\+[tT][iI][tT][lL][eE]:\\s-*\\(.*\\)" contents)
        (match-string 1 contents)
      (deft-base-filename file)))
  (advice-add 'deft-parse-title :override #'cm/deft-parse-title)
  (setq deft-strip-summary-regexp
        (concat "\\("
                "[\n\t]"
                "\\|^#\\+[[:alpha:]_]+:.*$"
                "\\|^:PROPERTIES:\n\\(.+\n\\)+:END:\n"
                "\\)")))

;; ─── Denote (Zettelkasten notes) ─────────────────────────────────────────────
(use-package! denote
  :defer t
  :commands (denote denote-date denote-find-link denote-link-or-create
                    denote-rename-file-keywords denote-rename-file
                    denote-rename-file-using-front-matter
                    denote-find-backlink)
  :custom
  (denote-link-description-function "%t")
  (denote-directory (expand-file-name "~/Documents/notes"))
  (denote-known-keywords '("创作" "学习" "工作" "生活" "技术" "思考" "索引"))
  :init
  (map! :leader
        (:prefix-map ("r d" . "Denote")
         :desc "New note"                "n" #'denote
         :desc "Date note"               "d" #'denote-date
         :desc "Find link"               "l" #'denote-find-link
         :desc "Link or create"          "i" #'denote-link-or-create
         :desc "Rename keywords"         "k" #'denote-rename-file-keywords
         :desc "Rename file"             "r" #'denote-rename-file
         :desc "Rename front matter"     "R" #'denote-rename-file-using-front-matter
         :desc "Search notes"            "f" #'consult-notes
         :desc "Find backlinks"          "b" #'denote-find-backlink)))

(use-package! consult-notes
  :after denote
  :custom
  (consult-notes-denote-display-keywords-indicator "_")
  :config
  (consult-notes-denote-mode))

(use-package! denote-org
  :after denote
  :config
  (map! :leader
        (:prefix-map ("r d" . "Denote")
         :desc "Link to heading"  "h" #'denote-org-link-to-heading)))

(use-package! denote-sequence
  :after denote
  :config
  (map! :leader
        (:prefix-map ("r d" . "Denote")
         :desc "New sequence"     "s" #'denote-sequence)))

(use-package! denote-explore
  :after denote
  :config
  (map! :leader
        (:prefix-map ("r d" . "Denote")
                     (:prefix-map ("e" . "Explore")
                      :desc "Count notes"         "c" #'denote-explore-count-notes
                      :desc "Count keywords"      "C" #'denote-explore-count-keywords
                      :desc "Random note"         "r" #'denote-explore-random-note
                      :desc "Random link"         "l" #'denote-explore-random-link
                      :desc "Knowledge network"   "n" #'denote-explore-network))))

;; ─── EPUB (nov.el) ──────────────────────────────────────────────────────────
(use-package! nov
  :mode ("\\.epub\\'" . nov-mode)
  :hook (nov-mode . visual-line-mode)
  (nov-mode . variable-pitch-mode)
  (nov-mode . olivetti-mode)
  (nov-mode . (lambda () (hl-line-mode -1)))
  :custom
  (nov-text-width t)
  (nov-variable-pitch-mode t)
  (nov-save-place-file (concat doom-cache-dir "nov-places")))

;; ─── PDF ─────────────────────────────────────────────────────────────────────
(after! pdf-tools
  (setq pdf-view-display-size 'fit-page
        pdf-view-resize-factor 1.1
        pdf-annot-activate-created-annotations t
        pdf-view-use-scaling nil
        pdf-view-use-imagemagick nil
        pdf-view-selection-style 'glyph)
  (add-hook! 'pdf-view-mode-hook #'pdf-view-roll-minor-mode #'evil-emacs-state))
;; pdf-view-current-overlay is a macro; org-noter-pdf's compiled bytecode calls
;; it as a function.  Provide function fallback regardless of org-noter-pdftools.
(after! org-noter-pdf
  (defun pdf-view-current-overlay (&optional window)
    "Get the current overlay for the pdf view.
Fallback to roll-mode overlay when standard overlay is nil."
    (or (image-mode-window-get 'overlay window)
        (when (and (bound-and-true-p pdf-view-roll-minor-mode)
                   (fboundp 'pdf-roll-page-overlay))
          (condition-case nil
              (pdf-roll-page-overlay (pdf-view-current-page) window)
            (error nil)))))
  ;; Suppress arrow timer errors when overlay is still nil
  (defadvice! +org-noter-pdf--show-arrow-a (orig-fn)
    "Suppress arrow timer errors in org-noter-pdf."
    :around #'org-noter-pdf--show-arrow
    (condition-case nil (funcall orig-fn) (error nil))))
;;
;; org-noter-pdftools struct → cons bridge
;; (with-eval-after-load 'org-noter-core
;;   (dolist (fn '(org-noter--get-location-top
;;                  org-noter--get-location-page
;;                  org-noter--get-location-left))
;;     (advice-add fn :around
;;       (lambda (orig-fn location)
;;         (funcall orig-fn
;;                  (if (and location (not (listp location))
;;                           (fboundp 'org-noter-pdftools--location-p)
;;                           (org-noter-pdftools--location-p location))
;;                      (org-noter-pdftools--location-link-to-cons location)
;;                    location))))))

;; -- org-pdftools: precise org links to PDF locations

(use-package! org-pdftools
  :defer t
  :commands org-pdftools-setup-link
  :hook (org-load . org-pdftools-setup-link))

;; Open current PDF in Zathura for quick reference / LaTeX preview
(map! :map pdf-view-mode-map
      :n "g z" (cmd! (when-let ((f (buffer-file-name)))
                        (start-process "zathura" nil "zathura" f))))

;; ─── Writing tools ───────────────────────────────────────────────────────────
(use-package! olivetti
  :defer t
  :hook (org-mode . olivetti-mode)
  :custom
  (olivetti-body-width 120)
  (olivetti-hide-mode-line t)
  :config
  (define-key olivetti-mode-map (kbd "C-c |") nil)
  (defun +olivetti-hide-line-numbers-h ()
    (display-line-numbers-mode -1))
  (defun +olivetti-show-line-numbers-h ()
    (display-line-numbers-mode 1))
  (add-hook 'olivetti-mode-on-hook #'+olivetti-hide-line-numbers-h)
  (add-hook 'olivetti-mode-off-hook #'+olivetti-show-line-numbers-h))

(use-package! super-save
  :hook (after-init . super-save-mode)
  :custom
  (super-save-auto-save-when-idle t)
  (super-save-silent t)
  (super-save-when-focus-lost nil)
  (super-save-when-buffer-switched nil)
  (super-save-delete-trailing-whitespace 'except-current-line)
  :config
  (add-to-list 'super-save-predicates
               (lambda () (not buffer-read-only))))

;; ─── Emacs state replaces Insert state ──────────────────────────────────────
(after! evil
  (defalias 'evil-insert-state 'evil-emacs-state)
  (setq evil-emacs-state-cursor 'bar)
  (define-key evil-emacs-state-map (kbd "<escape>") 'evil-normal-state))

;; ─── Global keybindings ─────────────────────────────────────────────────────
(map! :g "M-!" #'eshell-command)

;; ─── Chinese input (fcitx + Evil) ───────────────────────────────────────────
(add-transient-hook! 'doom-first-input-hook
  (when-let ((cmd (or (executable-find "fcitx5-remote")
                      (executable-find "fcitx-remote"))))
    (setq fcitx-remote-command cmd)
    (require 'fcitx)
    (fcitx-evil-turn-on)))

;; ─── Fuzzy matching with pinyin support ─────────────────────────────────────
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

;; ─── UI spacing ──────────────────────────────────────────────────────────────
(use-package! spacious-padding
  :commands spacious-padding-mode
  :custom (line-spacing 3)
  :init
  (if (daemonp)
      (add-hook 'server-after-make-frame-hook
                (lambda (&optional frame)
                  (when (display-graphic-p frame)
                    (spacious-padding-mode 1))))
    (spacious-padding-mode 1)))

;; ─── Large Org file handling ─────────────────────────────────────────────────
(defvar my/org-large-file-size-threshold (* 1024 1024)
  "Org files exceeding this size (bytes) disable all prettification.")

(defun my/org-maybe-disable-prettification ()
  "Disable prettification for large Org files to improve performance."
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

;; Prevent so-long from activating in Org files
(after! so-long
  (setq so-long-predicate
        (lambda () (and (not (derived-mode-p 'org-mode))
                        (doom-so-long-p)))))
