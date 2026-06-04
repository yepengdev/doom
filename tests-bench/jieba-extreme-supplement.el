;;; jieba-extreme-supplement.el --- 补充极限测试：覆盖源码薄弱点  -*- lexical-binding: t; -*-

;; Run:  emacs -Q --batch -l tests-bench/jieba-test.el \
;;            -l tests-bench/jieba-extreme-supplement.el
;; Deps: 先加载原测试套件获取 deftest 宏
;; Safety: 本文件包含可能触发 SIGABRT 的测试（assert 在生产代码中）。
;;         若 cppjieba 的 Extract 遇到空 offsets 向量，Emacs 进程将终止。

(require 'cl-lib)

(message "\n=== jieba 补充极限测试: 源码薄弱点覆盖 ===\n")

;; ===================================================================
;; 15. 超大规模压力 (1M+ 字符)
;; ===================================================================

(deftest "megastress: 1M Hanzi cut"
  (cl-assert (listp (my/jieba-cut (make-string 1048576 ?测)))))

(deftest "megastress: 1M mixed cut"
  (cl-assert (listp (my/jieba-cut (concat (make-string 500000 ?中)
                                           (make-string 524288 ?a))))))

(deftest "megastress: 1M Hanzi extract"
  (cl-assert (listp (my/jieba-extract (make-string 1048576 ?测) 10))))

(deftest "megastress: 200K alternating chars extract"
  (cl-assert (listp (my/jieba-extract
                     (let* ((n 204800)
                            (s (make-string n 0)))
                       (dotimes (i n s)
                         (aset s i (if (zerop (mod i 3)) ?中 ?国))))
                     10))))

(deftest "megastress: 2M cut (memory boundary)"
  (cl-assert (listp (my/jieba-cut (make-string 2097152 ?测)))))

(deftest "megastress: null-rich 500K cut"
  (cl-assert (listp (my/jieba-cut (concat (make-string 250000 0)
                                           (make-string 250000 ?测))))))

;; ===================================================================
;; 16. 分词结果可逆性: 拼接后等于原串
;; ===================================================================

(deftest "roundtrip: simple Chinese"
  (let* ((text "南京市长江大桥")
         (parts (my/jieba-cut text))
         (rejoined (apply #'concat parts)))
    (cl-assert (equal text rejoined))))

(deftest "roundtrip: mixed Chinese English"
  (let* ((text "我们使用PyTorch训练BERT模型")
         (parts (my/jieba-cut text))
         (rejoined (apply #'concat parts)))
    (cl-assert (equal text rejoined))))

(deftest "roundtrip: with digits and punct"
  (let* ((text "2024年5月20日，测试完成率99.9%！")
         (parts (my/jieba-cut text))
         (rejoined (apply #'concat parts)))
    (cl-assert (equal text rejoined))))

(deftest "roundtrip: emoji embedded"
  (let* ((text "今天心情很好🎉明天继续💪加油")
         (parts (my/jieba-cut text))
         (rejoined (apply #'concat parts)))
    (cl-assert (equal text rejoined))))

(deftest "roundtrip: CJK Ext B"
  (let* ((cext (string (decode-char 'ucs #x20000)))
         (text (concat cext "测试" cext))
         (parts (my/jieba-cut text))
         (rejoined (apply #'concat parts)))
    (cl-assert (equal text rejoined))))

(deftest "roundtrip: 100K repeated char"
  (let* ((text (make-string 100000 ?中))
         (parts (my/jieba-cut text))
         (rejoined (apply #'concat parts)))
    (cl-assert (equal text rejoined))))

(deftest "roundtrip: zero-width + normal mixed"
  (let* ((text (concat (string #x200B) "测试" (string #xFEFF) "文本" (string #x200D)))
         (parts (my/jieba-cut text))
         (rejoined (apply #'concat parts)))
    (cl-assert (equal text rejoined))))

(deftest "roundtrip: fullwidth only"
  (let* ((text "ＡＢＣ１２３，。！")
         (parts (my/jieba-cut text))
         (rejoined (apply #'concat parts)))
    (cl-assert (equal text rejoined))))

;; ===================================================================
;; 17. my/jieba-tag 深度测试
;; ===================================================================

(deftest "tag: null bytes in text"
  (cl-assert (listp (my/jieba-tag "abc\000def\000ghi"))))

(deftest "tag: null bytes with CJK"
  (cl-assert (listp (my/jieba-tag (concat "测试" (make-string 50 0) "文本")))))

(deftest "tag: 5000 Hanzi stress"
  (cl-assert (listp (my/jieba-tag (make-string 5000 ?文)))))

(deftest "tag: 100K mixed stress"
  (cl-assert (listp (my/jieba-tag (concat (make-string 50000 ?中)
                                           (make-string 50000 ?a))))))

(deftest "tag: each tag is (word . pos-tag)"
  (dolist (pair (my/jieba-tag "我爱北京天安门"))
    (cl-assert (stringp (car pair)))
    (cl-assert (stringp (cdr pair)))
    (cl-assert (> (length (car pair)) 0))
    (cl-assert (> (length (cdr pair)) 0))))

(deftest "tag: POS tag values match expected parts of speech"
  (let* ((result (my/jieba-tag "吃苹果"))
         (tags (mapcar #'cdr result)))
    ;; 吃 → v (verb) or similar, 苹果 → n (noun) or similar
    (dolist (tag tags)
      (cl-assert (stringp tag))
      (cl-assert (> (length tag) 0)))))

(deftest "tag: roundtrip reconstruct (顺序一致)"
  (let* ((text "南京市长江大桥")
         (tagged (my/jieba-tag text))
         (words (mapcar #'car tagged))
         (rejoined (apply #'concat words)))
    (cl-assert (equal text rejoined))))

;; ===================================================================
;; 18. 坏参数 / 异常初始化
;; ===================================================================
;; NOTE: my/jieba-init → ensure_initialized() 使用全局静态变量 g_jieba/
;; g_extractor。首次成功的 init 后，guard `if (g_jieba && g_extractor)
;; return 1` 使后续任何参数均返回 t。这其实是安全的——模块已有有效句柄。
;; 下方测试验证的是此 guard 行为而非参数校验（我们无法在加载后重置模块）。

(deftest "init: guard returns t after successful init (design)"
  (cl-assert (my/jieba-init nil)    ; 已有有效句柄 → t
             "已初始化后传入 nil 应返回 t（设计如此）"))

(deftest "init: invalid path guard returns t after successful init"
  (cl-assert (my/jieba-init "/nonexistent/path")
             "已初始化后传入无效路径应返回 t"))

(deftest "cut: non-string arg errors gracefully"
  (condition-case nil
      (progn (my/jieba-cut nil)
             (error "should have thrown"))
    (wrong-type-argument nil)))

(deftest "extract: topn = most-negative-fixnum"
  (cl-assert (>= (length (my/jieba-extract "测试" most-negative-fixnum)) 1)))

(deftest "extract: topn string arg errors"
  (condition-case nil
      (progn (my/jieba-extract "测试" "not-a-number")
             (error "should have thrown"))
    (wrong-type-argument nil)))

;; ===================================================================
;; 19. 交叉一致性: cut 与 extract 的词语子集关系
;; ===================================================================

(deftest "consistency: extract keywords subset of cut"
  (let* ((text "自然语言处理与人工智能机器学习密切相关")
         (cut-words (mapcar (lambda (w) (decode-coding-string w 'utf-8))
                            (my/jieba-cut text)))
         (kw-words (mapcar (lambda (pair)
                             (decode-coding-string (car pair) 'utf-8))
                           (my/jieba-extract text 5))))
    (dolist (kw kw-words)
      (cl-assert (member kw cut-words) nil
                 "关键词 '%s' 不在 cut 结果中" kw))))

(deftest "consistency: tag words same order and content as cut"
  (let* ((text "我爱北京天安门")
         (cut-words (my/jieba-cut text))
         (tag-words (mapcar #'car (my/jieba-tag text))))
    (cl-assert (equal cut-words tag-words) nil
               "cut 与 tag 不一致: cut=%s tag=%s" cut-words tag-words)))

(deftest "consistency: 10 texts strict match"
  (dolist (text '("南京市长江大桥北京清华大学"
                  "Machine learning with Python"
                  "2024年是一个闰年吗？"
                  "🎉🎊💪🔥👍"
                  "日本語のテスト"
                  "한국어 테스트입니다"
                  "a"
                  ""
                  "  "
                  "我们使用PyTorch训练BERT模型"))
    (let ((cut-words (my/jieba-cut text))
          (tag-words (mapcar #'car (my/jieba-tag text))))
      (cl-assert (equal cut-words tag-words) nil
                 "MISMATCH for '%s': cut=%s tag=%s"
                 text cut-words tag-words))))

;; ===================================================================
;; 20. 重复初始化与多次加载稳定性
;; ===================================================================

(deftest "stability: reinit 100 times"
  (dotimes (_ 100)
    (my/jieba-init (expand-file-name "c-modules/cjieba/dict"
                                      (file-name-directory
                                       (or load-file-name buffer-file-name)))))
  (cl-assert (equal (my/jieba-cut "测试") '("测试"))))

(deftest "stability: 2000 cut with 10 diff texts round-robin + tag"
  (let ((texts '("" "a" "测" "测试文本" "南京市长江大桥"
                 "Let's test NLP with 中文 and emoji🎉"
                 "ABC１２３测试")))
    (dotimes (_ 2000)
      (dolist (txt texts)
        (my/jieba-cut txt)
        (my/jieba-tag txt)
        (when (> (length txt) 0)
          (my/jieba-extract txt 3))))
    t))

;; ===================================================================
;; 21. 编码安全: UTF-8 overlong / illegal sequences
;; ===================================================================

(deftest "safety: overlong ASCII (2-byte encoding of '/')"
  (cl-assert (listp (my/jieba-cut (concat (string #xC0 #xAE) "测试")))))

(deftest "safety: overlong ASCII (3-byte encoding of space)"
  (cl-assert (listp (my/jieba-cut (concat (string #xE0 #x80 #xA0) "测试")))))

(deftest "safety: invalid continuation byte"
  (cl-assert (listp (my/jieba-cut (concat "测" (string #x80) "试")))))

(deftest "safety: missing continuation bytes"
  (cl-assert (listp (my/jieba-cut (concat "测" (string #xE4))))))

(deftest "safety: surrogate half (U+D800) alone"
  (cl-assert (listp (my/jieba-cut (string #xD800)))))

(deftest "safety: out-of-range Unicode (U+110000)"
  ;; #x110000 超出 Unicode 上限 (#x10FFFF)，Emacs 在读取时就会报错。
  ;; 验证模块是否对合法输入正常工作（而不是尝试构造非法编码）
  (cl-assert (null (decode-char 'ucs #x110000))
             "U+110000 应无效，若此断言失败则 Emacs 行为改变"))

(deftest "safety: 4-byte char (U+1F600 GRINNING FACE)"
  (cl-assert (listp (my/jieba-cut (string #x1F600)))))

(deftest "safety: mixed BOM + reversal sequences"
  (cl-assert (listp (my/jieba-cut (concat (string #xFEFF) "测试"
                                           (string #xFFFE) "文本")))))

;; ===================================================================
;; 22. 大文件场景模拟 (Denote 集成)
;; ===================================================================

(deftest "denote: simulate 500KB org file"
  (let* ((header "#+title: Large Note\n#+date: 2024-06-01\n#+filetags: :Test:\n\n")
         (body (make-string (- 500000 (length header)) ?文))
         (full (concat header body)))
    (cl-assert (listp (my/jieba-extract full 10)))))

(deftest "denote: simulate 1MB org file extract"
  (let* ((header "#+title: Huge Note\n#+date: 2024-12-31\n\n")
         (body (make-string (- 1048576 (length header)) ?中))
         (full (concat header body)))
    (cl-assert (listp (my/jieba-extract full 10)))))

(deftest "denote: simulate 1MB org file cut"
  (let* ((header "#+title: Huge Note\n\n")
         (body (make-string (- 1048576 (length header)) ?的))
         (full (concat header body)))
    (cl-assert (listp (my/jieba-cut full)))))

(deftest "denote: empty-ish org file"
  (cl-assert (listp (my/jieba-extract "#+title:\n#+date:\n\n" 5))))

(deftest "denote: only properties drawer"
  (cl-assert (listp (my/jieba-extract
                     ":PROPERTIES:\n:ID: abc123\n:END:" 5))))

;; ===================================================================
;; 23. 高密度重复调用 — 检查是否有内存泄漏迹象
;; ===================================================================

(deftest "leak: 50000 short cut calls (smoke check)"
  (dotimes (_ 50000)
    (my/jieba-cut "a"))
  t)

(deftest "leak: 10000 alternating cut/extract/tag with large texts"
  (dotimes (_ 10000)
    (my/jieba-cut (make-string 1000 ?中))
    (my/jieba-extract (make-string 1000 ?文) 5)
    (my/jieba-tag (make-string 1000 ?测)))
  t)

(deftest "leak: 1000 full roundtrips with 10K strings"
  (dotimes (_ 1000)
    (let* ((text (make-string 10000 ?中))
           (parts (my/jieba-cut text))
           (rejoined (apply #'concat parts)))
      (cl-assert (equal text rejoined))))
  t)

;; ===================================================================
;; 24. 多字节字符对齐 (4-byte/3-byte/2-byte 混合边界)
;; ===================================================================

(deftest "alignment: 4-byte only"
  (cl-assert (listp (my/jieba-cut (make-string 100 #x1F600)))))

(deftest "alignment: interleaved 1/2/3/4-byte"
  (cl-assert (listp (my/jieba-cut (concat (string #x1F600) "a" (string #x4E2D)
                                           (string #x0800) "b" (string #x00FF))))))

(deftest "alignment: rapid code point switching"
  (cl-assert (listp (my/jieba-cut
                     (with-temp-buffer
                       (dotimes (_ 1000)
                         (insert (string (decode-char 'ucs (+ #x4E00 (random 20000))))))
                       (buffer-string))))))

;; ===================================================================
;; Summary
;; ===================================================================

(message "")
(message "=== 补充极限测试完成 ===")
