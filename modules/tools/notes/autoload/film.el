;;; modules/tools/notes/autoload/film.el -*- lexical-binding: t; -*-
;;;###if (modulep! +film)

;; ─── 观影写作笔记模板 ──────────────────────────────────────────────
;; 模板围绕「电影→小说写作素材」设计，涵盖叙事、人物、对白、氛围、
;; 主题、灵感六个维度。评分保留但可选，便于回顾。

;;;###autoload
(defconst my/film-template
  "#+title:      %s
#+date:       %s
#+filetags:   :film:
#+identifier: %s

* 基本信息
:PROPERTIES:
:DIRECTOR: %s
:YEAR:     %s
:COUNTRY:  %s
:RATING:   %s
:WATCHED:  %s
:END:

* 叙事结构分析
  三幕式／非线性／倒叙／多线叙事？节奏如何控制？

* 人物弧光
  主角如何变化？配角、对立面如何设计？

* 可借鉴的写作手法
  细节描写、信息铺陈、悬念设置、视角运用……

* 场景与氛围
  环境描写、情绪渲染、光影／声音如何塑造气氛？

* 对白分析
  风格、潜台词、信息密度

* 主题与隐喻
  电影在探讨什么？用了哪些象征／意象？

* 灵感触发 / 写作素材
  看完这部片子，有哪些想法可以直接用在小说里？
")

;;;###autoload
(defun my/denote-new-film ()
  "交互式创建一篇观影写作笔记（Denote 独立文件，带模板）。"
  (interactive)
  (require 'denote)
  (let* ((title    (read-string "影片名称: "))
         (director (read-string "导演 (回车跳过): "))
         (year     (read-string "年份 (回车跳过): "))
         (watched  (format-time-string "%Y-%m-%d")))
    (denote title '("film") 'org "film")
    (let ((id (denote-retrieve-filename-identifier (buffer-file-name))))
      (erase-buffer)
      (insert (format my/film-template
                      title (format-time-string "%Y-%m-%d %H:%M") id
                      director year "" "" watched)))))

;; ─── 观影索引文件 ──────────────────────────────────────────────────

;;;###autoload
(defun my/film-index-file ()
  "Return the film index file path."
  (expand-file-name "film-index.org" org-directory))

;;;###autoload
(defun my/open-film-index ()
  "打开或创建观影索引文件。"
  (interactive)
  (find-file (my/film-index-file))
  (when (= (buffer-size) 0)
    (insert "#+title: 观影索引
#+filetags: :film:index:
#+COLUMNS: %40ITEM %DIRECTOR %YEAR %RATING %COUNTRY %WATCHED

* 统计

#+BEGIN_SRC emacs-lisp :results table :exports results
  (let ((files (directory-files-recursively
                (expand-file-name \"film\" denote-directory)
                \"\\\\.org$\")))
    (list (list \"总观影数\" (number-to-string (length files)))))
#+END_SRC

* 2026 观影记录
:PROPERTIES:
:COLUMNS: %40ITEM %DIRECTOR %YEAR %RATING %COUNTRY %WATCHED
:END:

** 六月
")))

;;;###autoload
(defun my/film-add-to-index ()
  "将当前 Denote 观影笔记添加到索引表格中。
在观影笔记 buffer 中调用此命令。"
  (interactive)
  (let* ((title    (or (denote-retrieve-title-value (buffer-file-name) 'org)
                       (read-string "影片名称: ")))
         (director (or (org-entry-get nil "DIRECTOR") ""))
         (year     (or (org-entry-get nil "YEAR") ""))
         (rating   (or (org-entry-get nil "RATING") ""))
         (country  (or (org-entry-get nil "COUNTRY") ""))
         (watched  (or (org-entry-get nil "WATCHED") ""))
         (file-id  (denote-retrieve-filename-identifier (buffer-file-name)))
         (link     (format "[[denote:%s][%s]]" file-id title)))
    (with-current-buffer (find-file-noselect (my/film-index-file))
      (goto-char (point-max))
      (insert (format "| %s | %s | %s | %s | %s | %s |\n"
                      link director year rating country watched))
      (save-buffer))
    (message "已将「%s」添加到观影索引！" title)))

;; ─── 旧笔记迁移 ────────────────────────────────────────────────────
;; 将旧版影评格式（观感/配乐/摄影/评分）迁移为新版写作分析格式。
;; 旧版标记：存在 * 观感 标题
;;
;; 映射规则：
;;   为什么看这部片子  →  灵感触发 / 写作素材
;;   印象深刻的场景   →  场景与氛围
;;   配乐/摄影/表演   →  可借鉴的写作手法（附来源说明）
;;   一句话总结       →  灵感触发（子标题）
;;   RATING /10       →  RATING（去掉后缀）

(defun my/film-section-body (heading)
  "获取 Org 标题 HEADING 下的正文（不含子标题），返回 trimmed string。"
  (save-excursion
    (goto-char (point-min))
    (when (re-search-forward (format "^\\*+ %s$" (regexp-quote heading)) nil t)
      (forward-line)
      (let ((beg (point))
            (end (if (re-search-forward "^\\*+ " nil t)
                     (match-beginning 0)
                   (point-max))))
        (string-trim (buffer-substring-no-properties beg end))))))

;;;###autoload
(defun my/film-migrate-note ()
  "将当前 buffer 的旧版观影笔记迁移为写作分析新版格式。
在旧笔记 buffer 中调用即可，自动识别旧版标记 * 观感。"
  (interactive)
  (unless (derived-mode-p 'org-mode)
    (user-error "请在 Org buffer 中运行"))
  (unless (save-excursion
            (goto-char (point-min))
            (re-search-forward "^\\* 观感" nil t))
    (user-error "已经是新版格式，无需迁移"))
  (require 'denote)
  (let* ((title    (or (denote-retrieve-title-value (buffer-file-name) 'org) ""))
         (id       (denote-retrieve-filename-identifier (buffer-file-name)))
         (director (or (org-entry-get nil "DIRECTOR") ""))
         (year     (or (org-entry-get nil "YEAR") ""))
         (country  (or (org-entry-get nil "COUNTRY") ""))
         (rating   (or (org-entry-get nil "RATING") ""))
         (watched  (or (org-entry-get nil "WATCHED") ""))
         ;; 旧版评分带 " / 10" 后缀，去掉
         (rating   (if (string-match "\\`\\([0-9]+\\)" rating)
                       (match-string 1 rating)
                     rating))
         (reason   (my/film-section-body "为什么看这部片子"))
         (scenes   (my/film-section-body "印象深刻的场景"))
         (tech     (my/film-section-body "配乐/摄影/表演"))
         (summary  (my/film-section-body "一句话总结"))
         ;; 灵感触发 = 为什么看 + 一句话总结
         (inspire  (string-join
                    (delq nil
                          (list (unless (string-empty-p reason) reason)
                                (unless (string-empty-p summary)
                                  (format "** 一句话总结\n%s" summary))))
                    "\n\n")))
    ;; 重建整个 buffer（避免 template 占位符与点位置跟踪的麻烦）
    (erase-buffer)
    (insert (format "#+title:      %s\n" title))
    (insert (format "#+date:       %s\n" (format-time-string "%Y-%m-%d %H:%M")))
    (insert "#+filetags:   :film:\n")
    (insert (format "#+identifier: %s\n" id))
    (insert "\n* 基本信息\n:PROPERTIES:\n")
    (insert (format ":DIRECTOR: %s\n" director))
    (insert (format ":YEAR:     %s\n"   year))
    (insert (format ":COUNTRY:  %s\n"   country))
    (insert (format ":RATING:   %s\n"   rating))
    (insert (format ":WATCHED:  %s\n"   watched))
    (insert ":END:\n\n")
    (insert "* 叙事结构分析\n\n")
    (insert "* 人物弧光\n\n")
    (insert "* 可借鉴的写作手法\n")
    (unless (string-empty-p tech)
      (insert "(以下内容源自旧版「配乐/摄影/表演」)\n\n" tech "\n"))
    (insert "\n* 场景与氛围\n")
    (unless (string-empty-p scenes)
      (insert scenes "\n"))
    (insert "\n* 对白分析\n\n")
    (insert "\n* 主题与隐喻\n\n")
    (insert "* 灵感触发 / 写作素材\n")
    (unless (string-empty-p inspire)
      (insert inspire "\n"))
    (save-buffer)
    (message "迁移完成！")))

;;;###autoload
(defun my/film-migrate-all ()
  "迁移所有旧版观影笔记到新版写作分析格式。"
  (interactive)
  (let* ((dir (expand-file-name "film" denote-directory))
         (files (and (file-directory-p dir)
                     (directory-files-recursively dir "\\.org$")))
         (ok 0)
         (fail 0))
    (unless files
      (user-error "观影笔记目录不存在或无 .org 文件: %s" dir))
    (dolist (file files)
      (with-current-buffer (find-file-noselect file)
        (condition-case e
            (when (save-excursion
                    (goto-char (point-min))
                    (re-search-forward "^\\* 观感" nil t))
              (my/film-migrate-note)
              (cl-incf ok))
          (error
           (message "迁移失败: %s — %s" file (error-message-string e))
           (cl-incf fail)))))
    (message "批量迁移完成: %d 篇成功, %d 篇失败" ok fail)))

;; ─── 写作素材导出 ──────────────────────────────────────────────────

;;;###autoload
(defun my/film-export-writing-notes ()
  "从所有观影笔记中提取「可借鉴的写作手法」和「灵感触发」章节，
合并导出到 ~/org/film-writing-snippets.org，每段附原笔记 Denote 链接。"
  (interactive)
  (let* ((dir (expand-file-name "film" denote-directory))
         (files (and (file-directory-p dir)
                     (directory-files-recursively dir "\\.org$")))
         (out-file (expand-file-name "film-writing-snippets.org" org-directory))
         snippets)
    (unless files
      (user-error "观影笔记目录不存在: %s" dir))
    (dolist (file files)
      (with-temp-buffer
        (insert-file-contents file)
        (let ((title  (or (denote-retrieve-title-value file 'org)
                          (file-name-base file)))
              (id     (denote-retrieve-filename-identifier file))
              (tech   (my/film-section-body "可借鉴的写作手法"))
              (insp   (my/film-section-body "灵感触发 / 写作素材")))
          (when (or (and tech (not (string-empty-p tech)))
                    (and insp (not (string-empty-p insp))))
            (push (format "** [[denote:%s][%s]]\n\n%s\n\n%s\n"
                          id title (or tech "") (or insp ""))
                  snippets)))))
    (unless snippets
      (user-error "没有找到写作素材，请先填写笔记中的「可借鉴的写作手法」或「灵感触发」"))
    (with-current-buffer (find-file out-file)
      (erase-buffer)
      (insert "#+title: 电影写作素材集锦
#+filetags: :film:writing:
#+date: " (format-time-string "%Y-%m-%d %H:%M") "

从所有观影笔记中提取的写作技法与灵感素材。

* 素材列表

")
      (dolist (s (nreverse snippets))
        (insert s "\n"))
      (goto-char (point-min))
      (save-buffer))
    (message "已导出 %d 篇素材到 %s" (length snippets) out-file)))

;; ─── 搜索与辅助函数 ────────────────────────────────────────────────

;;;###autoload
(defun my/denote-find-film ()
  "在观影笔记目录中搜索。"
  (interactive)
  (require 'denote)
  (let ((dir (expand-file-name "film" denote-directory)))
    (if (file-directory-p dir)
        (let ((denote-directory dir))
          (call-interactively #'denote-grep))
      (message "观影笔记目录不存在: %s" dir))))

;;;###autoload
(defun my/film-stats ()
  "显示观影统计信息。"
  (interactive)
  (let* ((dir (expand-file-name "film" denote-directory))
         (files (and (file-directory-p dir)
                     (directory-files-recursively dir "\\.org$")))
         (count (length files)))
    (message "你一共看了 %d 部片子" count)))
