;;; $DOOMDIR/config.el -*- lexical-binding: t; -*-

;; ─── Proxy for doom sync ─────────────────────────────────────────────────────
(setenv "DOOMGITCONFIG"
        (expand-file-name "doom-gitconfig" doom-user-dir))

;; ─── Basics ──────────────────────────────────────────────────────────────────
(setq confirm-kill-emacs nil)

;; ─── Fonts ───────────────────────────────────────────────────────────────────
(after! doom-ui
  (setq doom-font (font-spec :family "Monaspace Neon" :size 16)
        doom-variable-pitch-font (font-spec :family "Monaspace Neon" :size 16))
  (set-fontset-font t 'han (font-spec :family "LXGW WenKai Mono Screen" :size 16)))

;; ─── Theme & UI ──────────────────────────────────────────────────────────────
(defvar my/theme-day 'doom-one-light
  "Light theme used during daytime.")
(defvar my/theme-night 'doom-tokyo-night
  "Dark theme used at night.")
(defvar my/theme-day-start 7
  "Hour (0-23) when day theme activates.")
(defvar my/theme-night-start 18
  "Hour (0-23) when night theme activates.")

(defun my/theme-for-hour (&optional hour)
  "Return the theme appropriate for HOUR (default: current hour)."
  (let ((h (or hour (string-to-number (format-time-string "%H")))))
    (if (and (>= h my/theme-day-start) (< h my/theme-night-start))
        my/theme-day
      my/theme-night)))

(defun my/theme-apply (theme)
  "Apply THEME using Doom's theme reload."
  (setq doom-theme theme)
  (doom/reload-theme))

(defun my/theme-switch-maybe ()
  "Check hour and switch theme if needed."
  (let ((theme (my/theme-for-hour)))
    (unless (eq doom-theme theme)
      (my/theme-apply theme))))

(setq doom-theme (my/theme-for-hour))

;; Check theme on frame focus instead of polling every 60 minutes
(add-hook 'doom-switch-frame-hook #'my/theme-switch-maybe)

(setq display-line-numbers-type 'relative)
(setq auto-save-timeout 30
      auto-save-interval 300)

;; ─── Magit ───────────────────────────────────────────────────────────────────
(after! magit
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

;; ─── Org capture helper ───────────────────────────────────────────────────────
(defun org-capture-goto-target (&optional template-key)
  "Go to the target location of a capture template.
If TEMPLATE-KEY is nil, the user is queried for the template."
  (interactive)
  (require 'org-capture)
  (let ((entry (org-capture-select-template template-key)))
    (unless entry (error "No capture template selected"))
    (org-capture-set-plist entry)
    (org-capture-set-target-location)
    (pop-to-buffer-same-window (org-capture-get :buffer))
    (goto-char (org-capture-get :pos))))

;; ─── Pandoc docx export (Achuan-2 template) ──────────────────────────────────
(after! ox-pandoc
  (setq org-pandoc-options-for-docx
        `((reference-doc . ,(expand-file-name
                             "~/pandoc_docx_template/templates/template_标题不编号-列表第二行顶格.docx"))
          (lua-filter . ,(expand-file-name
                          "~/pandoc_docx_template/markdown-to-docx.lua")))))

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

;; ─── Dired ──────────────────────────────────────────────────────────────────
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

;; ─── Use external browser for links ──────────────────────────────────────────
(setq browse-url-browser-function #'browse-url-xdg-open)
(after! org
  (add-to-list 'org-file-apps '("\\.x?html?\\'" . "xdg-open %s")))

;; ─── Org HTML export ────────────────────────────────────────────────────────
(defvar my/org-export-assets-dir
  (expand-file-name "org-export/minimal" doom-user-dir)
  "Local directory for Org HTML export assets.")

(after! ox-html
  (setq org-html-head-include-default-style nil)
  (let ((css-dir (expand-file-name "css" my/org-export-assets-dir)))
    (setq org-html-head
          (concat
           "<link rel=\"stylesheet\" type=\"text/css\" href=\"" css-dir "/org.css\"/>\n"
           "<link rel=\"stylesheet\" type=\"text/css\" href=\"" css-dir "/htmlize.css\"/>"))
    (setq org-html-head-extra "")))

;; ─── Deft ────────────────────────────────────────────────────────────────────
(after! deft
  (setq deft-directory "~/notes"
        deft-recursive t)
  (defun my/deft-parse-title (file contents)
    (if (string-match "^#\\+[tT][iI][tT][lL][eE]:\\s-*\\(.*\\)" contents)
        (match-string 1 contents)
      (deft-base-filename file)))
  (advice-add 'deft-parse-title :override #'my/deft-parse-title)
  (setq deft-strip-summary-regexp
        (concat "\\("
                "[\n\t]"
                "\\|^#\\+[[:alpha:]_]+:.*$"
                "\\|^:PROPERTIES:\n\\(.+\n\\)+:END:\n"
                "\\)")))

;; ─── Denote ──────────────────────────────────────────────────────────────────
(use-package! denote
  :after-call doom-first-buffer-hook
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
         :desc "Link to heading"         "h" #'denote-org-link-to-heading
         :desc "New sequence"            "s" #'denote-sequence
         :desc "Rename keywords"         "k" #'denote-rename-file-keywords
         :desc "Rename file"             "r" #'denote-rename-file
         :desc "Rename front matter"     "R" #'denote-rename-file-using-front-matter
         :desc "Search notes"            "f" #'consult-notes
         :desc "Find backlinks"          "b" #'denote-find-backlink
         (:prefix-map ("e" . "Explore")
          :desc "Count notes"         "c" #'denote-explore-count-notes
          :desc "Count keywords"      "C" #'denote-explore-count-keywords
          :desc "Random note"         "r" #'denote-explore-random-note
          :desc "Random link"         "l" #'denote-explore-random-link
          :desc "Knowledge network"   "n" #'denote-explore-network)))
  :config
  (denote-rename-buffer-mode 1)
  (defun my/denote-git-auto-commit ()
    (when-let ((dir (denote-directory)))
      (when (file-exists-p (expand-file-name ".git" dir))
        (let ((default-directory dir))
          (shell-command-to-string "git add -A && git commit -m \"auto: note saved\"")))))
  (add-hook 'denote-after-new-note-hook #'my/denote-git-auto-commit))

(use-package! consult-notes
  :after denote
  :custom
  (consult-notes-denote-display-keywords-indicator "_")
  :config
  (consult-notes-denote-mode))

;; ─── EPUB ────────────────────────────────────────────────────────────────────
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

;; ─── PDF ─────────────────────────────────────────────────────────────────────
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
    "Get the current overlay for the pdf view.
Fallback to roll-mode overlay when standard overlay is nil."
    (or (image-mode-window-get 'overlay window)
        (when (and (bound-and-true-p pdf-view-roll-minor-mode)
                   (fboundp 'pdf-roll-page-overlay))
          (condition-case nil
              (pdf-roll-page-overlay (pdf-view-current-page) window)
            (error nil)))))
  (defadvice! +org-noter-pdf--show-arrow-a (orig-fn)
    "Suppress arrow timer errors in org-noter-pdf."
    :around #'org-noter-pdf--show-arrow
    (condition-case nil (funcall orig-fn) (error nil))))

(use-package! org-pdftools
  :defer t
  :commands org-pdftools-setup-link
  :hook (org-load . org-pdftools-setup-link))

(map! :map pdf-view-mode-map
      :n "g z" (cmd! (when-let ((f (buffer-file-name)))
                       (start-process "zathura" nil "zathura" f))))

;; ─── Writing tools ───────────────────────────────────────────────────────────
(use-package! olivetti
  :hook (org-mode . olivetti-mode)
  :custom
  (olivetti-body-width 100)
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

;; ─── Emacs state replaces Insert state ──────────────────────────────────────
(after! evil
  (defalias 'evil-insert-state 'evil-emacs-state)
  (setq evil-emacs-state-cursor 'bar)
  (define-key evil-emacs-state-map (kbd "<escape>") 'evil-normal-state))

;; ─── Global keybindings ─────────────────────────────────────────────────────
(map! :g "M-!" #'eshell-command)

;; ─── Immersive bilingual translation ─────────────────────────────────────────
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
  ;; Defer setup until first file/buffer is opened
  (add-hook! 'doom-first-buffer-hook
    (add-hook 'nov-pre-html-render-hook #'immersive-translate-setup)
    (add-hook 'org-mode-hook #'immersive-translate-setup)))

;; ─── Chinese input ───────────────────────────────────────────────────────────
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
(defvar my/enable-spacious-padding--done nil
  "Whether spacious-padding has been enabled.")

(defun my/enable-spacious-padding--fn (&optional _frame)
  "Enable spacious-padding on the first graphical frame."
  (when (and (display-graphic-p)
             (not my/enable-spacious-padding--done))
    (setq my/enable-spacious-padding--done t)
    (spacious-padding-mode 1)))

(use-package! spacious-padding
  :commands spacious-padding-mode
  :custom (line-spacing 3)
  :init
  (add-hook 'doom-switch-frame-hook #'my/enable-spacious-padding--fn))

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

(after! so-long
  (setq so-long-predicate
        (lambda () (and (not (derived-mode-p 'org-mode))
                        (doom-so-long-p)))))
