;;; $DOOMDIR/modules/tools/jieba/config.el -*- lexical-binding: t; -*-

;; ─── 加载 C 动态模块 ──────────────────────────────────────────────
(defvar my/jieba--so
  (expand-file-name "c-modules/jieba-module.so" doom-user-dir)
  "jieba Emacs 模块的 .so 路径。")

(defvar my/jieba--dict-dir
  (expand-file-name "c-modules/cjieba/dict" doom-user-dir)
  "jieba 词典文件目录。")

(defvar my/jieba--loaded nil)

(defun my/jieba--ensure ()
  "确保 jieba 模块已加载并初始化。
首次调用时加载词典（~1-2s），后续调用零开销。"
  (unless (featurep 'jieba-module)
    (unless (file-exists-p my/jieba--so)
      (error "jieba-module.so 不存在，请执行 make -C %s jieba"
             (expand-file-name "c-modules" doom-user-dir)))
    (module-load my/jieba--so))
  (unless my/jieba--loaded
    (my/jieba-init my/jieba--dict-dir)
    (setq my/jieba--loaded t)))

;; ─── 交互式关键词提取 ─────────────────────────────────────────────
;;;###autoload
(defun my/jieba-keywords (beg end &optional n)
  "对选中区域或 buffer 提取中文关键词。
区域/Buffer 中的文本经 jieba TF-IDF 分词后，
显示 TOP-N 个关键词及其权重。"
  (interactive "r\nP")
  (my/jieba--ensure)
  (let* ((text (buffer-substring-no-properties beg end))
         (top-n (if (numberp n) n 10))
         (result (my/jieba-extract text top-n))
         (buf (get-buffer-create "*jieba keywords*")))
    (with-current-buffer buf
      (let ((inhibit-read-only t))
        (erase-buffer)
        (insert (format "关键词（TF-IDF，top %d）：\n\n" top-n))
        (dolist (pair result)
          (insert (format "  %-20s %.4f\n" (car pair) (cdr pair)))))
      (special-mode)
      (goto-char (point-min))
      (pop-to-buffer buf))))

;; ─── 分词 ───────────────────────────────────────────────────────────
;;;###autoload
(defun my/jieba-cut-region (beg end)
  "对选中区域进行中文分词，显示切分结果。"
  (interactive "r")
  (my/jieba--ensure)
  (let* ((text (buffer-substring-no-properties beg end))
         (words (my/jieba-cut text)))
    (message "🔪 %s" (string-join words " / "))))

;; ─── 绑定 ──────────────────────────────────────────────────────────
(map! :leader
       (:prefix-map ("r n" . "Count")
       :desc "Jieba keywords" "k" #'my/jieba-keywords
       :desc "Jieba cut"      "j" #'my/jieba-cut-region))
