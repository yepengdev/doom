;;; $DOOMDIR/config/org.el -*- lexical-binding: t; -*-

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
  (setq org-hide-emphasis-markers t)
  (add-to-list 'org-file-apps '("\\.x?html?\\'" . "xdg-open %s")))

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

;; ─── Pandoc docx export ──────────────────────────────────────────────────────
(defvar my/pandoc-dir (expand-file-name "pandoc" doom-user-dir)
  "Base directory for Pandoc docx export templates.")

(after! ox-pandoc
  (setq org-pandoc-options-for-docx
        `((reference-doc . ,(expand-file-name
                             "templates/template_标题不编号-列表第二行顶格.docx"
                             my/pandoc-dir))
          (lua-filter . ,(expand-file-name "markdown-to-docx.lua" my/pandoc-dir)))))

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

;; ─── Use external browser for links ──────────────────────────────────────────
(setq browse-url-browser-function #'browse-url-xdg-open)

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
