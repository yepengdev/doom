;;; $DOOMDIR/config/notes.el -*- lexical-binding: t; -*-

;; ─── Deft ────────────────────────────────────────────────────────────────────
(after! deft
  (setq deft-directory "~/notes"
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
