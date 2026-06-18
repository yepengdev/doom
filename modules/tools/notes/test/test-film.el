;;; test-film.el --- Comprehensive test suite for +film module -*- lexical-binding: t; -*-
;;
;; Run:  emacs -Q --batch --script modules/tools/notes/test/test-film.el
;;
;; Tests: section-body, migration (single/batch/bench), note creation,
;;        writing export, stats, and nil-safety for missing sections.
;;
;; Design: all work in temporary directories.  Denote functions are mocked.
;; Each test gets a fresh temp dir to avoid cross-contamination.

;; ─── Test runner ────────────────────────────────────────────────────

(defvar test-passed 0)
(defvar test-failed 0)
(defvar test-errors '())

(defmacro deftest (name &rest body)
  "Define a test named NAME.  Signal error on failure."
  (declare (indent 1))
  `(progn
     (message "  TEST: %s" ,(symbol-name name))
     (condition-case err
         (progn ,@body
                (cl-incf test-passed)
                (message "    ✓ pass"))
       (error
        (cl-incf test-failed)
        (push (cons ',name err) test-errors)
        (message "    ✗ FAIL: %s" (error-message-string err))))))

(defun assert (condition &optional msg)
  (unless condition
    (error "Assertion failed: %s" (or msg "nil"))))

(defun assert-equal (a b &optional msg)
  (unless (equal a b)
    (error "Expected %S, got %S%s"
           a b (if msg (concat " -- " msg) ""))))

(defun assert-string-contains (haystack needle &optional msg)
  (unless (string-match-p (regexp-quote needle) haystack)
    (error "Expected %S to contain %S%s"
           haystack needle (if msg (concat " -- " msg) ""))))

(defun assert-error (form)
  (condition-case nil
      (progn (eval form) (error "Expected error, but got none"))
    (error nil)))

;; ─── Mock denote layer ─────────────────────────────────────────────

(defvar denote-directory nil)
(defvar org-directory nil)

(defun denote (title keywords &optional _type subdirectory _date)
  "Mock: create a denote-style file and open its buffer."
  (let* ((id   (format-time-string "%Y%m%dT%H%M%S" (current-time)))
         (safe (replace-regexp-in-string "[^a-z0-9A-Z_-]" "-" title))
         (kws  (mapconcat #'identity keywords "-"))
         (dir  (if subdirectory
                   (expand-file-name subdirectory denote-directory)
                 denote-directory))
         (file (expand-file-name (format "%s--%s__%s.org" id safe kws) dir)))
    (make-directory dir t)
    (with-temp-file file
      (insert (format "#+title:      %s\n#+filetags:   :%s:\n#+identifier: %s\n"
                      title (car keywords) id)))
    (find-file file)))

(defun denote-retrieve-title-value (file &optional _format)
  (with-temp-buffer
    (insert-file-contents file)
    (goto-char (point-min))
    (if (re-search-forward "^#\\+title:\\s-*\\(.*\\)" nil t)
        (match-string 1)
      nil)))

(defun denote-retrieve-filename-identifier (file)
  (let ((basename (file-name-nondirectory file)))
    (when (string-match "\\`\\([0-9]\\{8\\}T[0-9]\\{6\\}\\)" basename)
      (match-string 1 basename))))

(provide 'denote)

;; ─── Load module under test ────────────────────────────────────────

(defun modulep! (&rest _) t)

(let ((test-dir (file-name-directory load-file-name)))
  (load-file (expand-file-name "../autoload/film.el" test-dir)))

;; ─── Test helpers ──────────────────────────────────────────────────

(defun make-temp-env ()
  "Return (temp-root denote-dir org-dir film-dir)."
  (let* ((root (make-temp-file "film-test-" t))
         (den (expand-file-name "denote" root))
         (org (expand-file-name "org" root))
         (film (expand-file-name "film" den)))
    (make-directory film t)
    (make-directory org t)
    (list root den org film)))

(defmacro with-old-note-file (content-form &rest body)
  "Create file-backed old-format note, visit it in org-mode, run BODY.
CONTENT-FORM is an expression evaluating to the buffer content string."
  (declare (indent 1))
  `(let* ((env (make-temp-env))
          (root (nth 0 env))
          (denote-directory (nth 1 env))
          (content-str ,content-form)
          (file (expand-file-name
                 (format "%s--test__film.org"
                         (format-time-string "%Y%m%dT%H%M%S" (current-time)))
                 (nth 3 env)))
          buf)
     (with-temp-file file (insert content-str))
     (setq buf (find-file-noselect file))
     (with-current-buffer buf
       (org-mode)
       (goto-char (point-min))
       (re-search-forward "^\\* ")
       (beginning-of-line)          ; 停在 heading 行本身，org-entry-get 才能找到 property
       ,@body)
     (kill-buffer buf)
     (ignore-errors (delete-directory root t))))

(defun old-format-content (&rest props)
  "Build old-format film note with keyword args:
:title DIRECTOR YEAR COUNTRY RATING WATCHED REASON OVERALL SCENES TECH SUMMARY LINK"
  (let ((title   (plist-get props :title))
        (director (plist-get props :director))
        (year    (plist-get props :year))
        (country (plist-get props :country))
        (rating  (plist-get props :rating))
        (watched (plist-get props :watched))
        (reason  (plist-get props :reason))
        (overall (plist-get props :overall))
        (scenes  (plist-get props :scenes))
        (tech    (plist-get props :tech))
        (summary (plist-get props :summary))
        (link    (plist-get props :link))
        (id      (format-time-string "%Y%m%dT%H%M%S" (current-time)))
        (date    (format-time-string "%Y-%m-%d %H:%M")))
    (format "#+title:      %s
#+date:       %s
#+filetags:   :film:
#+identifier: %s

* 基本信息
:PROPERTIES:
:DIRECTOR: %s
:YEAR:     %s
:COUNTRY:  %s
:RATING:   %s / 10
:WATCHED:  %s
:END:

* 为什么看这部片子
%s

* 观感

** 整体印象
%s

** 印象深刻的场景
%s

** 配乐/摄影/表演
%s

* 一句话总结
%s

* 相关链接
%s
"
            title date id
            director year country rating watched
            (or reason "")
            (or overall "")
            (or scenes "")
            (or tech "")
            (or summary "")
            (or link ""))))

;; ════════════════════════════════════════════════════════════════════
;; Test suite
;; ════════════════════════════════════════════════════════════════════

(message "\n=== Film module test suite ===")

;; ───  1. my/film-section-body ──────────────────────────────────────

(deftest test/section-body-extract
  (with-temp-buffer
    (insert "* AAA\nbody1\n** sub\nbody2\n* BBB\nbody3")
    (goto-char (point-min))
    (assert-equal "body1" (my/film-section-body "AAA"))))

(deftest test/section-body-eob
  (with-temp-buffer
    (insert "* AAA\nlast body")
    (goto-char (point-min))
    (assert-equal "last body" (my/film-section-body "AAA"))))

(deftest test/section-body-missing
  (with-temp-buffer
    (insert "* AAA\nbody")
    (goto-char (point-min))
    (assert-equal nil (my/film-section-body "ZZZ"))))

(deftest test/section-body-stop-at-sibling
  (with-temp-buffer
    (insert "* AAA\ncontent AAA\n** sub\nsub content\n* BBB\ncontent BBB")
    (goto-char (point-min))
    ;; Should not include sub or * BBB content
    (assert-equal "content AAA" (my/film-section-body "AAA"))))

;; ───  2. my/film-template format ───────────────────────────────────

(deftest test/template-format
  (let ((result (format my/film-template
                        "Inception"
                        "2026-06-18 12:00"
                        "ID001"
                        "Nolan"
                        "2010"
                        "US"
                        "8"
                        "2026-06-18")))
    (assert-string-contains result "#+title:      Inception")
    (assert-string-contains result ":DIRECTOR: Nolan")
    (assert-string-contains result ":RATING:   8")
    (assert-string-contains result "* 灵感触发 / 写作素材")))

;; ───  3. Migration — single note ───────────────────────────────────

(deftest test/migrate-full-old-note
  (with-old-note-file
      (old-format-content
        :title "Inception" :director "Nolan" :year "2010"
        :country "US" :rating "8 / 10" :watched "2026-06-18"
        :reason "写悬疑小说" :overall "很好" :scenes "旋转走廊"
        :tech "配乐层层递进" :summary "时间层次的典范")
    (my/film-migrate-note)
    (let ((bufstr (buffer-string)))
      ;; old sections removed
      (assert (not (string-match-p "\\* 观感" bufstr)) "旧观感未删除")
      (assert (not (string-match-p "\\* 为什么看这部片子" bufstr)) "旧为什么看未删除")
      (assert (not (string-match-p "\\* 相关链接" bufstr)) "旧链接未删除")
      ;; new sections present
      (assert-string-contains bufstr "* 叙事结构分析")
      (assert-string-contains bufstr "* 人物弧光")
      (assert-string-contains bufstr "* 可借鉴的写作手法")
      (assert-string-contains bufstr "* 场景与氛围")
      (assert-string-contains bufstr "* 对白分析")
      (assert-string-contains bufstr "* 主题与隐喻")
      (assert-string-contains bufstr "* 灵感触发 / 写作素材")
      ;; content mapped
      (assert-string-contains bufstr "写悬疑小说")        ; reason → inspire
      (assert-string-contains bufstr "旋转走廊")          ; scenes → 场景与氛围
      (assert-string-contains bufstr "配乐层层递进")       ; tech → 写作手法
      (assert-string-contains bufstr "一句话总结")         ; summary subsection
      (assert-string-contains bufstr "时间层次的典范")       ; summary text
      ;; RATING stripped of /10
      (assert (not (string-match-p "/ 10" bufstr)) "RATING /10 未去掉")
      (assert-string-contains bufstr ":RATING:   8")
      ;; basic info preserved
      (assert-string-contains bufstr ":DIRECTOR: Nolan")
      (assert-string-contains bufstr ":YEAR:     2010")
      (assert-string-contains bufstr ":WATCHED:  2026-06-18")
      ;; file saved
      (assert (file-exists-p (buffer-file-name))))))

(deftest test/migrate-partial-no-reason-summary
  "Missing optional sections should not crash."
  (with-old-note-file
      (old-format-content
        :title "Test" :director "D" :year "2026"
        :rating "5" :watched "2026-01-01"
        :reason "" :scenes "scene1" :tech "" :summary "")
    (my/film-migrate-note)
    (let ((bufstr (buffer-string)))
      (assert-string-contains bufstr "* 灵感触发 / 写作素材")
      (assert-string-contains bufstr "scene1"))))

(deftest test/migrate-no-rating-suffix
  "RATING without / 10 suffix should still work."
  (with-old-note-file
      (old-format-content
        :title "NoSuffix" :director "D" :year "2026"
        :rating "8" :watched "2026-06-18"
        :reason "" :scenes "" :tech "" :summary "")
    (my/film-migrate-note)
    (assert-string-contains (buffer-string) ":RATING:   8")))

(deftest test/migrate-non-numeric-rating
  "RATING with arbitrary string preserved as-is."
  (with-old-note-file
      (old-format-content
        :title "Weird" :director "D" :year "2026"
        :rating "N/A" :watched "2026-06-18"
        :reason "" :scenes "" :tech "" :summary "")
    (my/film-migrate-note)
    (assert-string-contains (buffer-string) ":RATING:   N/A")))

(deftest test/migrate-already-migrated
  (with-old-note-file "* 基本信息\n* 叙事结构分析\n"
    (assert-error '(my/film-migrate-note))))

(deftest test/migrate-non-org
  (let ((file (make-temp-file "film-nonorg-" nil ".txt"))
        buf)
    (with-temp-file file (insert "* 观感"))
    (setq buf (find-file-noselect file))
    (with-current-buffer buf
      (assert-error '(my/film-migrate-note)))
    (kill-buffer buf)
    (delete-file file)))

;; ───  4. Migration — batch 100 ─────────────────────────────────────

(deftest test/migrate-batch-100
  (let* ((env (make-temp-env))
         (root (nth 0 env))
         (denote-directory (nth 1 env))
         (film-dir (nth 3 env)))
    (dotimes (i 100)
      (let ((file (expand-file-name
                   (format "%s--test-%03d__film.org"
                           (format-time-string "%Y%m%dT%H%M%S" (time-add nil (* i 0.01)))
                           i)
                   film-dir)))
        (with-temp-file file
          (insert (old-format-content
                   :title (format "Film %d" i)
                   :director "D" :year "2026"
                   :rating "7" :watched "2026-06-18"
                   :reason "写作素材" :scenes "场景"
                   :tech "技法" :summary "总结")))))
    (my/film-migrate-all)
    (let ((n (length (directory-files-recursively film-dir "\\.org$"))))
      (assert-equal 100 n "批迁移后文件数不等于 100")
      (dolist (file (directory-files-recursively film-dir "\\.org$"))
        (with-temp-buffer
          (insert-file-contents file)
          (assert-string-contains (buffer-string) "* 叙事结构分析"))))
    (ignore-errors (delete-directory root t))))

;; ───  5. Migration — bench 500 ─────────────────────────────────────

(deftest test/migrate-bench-500
  (let* ((env (make-temp-env))
         (root (nth 0 env))
         (denote-directory (nth 1 env))
         (film-dir (nth 3 env))
         (start (current-time)))
    (dotimes (i 500)
      (let ((file (expand-file-name
                   (format "%s--bench-%03d__film.org"
                           (format-time-string "%Y%m%dT%H%M%S" (time-add nil (* i 0.001)))
                           i)
                   film-dir)))
        (with-temp-file file
          (insert (old-format-content
                   :title (format "Bench %d" i)
                   :director "D" :year "2026"
                   :rating "7" :watched "2026-06-18"
                   :reason "素材" :scenes "场景"
                   :tech "技法" :summary "总结")))))
    (my/film-migrate-all)
    (let* ((elapsed (float-time (time-subtract (current-time) start)))
           (files (directory-files-recursively film-dir "\\.org$")))
      (assert-equal 500 (length files))
      (message "      500 files in %.1fs" elapsed))
    (ignore-errors (delete-directory root t))))

;; ───  6. my/denote-new-film ────────────────────────────────────────

(deftest test/denote-new-film
  (let* ((env (make-temp-env))
         (root (nth 0 env))
         (denote-directory (nth 1 env))
         (org-directory (nth 2 env))
         file-created)
    (cl-letf (((symbol-function 'read-string)
               (lambda (prompt &rest _)
                 (cond ((string-match-p "影片名称" prompt) "盗梦空间")
                       ((string-match-p "导演" prompt) "诺兰")
                       ((string-match-p "年份" prompt) "2010")
                       (t "mocked")))))
      (my/denote-new-film)
      (setq file-created (buffer-file-name))
      ;; Read from buffer (not disk — save-buffer not called yet)
      (let ((bufstr (buffer-string)))
        (assert file-created "文件未创建")
        (assert-string-contains file-created "film/")
        (assert-string-contains bufstr "#+title:      盗梦空间")
        (assert-string-contains bufstr ":DIRECTOR: 诺兰")
        (assert-string-contains bufstr ":YEAR:     2010")
        (assert-string-contains bufstr "* 叙事结构分析")
        (assert-string-contains bufstr "* 灵感触发 / 写作素材")
        (assert (not (string-match-p "\\* 观感" bufstr)) "含旧观感标题")))
    (ignore-errors (delete-directory root t))))

;; ───  7. my/film-export-writing-notes ──────────────────────────────

(deftest test/export-writing-notes
  (let* ((env (make-temp-env))
         (root (nth 0 env))
         (denote-directory (nth 1 env))
         (org-directory (nth 2 env))
         (film-dir (nth 3 env)))
    ;; create 3 notes
    (dolist (data '(("Film A" "技法A" "灵感A")
                    ("Film B" "技法B" "灵感B")
                    ("Film C" "" "灵感C")))
      (let* ((title (nth 0 data))
             (tech  (nth 1 data))
             (insp  (nth 2 data))
             (id    (format-time-string "%Y%m%dT%H%M%S" (current-time)))
             (safe  (replace-regexp-in-string "[^a-z0-9A-Z_-]" "-" title))
             (file  (expand-file-name (format "%s--%s__film.org" id safe) film-dir)))
        (with-temp-file file
          (insert (format "#+title:      %s
#+filetags:   :film:
#+identifier: %s

* 基本信息
:PROPERTIES:
:DIRECTOR: D
:YEAR:     2026
:COUNTRY:
:RATING:
:WATCHED:  2026-06-18
:END:

* 可借鉴的写作手法
%s

* 灵感触发 / 写作素材
%s
" title id tech insp)))))
    (my/film-export-writing-notes)
    (let* ((out-file (expand-file-name "film-writing-snippets.org" org-directory))
           (content (with-temp-buffer
                      (insert-file-contents out-file)
                      (buffer-string))))
      (assert-string-contains content "#+title: 电影写作素材集锦")
      (assert-string-contains content "Film A")
      (assert-string-contains content "技法A")
      (assert-string-contains content "灵感A")
      (assert-string-contains content "Film B")
      (assert-string-contains content "Film C")
      (assert-string-contains content "灵感C")
      (assert (string-match-p "\\[\\[denote:" content) "缺少 denote 链接"))
    (ignore-errors (delete-directory root t))))

(deftest test/export-empty
  (let* ((env (make-temp-env))
         (root (nth 0 env))
         (denote-directory (nth 1 env))
         (org-directory (nth 2 env))
         (film-dir (nth 3 env)))
    (dotimes (i 3)
      (let* ((id   (format-time-string "%Y%m%dT%H%M%S" (current-time)))
             (file (expand-file-name (format "%s--empty-%d__film.org" id i) film-dir)))
        (with-temp-file file
          (insert (format "#+title: Empty %d\n#+filetags: :film:\n" i)))))
    (assert-error '(my/film-export-writing-notes))
    (ignore-errors (delete-directory root t))))

;; ───  8. my/film-stats ─────────────────────────────────────────────

(deftest test/film-stats
  (let* ((env (make-temp-env))
         (root (nth 0 env))
         (denote-directory (nth 1 env))
         (film-dir (nth 3 env)))
    (dotimes (i 7)
      (let* ((id   (format-time-string "%Y%m%dT%H%M%S" (current-time)))
             (file (expand-file-name (format "%s--note-%d__film.org" id i) film-dir)))
        (with-temp-file file
          (insert "#+title: test\n#+filetags: :film:\n"))))
    (my/film-stats)
    (assert t)
    (ignore-errors (delete-directory root t))))

;; ───  Report ───────────────────────────────────────────────────────

(message "")
(message "══════════════════════════════════════════")
(message "  %d / %d passed" test-passed (+ test-passed test-failed))
(when test-errors
  (message "")
  (message "  Failed tests:")
  (dolist (e test-errors)
    (message "    %s: %s" (car e) (error-message-string (cdr e)))))
(message "══════════════════════════════════════════")

(kill-emacs (if (> test-failed 0) 1 0))
