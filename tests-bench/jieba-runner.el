;;; jieba-runner.el --- run all jieba tests (original + supplement)

(require 'cl-lib)

(let* ((script-dir (file-name-directory
                    (or (and load-in-progress load-file-name)
                        buffer-file-name
                        default-directory)))
       (doom-dir  (expand-file-name ".." script-dir))
       (so-path   (expand-file-name "c-modules/jieba-module.so" doom-dir))
       (dict-dir  (expand-file-name "c-modules/cjieba/dict" doom-dir)))
  (module-load so-path)
  (my/jieba-init dict-dir))

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

;; Load original tests, intercepting kill-emacs
(defun jt--suppress-kill (&rest _) (message "  (kill-emacs suppressed)"))
(advice-add 'kill-emacs :override #'jt--suppress-kill)
(load (expand-file-name "jieba-test.el"
       (file-name-directory (or (and load-in-progress load-file-name) buffer-file-name default-directory)))
      nil 'nomessage)
(advice-remove 'kill-emacs #'jt--suppress-kill)
(setq jt-count 0 jt-pass 0 jt-fail 0)

;; Load supplementary tests
(load (expand-file-name "jieba-extreme-supplement.el"
       (file-name-directory (or (and load-in-progress load-file-name) buffer-file-name default-directory)))
      nil 'nomessage)

(message "")
(if (= jt-fail 0)
    (message "=== Combined: ALL %d tests PASSED ===" jt-count)
  (message "=== Combined: %d/%d passed, %d FAILED ===" jt-pass jt-count jt-fail))
(kill-emacs jt-fail)
