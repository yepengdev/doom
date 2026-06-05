;;; $DOOMDIR/modules/tools/cjk/config.el -*- lexical-binding: t; -*-

;; ─── 文本统计（CJK + 英文，纯 C 模块）────────────────────────────────
;;
;; C 模块（c-modules/count-cjk.so）在单次 UTF-8 扫描中完成所有计数。
;; 加载器自动检测过期/缺失的 .so 并运行 make(1)。
;;
;; 导出的 C 函数：
;;   my/count-cjk  （字符串）→ cons（汉字数 . 标点数）
;;   my/count-text （字符串）→ vector [cjk punct en-words en-chars total-cp]
;;
;; 绑定：
;;   M-=         — my/count-words（替换 `count-words-region'）
;;   SPC r n c   — my/count-chinese-chars（传统 CJK 计数器）
;;   SPC r n b   — my/build-cjk-module（重建并重新加载）

(defvar my/cjk-so (expand-file-name "c-modules/count-cjk.so" doom-user-dir)
  "count-cjk 模块的 .so 文件路径。")
(defvar my/cjk-src (expand-file-name "c-modules/count-cjk.c" doom-user-dir))

(defun my/cjk-module-outdated-p ()
  "检查 count-cjk.so 是否需要重新编译（源码比 .so 新则返回 t）。"
  (let ((c-attrs (file-attributes my/cjk-src)))
    (and c-attrs
         (or (not (file-exists-p my/cjk-so))
             (time-less-p (file-attribute-modification-time
                           (file-attributes my/cjk-so))
                          (file-attribute-modification-time c-attrs))))))

(defun my/build-cjk-module ()
  (interactive)
  (let* ((build-dir (expand-file-name "c-modules" doom-user-dir))
         (buf (get-buffer-create "*cjk-build*")))
    (with-current-buffer buf (view-mode -1) (erase-buffer))
    (if (zerop (call-process "make" nil buf nil "-C" build-dir))
        (progn (message "count-cjk.so rebuilt") t)
      (display-buffer buf)
      (error "count-cjk.so build failed — see *cjk-build* buffer"))))

(defun my/load-cjk-module ()
  (interactive)
  (when (fboundp 'module-load)
    (cond
     ((my/cjk-module-outdated-p)
      (message "count-cjk.so 已过期 — 首次使用时会自动重新编译"))
     ((not (file-exists-p my/cjk-so))
      (message "count-cjk.so 缺失 — 首次使用时会自动编译"))
     (t nil))))

(my/load-cjk-module)

(defun my/ensure-cjk-module ()
  (unless (fboundp 'my/count-text)
    (when (my/cjk-module-outdated-p)
      (my/build-cjk-module))
    (when (file-exists-p my/cjk-so)
      (module-load my/cjk-so))
    (unless (fboundp 'my/count-text)
      (error "count-cjk.so 重建后仍不可用"))))

(defun my/--fmt-num (n)
  (let ((abs-n (abs n)))
    (cond
     ((>= abs-n 100000000)
      (format "%.2f亿（%d）" (/ n 100000000.0) n))
     ((>= abs-n 10000)
      (format "%.2f万（%d）" (/ n 10000.0) n))
     (t
      (format "%d" n)))))

;;;###autoload
(defun my/count-chinese-chars (&optional beg end)
  (interactive)
  (my/ensure-cjk-module)
  (let* ((beg (or beg (if (use-region-p) (region-beginning) (point-min))))
         (end (or end (if (use-region-p) (region-end) (point-max))))
         (result (my/count-cjk (buffer-substring-no-properties beg end)))
         (cn-chars (car result))
         (cn-punct (cdr result))
         (total (- end beg))
         (pct (if (> total 0) (/ (* (+ cn-chars cn-punct) 100.0) total) 0.0)))
    (message (concat "字:%s  含标点:%s  总:%d  %.1f%%"
                     (if (use-region-p) " (选中)" ""))
             (my/--fmt-num cn-chars)
             (my/--fmt-num (+ cn-chars cn-punct))
             total pct)))

;;;###autoload
(defun my/count-words (&optional beg end)
  (interactive)
  (my/ensure-cjk-module)
  (let* ((beg (or beg (if (use-region-p) (region-beginning) (point-min))))
         (end (or end (if (use-region-p) (region-end) (point-max))))
         (v (my/count-text (buffer-substring-no-properties beg end)))
         (cjk (aref v 0))
         (punct (aref v 1))
         (en-words (aref v 2))
         (total (aref v 4)))
    (message "中:%s  英:%s  标点:%s  总:%s"
             (my/--fmt-num cjk)
             (my/--fmt-num en-words)
             (my/--fmt-num punct)
             (my/--fmt-num total))))

;;;###autoload
(defun my/word-count (&optional beg end)
  (interactive "r")
  (my/ensure-cjk-module)
  (let* ((text (if (use-region-p)
                   (buffer-substring-no-properties beg end)
                 (buffer-substring-no-properties (point-min) (point-max))))
         (label (if (use-region-p) "Region" "Buffer"))
         (v (my/count-text text)))
    (message "%s: %s CJK, %s punct, %s EN words (%s EN chars), %s total cp"
             label (my/--fmt-num (aref v 0)) (my/--fmt-num (aref v 1))
             (my/--fmt-num (aref v 2)) (my/--fmt-num (aref v 3))
             (my/--fmt-num (aref v 4)))))

;; ─── 绑定 ────────────────────────────────────────────────────────────
(map! :leader
       (:prefix-map ("r n" . "Count")
       :desc "Chinese chars"  "c" #'my/count-chinese-chars
       :desc "Word count"     "w" #'my/word-count
       :desc "Rebuild module" "b" #'my/build-cjk-module
       :desc "Toggle stats"   "s" #'my/writing-stats-mode))
(map! :g "M-=" #'my/count-words)

;; ─── Modeline 实时写作统计（C 模块驱动）────────────────────────────
;;
;; 在 Org 缓冲区的 modeline 上实时显示中/英文词数、标点数。
;; 利用已有的 count-cjk C 模块（my/count-text）做单次 UTF-8 扫描，
;; 空闲 1 秒后自动刷新。大文件（≥ 1 MiB）自动跳过。
;;
;; 绑定：SPC r n s — 开关
;;

(defvar-local my/writing-stats--str nil
  "当前 Org buffer 的写作统计格式化字符串。buffer-local。")

(defvar my/writing-stats--timer nil
  "写作统计 idle timer。全局唯一，首次启用时创建。")

(defvar my/writing-stats--seg-added nil
  "writing-stats 段是否已加入 modeline，防止重复添加。")

(defun my/writing-stats--refresh ()
  "更新当前 buffer 的写作统计并刷新 modeline。
大文件（≥ `my/org-large-file-size-threshold'）跳过。"
  (when (and (derived-mode-p 'org-mode)
             (bound-and-true-p my/writing-stats-mode))
    (if (> (buffer-size) my/org-large-file-size-threshold)
        (setq my/writing-stats--str nil)
      (my/ensure-cjk-module)
      (let* ((text (buffer-substring-no-properties (point-min) (point-max)))
             (v (my/count-text text)))
        (setq my/writing-stats--str
              (format " [中:%s 英:%s 标:%s]"
                      (my/--fmt-num (aref v 0))
                      (my/--fmt-num (aref v 2))
                      (my/--fmt-num (aref v 1))))))
    (force-mode-line-update)))

(define-minor-mode my/writing-stats-mode
  "切换 Org 缓冲区的 modeline 实时写作统计。

启用后，在 modeline 上「中:xxx 英:xxx 标:xxx」实时显示，
空闲 1 秒自动刷新。使用 count-cjk C 模块，单次 UTF-8 扫描。"
  :lighter ""
  :keymap nil
  (if my/writing-stats-mode
      (progn
        (my/writing-stats--refresh)
        (unless my/writing-stats--timer
          (setq my/writing-stats--timer
                (run-with-idle-timer 1.0 t #'my/writing-stats--refresh))))
    (setq my/writing-stats--str nil)
    (force-mode-line-update)))

(after! doom-modeline
  (doom-modeline-def-segment writing-stats
    "显示当前 Org buffer 的写作统计（中/英文词数、标点数）。"
    (when (bound-and-true-p my/writing-stats--str)
      (propertize my/writing-stats--str 'face 'font-lock-comment-face)))
  (unless my/writing-stats--seg-added
    (doom-modeline-add-segment 'writing-stats 'word-count :after)
    (setq my/writing-stats--seg-added t)))

(add-hook 'org-mode-hook #'my/writing-stats-mode)

;; ─── 中文词典（萌典 + mapull 离线数据）────────────────
;;
;; SPC o d / K 统一入口：
;;   中文单字  → 萌典释义 + 汉字档案 + 相关词语/成语
;;   中文多字  → mapull 词语/成语
;;   非中文    → 原始英语后端
;;
;; 数据目录：~/.config/emacs/.local/dict/  (via doom-local-dir)
;;   dict.sqlite3  — 萌典（61MB，需自行准备）
;;   mapull.db     — mapull（首次查询自动下载并导入）
;;   *.json        — mapull 原始数据缓存

(defvar my/mapull-data-dir
  (expand-file-name "dict" doom-local-dir)
  "mapull JSON 文件所在目录。")

(defvar my/mapull-db
  (expand-file-name "mapull.db" my/mapull-data-dir)
  "mapull sqlite3 数据库路径。")

(defvar my/mapull--base-url
  "https://gh-proxy.com/https://raw.githubusercontent.com/mapull/chinese-dictionary/main/"
  "mapull JSON 原始数据的代理下载地址。")

(defvar my/mapull--json-files
  '(("character/char_base.json"   . "char_base.json")
    ("character/char_detail.json" . "char_detail.json")
    ("word/word.json"             . "word.json")
    ("idiom/idiom.json"           . "idiom.json"))
  "需要下载的 mapull 文件列表：源路径 → 本地文件名。")

(defvar my/dict--faces
  '((title    . (:foreground "#ff8700" :bold t :height 1.2))
    (radical  . (:foreground "#ffffff" :background "#a40000"))
    (bopomofo . (:foreground "#008700" :background "#d7ff87"))
    (pinyin   . (:foreground "#008700" :background "#d7ff87"))
    (type     . (:foreground "#ffffd7" :background "#525252"))
    (def      . (:foreground "#1f5bff"))
    (example  . (:foreground "#525252"))
    (quote    . (:foreground "#ff4ea3" :slant italic))
    (link     . (:foreground "#00a775"))
    (synonyms . (:foreground "#9a08ff"))
    (antonyms . (:foreground "#9a08ff"))
    (section  . (:foreground "#626262" :underline t)))
  "词典渲染用的面 alist。")

;; ── 导入：mapull JSON → mapull.db ────────────────────

(defun my/mapull--read-ndjson (file)
  (with-temp-buffer
    (insert-file-contents file)
    (save-excursion
      (goto-char (point-min))
      (when (not (= (char-after) ?\[))
        (insert "[")
        (goto-char (point-max))
        (skip-chars-backward ",\n\r\t ")
        (insert "]")))
    (json-parse-buffer :object-type 'alist :array-type 'list)))

;; ── 自动下载 ───────────────────────────────────────────

(defun my/mapull--download-missing ()
  "下载缺失的 mapull JSON 文件到 `my/mapull-data-dir'。"
  (let ((data-dir my/mapull-data-dir))
    (unless (file-exists-p data-dir)
      (make-directory data-dir t))
    (dolist (pair my/mapull--json-files)
      (let ((dest (expand-file-name (cdr pair) data-dir)))
        (unless (file-exists-p dest)
          (message "词典数据：下载 %s ..." (cdr pair))
          (condition-case err
              (url-copy-file
               (concat my/mapull--base-url (car pair)) dest t)
            (error
             (message "下载 %s 失败：%s，跳过" (cdr pair) (error-message-string err))
             nil)))))))

;;;###autoload
(defun my/mapull-import (&optional base detail words idioms)
  "下载（如需）并导入 mapull JSON 数据为 mapull.db。
可选参数控制导入哪些表（默认全导入）。"
  (interactive)
  (let ((data-dir my/mapull-data-dir))
    (unless (file-exists-p data-dir)
      (make-directory data-dir t))
    (my/mapull--download-missing)
    (when (or base (not (or base detail words idioms)))
      (my/mapull--import-char-base))
    (when (or detail (not (or base detail words idioms)))
      (my/mapull--import-char-detail))
    (when (or words (not (or base detail words idioms)))
      (my/mapull--import-words))
    (when (or idioms (not (or base detail words idioms)))
      (my/mapull--import-idioms))
    (message "mapull 导入完成！")))

(defun my/mapull--import-char-base ()
  (let* ((file (expand-file-name "char_base.json" my/mapull-data-dir))
         (db (sqlite-open my/mapull-db))
         (data (my/mapull--read-ndjson file))
         (total (length data))
         (n 0))
    (sqlite-execute db "CREATE TABLE IF NOT EXISTS chars (
      char TEXT PRIMARY KEY, strokes INTEGER, pinyin TEXT,
      radical TEXT, freq INTEGER, structure TEXT,
      traditional TEXT, variant TEXT, definition TEXT)")
    (sqlite-execute db "BEGIN TRANSACTION")
    (dolist (entry data)
      (condition-case nil
          (sqlite-execute db
            "INSERT OR REPLACE INTO chars (char,strokes,pinyin,radical,freq,structure,traditional,variant)
             VALUES (?,?,?,?,?,?,?,?)"
            (list (alist-get 'char entry)
                  (alist-get 'strokes entry)
                  (string-join (alist-get 'pinyin entry) ",")
                  (alist-get 'radicals entry)
                  (alist-get 'frequency entry)
                  (alist-get 'structure entry)
                  (or (alist-get 'traditional entry) "")
                  (or (alist-get 'variant entry) "")))
        (error nil))
      (cl-incf n)
      (when (= (% n 1000) 0)
        (message "导入 char_base: %d/%d" n total)))
    (sqlite-execute db "COMMIT")
    (message "import char_base: %d rows"
             (caar (sqlite-select db "SELECT COUNT(*) FROM chars")))
    (sqlite-close db)))

(defun my/mapull--import-char-detail ()
  (let* ((file (expand-file-name "char_detail.json" my/mapull-data-dir))
         (db (sqlite-open my/mapull-db))
         (data (my/mapull--read-ndjson file))
         (total (length data))
          (n 0))
    (sqlite-execute db "BEGIN TRANSACTION")
    (dolist (entry data)
      (let* ((char (alist-get 'char entry))
             (prons (alist-get 'pronunciations entry))
             (first-def
              (when (and prons (listp prons))
                (let* ((p (car prons))
                       (exps (alist-get 'explanations p)))
                  (when (and exps (listp exps))
                    (alist-get 'content (car exps)))))))
        (when (and char first-def)
          (condition-case nil
              (sqlite-execute db
                "UPDATE chars SET definition = ? WHERE char = ?"
                (list first-def char))
            (error nil))))
      (cl-incf n)
      (when (= (% n 1000) 0)
        (message "导入 char_detail: %d/%d" n total)))
    (sqlite-execute db "COMMIT")
    (message "import char_detail: done")
    (sqlite-close db)))

(defun my/mapull--import-words ()
  (let* ((file (expand-file-name "word.json" my/mapull-data-dir)))
    (if (not (file-exists-p file))
        (message "跳过 words: %s 不存在" file)
      (let* ((db (sqlite-open my/mapull-db))
             (data (with-temp-buffer
                     (insert-file-contents file)
                     (json-parse-buffer :object-type 'alist :array-type 'list)))
             (total (length data))
             (n 0))
        (sqlite-execute db "CREATE TABLE IF NOT EXISTS words (
          word TEXT, pinyin TEXT, definition TEXT)")
        (sqlite-execute db "BEGIN TRANSACTION")
        (dolist (entry data)
          (condition-case nil
              (sqlite-execute db
                "INSERT INTO words VALUES (?,?,?)"
                (list (alist-get 'word entry)
                      (or (alist-get 'pinyin entry) "")
                      (or (alist-get 'explanation entry) "")))
            (error nil))
          (cl-incf n)
          (when (= (% n 5000) 0)
            (message "导入 words: %d/%d" n total)))
        (sqlite-execute db "COMMIT")
        (sqlite-execute db "CREATE INDEX IF NOT EXISTS idx_words_word ON words(word)")
        (message "import words: %d rows"
                 (caar (sqlite-select db "SELECT COUNT(*) FROM words")))
        (sqlite-close db)))))

(defun my/mapull--import-idioms ()
  (let* ((file (expand-file-name "idiom.json" my/mapull-data-dir))
         (db (sqlite-open my/mapull-db))
         (data (with-temp-buffer
                 (insert-file-contents file)
                 (json-parse-buffer :object-type 'alist :array-type 'list)))
         (total (length data))
         (n 0))
    (sqlite-execute db "CREATE TABLE IF NOT EXISTS idioms (
      idiom TEXT, pinyin TEXT, definition TEXT, source TEXT)")
    (sqlite-execute db "BEGIN TRANSACTION")
    (dolist (entry data)
      (condition-case nil
          (sqlite-execute db
            "INSERT INTO idioms VALUES (?,?,?,?)"
            (list (alist-get 'word entry)
                  (or (alist-get 'pinyin entry) "")
                  (or (alist-get 'explanation entry) "")
                  (or (let ((s (alist-get 'source entry)))
                        (when (and s (listp s))
                          (alist-get 'book s)))
                      "")))
        (error nil))
      (cl-incf n)
      (when (= (% n 5000) 0)
        (message "导入 idioms: %d/%d" n total)))
    (sqlite-execute db "COMMIT")
    (sqlite-execute db "CREATE INDEX IF NOT EXISTS idx_idioms_idiom ON idioms(idiom)")
    (message "import idioms: %d rows"
             (caar (sqlite-select db "SELECT COUNT(*) FROM idioms")))
    (sqlite-close db)))

;; ── 萌典查询（移植自 config.el）────────────────────────

(defvar my/moedict-db
  (expand-file-name "dict/dict.sqlite3" doom-local-dir))

(defun my/mapull--cjk-p (string)
  "判断 STRING 是否包含中文字符（使用 Emacs 的 chinese category）。"
  (string-match (rx (category chinese)) string))

(defun my/mapull--fmt (n)
  (let ((abs-n (abs n)))
    (cond ((>= abs-n 100000000)
           (format "%.2f亿（%d）" (/ n 100000000.0) n))
          ((>= abs-n 10000)
           (format "%.2f万（%d）" (/ n 10000.0) n))
          (t (format "%d" n)))))

;; 萌典内部查询（写当前 buffer）
(defun my/mapull--moedict-query (word)
  (unless (file-exists-p my/moedict-db)
    (error "dict.sqlite3 不存在于 %s" my/moedict-db))
  (let ((db (sqlite-open my/moedict-db))
        (n 0))
    (unwind-protect
        (dolist (row (sqlite-select db "
SELECT e.title, e.radical, e.stroke_count, e.non_radical_stroke_count,
       h.bopomofo, h.bopomofo2, h.pinyin,
       d.type, d.def, d.example, d.quote, d.link,
       d.synonyms, d.antonyms
FROM entries e, heteronyms h, definitions d
WHERE e.title = ?
  AND h.entry_id = e.id
  AND d.heteronym_id = h.id" (list word)))
          (cl-incf n)
          (my/mapull--moedict-insert-row row)
          (insert "\n"))
      (sqlite-close db))
    (when (= n 0)
      (error "未找到「%s」" word))))

(defun my/mapull--moedict-insert-row (row)
  (cl-flet ((col (pos)
              (let ((v (nth pos row)))
                (and (not (null v)) v))))
    (let ((title        (col 0)) (radical   (col 1)) (stroke-c   (col 2))
          (non-rad-sc   (col 3)) (bopomofo  (col 4)) (bopomofo2  (col 5))
          (pinyin       (col 6)) (type      (col 7)) (def        (col 8))
          (example      (col 9)) (quote     (col 10)) (link      (col 11))
          (synonyms     (col 12)) (antonyms  (col 13)))
      (when radical
        (insert (propertize (format "部首:%s  笔画:%s(+%s)" radical stroke-c non-rad-sc)
                            'face (cdr (assq 'radical my/dict--faces))))
        (insert "\n"))
      (when title
        (insert (propertize title 'face (cdr (assq 'title my/dict--faces))))
        (when bopomofo (insert "  " (propertize bopomofo 'face (cdr (assq 'bopomofo my/dict--faces)))))
        (when pinyin   (insert "  " (propertize pinyin 'face (cdr (assq 'pinyin my/dict--faces)))))
        (insert "\n"))
      (when type
        (insert (propertize (format " [%s]" type) 'face (cdr (assq 'type my/dict--faces)))))
      (when def
        (insert "\n" (propertize def 'face (cdr (assq 'def my/dict--faces)))))
      (when example
        (insert "\n  " (propertize example 'face (cdr (assq 'example my/dict--faces)))))
      (when quote
        (insert "\n  " (propertize quote 'face (cdr (assq 'quote my/dict--faces)))))
      (when link
        (insert "\n  " (propertize link 'face (cdr (assq 'link my/dict--faces)))))
      (when synonyms
        (insert "\n  [同] " (propertize synonyms 'face (cdr (assq 'synonyms my/dict--faces)))))
      (when antonyms
        (insert "\n  [反] " (propertize antonyms 'face (cdr (assq 'antonyms my/dict--faces))))))))

;; ── mapull 查询 ──────────────────────────────────────

(defun my/mapull--open-db ()
  (unless (file-exists-p my/mapull-db)
    (when (yes-or-no-p "mapull.db 不存在，首次需要下载约 100MB 数据并建立索引，现在进行？")
      (my/mapull-import)))
  (if (file-exists-p my/mapull-db)
      (sqlite-open my/mapull-db)
    (error "mapull.db 不存在，运行 M-x my/mapull-import 手动导入")))

(defun my/mapull--query-char (db char)
  (car (sqlite-select db "SELECT * FROM chars WHERE char = ?" (list char))))

(defun my/mapull--query-words (db word)
  (sqlite-select db
    "SELECT word, pinyin, definition FROM words
     WHERE word = ? OR word LIKE ?
     ORDER BY CASE WHEN word = ? THEN 0 ELSE 1 END
     LIMIT 20"
    (list word (format "%%%s%%" word) word)))

(defun my/mapull--query-idioms (db word)
  (sqlite-select db
    "SELECT idiom, pinyin, definition FROM idioms
     WHERE idiom = ? OR idiom LIKE ?
     ORDER BY CASE WHEN idiom = ? THEN 0 ELSE 1 END
     LIMIT 10"
    (list word (format "%%%s%%" word) word)))

;; ── 渲染 ─────────────────────────────────────────────

(defun my/dict--render-section (label)
  (insert "\n" (propertize (make-string 50 ?─)
                           'face (cdr (assq 'section my/dict--faces)))
          "\n"
          (propertize (concat "  " label)
                      'face (cdr (assq 'section my/dict--faces)))
          "\n"))

(defun my/dict--render-char-archive (db char)
  (let ((row (my/mapull--query-char db char)))
    (when row
      (my/dict--render-section "汉字档案")
      (let ((strokes   (nth 1 row))
            (pinyin    (nth 2 row))
            (radical   (nth 3 row))
            (freq      (nth 4 row))
            (structure (nth 5 row))
            (trad      (nth 6 row))
            (variant   (nth 7 row))
            (defn      (nth 8 row)))
        (insert (format "笔画:%s  部首:%s  结构:%s" (or strokes "?")
                        (or radical "?") (or structure "?"))
                (when pinyin (format "  拼音:%s" pinyin))
                (when freq   (format "  频次:%s"
                                     (nth freq '("常用0" "常用1" "常用2" "二级" "三级" "生僻"))))
                "\n")
        (when (and trad (not (string= trad "")))
          (insert (format "繁体:%s\n" trad)))
        (when (and defn (not (string= defn "")))
          (insert (propertize defn 'face (cdr (assq 'def my/dict--faces))) "\n"))))))

(defun my/dict--render-word-results (db word)
  (let ((rows (my/mapull--query-words db word)))
    (when rows
      (my/dict--render-section
       (format "词语（%d 条）" (length rows)))
      (dolist (r rows)
        (insert (propertize (car r) 'face (cdr (assq 'title my/dict--faces))))
        (let ((pinyin (nth 1 r))
              (defn (nth 2 r)))
          (when (and pinyin (not (string= pinyin "")))
            (insert "  " (propertize pinyin 'face (cdr (assq 'pinyin my/dict--faces)))))
          (when (and defn (not (string= defn "")))
            (insert "\n" (propertize defn 'face (cdr (assq 'def my/dict--faces)))))
          (insert "\n\n"))))))

(defun my/dict--render-idiom-results (db word)
  (let ((rows (my/mapull--query-idioms db word)))
    (when rows
      (my/dict--render-section
       (format "成语（%d 条）" (length rows)))
      (dolist (r rows)
        (insert (propertize (car r) 'face (cdr (assq 'title my/dict--faces))))
        (let ((pinyin (nth 1 r))
              (defn (nth 2 r)))
          (when (and pinyin (not (string= pinyin "")))
            (insert "  " (propertize pinyin 'face (cdr (assq 'pinyin my/dict--faces)))))
          (when (and defn (not (string= defn "")))
            (insert "\n" (propertize defn 'face (cdr (assq 'def my/dict--faces)))))
          (insert "\n\n"))))))

;; ── 主入口 ────────────────────────────────────────────

(defun my/dict--render (word)
  "显示 WORD 的词典信息。单字合并萌典+mapull，多字仅 mapull。"
  (let ((buf (get-buffer-create "*萌典*")))
    (with-current-buffer buf
      (let ((inhibit-read-only t) db)
        (erase-buffer)
        (condition-case err
            (progn
              (setq db (condition-case nil
                           (sqlite-open my/mapull-db)
                         (error nil)))
              (when (= (length word) 1)
                (condition-case nil
                    (my/mapull--moedict-query word)
                  (error
                   (my/dict--render-section "萌典释义")
                   (insert (propertize (format "（萌典未收录「%s」）" word)
                                       'face (cdr (assq 'def my/dict--faces))))))
                (when db
                  (my/dict--render-char-archive db word)))
              (when db
                (my/dict--render-word-results db word)
                (my/dict--render-idiom-results db word)))
          (error
           (insert (format "错误: %s" (error-message-string err)))))
        (when db (ignore-errors (sqlite-close db)))
        (when (= (buffer-size) 0)
          (insert (format "没有找到「%s」的相关结果" word)))
        (goto-char (point-min))
        (special-mode)
        (setq buffer-read-only t
              header-line-format (format "  萌典 · mapull: %s" word)))
      (display-buffer buf))))

;;;###autoload
(defun my/+lookup-dictionary-definition-a (fn identifier &optional arg)
  "中文用萌典+mapull，英文用原始后端。"
  (if (and identifier (my/mapull--cjk-p identifier))
      (my/dict--render identifier)
    (funcall fn identifier arg)))

(advice-add '+lookup/dictionary-definition :around #'my/+lookup-dictionary-definition-a)
