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
       :desc "Rebuild module" "b" #'my/build-cjk-module))
(map! :g "M-=" #'my/count-words)
