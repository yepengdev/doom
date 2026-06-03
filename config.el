;;; $DOOMDIR/config.el -*- lexical-binding: t; -*-
;;;
;;; Doom Emacs 个人配置 — 在模块（自动加载及包）就绪后加载。
;;; 此处所有更改只需 `M-x doom/reload`（或 `M-x my/doom-full-reload`，
;;; 后者还会重新加载自动加载/包/主题/字体）；无需 `doom sync`，
;;; 除非修改了 `packages.el` 或 `init.el`。
;;;

;; ═══════════════════════════════════════════════════════════════════════════
;; Git 代理（受限网络）
;; ═══════════════════════════════════════════════════════════════════════════
;;
;; `doom-gitconfig` 包装 git(1)，将所有 GitHub HTTPS 请求路由到
;; gh-proxy.com。在 GFW 或任何屏蔽原始 github.com 的防火墙后需要此配置。
;; 环境变量由 Doom 的 git 包装器读取；实际的 gitconfig 文件存放在
;; 本目录的 `doom-gitconfig` 中。
;;
(setenv "DOOMGITCONFIG"
        (expand-file-name "doom-gitconfig" doom-user-dir))


;; ═══════════════════════════════════════════════════════════════════════════
;; UI
;; ═══════════════════════════════════════════════════════════════════════════

;; ─── 字体 ────────────────────────────────────────────────────────────────
;;
;; 主字体：Monaspace Neon 16pt — 专为代码可读性设计，字母形状清晰
;;（无混淆的 1/l/I）。变量宽字体也使用同一字体（Monaspace 有精心调校的
;; 斜体/正体对），使散文与代码在视觉上不冲突。
;;
;; CJK 后备字体：LXGW WenKai Mono Screen — 等宽中文字体，其 x 高度和
;; 字重接近 Monaspace Neon，在拉丁字母与 CJK 字形交错时保持视觉节奏。
;;
;; 字号 16 在现代高 DPI 显示器上平衡了舒适度（14pt 太挤）与屏幕空间
;;（18pt 浪费水平空间）。
;;
(after! doom-ui
  (setq doom-font (font-spec :family "Monaspace Neon" :size 15)
        doom-variable-pitch-font (font-spec :family "Monaspace Neon" :size 15))
  (set-fontset-font t 'han (font-spec :family "LXGW WenKai Mono Screen" :size 15)))

;; ─── 自动切换主题（日/夜）─────────────────────────────────────────────
;;
;; 根据当前小时在 doom-one-light（日间）和 doom-tokyo-night（夜间）之间切换。
;; 为何使用小时而非日出/日落：
;;   - 日出 API 需要网络和地理位置配置；配置文件需要随处可用，这样做太脆弱。
;;   - 开发者的日程以办公桌为中心；7–19 覆盖典型工作日。
;;     可根据你的纬度/偏好调整这些常量。
;;
;; 切换在每次帧切换时执行，但 `unless (eq doom-theme ...)`
;; guard 使其在非切换时间（7:00/19:00）近乎零开销。
;; 持久挂在 hook 上确保即使在跨日夜边界的长时间会话中也能更新主题。
;;
(defconst my/theme-day 'doom-one-light
  "日间主题（7:00–18:59，包含起始，排除结束）。")

(defconst my/theme-night 'doom-tokyo-night
  "夜间主题（19:00–6:59）。深色背景减轻低光环境下的眼疲劳。")

(defconst my/theme-day-start 7
  "日间主题开始的小时（0–23）。按典型办公时间调整。")

(defconst my/theme-night-start 19
  "夜间主题开始的小时（0–23）。7–19 覆盖普通工作日。")

(defun my/theme-for-hour (&optional hour)
  "返回指定 HOUR（0–23，默认为当前本地时间）对应的主题常量。

纯函数 — 无状态、无副作用。从 `my/theme-switch-maybe' 抽取，
供调用者在不应用主题的情况下预览。"
  (let ((h (or hour (string-to-number (format-time-string "%H")))))
    (if (and (>= h my/theme-day-start) (< h my/theme-night-start))
        my/theme-day
      my/theme-night)))

(defun my/theme-apply (theme)
  "立即将 `doom-theme' 切换为 THEME，触发完整的 UI 重绘。
副作用：修改全局 `doom-theme' 变量并调用 `doom/reload-theme'，
会影响所有帧。"
  (setq doom-theme theme)
  (doom/reload-theme))

(defun my/theme-switch-maybe ()
  "检查当前小时，若与当前主题不同则切换日/夜主题。
挂在 `doom-switch-frame-hook' 上，使过渡（7:00/19:00）
即使在长时间运行的会话中也能被捕获。若主题已正确则为空操作。"
  (let ((theme (my/theme-for-hour)))
    (unless (eq doom-theme theme)
      (my/theme-apply theme))))

(setq doom-theme (my/theme-for-hour))
(add-hook 'doom-switch-frame-hook #'my/theme-switch-maybe 'append)

;; ─── 行号与自动保存 ─────────────────────────────────────────────────
;; 相对行号是 Evil/Vim 的惯例 — `j`/`k` 移动距离一目了然。
;; 当前行显示绝对编号，其他行显示相对编号是 Doom 默认行为；
;; `'relative` 保持此设置。散文为主的缓冲区中，olivetti 会完全禁用
;; 行号（参见下方 olivetti 配置）。
(setq display-line-numbers-type 'relative)

;; auto-save-timeout: 空闲活动秒数后自动保存。30s 足够短以防止崩溃时丢失大量工作，
;; 也足够长以批量处理快速编辑。
;; auto-save-interval: 按键次数间保存（双保险）。
(setq auto-save-timeout 30
      auto-save-interval 300)

;; ─── 宽松内边距（UI 呼吸空间）─────────────────────────────────────────
;;
;; 仅在第一个图形帧上启用 `spacious-padding-mode`。
;; `doom-switch-frame-hook` + 哨兵变量的模式确保此功能
;; 在 Emacs 守护进程中安全运行：如果 Emacs 在终端中启动，
;; 内边距模式在 GUI 帧出现前不会激活。
;;
(defvar my/enable-spacious-padding--done nil)

(defun my/enable-spacious-padding--fn (&optional _frame)
  "仅在第一个图形帧上启用 `spacious-padding-mode'。
激活后自动从 `doom-switch-frame-hook' 移除。若 Emacs 处于终端模式
（守护进程通过 emacsclient -t 启动），则为空操作。"
  (when (and (display-graphic-p)
             (not my/enable-spacious-padding--done))
    (setq my/enable-spacious-padding--done t)
    (remove-hook 'doom-switch-frame-hook #'my/enable-spacious-padding--fn)
    (spacious-padding-mode 1)))

(use-package! spacious-padding
  :commands spacious-padding-mode
  :init
  ;; line-spacing 3pt: 在现代高 DPI LCD 上有足够视觉呼吸空间
  ;; 而不浪费垂直空间（1pt 太挤，5pt+ 浪费空间）。
  (setq-default line-spacing 3)
  (add-hook 'doom-switch-frame-hook #'my/enable-spacious-padding--fn))


;; ═══════════════════════════════════════════════════════════════════════════
;; 编辑器
;; ═══════════════════════════════════════════════════════════════════════════

;; ─── Shell 与服务器基础 ────────────────────────────────────────────────
;;
;; `shell-file-name` → bash（而非用户的交互式 shell，可能为 zsh/fish）。
;; Emacs 的 `shell-command' 和编译模式依赖 POSIX sh 语法；fish 尤其不兼容。
;; 相比之下 `vterm-shell` 和 `explicit-shell-file-name' 特意使用 fish —
;; 那些是交互式且面向用户的。
;;
;; `confirm-kill-emacs`：守护模式下 `kill-emacs' 仅终止守护进程，
;; 对客户端无可见反馈。用户通过 `emacsclient` 交互，
;; 应使用 `save-buffers-kill-emacs'（`C-x C-c'）来提示未保存的缓冲区。
;; 设为 nil 是安全的，因为守护进程的 `kill-emacs' 在正常使用中很少
;; 被直接调用。
;;
;; `server-raise-frame t`：`emacsclient' 帧将 Emacs 窗口提升至
;; 窗口堆栈顶部。否则帧会创建但可能位于其他窗口后方，造成困惑。
;; `server-client-instructions nil`：抑制 "When done, type C-x #"
;; 回显 — 对有经验的用户来说是噪音。
;;
(setq confirm-kill-emacs nil)
(setq shell-file-name (executable-find "bash"))
(setq-default vterm-shell "/usr/bin/fish")
(setq-default explicit-shell-file-name "/usr/bin/fish")
(setq server-raise-frame t
      server-client-instructions nil)

;; ─── Magit ────────────────────────────────────────────────────────────────
;;
;; 禁用 hunk 精炼：大型差异对比中会带来明显延迟，且实际收益很小
;;（单词级差异高亮）。
;;
;; magit-diff-highlight-trailing t 是 Doom 默认值；保留此设置
;;（尾部空白不依赖上下文且高亮开销低）。
;;
(after! magit
  (setq magit-diff-refine-hunk nil))

;; ─── 写作工具 ────────────────────────────────────────────────────────
;;
;; Olivetti：在 org-mode 中居中书写。宽度 100（字符数）使行长
;; 在宽屏显示器上适合舒适阅读。隐藏模式行以减少散文缓冲区中的视觉噪音。
;;
(use-package! olivetti
  :hook (org-mode . olivetti-mode)
  :custom
  (olivetti-body-width 100)
  (olivetti-hide-mode-line t)
  :config
  (define-key olivetti-mode-map (kbd "C-c |") nil)
  (defvar-local my/olivetti--line-numbers-p nil
    "若在 olivetti 开启前行号已启用，则为非 nil。")

  (defun my/olivetti-toggle-line-numbers-h ()
    "在 olivetti-mode 中禁用行号；退出时恢复原始状态。
进入时将原始状态保存在 `my/olivetti--line-numbers-p' 中，退出时恢复。"
    (if olivetti-mode
        (setq my/olivetti--line-numbers-p (display-line-numbers-mode -1))
      (when my/olivetti--line-numbers-p
        (display-line-numbers-mode 1))))
  (add-hook 'olivetti-mode-hook #'my/olivetti-toggle-line-numbers-h))

;;
;; Super-save：在空闲时自动保存，而非在焦点/窗口切换事件时保存，
;; 这样在流程中干扰较小。保存时修剪尾部空白（当前行除外 —
;; 防止与光标位置冲突）。静默模式避免 mini-buffer 消息。
;;
(use-package! super-save
  :hook (doom-first-file . super-save-mode)
  :custom
  (super-save-auto-save-when-idle t)
  (super-save-silent t)
  (super-save-when-focus-lost nil)
  (super-save-when-buffer-switched nil)
  (super-save-delete-trailing-whitespace 'except-current-line)
  :config
  (add-to-list 'super-save-predicates
               (lambda () (not buffer-read-only))))

;; ─── Palimpsest（移动文本而不删除）───────────────────────────────────
;;
;; 移动文本 vs 删除：草稿过程中，文本常需暂时搁置而非丢弃。
;; Palimpsest 将区域移至缓冲区顶部/底部（在视野之外但仍在上下文中）
;; 或移至每个文件的回收文件。
;;
;; 在 org-mode 中绑定到 SPC m P（P = Palimpsest）：
;;   t — 移至顶部
;;   b — 移到底部
;;   T — 移至回收文件（<basename>.trash.<ext>）
;;
(use-package! palimpsest
  :hook (org-mode . palimpsest-mode)
  :config
  (map! :localleader
        :map org-mode-map
        :prefix ("P" . "Palimpsest")
        :desc "Move to top"    "t" #'palimpsest-move-region-to-top
        :desc "Move to bottom" "b" #'palimpsest-move-region-to-bottom
        :desc "Move to trash"  "T" #'palimpsest-move-region-to-trash))

;; ─── Evil Insert → 混合模式（Emacs 键位 + 竖线光标）───────────────
;;
;; 目标：`i` 进入插入状态，使用竖线光标和 Emacs 原生键位绑定
;;（C-w、C-a、C-e 等），同时保留 `evil-insert-state-map` 以使
;; 第三方包（evil-surround、evil-commentary 等）能正常注册
;; 插入模式绑定。
;;
;; 机制：用仅有 `<escape>` → 正常状态的稀疏键映射替换
;; `evil-insert-state-map`。其他所有按键回退到 Emacs 的
;; 全局键绑定系统。这产生了与 `evil-emacs-state` 相同的用户体验，
;; 但保持了 `evil-insert-state` 的身份不变。
;;
(after! evil
  (setq evil-insert-state-cursor 'bar)
  (setcdr evil-insert-state-map nil)
  (define-key evil-insert-state-map (kbd "<escape>") 'evil-normal-state))

;; ─── 全局键绑定 ──────────────────────────────────────────────────
;; M-! 运行 eshell 命令
(map! :g "M-!" #'eshell-command)


;; ═══════════════════════════════════════════════════════════════════════════
;; Org mode
;; ═══════════════════════════════════════════════════════════════════════════

;; 所有 Org 相关内容位于单个顶级目录下。
;; 这固定了 org-capture、org-agenda、denote、deft 和 org-noter 的路径 —
;; 更改它需要更新所有使用者。
(setq org-directory "~/org/")

;; org-noter 在此路径中搜索与 PDF/DJVU 文档关联的注释笔记。
;; 将注释放在专用子目录中避免主笔记池的混乱。
(setq org-noter-notes-search-path '("~/org/deft/annotations"))

(after! org
  ;; 自定义 TODO 工作流：DRAFT（写作）→ REVIEW（编辑）→ DONE / CANCELLED。
  ;; 第三个管道段 `|` 分隔激活与非激活关键词。
  (add-to-list 'org-todo-keywords
               '(sequence "DRAFT(R)" "REVIEW(r)" "|" "CANCELLED(C)") t)

  ;; 小说创意捕获模板 — 包含角色、情绪和来源追踪的元数据丰富的条目。
  ;; 使用 prepend 使最新的在最前面。
  (add-to-list 'org-capture-templates
               '("w" "Novel idea" entry
                 (file+headline "~/org/novel-inbox.org" "Inspiration inbox")
                 "* %^{Title} :%^g\n  :PROPERTIES:\n  :CREATED: %U\n  :Source: %^{Source}\n  :Character: %^{Character}\n  :Mood: %^{Mood}\n  :Notes: %^{Notes}\n  :END:\n\n  %?\n  - From: %a"
                 :prepend t
                 :empty-lines 1))

  ;; 隐藏 `=`、`*`、`~` 等标记 — 视觉上像渲染的标记，
  ;; 在写作时消除视觉噪音。字体化（斜体/粗体/等宽）仍然生效，
  ;; 因此格式仍然可见。
  (setq org-hide-emphasis-markers t)
  ;; 通过 OS 外部程序打开 `.html` / `.xhtml` 文件，而非 Emacs
  ;;（shr/eww）。HTML 内容应在浏览器中查看以获得正确的 CSS/JS。
  (add-to-list 'org-file-apps '("\\.x?html?\\'" . "xdg-open %s")))

;; ─── Org 捕获辅助 ───────────────────────────────────────────────────
(defun org-capture-goto-target (&optional template-key)
  "跳转到捕获模板的目标位置而不实际执行捕获。
在提交前预览捕获会落在哪里时很有用。"
  (interactive)
  (require 'org-capture)
  (let ((entry (org-capture-select-template template-key)))
    (unless entry (error "No capture template selected — use C-u to specify a template key"))
    (org-capture-set-plist entry)
    (org-capture-set-target-location)
    (pop-to-buffer-same-window (org-capture-get :buffer))
    (goto-char (org-capture-get :pos))))

;; ─── Pandoc docx 导出 ───────────────────────────────────────────────────
(defvar my/pandoc-dir (expand-file-name "pandoc" doom-user-dir)
  "Pandoc 参考 docx 和 Lua 过滤器所在的目录。")

(after! ox-pandoc
  ;; 设置 docx 导出的 Pandoc 选项 — 使用自定义模板。
  (setq org-pandoc-options-for-docx
        `((reference-doc . ,(expand-file-name
                             "templates/template_标题不编号-列表第二行顶格.docx"
                             my/pandoc-dir))
          (lua-filter . ,(expand-file-name "markdown-to-docx.lua" my/pandoc-dir)))))

;; ─── Org HTML 导出（本地极简主题）───────────────────────────────────
;;
;; 自定义 CSS — 不包含默认样式，零 JavaScript。CSS 文件
;; 位于 `org-export/minimal/css/` 中，提供干净的类打印布局。
;; 理由：默认的 org 导出 HTML 包含面向打印的全页样式 —
;; 在屏幕上查看时过于繁重且难以定制主题。
;;
(defvar my/org-export-assets-dir
  (expand-file-name "org-export/minimal" doom-user-dir)
  "包含 Org HTML 导出资源（CSS，无 JS）的目录。
由下方的 `ox-html' 配置引用。结构：
  org-export/minimal/css/org.css
  org-export/minimal/css/htmlize.css")

(after! ox-html
  (setq org-html-head-include-default-style nil)
  (let ((css-dir (expand-file-name "css" my/org-export-assets-dir)))
    (setq org-html-head
          (concat
           "<link rel=\"stylesheet\" type=\"text/css\" href=\"" css-dir "/org.css\"/>\n"
           "<link rel=\"stylesheet\" type=\"text/css\" href=\"" css-dir "/htmlize.css\"/>"))
    (setq org-html-head-extra "")))

;; ─── 外部链接打开 ────────────────────────────────────────────
;; browse-url: 通用链接（普通打开/org 链接）走 xdg-open 到默认浏览器。
(setq browse-url-browser-function #'browse-url-xdg-open)

;; +lookup/online（SPC s o）打开搜索 URL 后，自动将 niri 焦点切到浏览器。
;; 用法：结合 niri IPC（`niri msg --json windows`）按 app_id 查窗口 ID，
;; 然后用 `focus-window --id` 切换焦点，避免 Wayland 下 xdg-open 不自动
;; 弹到前台的问题。
(defun my/niri-focus-by-app-id (app-id)
  "Focus first niri window whose app_id matches APP-ID.
Uses `niri msg --json windows` parsed via jq, then `focus-window --id`."
  (call-process-shell-command
   (format "niri msg action focus-window --id $(niri msg --json windows | jq --arg a \"%s\" '.[] | select(.app_id==$a) | .id')" app-id)
   nil 0 nil))

(defun my/open-url-and-focus (url)
  "Open URL via xdg-open, then focus the browser with `my/niri-focus-by-app-id'.
Delays 0.4s for browser window to appear."
  (interactive (list (read-string "URL: ")))
  (let ((process-connection-type nil))
    (start-process "xdg-open" nil "xdg-open" url)
    (run-at-time 0.4 nil
      (lambda ()
        (my/niri-focus-by-app-id "brave-browser")))))
(setq +lookup-open-url-fn #'my/open-url-and-focus)

;; 扩展 +lookup/online 搜索引擎列表（追加到默认 Google/Wikipedia 等之后）。
(setq +lookup-provider-url-alist
      (append +lookup-provider-url-alist
              '(("Bing"      "https://www.bing.com/search?q=%s")
                ("Bilibili"  "https://search.bilibili.com/all?keyword=%s")
                ("Douyin"    "https://www.douyin.com/search/%s"))))

;; ─── 大型 Org 文件处理（≥1 MiB）────────────────────────────────────
;;
;; Org-mode 的装饰功能（org-modern、org-appear、org-indent、字体化、
;; prettify-symbols、variable-pitch）在大于 ~1 MiB 的文件中
;; 会导致明显的 UI 延迟。此 hook 在打开时检测过大的缓冲区，
;; 并移除所有装饰 — 用美观换取响应速度。阈值是一个启发式值；
;; 请根据你的机器调整 MY/ORG-LARGE-FILE-SIZE-THRESHOLD。
;;
(defvar my/org-large-file-size-threshold (* 1024 1024)
  "文件 >= 1 MiB 触发 `my/org-maybe-disable-prettification' 移除装饰。
1 MiB 是启发式值 — Org 的重绘成本随文件大小和美化复杂度扩展。
请根据机器调整。

参考：一个 ~600 KiB、约 5000 行、~50 个标题的 Org 文件在 2022 年
笔记本 CPU 上已可能出现数秒的 font-lock 暂停。")

(defun my/org-maybe-disable-prettification ()
  "对缓冲区 >= `my/org-large-file-size-threshold' 的 Org 文件禁用装饰模式。

从 `org-mode-hook' 调用。用美观换取滚动和输入的响应速度。
当超过阈值时无条件禁用以下功能：
  - org-modern、org-appear、org-indent（结构性覆盖层）
  - prettify-symbols（每次插入时的组成正则）
  - variable-pitch（混合字体拖慢重绘）
  - 额外字体化（TODO 面、优先级面、强调标记）"
  (when-let ((attrs (and buffer-file-name
                         (not (file-remote-p buffer-file-name))
                         (file-attributes buffer-file-name))))
    (when (> (file-attribute-size attrs) my/org-large-file-size-threshold)
      (when (bound-and-true-p org-modern-mode) (org-modern-mode -1))
      (when (bound-and-true-p org-appear-mode) (org-appear-mode -1))
      (when (bound-and-true-p org-indent-mode) (org-indent-mode -1))
      (setq-local org-hide-leading-stars nil
                  org-fontify-done-headline nil
                  org-fontify-quote-and-verse-blocks nil
                  org-fontify-whole-heading-line nil
                  org-priority-faces nil
                  org-todo-keyword-faces nil
                  org-pretty-entities nil
                  org-hide-emphasis-markers nil
                  org-ellipsis "...")
      (when (bound-and-true-p prettify-symbols-mode) (prettify-symbols-mode -1))
      (setq-local prettify-symbols-alist nil)
      (when (bound-and-true-p variable-pitch-mode) (variable-pitch-mode -1))
      (when (bound-and-true-p olivetti-mode) (olivetti-mode -1))
      (font-lock-flush))))

(add-hook 'org-mode-hook #'my/org-maybe-disable-prettification)

;; 不让 so-long 劫持 org-mode（其有自己的大型文件处理器，见上）。
(after! so-long
  (setq so-long-predicate
        (lambda () (and (not (derived-mode-p 'org-mode))
                        (doom-so-long-p)))))


;; ═══════════════════════════════════════════════════════════════════════════
;; LaTeX（AUCTeX + Org → LaTeX 导出）
;; ═══════════════════════════════════════════════════════════════════════════

;; XeLaTeX 默认引擎 — 支持中文/OpenType 字体所需。
;; PDFTeX 无法处理 CJK 字符（除非使用侵入性包如 CJKutf8）；
;; LuaLaTeX 是另一个选项，但对小型文档较慢。
;;
(setq-default TeX-engine 'xetex)

;; ─── Org → LaTeX 标题格式化 ──────────────────────────────────────
;;
;; 自定义 `org-latex-format-headline-function`，将 TODO 关键字、
;; 优先级和标签包装在 `\texorpdfstring{}{}` 中，使 PDF 书签
;;（无法处理 LaTeX 颜色命令）有纯文本回退。
;; 没有此函数时，书签会显示 `{\color{red!65!black}...}` 等原始代码。
;;
(defun my/org-latex-format-headline (todo todo-type priority text tags _info)
  (concat
   (and todo
        (let ((fmt (pcase todo-type
                     ('todo "{\\color{red!65!black}\\bfseries\\sffamily %s}")
                     ('done "{\\color{green!45!black}\\bfseries\\sffamily %s}")
                     (_ "{\\bfseries\\sffamily %s}"))))
          (format "\\texorpdfstring{%s }{%s }" (format fmt todo) todo)))
   (and priority
        (let* ((pri-str (org-priority-to-string priority))
               (colored (format "{\\color{orange!60!black}\\small\\sffamily [\\#%s]}" pri-str)))
          (format "\\texorpdfstring{%s }{%s }" colored (format "[\\#%s]" pri-str))))
   text
   (and tags
        (let ((tag-text (mapconcat #'org-latex--protect-text tags ":")))
          (format "\\texorpdfstring{\\hfill{}{\\color{gray!50!black}\\small %s}}{}" tag-text)))))

(use-package! ox-latex
  :defer t
  :after ox
  :custom
  (org-latex-format-headline-function #'my/org-latex-format-headline)

  (org-latex-logfiles-extensions
   '("lof" "lot" "tex~" "aux" "idx" "log" "out" "toc" "nav" "snm"
     "vrb" "dvi" "fdb_latexmk" "blg" "brf" "fls" "entoc" "ps" "spl" "bbl" "tex" "bcf"))

  :config
  ;; 使用 TEXINPUTS 查找 modules/ 目录中的 ctexbook-org.cls
  ;; 的 LaTeX 编译命令。
  (let* ((modules-dir (expand-file-name "modules" doom-user-dir))
         (cmd (format "env TEXINPUTS=%s//: latexmk -xelatex -shell-escape -interaction=nonstopmode -f -output-directory=%%o %%f"
                      modules-dir)))
    (setq org-latex-pdf-process (list cmd)))

  ;; 基于 ctexbook 的中文排版自定义 LaTeX 类。
  ;; 所有包从 modules/ctexbook-org.cls 加载。
  (add-to-list 'org-latex-classes
               '("ctexbook"
                 "\\documentclass{ctexbook-org}
[PACKAGES]
[EXTRA]"
                 ("\\chapter{%s}" . "\\chapter*{%s}")
                 ("\\section{%s}" . "\\section*{%s}")
                 ("\\subsection{%s}" . "\\subsection*{%s}")))
  (setq org-latex-default-class "ctexbook"))


;; ═══════════════════════════════════════════════════════════════════════════
;; 笔记（Deft + Denote + Consult-notes）
;; ═══════════════════════════════════════════════════════════════════════════

;; ─── Deft（纯文本笔记文件浏览）────────────────────────────────────
;;
;; 重写 `deft-parse-title'：默认实现期望 org-mode 的 #+TITLE；
;; 但 Deft 也会选取非 org 文件，这些文件仍需提取标题。
;; 自定义正则同时匹配 `#+title:` 和 Org 的 `#+TITLE:` 变体。
;;
;; deft-strip-summary-regexp：从预览摘要中移除元数据行，
;; 否则每个文件都会显示一排 #+KEYWORD: ... 和 :PROPERTIES:
;; 抽屉，而非实际的散文首段。
;;
(after! deft
  (setq deft-directory "~/org/deft"
        deft-recursive t)
  (defun my/deft-parse-title (file contents)
    "重写 `deft-parse-title' 以接受大小写不敏感的 #+TITLE 行。
默认只匹配 `#+title'（小写）；我们的约定是大写 Org 关键字。"
    (if (string-match "^#\\+[tT][iI][tT][lL][Ee]:\\s-*\\(.*\\)" contents)
        (match-string 1 contents)
      (deft-base-filename file)))
  (advice-add 'deft-parse-title :override #'my/deft-parse-title)
  (setq deft-strip-summary-regexp
        (concat "\\("
                "[\n\t]"
                "\\|^#\\+[[:alpha:]_]+:.*$"
                "\\|^:PROPERTIES:\n\\(.+\n\\)+:END:\n"
                "\\)")))

;; ─── Denote（文件命名式 Zettelkasten）───────────────────────────────────
;;
;; Denote 通过时间戳 + 标题 + 关键字生成文件名，实现无数据库的发现。
;; 所有文件为纯文本，位于 `~/Documents/notes/`。
;;
;; `:after-call doom-first-buffer-hook` 将加载推迟到 Emacs 启动后空闲时 —
;; 比 `:defer t`（会在触发自动加载的第一个交互式命令时阻塞）启动更快。
;;
(use-package! denote
  :after-call doom-first-buffer-hook
  :hook
  (dired-mode . denote-dired-mode-in-directories)
  (text-mode . denote-fontify-links-mode)
  :custom
  (denote-directory "~/org/denote")
  (denote-dired-directories (list denote-directory))
  (denote-dired-directories-include-subdirectories t)
  ;; 个人关键字分类法 — 根据你的领域调整。
  (denote-known-keywords '("创作" "学习" "工作" "生活" "技术" "思考" "索引"))
  (denote-infer-keywords t)
  (denote-sort-keywords t)
  (denote-prompts '(title keywords))
  (denote-date-prompt-use-org-read-date t)
  (denote-save-buffers nil)
  (denote-rename-confirmations '(rewrite-front-matter modify-file-name))
  (denote-link-description-format "%t")
  :init
  (map! :leader
        (:prefix-map ("r d" . "Denote")
         :desc "New note"                "n" #'denote
         :desc "Date note"               "d" #'denote-date
         :desc "Select type"             "t" #'denote-type
         :desc "Open or create"          "o" #'denote-open-or-create
         :desc "Find link"               "l" #'denote-find-link
         :desc "Link or create"          "i" #'denote-link-or-create
         :desc "New sequence"            "s" #'denote-sequence
         :desc "Rename keywords"         "k" #'denote-rename-file-keywords
         :desc "Rename file"             "r" #'denote-rename-file
         :desc "Rename front matter"     "R" #'denote-rename-file-using-front-matter
         :desc "Search notes"            "f" #'consult-notes
         :desc "Find backlinks"          "b" #'denote-find-backlink
         :desc "Dired notes"             "D" #'denote-dired
         :desc "Grep notes"              "g" #'denote-grep
         (:prefix-map ("e" . "Explore")
          :desc "Count notes"         "c" #'denote-explore-count-notes
          :desc "Count keywords"      "C" #'denote-explore-count-keywords
          :desc "Random note"         "r" #'denote-explore-random-note
          :desc "Random link"         "l" #'denote-explore-random-link
          :desc "Knowledge network"   "n" #'denote-explore-network)))
  :config
  (denote-rename-buffer-mode 1)

  ;; 每次新建笔记后自动提交到 git。
  ;; 这是一个简单的安全网，不是完整的 VCS 工作流。
  ;; 如果笔记目录不是 git 仓库，则静默无操作。
  (defun my/denote-git-auto-commit ()
    "通过 git 自动添加并提交 Denote 目录的所有更改。
如果目录不是 git 仓库，则为静默空操作（不报错）。"
    (when-let ((dir (denote-directory)))
      (let ((git-dir (expand-file-name ".git" dir)))
        (when (file-exists-p git-dir)
          (let ((default-directory dir))
            (unless (zerop (call-process "git" nil nil nil "add" "-A"))
              (message "WARN: denote git add failed"))
            (unless (zerop (call-process "git" nil nil nil
                                         "commit" "--allow-empty"
                                         "-m" "auto: note saved"))
              (message "WARN: denote git commit failed")))))))
  (add-hook 'denote-after-new-note-hook #'my/denote-git-auto-commit))

(use-package! denote-journal
  :after denote
  :hook (calendar-mode . denote-journal-calendar-mode)
  :custom
  (denote-journal-directory (concat denote-directory "/journal"))
  (denote-journal-keyword '("journal"))
  (denote-journal-title-format 'day-date-month-year)
  :init
  (map! :leader
        (:prefix-map ("r d" . "Denote")
         :desc "Journal entry" "j" #'denote-journal-new-or-existing-entry)))

(use-package! denote-menu
  :after denote
  :custom
  (denote-menu-show-file-type t)
  (denote-menu-show-file-signature t)
  :init
  (map! :leader
        (:prefix-map ("r d" . "Denote")
         :desc "List notes (menu)" "m" #'list-denotes))
  :config
  (define-key denote-menu-mode-map (kbd "c")   #'denote-menu-clear-filters)
  (define-key denote-menu-mode-map (kbd "/ r") #'denote-menu-filter)
  (define-key denote-menu-mode-map (kbd "/ k") #'denote-menu-filter-by-keyword)
  (define-key denote-menu-mode-map (kbd "/ o") #'denote-menu-filter-out-keyword)
  (define-key denote-menu-mode-map (kbd "e")   #'denote-menu-export-to-dired))

(use-package! denote-org
  :after denote
  :commands
  (denote-org-link-to-heading
   denote-org-backlinks-for-heading
   denote-org-extract-org-subtree
   denote-org-convert-links-to-file-type
   denote-org-convert-links-to-denote-type)
  :init
  (map! :leader
        (:prefix-map ("r d" . "Denote")
         :desc "Link to heading"     "h" #'denote-org-link-to-heading
         :desc "Heading backlinks"   "H" #'denote-org-backlinks-for-heading
         :desc "Extract subtree"    "x" #'denote-org-extract-org-subtree))
  (map! :localleader
        :map org-mode-map
        :prefix ("D" . "Denote")
        :desc "Link to heading"     "h" #'denote-org-link-to-heading
        :desc "Heading backlinks"   "b" #'denote-org-backlinks-for-heading
        :desc "Extract subtree"     "x" #'denote-org-extract-org-subtree))

(use-package! consult-notes
  :after denote
  :custom
  (consult-notes-denote-display-keywords-indicator "_")
  :config
  (consult-notes-denote-mode))


;; ═══════════════════════════════════════════════════════════════════════════
;; 阅读（Dired、EPUB、PDF）
;; ═══════════════════════════════════════════════════════════════════════════

;; ─── Dired：外部程序打开文件 ─────────────────────────────────────────
;;
;; Dired 中的 `E` 键使用 OS 处理器打开标记文件（Linux 上为 xdg-open，
;; macOS 上为 open，Windows 上为 start）。为何用 `E`（大写）：Doom 的
;; dired 使用 `e` 进行 `dired-find-file`（内联），而 `E` 可记忆为
;; "External"。使用 `start-process`（异步，不等待）。
;;
(after! dired
  (defun my/dired-open-externally ()
    "使用 OS 默认应用程序打开每个标记文件（异步）。
使用 `xdg-open`（Linux）、`open`（macOS）或 `start`（Windows）。
立即返回而不等待子进程 — 适合从 Dired 批量打开。"
    (interactive)
    (let* ((files (dired-get-marked-files))
           (cmd (pcase system-type
                  ('darwin "open")
                  ('windows-nt "start")
                  (_ "xdg-open"))))
      (dolist (f files)
        (start-process cmd nil cmd f))))
  (map! :map dired-mode-map
        :n "E" #'my/dired-open-externally))

;; ─── EPUB（nov.el）─────────────────────────────────────────────────
;;
;; nov.el 将 EPUB 渲染为带样式的 HTML，在 Emacs 缓冲区中显示。
;; 启用 visual-line-mode + variable-pitch-mode 以获得类图书阅读体验。
;; olivetti-mode 居中文本。禁用 hl-line（阅读时分心）。
;; 通过 `nov-save-place-file` 跨会话保存阅读位置。
;;
(use-package! nov
  :mode ("\\.epub\\'" . nov-mode)
  :hook ((nov-mode . visual-line-mode)
         (nov-mode . variable-pitch-mode)
         (nov-mode . (lambda () (hl-line-mode -1))))
  :custom
  (nov-text-width t)
  (nov-variable-pitch-mode t)
  (nov-save-place-file (concat doom-cache-dir "nov-places"))
  :config
  (add-hook 'nov-mode-hook #'olivetti-mode)
  (defun my/nov-disable-adaptive-fill ()
    (setq-local adaptive-fill-mode nil))
  (add-hook 'nov-mode-hook #'my/nov-disable-adaptive-fill))

;; ─── PDF（pdf-tools）───────────────────────────────────────────────────
;;
;; `fit-page` 用于整页视图（像真正的 PDF 阅读器）。滚动次要模式
;; 提供平滑滚动。org-noter-pdf 的 advice 抑制箭头定时器错误
;;（滚动模式和 org-noter 交互时的一个已知 bug）。
;;
;; pdf-view-resize-factor 1.1：缩放步长（比默认的 1.2 更精细控制）。
;; pdf-view-selection-style 'glyph：按字形边界（而非像素）选择文本 —
;; 复制粘贴更精确。
;;
(after! pdf-tools
  (setq pdf-view-display-size 'fit-page
        pdf-view-resize-factor 1.1
        pdf-annot-activate-created-annotations t
        pdf-view-use-scaling nil
        pdf-view-use-imagemagick nil
        pdf-view-selection-style 'glyph)
  (add-hook! 'pdf-view-mode-hook #'pdf-view-roll-minor-mode #'evil-emacs-state))

;; FIXME: `org-noter-pdf--show-arrow` 错误的变通方案，在
;; `pdf-view-roll-minor-mode` 激活时触发。错误非致命（箭头
;; 仅在滚动页面上不显示），但会污染 `*Messages*`。
;; 当 org-noter-pdf 上游修复了滚动模式交互后移除。
(after! org-noter-pdf
  (defun pdf-view-current-overlay (&optional window)
    (or (image-mode-window-get 'overlay window)
        (when (and (bound-and-true-p pdf-view-roll-minor-mode)
                   (fboundp 'pdf-roll-page-overlay))
          (condition-case nil
              (pdf-roll-page-overlay (pdf-view-current-page) window)
            (error nil)))))
  (defadvice! +org-noter-pdf--show-arrow-a (orig-fn)
    :around #'org-noter-pdf--show-arrow
    (condition-case nil (funcall orig-fn) (error nil))))

(use-package! org-pdftools
  :defer t
  :commands org-pdftools-setup-link
  :hook (org-load . org-pdftools-setup-link))

;; 通过 `g z` 在 Zathura（外部查看器）中打开当前 PDF。
;; 当 pdf-tools 无法渲染某些内容或你需要注释器时有用。
(map! :map pdf-view-mode-map
      :n "g z" (cmd! (when-let ((f (buffer-file-name)))
                       (start-process "zathura" nil "zathura" f))))


;; ═══════════════════════════════════════════════════════════════════════════
;; 国际化 / 中文支持
;; ═══════════════════════════════════════════════════════════════════════════

;; ─── 中文输入法（fcitx5）───────────────────────────────────────────
;;
;; `doom-first-input-hook` 将加载推迟到用户实际输入时 —
;; 避免在 Emacs 启动时启动 fcitx5。fcitx5-remote 在 Evil 模式切换时
;; 切换输入法状态；没有这个，你会在正常状态卡在中文输入法，
;; 或者在插入状态无法输入中文。
;;
(add-transient-hook! 'doom-first-input-hook
  (when-let ((cmd (or (executable-find "fcitx5-remote")
                      (executable-find "fcitx-remote"))))
    (setq fcitx-remote-command cmd)
    (require 'fcitx)
    (fcitx-evil-turn-on)))

;; ─── 拼音模糊匹配（搜索 + 导航）─────────────────────────────────────
;;
;; 两个互补包：
;;   - evil-pinyin：advice `orderless-regexp` 返回拼音模糊正则，
;;     使 `M-x` / `consult` / `vertico` 搜索能通过拼音首字母
;;     匹配中文（例如 "xie" → "写作"、"xiexie" 等）。
;;   - ace-pinyin：扩展 Avy（字符跳转）以接受拼音输入匹配中文字符，
;;     因此你可以用拼音进行 `avy-goto-char-timer`。
;;
(use-package! evil-pinyin
  :defer t
  :commands (evil-pinyin--build-regexp-string)
  :init
  (after! orderless
    (advice-add #'orderless-regexp :filter-return #'evil-pinyin--build-regexp-string))
  :config (evil-pinyin-mode 1))

(use-package! ace-pinyin
  :commands ace-pinyin-global-mode
  :after-call avy-goto-char-timer
  :init (setq ace-pinyin-use-avy t)
  :config (ace-pinyin-global-mode t))

;; ─── 文本统计（CJK + 英文，纯 C 模块）────────────────────────────────
;;
;; C 模块（modules/count-cjk.so）在单次 UTF-8 扫描中完成所有计数。
;; 加载器自动检测过期/缺失的 .so 并运行 make(1)；
;; 如果调用时模块不存在，命令会尝试按需重建。
;;
;; 导出的 C 函数：
;;   my/count-cjk  （字符串）→ cons（汉字数 . 标点数）
;;   my/count-text （字符串）→ vector [cjk punct en-words en-chars total-cp]
;;
;; 绑定：
;;   M-=         — my/count-words（替换 `count-words-region'）
;;   SPC r n c   — my/count-chinese-chars（传统 CJK 计数器）
;;   SPC r n b   — my/build-cjk-module（重建并重新加载）
;;
;; 基准测试（Emacs 30，GCC 15，约 50/50 CJK/ASCII 混合）：
;;   大小     原始（Elisp）  C 模块  加速比
;;   1 KB        28 ms       0.7 ms   42×
;;   10 KB      211 ms       21 ms     10×
;;   100 KB   1926 ms       162 ms     12×
;;   500 KB   9376 ms       613 ms     15×

;; ─── C 模块加载器 ─────────────────────────────────────────────────────

(defvar my/cjk-so (expand-file-name "modules/count-cjk.so" doom-user-dir)
  "count-cjk 模块的 .so 文件路径。首次使用时惰性加载。")
(defvar my/cjk-src (expand-file-name "modules/count-cjk.c" doom-user-dir))

(defun my/cjk-module-outdated-p ()
  "如果 .so 缺失或比 .c 源文件旧，返回 t。"
  (let ((c-attrs (file-attributes my/cjk-src)))
    (and c-attrs
         (or (not (file-exists-p my/cjk-so))
             (time-less-p (file-attribute-modification-time
                           (file-attributes my/cjk-so))
                          (file-attribute-modification-time c-attrs))))))

(defun my/build-cjk-module ()
  "通过运行 `make -C modules/' 编译 count-cjk.so。失败时显示构建日志缓冲区。"
  (interactive)
  (let* ((build-dir (expand-file-name "modules" doom-user-dir))
         (buf (get-buffer-create "*cjk-build*")))
    (with-current-buffer buf (view-mode -1) (erase-buffer))
    (if (zerop (call-process "make" nil buf nil "-C" build-dir))
        (progn (message "count-cjk.so rebuilt") t)
      (display-buffer buf)
      (error "count-cjk.so build failed — see *cjk-build* buffer"))))

(defun my/load-cjk-module ()
  "检查 CJK 模块状态，启动时仅提示不编译不加载。
真正的编译/加载推迟到首次调用命令时由 my/ensure-cjk-module 处理。"
  (interactive)
  (when (fboundp 'module-load)
    (cond
     ((my/cjk-module-outdated-p)
      (message "count-cjk.so 已过期 — 首次使用时会自动重新编译"))
     ((not (file-exists-p my/cjk-so))
      (message "count-cjk.so 缺失 — 首次使用时会自动编译"))
     (t
      ;; .so 存在且未过期，但不加载——留给 ensure 按需加载
      nil))))

(my/load-cjk-module)

;; ─── 辅助函数 ──────────────────────────────────────────────────────

(defun my/ensure-cjk-module ()
  "确保 C 模块已加载；按需编译（仅在 .so 过期或缺失时）。
如果模块仍不可用则报错。"
  (unless (fboundp 'my/count-text)
    (when (my/cjk-module-outdated-p)
      (my/build-cjk-module))
    (when (file-exists-p my/cjk-so)
      (module-load my/cjk-so))
    (unless (fboundp 'my/count-text)
      (error "count-cjk.so 重建后仍不可用"))))

;; ─── 辅助函数 ────────────────────────────────────────────────────────

(defun my/--fmt-num (n)
  "用中文单位格式化大数字：≥1万显示为 `X.X万（精确）'，≥1亿同理。"
  (let ((abs-n (abs n)))
    (cond
     ((>= abs-n 100000000)
      (format "%.2f亿（%d）" (/ n 100000000.0) n))
     ((>= abs-n 10000)
      (format "%.2f万（%d）" (/ n 10000.0) n))
     (t
      (format "%d" n)))))

;; ─── 命令 ────────────────────────────────────────────────────────────

;;;###autoload
(defun my/count-chinese-chars (&optional beg end)
  "CJK 字符计数（传统）。绑定到 `SPC r n c'。"
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
  "统计区域或缓冲区中的 CJK 字符、英文单词和标点符号。

替换 `count-words-region'（M-=）。使用 C 模块进行所有计数。

输出：  中:42  英:18  标点:7  总:67

   中       CJK 表意文字（中文的词数等价物）
   英       英文单词（字母/数字/撇号序列）
   标点     CJK 标点符号
   总       区域中的 Unicode 码点总数"
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

;; ─── 绑定 ────────────────────────────────────────────────────────────

(map! :leader
      (:prefix-map ("r n" . "Count")
       :desc "Chinese chars"  "c" #'my/count-chinese-chars
       :desc "Rebuild module" "b" #'my/build-cjk-module))

(map! :g "M-=" #'my/count-words)





;; ═══════════════════════════════════════════════════════════════════════════
;; 工具
;; ═══════════════════════════════════════════════════════════════════════════

;; ─── 完整重载（配置 + 自动加载 + 包 + 主题 + 字体 + 帧）───────────
;;
;; Doom 内置的 `doom/reload` 仅重新求值配置文件。此自定义命令
;; 在更改主题、字体、包或自动加载文件时更彻底：
;;   1. `doom/reload-autoloads` — 重新扫描自动加载（无需 `doom sync`）
;;   2. `doom/reload-packages` — 重新求值 `packages.el`
;;   3. `doom/reload` — 重新求值 `config.el`（核心）
;;   4. 重载后：重新应用主题、字体并重新运行帧 hook
;;     （因为 `doom/reload` 重置了它们但不会重新触发）。
;;
;; 绑定到 `SPC h r R`（大写 R = 完全重载 vs 小写 r = 重载）。
;;
(defun my/doom-full-reload--apply (&rest _)
  "在 `doom/reload' 后重新应用主题和字体。

仅重新应用主题 + 字体 — 不重新运行 `server-after-make-frame-hook'
或其他非幂等帧 hook。通过 `doom-after-reload-hook' 运行。"
  (my/theme-apply (my/theme-for-hour))
  (when (fboundp 'doom/reload-font)
    (doom/reload-font))
  (message "Full reload complete (config + theme + font)"))

;; 在顶层注册一次（不在 `my/doom-full-reload' 内部），以防止
;; 重复调用时 hook 累积。
(after! doom
  (add-hook 'doom-after-reload-hook #'my/doom-full-reload--apply))

(defun my/doom-full-reload ()
  "重新加载自动加载、包和配置。

步骤：
1. `doom/reload-autoloads` — 获取新的自动加载命令/面。
2. `doom/reload-packages` — 重新求值 `packages.el'（无需 `doom sync`）。
3. `doom/reload` — 重新求值 `config.el'（核心）。
4. `doom-after-reload-hook' 自动触发，通过 `my/doom-full-reload--apply'
   （在顶层注册）重新应用主题和字体。

每一步都检查 fboundp（在 Doom 的重载机制完全初始化前调用时安全）。

绑定到 `SPC h r R'。"
  (interactive)
  (when (fboundp 'doom/reload-autoloads)
    (ignore-errors (doom/reload-autoloads)))
  (when (fboundp 'doom/reload-packages)
    (ignore-errors (doom/reload-packages)))
  (when (fboundp 'doom/reload)
    (ignore-errors
      (doom/reload))))

(map! :leader
      :desc "Full reload" "h r R" #'my/doom-full-reload)

;; ── C 动态模块路径 ─────────────────────────────────────────────
(defvar my/cnotify-so (expand-file-name "modules/cnotify-module.so" doom-user-dir)
  "cnotify 模块的 .so 文件路径。首次使用时惰性加载。")
(defvar my/random-so (expand-file-name "modules/random.so" doom-user-dir)
  "random 模块的 .so 文件路径。首次使用时惰性加载。")




;; ─── 番茄钟日志 ────────────────────────────────────────────────────────
(defvar my/pomodoro-log-file
  (expand-file-name "pomodoro.log.el" doom-user-dir)
  "已完成番茄钟周期的 Sexp 日志。")

(defvar my/pomodoro-default-task "专注"
  "未在提示中提供时的默认任务名称。")

(defun my/pomodoro-log-read ()
  "读取所有日志条目，返回 plist 列表。"
  (when (file-exists-p my/pomodoro-log-file)
    (with-temp-buffer
      (insert-file-contents my/pomodoro-log-file)
      (goto-char (point-min))
      (read (current-buffer)))))

(defun my/pomodoro-log-write (entry)
  "将 ENTRY（plist）追加到日志文件。"
  (with-temp-file my/pomodoro-log-file
    (when (file-exists-p my/pomodoro-log-file)
      (insert-file-contents my/pomodoro-log-file))
    (goto-char (point-max))
    (insert (prin1-to-string entry) "\n")))

(defun my/pomodoro-log-entry (task minutes)
  "写入一个完成的番茄钟条目。"
  (my/pomodoro-log-write
   `(:time ,(format-time-string "%Y-%m-%d %H:%M")
     :task ,task :work ,minutes :break 5)))

(defun my/pomodoro-show-stats ()
  "显示番茄钟统计：今日、本周、总计。"
  (interactive)
  (let* ((entries (my/pomodoro-log-read))
         (today (format-time-string "%Y-%m-%d"))
         (week-start (format-time-string "%Y-%m-%d"
                                         (time-subtract (current-time)
                                                        (* (1- (string-to-number (format-time-string "%u"))) 86400))))
         (today-entries (seq-filter
                         (lambda (e) (string-prefix-p today (plist-get e :time)))
                         entries))
         (week-entries (seq-filter
                        (lambda (e) (not (string< (substring (plist-get e :time) 0 10) week-start)))
                        entries))
         (today-cycles (length today-entries))
         (today-minutes (apply #'+ (mapcar (lambda (e) (plist-get e :work)) today-entries)))
         (week-cycles (length week-entries))
         (week-minutes (apply #'+ (mapcar (lambda (e) (plist-get e :work)) week-entries)))
         (total-cycles (length entries))
         (total-minutes (apply #'+ (mapcar (lambda (e) (plist-get e :work)) entries)))
         (buf (get-buffer-create "*Pomodoro Stats*")))
    (with-current-buffer buf
      (erase-buffer)
      (insert (format "🍅 Pomodoro Statistics\n\n"))
      (insert (format "Today:  %d cycles, %d min\n" today-cycles today-minutes))
      (insert (format "Week:   %d cycles, %d min\n" week-cycles week-minutes))
      (insert (format "Total:  %d cycles, %d min (%.1f hours)\n\n"
                      total-cycles total-minutes (/ total-minutes 60.0)))
      (insert "Recent:\n")
      (dolist (e (reverse (seq-take (reverse entries) 10)))
        (insert (format "  %s  %s  %dmin\n"
                        (plist-get e :time) (plist-get e :task) (plist-get e :work))))
      (special-mode)
      (goto-char (point-min)))
    (switch-to-buffer buf)))

;; ─── 番茄钟追踪（阶段转换）────────────────────────────────
(defvar my/pomodoro--prev-phase 0 "之前的番茄钟阶段，用于检测周期完成。")
(defvar my/pomodoro--current-task nil "当前番茄钟会话的任务名称。")
(defvar my/pomodoro--current-work-min 25 "当前会话的工作分钟数。")

;; ─── cnotify 惰性加载 ──────────────────────────────────────────────
(defun my/cnotify--ensure ()
  "确保 cnotify C 模块已加载。首次调用时通过 module-load 加载 .so。"
  (unless (featurep 'cnotify-module)
    (module-load my/cnotify-so)))

(defun my/pomodoro-start (&optional task work-min break-min)
  "以 TASK 名称开始番茄钟（默认为\"专注\"）。"
  (interactive)
  (my/cnotify--ensure)
  (let ((tname (or task
                   (let ((s (read-string "Task: " nil nil my/pomodoro-default-task)))
                     (if (string= s "") my/pomodoro-default-task s))))
        (w (or work-min 25))
        (b (or break-min 5)))
    (setq my/pomodoro--current-task tname
          my/pomodoro--current-work-min w
          my/pomodoro--prev-phase 0)
    (cnotify-pomodoro-start w b)
    (my/cnotify-start-poll)
    (message "🍅 %s — %d min" tname w)))

(defun my/pomodoro-stop ()
  "停止正在运行的番茄钟（不完整 — 不记录）。"
  (interactive)
  (my/cnotify--ensure)
  (cnotify-pomodoro-stop)
  (setq my/pomodoro--prev-phase 0)
  (my/cnotify-refresh)
  (message "🍅 Pomodoro stopped — not logged"))

(defun my/timer-start (minutes &optional message)
  "开始 MINUTES 倒计时，以 MESSAGE 通知。"
  (interactive "nMinutes: \nsMessage: ")
  (my/cnotify--ensure)
  (cnotify-timer-start (* minutes 60) (or message "Timer finished"))
  (my/cnotify-start-poll))

(defun my/timer-stop ()
  "停止正在运行的计时器。"
  (interactive)
  (my/cnotify--ensure)
  (cnotify-timer-stop)
  (my/cnotify-refresh))



(defun my/random--ensure ()
  "确保 random C 模块已加载。首次调用时通过 module-load 加载 .so。"
  (unless (featurep 'random-module)
    (module-load my/random-so)))

(defun my/random-password (&optional length)
  "生成随机密码并复制到剪贴板。
使用内核熵池（getrandom），不回退 PRNG。"
  (interactive "P")
  (my/random--ensure)
  (let* ((len (if (numberp length) length 24))
         (pw (random-password len)))
    (kill-new pw)
    (message "🔑 密码（%d 字符）已复制到剪贴板" len)))

(defun my/word-count (&optional beg end)
  "统计区域（或整个缓冲区）中的 CJK/英文字符和词数。"
  (interactive "r")
  (my/ensure-cjk-module)
  (let* ((text (if (use-region-p)
                   (buffer-substring-no-properties beg end)
                 (buffer-substring-no-properties (point-min) (point-max))))
         (label (if (use-region-p) "Region" "Buffer"))
         (v    (my/count-text text)))
    (message "%s: %s CJK, %s punct, %s EN words (%s EN chars), %s total cp"
             label (my/--fmt-num (aref v 0)) (my/--fmt-num (aref v 1))
             (my/--fmt-num (aref v 2)) (my/--fmt-num (aref v 3))
             (my/--fmt-num (aref v 4)))))

(map! :leader
      (:prefix-map ("r t" . "Tools")
       :desc "Start timer"              "t" #'my/timer-start
       :desc "Stop timer"               "T" #'my/timer-stop
       :desc "Start pomodoro"           "s" #'my/pomodoro-start
       :desc "Stop pomodoro"            "S" #'my/pomodoro-stop
       :desc "Word count"               "w" #'my/word-count
       :desc "Pomodoro stats"           "v" #'my/pomodoro-show-stats))

;; ── 模式行：计时器/番茄钟倒计时 ───────────────────────
(defvar my/cnotify-indicator nil "模式行中计时器/番茄钟的显示字符串。")
(defvar my/cnotify-update-timer nil "模式行刷新的内部 1 秒定时器。")

(defun my/cnotify-refresh ()
  "从 C 模块状态刷新模式行。每秒调用一次。"
  (my/cnotify--ensure)
  ;; 处理通知点击 — 如果用户点击了弹窗则将焦点设回 Emacs
  (when (cnotify-poll-action)
    (select-frame-set-input-focus (selected-frame)))

  ;; 检测番茄钟周期完成（阶段 1→2 = 工作完成）
  (pcase-let ((`(,remaining . ,phase) (cnotify-status)))
    (when (and (= my/pomodoro--prev-phase 1) (= phase 2)
               my/pomodoro--current-task)
      (my/pomodoro-log-entry my/pomodoro--current-task
                             my/pomodoro--current-work-min)
      (message "🍅 %s — %d min ✓" my/pomodoro--current-task
               my/pomodoro--current-work-min))
    (setq my/pomodoro--prev-phase phase)

    ;; 更新模式行指示器
    (if (and (= remaining 0) (= phase 0))
        (progn (setq my/cnotify-indicator nil)
               (when my/cnotify-update-timer
                 (cancel-timer my/cnotify-update-timer)
                 (setq my/cnotify-update-timer nil)))
      (setq my/cnotify-indicator
            (cond
             ((= phase 1) (format " 🍅 %d:%02d" (/ remaining 60) (% remaining 60)))
             ((= phase 2) (format " ☕ %d:%02d" (/ remaining 60) (% remaining 60)))
             (t           (format " ⏱ %d:%02d" (/ remaining 60) (% remaining 60))))))
    (force-mode-line-update)))

;; 计时器/番茄钟启动时开始每秒轮询
(defun my/cnotify-start-poll ()
  (my/cnotify-refresh)
  (unless my/cnotify-update-timer
    (setq my/cnotify-update-timer (run-with-timer 1 1 #'my/cnotify-refresh))))

;; 将计时器指示器添加到模式行
(add-to-list 'mode-line-misc-info '("" my/cnotify-indicator ""))
