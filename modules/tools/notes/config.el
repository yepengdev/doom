;;; $DOOMDIR/modules/tools/notes/config.el -*- lexical-binding: t; -*-

;; ─── Deft（纯文本笔记文件浏览）────────────────────────────────────
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

;; ─── Denote（文件命名式 Zettelkasten）───────────────────────────────────
(use-package! denote
  :after-call doom-first-buffer-hook
  :hook ((dired-mode . denote-dired-mode-in-directories)
         (text-mode . denote-fontify-links-mode))
  :custom
  (denote-directory "~/org/denote")
  (denote-dired-directories (list denote-directory))
  (denote-dired-directories-include-subdirectories t)
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

  (defun my/denote-git-auto-commit ()
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
  (add-hook 'denote-after-new-note-hook #'my/denote-git-auto-commit)

  (defun my/denote-jieba-infer-keywords ()
    "用 jieba TF-IDF 提取关键词，与 `denote-known-keywords' 匹配后自动添加标签。
若提取的关键词命中已知标签列表，则自动更新文件 front-matter。"
    (when (and buffer-file-name
               (derived-mode-p 'org-mode)
               (require 'jieba-module nil t))
      (condition-case nil
          (let* ((text (buffer-string))
                 (top-kw (mapcar #'car (my/jieba-extract text 5)))
                 (existing (denote--file-keywords buffer-file-name))
                 (matched (seq-intersection top-kw
                                            (append denote-known-keywords existing)
                                            #'equal)))
            (when matched
              (denote-rename-file-keywords buffer-file-name
                                           (delete-dups (append existing matched)))))
        (error nil))))
  (add-hook 'denote-after-new-note-hook #'my/denote-jieba-infer-keywords 80))

(use-package! denote-journal
  :after denote
  :hook (calendar-mode . denote-journal-calendar-mode)
  :custom
  (denote-journal-directory (concat denote-directory "/journal"))
  (denote-journal-keyword '("journal"))
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

;; ─── 观影日记（+film 标记）────────────────────────────────────────
(when (modulep! +film)
  (load! "contrib/film" nil t))
