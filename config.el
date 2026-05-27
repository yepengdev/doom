;;; $DOOMDIR/config.el -*- lexical-binding: t; -*-

;; Place your private configuration here! Remember, you do not need to run 'doom
;; sync' after modifying this file!

;; Some functionality uses this to identify you, e.g. GPG configuration, email
;; clients, file templates and snippets. It is optional.
;; (setq user-full-name "John Doe"
;;       user-mail-address "john@doe.com")

;; Doom exposes five (optional) variables for controlling fonts in Doom:
;;
;; - `doom-font' -- the primary font to use
;; - `doom-variable-pitch-font' -- a non-monospace font (where applicable)
;; - `doom-big-font' -- used for `doom-big-font-mode'; use this for
;;   presentations or streaming.
;; - `doom-symbol-font' -- for symbols
;; - `doom-serif-font' -- for the `fixed-pitch-serif' face
;;
;; See 'C-h v doom-font' for documentation and more examples of what they
;; accept. For example:
;;
;;(setq doom-font (font-spec :family "Fira Code" :size 12 :weight 'semi-light)
;;      doom-variable-pitch-font (font-spec :family "Fira Sans" :size 13))
;;
;; 英文默认字体
;; (setq doom-font (font-spec :family "Monaspace Neon" :size 15))

;; ;; 中文单独覆盖
;; (set-fontset-font t 'han (font-spec :family "LXGW WenKai Mono Screen" :size 16))


(defun my/apply-fonts (&optional frame)
  "Apply fonts when a graphical frame is created."
  (when (display-graphic-p frame)
    ;; 英文默认
    (setq doom-font (font-spec :family "Monaspace Neon" :size 15))
    (setq doom-variable-pitch-font (font-spec :family "Monaspace Neon" :size 16))
    ;; 中文覆盖
    (set-fontset-font t 'han (font-spec :family "LXGW WenKai Mono Screen" :size 16))
    ;; 只在有主题功能时才刷新字体
    (when (fboundp 'doom/reload-font)
      (doom/reload-font))))

;; 两个场景都只靠这个函数
(add-hook 'after-init-hook #'my/apply-fonts)
(add-hook 'server-after-make-frame-hook #'my/apply-fonts)

;; If you or Emacs can't find your font, use 'M-x describe-font' to look them
;; up, `M-x eval-region' to execute elisp code, and 'M-x doom/reload-font' to
;; refresh your font settings. If Emacs still can't find your font, it likely
;; wasn't installed correctly. Font issues are rarely Doom issues!

;;There are two ways to load a theme. Both assume the theme is installed and
;; available. You can either set `doom-theme' or manually load a theme with the
;; `load-theme' function. This is the default:
(setq doom-theme 'doom-one)

;; This determines the style of line numbers in effect. If set to `nil', line
;; numbers are disabled. For relative line numbers, set this to `relative'.
(setq display-line-numbers-type 'relative)

;; If you use `org' and don't want your org files in the default location below,
;; change `org-directory'. It must be set before org loads!
(setq org-directory "~/org/")


;; Whenever you reconfigure a package, make sure to wrap your config in an
;; `with-eval-after-load' block, otherwise Doom's defaults may override your
;; settings. E.g.
;;
;;   (with-eval-after-load 'PACKAGE
;;     (setq x y))
;;
;; The exceptions to this rule:
;;
;;   - Setting file/directory variables (like `org-directory')
;;   - Setting variables which explicitly tell you to set them before their
;;     package is loaded (see 'C-h v VARIABLE' to look them up).
;;   - Setting doom variables (which start with 'doom-' or '+').
;;
;; Here are some additional functions/macros that will help you configure Doom.
;;
;; - `load!' for loading external *.el files relative to this one
;; - `add-load-path!' for adding directories to the `load-path', relative to
;;   this file. Emacs searches the `load-path' when you load packages with
;;   `require' or `use-package'.
;; - `map!' for binding new keys
;;
;; To get information about any of these functions/macros, move the cursor over
;; the highlighted symbol at press 'K' (non-evil users must press 'C-c c k').
;; This will open documentation for it, including demos of how they are used.
;; Alternatively, use `C-h o' to look up a symbol (functions, variables, faces,
;; etc).
;;
;; You can also try 'gd' (or 'C-c c d') to jump to their definition and see how
;; they are implemented.
;; -*- mode: elisp; -*-

;; Scratch buffer 使用 text-mode（纯文本，适合记临时笔记）
(setq initial-major-mode 'text-mode)

(setq auto-save-timeout 30)      ; 空闲多少秒后自动保存，默认 30
(setq auto-save-interval 300)    ; 输入多少个字符后自动保存，默认 300

(setq deft-directory "~/notes"
      deft-recursive t)

(setq confirm-kill-emacs nil)        ; 不额外确认

(setq org-noter-notes-search-path '("~/notes/annotations"))  ; 笔记保存位置

;; 也可以保留原来的 find-file-hook 但加上 idle
(add-hook 'find-file-hook
          (lambda ()
            (run-with-idle-timer 0.5 nil
                                 (lambda ()
                                   (when (and (featurep 'evil)
                                              (setq fcitx-remote-command
                                                    (or (executable-find "fcitx5-remote")
                                                        (executable-find "fcitx-remote"))))
                                     (require 'fcitx)
                                     (fcitx-evil-turn-on)))))
          'append)

(use-package! spacious-padding
  :defer t
  :custom (line-spacing 3)
  :init
  (defun my/enable-spacious-padding-later (&optional frame)
    (when (display-graphic-p frame)
      (run-with-idle-timer 0.1 nil #'spacious-padding-mode)))
  (if (daemonp)
      (add-hook 'server-after-make-frame-hook #'my/enable-spacious-padding-later)
    (add-hook 'after-init-hook #'my/enable-spacious-padding-later)))

(use-package! denote
  :defer t
  :commands (denote denote-date denote-find-link denote-link-or-create
                    denote-rename-file-keywords denote-rename-file
                    denote-rename-file-using-front-matter
                    denote-find-backlink)  ;; 将所有要绑定的命令列全
  :custom
  (denote-link-description-function "%t")

  (denote-directory (expand-file-name "~/Documents/notes"))
  (denote-known-keywords
   '("创作" "学习" "工作" "生活" "技术" "思考" "索引"))
  ;; (denote-sort-keywords t)
  ;; (denote-rename-buffer-mode 1)

  :init
  (map! :leader
        (:prefix-map ("r d" . "Denote")   ; 定义 SPC r d 为 "Denote" 菜单
         :desc "New note"          "n" #'denote
         :desc "Date note"         "d" #'denote-date
         :desc "Find link"         "l" #'denote-find-link
         :desc "Link or create"    "i" #'denote-link-or-create
         :desc "Rename keywords"   "k" #'denote-rename-file-keywords
         :desc "Rename file"       "r" #'denote-rename-file
         :desc "Rename front"      "R" #'denote-rename-file-using-front-matter
         :desc "Search notes"      "f" #'consult-notes
         :desc "Find backlinks"    "b" #'denote-find-backlink))
  )
;; 为了 consult-notes 工作，需要安装并配置它
(use-package! consult-notes
  :defer t
  ;; :commands (consult-notes)
  :custom
  (consult-notes-denote-display-keywords-indicator "_")
  :config
  (consult-notes-denote-mode)
  ;; (consult-notes-org-roam-mode)
  ;; (consult-notes-org-headings-mode)
  )

(use-package! denote-org
  :after denote
  :config
  (map! :leader
        (:prefix-map ("r d" . "Denote")
         :desc "Link to heading"        "h" #'denote-org-link-to-heading)))

;; Denote 序列（如果需要系列笔记）
(use-package! denote-sequence
  :after denote
  :config
  (map! :leader
        (:prefix-map ("r d" . "Denote")
         :desc "New sequence"           "s" #'denote-sequence)))

;; 可选：Denote 探索与可视化
(use-package! denote-explore
  :after denote
  :config
  (map! :leader
        (:prefix-map ("r d" . "Denote")
                     (:prefix-map ("e" . "Explore")
                      :desc "Count notes"            "c" #'denote-explore-count-notes
                      :desc "Count keywords"         "C" #'denote-explore-count-keywords
                      :desc "Random note"            "r" #'denote-explore-random-note
                      :desc "Random link"            "l" #'denote-explore-random-link
                      :desc "Knowledge network"      "n" #'denote-explore-network))))

(use-package! ox-latex
  :defer t
  :after ox
  :custom

  (org-latex-pdf-process
   '(
     "xelatex -interaction nonstopmode -output-directory %o %f"
     "bibtex %b"
     "xelatex -shell-escape -interaction nonstopmode -output-directory %o %f"
     "xelatex -shell-escape -interaction nonstopmode -output-directory %o %f"
     )
   (org-latex-logfiles-extensions
    '("lof" "lot" "tex~" "aux" "idx" "log" "out"
      "toc" "nav" "snm" "vrb" "dvi" "fdb_latexmk"
      "blg" "brf" "fls" "entoc" "ps" "spl" "bbl"
      "tex" "bcf"))
   (org-latex-default-packages-alist
    (remove '("AUTO" "inputenc" t) org-latex-default-packages-alist)))  ; 移除 inputenc，避免冲突
  ;; 使用 xelatex 以支持中文
  ;; 添加 xeCJK 支持
  ;; (add-to-list 'org-latex-packages-alist '("" "xeCJK" t))
  ;; 设置默认中文字体（可在文档头部覆盖）
  :config
  ;; 如果你希望保留 EWS 的平装本样式，可以加入（改为 xelatex 中文版）
  ;;   (setq org-latex-classes nil)  ;; 清空默认，避免冲突（可选）
  (setq org-latex-classes nil)  ;; 清空默认，避免冲突（可选）
  (add-to-list 'org-latex-classes
               '("elegantbook"
                 "\\documentclass[fontsize=10pt,paper=a4,twoside=true,lang=cn]{elegantbook}
\\usepackage{xeCJK}                         % 中文支持
%\\setCJKmainfont{Noto Serif CJK SC}        % 改成你的中文字体
%\\setmainfont{TeX Gyre Pagella}            % 可换
%\\setmonofont{JetBrains Mono}              % 可换
\\hypersetup{colorlinks=true}
\\usepackage{fvextra}
\\DefineVerbatimEnvironment{verbatim}{Verbatim}{
  breaklines=true,
  breakanywhere=true,
  breaksymbol={},
  breakautoindent=false
}
% ===== 代码高亮 =====
\\usepackage{minted}
\\setminted{
  fontsize=\\footnotesize,
  linenos,
  breaklines,
  frame=leftline,
  framesep=2mm
}

[NO-DEFAULT-PACKAGES]
[NO-PACKAGES]"
                 ("\\chapter{%s}" . "\\chapter*{%s}")
                 ("\\section{%s}" . "\\section*{%s}")
                 ("\\subsection{%s}" . "\\subsection*{%s}")))
  (setq org-latex-default-class "elegantbook")
  )


(after! pdf-tools
  (setq pdf-view-display-size 'fit-page
        pdf-view-resize-factor 1.1
        pdf-annot-activate-created-annotations t)

  ;; 如果你喜欢夜间模式
  ;; (pdf-view-midnight-minor-mode)
  (add-hook 'pdf-view-mode-hook #'pdf-view-roll-minor-mode)
  (setq pdf-view-use-scaling t
        pdf-view-use-imagemagick nil) ; 通常不需要 imagemagick

  )

(after! org
  (add-to-list 'org-capture-templates
               '("w" "小说灵感" entry
                 (file+headline "~/org/novel-inbox.org" "灵感收件箱")  ; 改为你自己的文件路径
                 "* %^{灵感标题} :%^g\n  :PROPERTIES:\n  :CREATED: %U\n  :来源: %^{灵感来源}\n  :角色: %^{相关角色}\n  :情感: %^{情绪基调}\n  :备注: %^{其他备注}\n  :END:\n\n  %?\n  - 记录自：%a"
                 :prepend t
                 :empty-lines 1))

  )

(use-package! olivetti
  :defer t
  :init
  (add-hook 'org-mode-hook #'olivetti-mode)

  :config
  (define-key olivetti-mode-map (kbd "C-c |") nil)

  (setq olivetti-body-width 100)                ; 适合中文 35~40 字/行
  ;; 打开 Org 文件时自动进入专注模式
  (add-hook 'olivetti-mode-on-hook (lambda () (display-line-numbers-mode -1)))
  (add-hook 'olivetti-mode-off-hook (lambda () (display-line-numbers-mode 1)))
  (setq olivetti-hide-mode-line t)
  )          ; 手动开关

(use-package! super-save
  :hook (after-init . super-save-mode)
  :config
  (super-save-mode +1)
  (setq super-save-auto-save-when-idle t
        super-save-silent t)
  (setq super-save-when-focus-lost nil)

  ;; disable saving on buffer/window switch
  (setq super-save-when-buffer-switched nil)
  ;; 保存时清理所有行尾空格
  (setq super-save-delete-trailing-whitespace t)
  ;; 或者，只清理非当前行的行尾空格
  (setq super-save-delete-trailing-whitespace 'except-current-line)

  )
;; 在 ~/.config/doom/config.el 或相应模块中
(use-package! flycheck-package
  :defer t
  :config
  (flycheck-package-setup))

(use-package! expand-region
  :defer t
  :commands (er/expand-region))

(use-package! embrace
  :defer t
  :commands (embrace-add-pair embrace-remove-pair embrace-add-pair-for-mode))
(use-package! evil-easymotion
  :defer t
  :commands (evilem-create evilem-default-keybindings))

;; Stop benchmark-init after init is done (report via M-x benchmark-init/show-durations-tabulated)
(add-hook 'after-init-hook #'benchmark-init/deactivate)
