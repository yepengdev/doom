;;; jieba-test.el --- extreme/boundary tests for jieba C module   -*- lexical-binding: t; -*-

;; Run:  emacs -Q --batch -l tests-bench/jieba-test.el
;; Deps: c-modules/jieba-module.so (run make -C c-modules/ first)

(require 'cl-lib)

(let* ((script-dir (file-name-directory (or load-file-name buffer-file-name)))
       (doom-dir  (expand-file-name ".." script-dir))
       (so-path   (expand-file-name "c-modules/jieba-module.so" doom-dir))
       (dict-dir  (expand-file-name "c-modules/cjieba/dict" doom-dir)))
  (unless (file-exists-p so-path)
    (error "jieba-module.so not found at %s, run make -C c-modules/" so-path))
  (module-load so-path)
  (unless (my/jieba-init dict-dir)
    (error "jieba init failed")))

(defvar jt-count 0)
(defvar jt-pass 0)
(defvar jt-fail 0)

(defmacro deftest (name &rest body)
  (declare (indent 1))
  `(let ((name ,name))
     (setq jt-count (1+ jt-count))
     (condition-case e
         (progn ,@body
                (setq jt-pass (1+ jt-pass))
                (message "  PASS: %s" name))
       (error
        (setq jt-fail (1+ jt-fail))
        (message "  FAIL: %s -- %s" name (error-message-string e))))))

(message "=== jieba extreme/boundary test suite ===")

;; ===================================================================
;; 1. Empty / whitespace only input
;; ===================================================================

(deftest "empty string cut"
  (cl-assert (equal (my/jieba-cut "") '())))

(deftest "empty string extract"
  (cl-assert (equal (my/jieba-extract "" 5) '())))

(deftest "empty string tag"
  (cl-assert (equal (my/jieba-tag "") '())))

(deftest "single space cut"
  (cl-assert (equal (my/jieba-cut " ") '(" "))))

(deftest "multiple spaces"
  (let ((r (my/jieba-cut "   ")))
    (cl-assert (listp r))
    (cl-assert (> (length r) 0))))

(deftest "tab only"
  (cl-assert (listp (my/jieba-cut "\t"))))

(deftest "newline only"
  (cl-assert (listp (my/jieba-cut "\n"))))

(deftest "CR only"
  (cl-assert (listp (my/jieba-cut "\r"))))

(deftest "mixed whitespace"
  (cl-assert (listp (my/jieba-cut " \t\n\r  "))))

;; ===================================================================
;; 2. Single character / very short input
;; ===================================================================

(deftest "single Hanzi cut"
  (cl-assert (equal (my/jieba-cut "人") '("人"))))

(deftest "single Hanzi extract"
  (cl-assert (listp (my/jieba-extract "人" 5))))

(deftest "single Latin letter"
  (cl-assert (equal (my/jieba-cut "a") '("a"))))

(deftest "single digit"
  (cl-assert (equal (my/jieba-cut "1") '("1"))))

(deftest "two Hanzi"
  (cl-assert (equal (my/jieba-cut "中国") '("中国"))))

(deftest "three Hanzi"
  (cl-assert (> (length (my/jieba-cut "三个人")) 0)))

;; ===================================================================
;; 3. Unicode / encoding boundaries
;; ===================================================================

(deftest "CJK Ext B (U+20000)"
  (let* ((cp #x20000)
         (c (string (decode-char 'ucs cp)))
         (r (my/jieba-cut c)))
    (cl-assert (equal r (list c)))))

(deftest "CJK Ext C (U+2A700)"
  (let* ((cp #x2A700)
         (c (string (decode-char 'ucs cp)))
         (r (my/jieba-cut c)))
    (cl-assert (equal r (list c)))))

(deftest "CJK Ext D (U+2B740)"
  (let* ((cp #x2B740)
         (c (string (decode-char 'ucs cp)))
         (r (my/jieba-cut c)))
    (cl-assert (equal r (list c)))))

(deftest "CJK Ext + basic mixed"
  (let* ((cext (string (decode-char 'ucs #x20000)))
         (text (concat cext "测试" cext))
         (r (my/jieba-cut text)))
    (cl-assert (= (length r) 3))))

(deftest "fullwidth Latin"
  (let ((r (my/jieba-cut "ＡＢＣ")))
    (cl-assert (= (length r) 3))))

(deftest "fullwidth digits"
  (let ((r (my/jieba-cut "１２３")))
    (cl-assert (= (length r) 3))))

(deftest "halfwidth + fullwidth mixed"
  (cl-assert (listp (my/jieba-cut "ABC１２３测试"))))

(deftest "zero-width space (U+200B)"
  (cl-assert (listp (my/jieba-cut (string #x200B ?测 ?试)))))

(deftest "zero-width joiner (U+200D)"
  (cl-assert (listp (my/jieba-cut (string #x200D ?测 ?试)))))

(deftest "BOM (U+FEFF)"
  (cl-assert (listp (my/jieba-cut (concat (string #xFEFF) "测试")))))

(deftest "lone surrogate must not crash"
  (cl-assert (listp (my/jieba-cut (string #xD800 #xDC00)))))

(deftest "Latin-1 supplement"
  (cl-assert (listp (my/jieba-cut "café résumé"))))

;; ===================================================================
;; 4. Special content types
;; ===================================================================

(deftest "pure English"
  (let ((r (my/jieba-cut "Hello World this is a test")))
    (cl-assert (member "Hello" r))))

(deftest "pure English extract"
  (cl-assert (listp (my/jieba-extract "Machine learning is cool" 3))))

(deftest "pure digits"
  (cl-assert (equal (my/jieba-cut "12345") '("12345"))))

(deftest "mixed Chinese-English no space"
  (cl-assert (listp (my/jieba-cut "我们使用PyTorch训练BERT模型"))))

(deftest "mixed Chinese English digits"
  (let ((r (my/jieba-cut "2024年5月20日")))
    (cl-assert (member "2024" r))))

(deftest "HTML tags mixed in"
  (let ((r (my/jieba-cut "这是一段<b>加粗</b>文本")))
    (cl-assert (member "加粗" r))))

(deftest "URL mixed in"
  (let ((r (my/jieba-cut "访问 https://github.com 获取信息")))
    (cl-assert (listp r))))

(deftest "email mixed in"
  (let ((r (my/jieba-cut "联系 user@example.com 获取信息")))
    (cl-assert (listp r))))

(deftest "JSON string"
  (let ((r (my/jieba-cut "{\"name\":\"张三\",\"age\":28}")))
    (cl-assert (member "张三" r))))

(deftest "emoji mixed in"
  (let ((r (my/jieba-cut "今天心情很好🎉明天继续💪加油")))
    (cl-assert (member "今天" r))
    (cl-assert (member "明天" r))))

(deftest "emoji only"
  (cl-assert (listp (my/jieba-cut "🎉🎊💪🔥👍"))))

(deftest "math symbols mixed"
  (cl-assert (listp (my/jieba-cut "当 x ∈ ℝ 且 y ≥ 0 时"))))

(deftest "Japanese kana mixed"
  (cl-assert (listp (my/jieba-cut "日本語のテスト"))))

(deftest "Korean hangul mixed"
  (cl-assert (listp (my/jieba-cut "한국어 테스트입니다"))))

;; ===================================================================
;; 5. top-n parameter boundary
;; ===================================================================

(deftest "extract top-n=0 (clamped to 1)"
  (cl-assert (>= (length (my/jieba-extract "测试文本" 0)) 1)))

(deftest "extract top-n=1"
  (cl-assert (= (length (my/jieba-extract "今天天气真好" 1)) 1)))

(deftest "extract top-n small"
  (cl-assert (<= (length (my/jieba-extract "我爱北京天安门" 2)) 2)))

(deftest "extract top-n huge (returns all)"
  (let ((kw (my/jieba-extract "测试" 9999)))
    (cl-assert (> (length kw) 0))
    (cl-assert (<= (length kw) 10))))

(deftest "extract top-n negative (clamped to 1)"
  (cl-assert (>= (length (my/jieba-extract "测试文本" -1)) 1)))

(deftest "extract top-n very negative"
  (cl-assert (>= (length (my/jieba-extract "测试文本" -999999999)) 1)))

(deftest "extract top-n most-positive-fixnum"
  (cl-assert (listp (my/jieba-extract "测试文本" most-positive-fixnum))))

;; ===================================================================
;; 6. Large text stress
;; ===================================================================

(deftest "stress: 100k Hanzi cut"
  (cl-assert (listp (my/jieba-cut (make-string 100000 ?测)))))

(deftest "stress: 100k Hanzi extract"
  (cl-assert (listp (my/jieba-extract (make-string 100000 ?测) 10))))

(deftest "stress: 200k mixed chars cut"
  (cl-assert (listp (my/jieba-cut (concat (make-string 50000 ?中)
                                           (make-string 50000 ?国)
                                           (make-string 50000 ?文)
                                           (make-string 50000 ?测))))))

(deftest "stress: 5k tag"
  (cl-assert (listp (my/jieba-tag (make-string 5000 ?文)))))

(deftest "stress: 10k mixed charset tag"
  (cl-assert (listp (my/jieba-tag (concat (make-string 3000 ?文)
                                           (make-string 3000 ?a)
                                           (make-string 3000 ?1))))))

;; ===================================================================
;; 7. Stability & memory safety
;; ===================================================================

(deftest "stability: 10000 cut calls"
  (dotimes (_ 10000)
    (my/jieba-cut "南京市长江大桥北京清华大学"))
  t)

(deftest "stability: 10000 extract calls"
  (dotimes (_ 10000)
    (my/jieba-extract "自然语言处理人工智能" 5))
  t)

(deftest "stability: 5000 tag calls"
  (dotimes (_ 5000)
    (my/jieba-tag "我爱北京天安门"))
  t)

(deftest "stability: 2000 interleaved cut/extract/tag"
  (dotimes (_ 2000)
    (my/jieba-cut "测试文本")
    (my/jieba-extract "测试文本" 3)
    (my/jieba-tag "测试文本"))
  t)

(deftest "stability: 3000 variable-length texts"
  (dotimes (i 3000)
    (my/jieba-cut (make-string (1+ (random 1000)) ?测)))
  t)

(deftest "stability: 1000 extract different top-n"
  (dotimes (i 1000)
    (my/jieba-extract "测试文本" (1+ (random 20))))
  t)

(deftest "stability: 20000 short burst"
  (dotimes (_ 20000)
    (my/jieba-cut "a"))
  t)

(deftest "stability: 5000 multi-text round-robin"
  (let ((texts '("我爱北京天安门"
                 "南京市长江大桥"
                 "Machine learning with PyTorch"
                 "")))
    (dotimes (_ 5000)
      (dolist (txt texts)
        (my/jieba-cut txt)
        (when (> (length txt) 0)
          (my/jieba-extract txt 5)
          (my/jieba-tag txt)))))
  t)

;; ===================================================================
;; 8. Return value structure validation
;; ===================================================================

(deftest "cut result: all strings"
  (dolist (w (my/jieba-cut "我爱北京天安门"))
    (cl-assert (stringp w))))

(deftest "extract result: weights descending"
  (let* ((text "自然语言处理与人工智能机器学习密切相关")
         (kw (my/jieba-extract text 10)))
    (when (> (length kw) 1)
      (let ((prev (cdar kw)))
        (dolist (pair (cdr kw))
          (cl-assert (>= prev (cdr pair)))
          (setq prev (cdr pair)))))))

(deftest "extract result: weight > 0"
  (dolist (pair (my/jieba-extract "测试文本" 5))
    (cl-assert (> (cdr pair) 0.0))))

(deftest "extract result: word not empty"
  (dolist (pair (my/jieba-extract "测试文本" 5))
    (cl-assert (> (length (car pair)) 0))))

(deftest "tag result: all (string . string) pairs"
  (dolist (pair (my/jieba-tag "我爱北京天安门"))
    (cl-assert (stringp (car pair)))
    (cl-assert (stringp (cdr pair)))
    (cl-assert (> (length (cdr pair)) 0))))

(deftest "tag POS tag non-empty"
  (dolist (pair (my/jieba-tag "测试文本"))
    (cl-assert (> (length (cdr pair)) 0))))

;; ===================================================================
;; 9. Determinism (same input => same output)
;; ===================================================================

(deftest "determinism: cut 10x identical"
  (let* ((text "南京市长江大桥")
         (baseline (my/jieba-cut text)))
    (dotimes (_ 10)
      (cl-assert (equal baseline (my/jieba-cut text))))))

(deftest "determinism: extract 10x identical"
  (let* ((text "自然语言处理机器学习")
         (baseline (my/jieba-extract text 5)))
    (dotimes (_ 10)
      (cl-assert (equal baseline (my/jieba-extract text 5))))))

(deftest "determinism: tag 10x identical"
  (let* ((text "我爱北京天安门")
         (baseline (my/jieba-tag text)))
    (dotimes (_ 10)
      (cl-assert (equal baseline (my/jieba-tag text))))))

;; ===================================================================
;; 10. Denote note scenarios
;; ===================================================================

(deftest "Denote: org-mode metadata + body extract"
  (cl-assert (listp (my/jieba-extract "#+title: Machine Learning Notes
#+date: 2024-06-01
Supervised learning includes linear regression and SVM." 5))))

(deftest "Denote: markdown headings"
  (cl-assert (listp (my/jieba-extract "# NLP\n\n## Tokenization\nJieba is widely used." 5))))

(deftest "Denote: front-matter only"
  (cl-assert (listp (my/jieba-extract "#+title: Test Note" 5))))

(deftest "Denote: Chinese-English mixed title"
  (cl-assert (listp (my/jieba-extract "Using PyTorch to implement Transformer" 5))))

(deftest "Denote: filetags field"
  (cl-assert (listp (my/jieba-extract "#+filetags: :Emacs:Chinese:NoteTaking:" 5))))

;; ===================================================================
;; 11. Idempotent init
;; ===================================================================

(deftest "repeated init returns t"
  (cl-assert (my/jieba-init))
  (cl-assert (my/jieba-init)))

;; ===================================================================
;; 12. Smoke test: real-world text quality
;; ===================================================================

(deftest "smoke: Tang poem"
  (let ((r (my/jieba-cut "床前明月光疑是地上霜举头望明月低头思故乡")))
    (cl-assert (member "故乡" r))
    (message "    唐诗词: %s" (string-join r " / "))))

(deftest "smoke: classical Chinese"
  (let ((r (my/jieba-cut "话说天下大势分久必合合久必分")))
    (cl-assert (member "天下" r))))

(deftest "smoke: idioms"
  (let ((r (my/jieba-cut "胸有成竹")))
    (cl-assert (member "胸有成竹" r))))

(deftest "smoke: person + institution names"
  (let ((r (my/jieba-cut "李华毕业于北京大学计算机系")))
    (cl-assert (member "李华" r))
    (cl-assert (member "北京大学" r))))

(deftest "smoke: finance text extract"
  (cl-assert (listp (my/jieba-extract "沪深两市成交量突破万亿大关" 5))))

(deftest "smoke: tech news extract"
  (cl-assert (listp (my/jieba-extract "OpenAI 发布 GPT-5 模型" 5))))

;; ===================================================================
;; 13. Weight sanity: rare > common in long text
;; ===================================================================

(deftest "weight: rare terms rank above common terms (diagnostic)"
  (let* ((text (concat "在自然语言处理中变压器模型被广泛应用。"
                        "注意力机制发挥了关键作用。"
                        "反向传播算法用于训练神经网络。"
                        "正则化技术防止过拟合。"
                        "常见词常见词常见词常见词常见词常见词。"))
         (kw (my/jieba-extract text 15)))
    (message "    TF-IDF 关键词排名: %s" kw)
    (cl-assert (listp kw))
    (when (>= (length kw) 2)
      (let ((prev (cdar kw)))
        (dolist (pair (cdr kw))
          (cl-assert (>= prev (cdr pair)) nil "权重不单调: %s" kw)
          (setq prev (cdr pair)))))))

;; ===================================================================
;; 14. Extreme/malicious input safety
;; ===================================================================

(deftest "safety: ASCII control chars 0x00-0x1F"
  (cl-assert (listp (my/jieba-cut (apply #'string (cl-loop for c from 0 to 31 collect c))))))

(deftest "safety: DEL character"
  (cl-assert (listp (my/jieba-cut (string #x7F)))))

(deftest "safety: null bytes in string"
  (cl-assert (listp (my/jieba-cut "abc\000def\000ghi"))))

(deftest "safety: repeated null bytes"
  (cl-assert (listp (my/jieba-cut (concat "测试" (make-string 100 0) "文本")))))

(deftest "safety: 5000-char single word"
  (let ((word (make-string 5000 ?a)))
    (cl-assert (equal (my/jieba-cut word) (list word)))))

(deftest "safety: 10000-char single Hanzi run"
  (cl-assert (listp (my/jieba-cut (make-string 10000 ?中)))))

(deftest "safety: all zero bytes"
  (cl-assert (listp (my/jieba-cut (make-string 1000 0)))))

(deftest "safety: HTML+JS+JSON+emoji hodgepodge"
  (let ((mess "<html><body><script>alert('hi🎉')</script><p>JSON: {\"name\":\"张三\"}</p></body></html>"))
    (cl-assert (listp (my/jieba-cut mess)))))

(deftest "safety: code comment"
  (let ((code "// calculate Fibonacci\nfn fib(n: u32) -> u32 { match n { 0 => 1, 1 => 1, _ => fib(n-1) + fib(n-2) } }"))
    (cl-assert (listp (my/jieba-cut code)))))

(deftest "safety: LaTeX formula"
  (let ((latex "Let $f(x) = \\int_{-\\infty}^{\\infty} e^{-x^2} dx$, then $f(x) = \\sqrt{\\pi}$"))
    (cl-assert (listp (my/jieba-cut latex)))))

(deftest "safety: URL-encoded string"
  (let ((encoded "https://example.com/search?q=%E6%B5%8B%E8%AF%95&page=1"))
    (cl-assert (listp (my/jieba-cut encoded)))))

(deftest "safety: academic paper title"
  (let ((title "End-to-End Speech Recognition based on Attention Mechanism"))
    (cl-assert (listp (my/jieba-extract title 5)))))

;; ===================================================================
;; Summary
;; ===================================================================

(message "")
(if (= jt-fail 0)
    (message "=== All %d tests PASSED ===" jt-count)
  (message "=== %d/%d passed, %d FAILED ===" jt-pass jt-count jt-fail))
(kill-emacs jt-fail)
