;;; modules/ffi/dyncall/doctor.el

(let ((so-path (expand-file-name "c-modules/dyncall.so" doom-user-dir)))
  (unless (file-exists-p so-path)
    (warn! "dyncall.so 未编译。在 ~/.config/doom/c-modules 下执行 make 即可编译")))

(unless (with-temp-buffer
          (equal (call-process "pkg-config" nil t nil "--exists" "libffi") 0))
  (warn! "系统缺少 libffi 库。安装： sudo pacman -S libffi 或 sudo apt install libffi-dev"))

(unless (executable-find "gcc")
  (warn! "需要 gcc 编译 dyncall.so（以及 emacs-module.h）"))
