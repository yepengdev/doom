;;; dyncall-test.el --- 测试套件：dyncall C 模块              -*- lexical-binding: t; -*-

;; 运行： emacs -Q --batch -l tests-bench/dyncall-test.el
;; 依赖： c-modules/dyncall.so（需先 make -C c-modules/）

(require 'cl-lib)

(let* ((script-dir (file-name-directory (or load-file-name buffer-file-name)))
       (doom-dir  (expand-file-name ".." script-dir))
       (so-path   (expand-file-name "c-modules/dyncall.so" doom-dir)))
  (unless (file-exists-p so-path)
     (error "dyncall.so 不存在于 %s，先执行 make -C c-modules/" so-path))
  (module-load so-path))

(defvar dyncall-test-count 0)
(defvar dyncall-test-pass 0)
(defvar dyncall-test-fail 0)

(defmacro deftest (name &rest body)
  (declare (indent 1))
  `(let ((name ,name))
     (setq dyncall-test-count (1+ dyncall-test-count))
     (condition-case e
         (progn ,@body
                (setq dyncall-test-pass (1+ dyncall-test-pass))
                (message "  ✅ %s" name))
       (error
        (setq dyncall-test-fail (1+ dyncall-test-fail))
        (message "  ❌ %s: %s" name (error-message-string e))))))

(message "")
(message "═══ dyncall 测试套件 ═══")

(deftest "getpid（无参，int 返回）"
  (let ((pid (dyncall nil "getpid" :int)))
    (cl-assert (and (integerp pid) (> pid 0)))))

(deftest "sqrt（double 参，double 返回）"
  (cl-assert (= (dyncall "libm.so.6" "sqrt" :double :double 4.0) 2.0)))

(deftest "tgamma（load+sym+call 三步模式）"
  (let* ((lib (dyncall-load "libm.so.6"))
         (fn (dyncall-sym lib "tgamma"))
         (r (dyncall-call fn :double :double 5.0)))
    (dyncall-close lib)
    (cl-assert (= r 24.0))))

(deftest "pow（多参数）"
  (cl-assert (= (dyncall "libm.so.6" "pow" :double :double 2.0 :double 10.0)
                1024.0)))

(deftest "strcmp（字符串参数，int 返回）"
  (cl-assert (= (dyncall nil "strcmp" :int :string "a" :string "a") 0))
  (cl-assert (/= (dyncall nil "strcmp" :int :string "a" :string "b") 0)))

(deftest "strlen（字符串参数）"
  (cl-assert (= (dyncall nil "strlen" :int :string "hello") 5))
  (cl-assert (= (dyncall nil "strlen" :int :string "") 0)))

(deftest "cos / sin / floor（多个数学函数）"
  (cl-assert (= (dyncall "libm.so.6" "cos" :double :double 0.0) 1.0))
  (cl-assert (= (dyncall "libm.so.6" "sin" :double :double 0.0) 0.0))
  (cl-assert (= (dyncall "libm.so.6" "floor" :double :double 3.14) 3.0)))

(deftest "uint / long 类型"
  (cl-assert (integerp (dyncall nil "getuid" :uint)))
  (cl-assert (integerp (dyncall nil "getpid" :long))))

(deftest "多次调用无状态泄漏"
  (dotimes (_ 100)
    (dyncall "libm.so.6" "sqrt" :double :double 2.0))
  t)

(deftest "dyncall-load nil → RTLD_DEFAULT"
  (let ((lib (dyncall-load nil)))
    (cl-assert (eq (type-of lib) 'user-ptr))))

(deftest "dyncall-close 后可重新加载"
  (let ((lib (dyncall-load "libm.so.6")))
    (dyncall-close lib))
  (let ((lib (dyncall-load "libm.so.6")))
    (cl-assert (eq (type-of lib) 'user-ptr))
    (dyncall-close lib)))

(deftest "dyncall-call 返回 int 类型的多种宽度"
  (cl-assert (integerp (dyncall nil "getppid" :int)))
  (cl-assert (integerp (dyncall nil "getuid" :int)))
  (cl-assert (integerp (dyncall nil "getgid" :int))))

(message "")
(if (= dyncall-test-fail 0)
    (message "═══ 全部 %d 个测试通过 ═══" dyncall-test-count)
  (message "═══ %d/%d 通过，%d 失败 ═══"
           dyncall-test-pass dyncall-test-count dyncall-test-fail))
(kill-emacs dyncall-test-fail)
