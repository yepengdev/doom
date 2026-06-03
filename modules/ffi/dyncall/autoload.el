;;; modules/ffi/dyncall/autoload.el -*- lexical-binding: t; -*-

;; ─── 缓存句柄（dlsym 结果，避免重复 dlopen）────────────

(defvar +dyncall--libc nil "缓存 libc 句柄（RTLD_DEFAULT）")
(defvar +dyncall--libm nil "缓存 libm.so.6 句柄")

;;;###autoload
(defun +dyncall-libc ()
  (unless +dyncall--libc
    (setq +dyncall--libc (dyncall-load nil)))
  +dyncall--libc)

;;;###autoload
(defun +dyncall-libm ()
  (unless +dyncall--libm
    (setq +dyncall--libm (dyncall-load "libm.so.6")))
  +dyncall--libm)

;;;###autoload
(defun +dyncall-sym-libc (name)
  (dyncall-sym (+dyncall-libc) name))

;;;###autoload
(defun +dyncall-sym-libm (name)
  (dyncall-sym (+dyncall-libm) name))

;; ── 进程 / 系统 ────────────────────────────────────────

;;;###autoload
(defun +dyncall-pid () (dyncall-call (+dyncall-sym-libc "getpid")  :int))

;;;###autoload
(defun +dyncall-ppid () (dyncall-call (+dyncall-sym-libc "getppid") :int))

;;;###autoload
(defun +dyncall-uid () (dyncall-call (+dyncall-sym-libc "getuid")  :int))

;;;###autoload
(defun +dyncall-gid () (dyncall-call (+dyncall-sym-libc "getgid")  :int))

;; ── 数学 ───────────────────────────────────────────────

;;;###autoload
(defun +dyncall-sqrt (x)
  (dyncall-call (+dyncall-sym-libm "sqrt") :double :double x))

;;;###autoload
(defun +dyncall-pow (x y)
  (dyncall-call (+dyncall-sym-libm "pow") :double :double x :double y))

;;;###autoload
(defun +dyncall-exp (x)
  (dyncall-call (+dyncall-sym-libm "exp") :double :double x))

;;;###autoload
(defun +dyncall-log (x)
  (dyncall-call (+dyncall-sym-libm "log") :double :double x))

;;;###autoload
(defun +dyncall-log10 (x)
  (dyncall-call (+dyncall-sym-libm "log10") :double :double x))

;;;###autoload
(defun +dyncall-sin (x)
  (dyncall-call (+dyncall-sym-libm "sin") :double :double x))

;;;###autoload
(defun +dyncall-cos (x)
  (dyncall-call (+dyncall-sym-libm "cos") :double :double x))

;;;###autoload
(defun +dyncall-tan (x)
  (dyncall-call (+dyncall-sym-libm "tan") :double :double x))

;;;###autoload
(defun +dyncall-floor (x)
  (dyncall-call (+dyncall-sym-libm "floor") :double :double x))

;;;###autoload
(defun +dyncall-ceil (x)
  (dyncall-call (+dyncall-sym-libm "ceil") :double :double x))

;;;###autoload
(defun +dyncall-round (x)
  (dyncall-call (+dyncall-sym-libm "round") :double :double x))

;;;###autoload
(defun +dyncall-abs (x)
  (dyncall-call (+dyncall-sym-libm "fabs") :double :double x))

;;;###autoload
(defun +dyncall-erf (x)
  (dyncall-call (+dyncall-sym-libm "erf") :double :double x))

;; ── 字符串 ─────────────────────────────────────────────

;;;###autoload
(defun +dyncall-strcmp (a b)
  (dyncall-call (+dyncall-sym-libc "strcmp") :int :string a :string b))

;;;###autoload
(defun +dyncall-strcasecmp (a b)
  (dyncall-call (+dyncall-sym-libc "strcasecmp") :int :string a :string b))

;; ── 演示 ───────────────────────────────────────────────

;;;###autoload
(defun +dyncall-demo ()
  (interactive)
  (message "PID=%d  PPID=%d  UID=%d  GID=%d"
           (+dyncall-pid) (+dyncall-ppid) (+dyncall-uid) (+dyncall-gid))
  (message "sqrt(2)=%.6f  erf(1)=%.6f  e^π=%.6f"
           (+dyncall-sqrt 2) (+dyncall-erf 1)
           (+dyncall-exp (+dyncall-sqrt (+dyncall-pow 3.14159 2))))
  (message "strcmp(a,a)=%d  strcasecmp(A,a)=%d"
           (+dyncall-strcmp "a" "a") (+dyncall-strcasecmp "A" "a")))
