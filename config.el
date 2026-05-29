;;; $DOOMDIR/config.el -*- lexical-binding: t; -*-

;; ─── Basics ──────────────────────────────────────────────────────────────────

(global-auto-revert-mode 1)
(global-so-long-mode 0)
(setq confirm-kill-emacs nil)

;; ─── Fonts ───────────────────────────────────────────────────────────────────

(defun my/apply-fonts (&optional frame)
  "Apply fonts on graphical frames (handles daemon and normal startup)."
  (when (display-graphic-p frame)
    (setq doom-font (font-spec :family "Monaspace Neon" :size 15))
    (setq doom-variable-pitch-font (font-spec :family "Monaspace Neon" :size 16))
    (set-fontset-font t 'han (font-spec :family "LXGW WenKai Mono Screen" :size 16))
    (when (fboundp 'doom/reload-font)
      (doom/reload-font))))

(add-hook 'after-init-hook #'my/apply-fonts)
(add-hook 'server-after-make-frame-hook #'my/apply-fonts)

;; ─── Theme & UI ──────────────────────────────────────────────────────────────

(setq doom-theme 'doom-wilmersdorf)
(setq display-line-numbers-type 'relative)
(setq auto-save-timeout 30
      auto-save-interval 300)

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
                 :empty-lines 1)))

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

;; ─── Deft (quick note search) ────────────────────────────────────────────────

(setq deft-directory "~/notes"
      deft-recursive t)

(after! deft
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
  :defer t
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

;; ─── PDF ─────────────────────────────────────────────────────────────────────

(after! pdf-tools
  (setq pdf-view-display-size 'fit-page
        pdf-view-resize-factor 1.1
        pdf-annot-activate-created-annotations t
        pdf-view-use-scaling t
        pdf-view-use-imagemagick nil)
  (add-hook 'pdf-view-mode-hook #'pdf-view-roll-minor-mode)
  (add-hook 'pdf-view-mode-hook #'evil-emacs-state))

;; ─── Writing tools ───────────────────────────────────────────────────────────

(use-package! olivetti
  :defer t
  :init
  (add-hook 'org-mode-hook #'olivetti-mode)
  :config
  (define-key olivetti-mode-map (kbd "C-c |") nil)
  (setq olivetti-body-width 100)
  (add-hook 'olivetti-mode-on-hook (lambda () (display-line-numbers-mode -1)))
  (add-hook 'olivetti-mode-off-hook (lambda () (display-line-numbers-mode 1)))
  (setq olivetti-hide-mode-line t))

(use-package! super-save
  :hook (after-init . super-save-mode)
  :config
  (super-save-mode +1)
  (setq super-save-auto-save-when-idle t
        super-save-silent t
        super-save-when-focus-lost nil
        super-save-when-buffer-switched nil
        super-save-delete-trailing-whitespace 'except-current-line))

;; ─── Chinese input (fcitx + Evil) ───────────────────────────────────────────

(after! evil
  (run-with-idle-timer 0.5 nil
                       (lambda ()
                         (when (setq fcitx-remote-command
                                     (or (executable-find "fcitx5-remote")
                                         (executable-find "fcitx-remote")))
                           (require 'fcitx)
                           (fcitx-evil-turn-on)))))

;; ─── Fuzzy matching with pinyin support ─────────────────────────────────────

(after! vertico
  (when (modulep! :editor evil +everywhere)
    (require 'evil-pinyin)
    (advice-add #'orderless-regexp
                :filter-return
                #'evil-pinyin--build-regexp-string)))

(use-package! ace-pinyin
  :after avy
  :init (setq ace-pinyin-use-avy t)
  :config (ace-pinyin-global-mode t))

;; ─── UI spacing ──────────────────────────────────────────────────────────────

(use-package! spacious-padding
  :defer t
  :custom (line-spacing 3)
  :init
  (defun my/enable-spacious-padding-later (&optional frame)
    (when (display-graphic-p frame)
      (run-with-idle-timer 0.1 nil #'spacious-padding-mode)))
  (if (daemonp)
      (add-hook 'server-after-make-frame-hook #'my/enable-spacious-padding-later)
    (add-hook 'after-init-hook #'my/enable-spacious-padding-later)))

;; ─── Large Org file handling ─────────────────────────────────────────────────

(defvar my/org-large-file-size-threshold (* 1024 1024)
  "Org files exceeding this size (bytes) disable all prettification.")

(defun my/org-maybe-disable-prettification ()
  "Disable prettification for large Org files to improve performance."
  (when (and (derived-mode-p 'org-mode)
             buffer-file-name
             (> (file-attribute-size (file-attributes buffer-file-name))
                my/org-large-file-size-threshold))
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
    (font-lock-flush)))

;; Prevent so-long from activating in Org files
(defun my/org-so-long-p ()
  (unless (derived-mode-p 'org-mode)
    (doom-so-long-p)))

(after! so-long
  (setq so-long-predicate #'my/org-so-long-p))
