;;; $DOOMDIR/config.el -*- lexical-binding: t; -*-
;;;
;;; Doom Emacs 个人配置 — 在模块（自动加载及包）就绪后加载。
;;; 此处所有更改只需 `M-x doom/reload`（或 `M-x my/doom-full-reload`，
;;; 后者还会重新加载自动加载/包/主题/字体）；无需 `doom sync`，
;;; 除非修改了 `packages.el` 或 `init.el`。
;;;
;;; 一些增加速度的变量
(setq native-comp-speed 2)   ; -O2 是甜点；-O3 膨胀 .eln 文件且差距极小
(setq native-comp-async-jobs-number  ; 并行编译任务数
      (min 4 (max 1 (/ (num-processors) 2))))
(setq package-native-compile t)      ; 安装包时自动编译
(setq native-comp-async-report-warnings-errors 'silent)

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
;; (after! doom-ui
;;   (setq doom-font (font-spec :family "Monaspace Neon" :size 15)
;;         doom-variable-pitch-font (font-spec :family "Monaspace Neon" :size 15))
;;   (set-fontset-font t 'han (font-spec :family "LXGW WenKai Mono Screen" :size 15)))

(after! doom-ui
  ;; 1. 等宽主体字体：拉丁部分用 Maple Mono NF
  (setq doom-font (font-spec :family "Maple Mono NF" :size 16))

  ;; 2. 变宽字体（用于写作、阅读）：比例版霞鹜文楷
  (setq doom-variable-pitch-font (font-spec :family "LXGW WenKai" :size 16))

  ;; 3. 为默认等宽字体集添加 CJK 回退 → 只影响 fixed-pitch 面
  (set-fontset-font t 'han (font-spec :family "LXGW WenKai Mono Screen" :size 16))
  (set-fontset-font t 'kana (font-spec :family "LXGW WenKai Mono Screen" :size 16))
  (set-fontset-font t 'cjk-misc (font-spec :family "LXGW WenKai Mono Screen" :size 16)))

(add-hook 'writeroom-mode-hook #'mixed-pitch-mode)

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
(when-let ((fish (executable-find "fish")))
  (setq-default vterm-shell fish
                explicit-shell-file-name fish))
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
    "在 olivetti-mode 中禁用行号；退出时恢复原始状态。"
    (if olivetti-mode
        (progn
          (setq my/olivetti--line-numbers-p
                (and (bound-and-true-p display-line-numbers-mode) t))
          (display-line-numbers-mode -1))    ; ← 这里真正关闭行号
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
;;
;; 所有 `#+SETUPFILE: ~/org/.export-settings' 可集中管理共享的
;; 导出选项（LaTeX class、LANGUAGE、OPTIONS），减少各文件头部杂音。
;; SETUPFILE 包含 `#+EXCLUDE_TAGS: noexport'，因此标记 `:noexport:'
;; 的子树在导出中完全不可见，可在写作文件中保留注释/草稿而不污染输出。
(defvar my/pandoc-dir (expand-file-name "pandoc" doom-user-dir)
  "Pandoc 参考 docx 和 Lua 过滤器所在的目录。")

(after! ox-pandoc
  ;; 设置 docx 导出的 Pandoc 选项 — 使用自定义模板。
  (setq org-pandoc-options-for-docx
        `((reference-doc . ,(expand-file-name
                             "templates/template-default.docx"
                             my/pandoc-dir))
          (lua-filter . ,(expand-file-name "markdown-to-docx.lua" my/pandoc-dir)))))

;; ─── Org HTML 导出（本地极简主题）───────────────────────────────────
;;
;; SETUPFILE: `~/org/.export-settings' 是每篇 Org 共享导出选项的种子文件，
;; 添加一行 `#+SETUPFILE: ~/org/.export-settings' 即继承共享配置。
;; 内部草稿/注释可标记 `:noexport:' 标签以自动排除在导出之外。
;;
;; 自定义 CSS — 不包含默认样式，零 JavaScript。CSS 文件
;; 位于 `org-export/minimal/css/` 中，提供干净的类打印布局。
;; 理由：默认的 org 导出 HTML 包含面向打印的全页样式 —
;; 在屏幕上查看时过于繁重且难以定制主题。
;;
(defvar my/org-export-assets-dir
  (expand-file-name "org/export/minimal" doom-user-dir)
  "包含 Org HTML 导出资源（CSS，无 JS）的目录。
由下方的 `ox-html' 配置引用。结构：
  org/export/minimal/css/org.css
  org/export/minimal/css/htmlize.css")

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
Uses `niri msg --json windows` parsed with json-read-from-string."
  (let ((data (shell-command-to-string "niri msg --json windows")))
    (when (and data (not (string-empty-p data)))
      (let* ((json-object-type 'plist)
             (json-array-type 'list)
             (windows (json-read-from-string data))
             (match (seq-find (lambda (w) (equal (plist-get w :app_id) app-id))
                              windows))
             (id (and match (plist-get match :id))))
        (when id
          (call-process "niri" nil 0 nil
                        "msg" "action" "focus-window"
                        "--id" (format "%d" id)))))))

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
              '(("Bing"         "https://www.bing.com/search?q=%s")
                ("Bilibili"     "https://search.bilibili.com/all?keyword=%s")
                ("Douyin"       "https://www.douyin.com/search/%s")
                ("Emacs China"  "https://emacs-china.org/search?q=%s")
                ("Emacs Wiki"   "https://emacswiki.org/emacs?search=%s")
                ("知乎"          "https://www.zhihu.com/search?type=content&q=%s")
                ("术语在线"      "https://www.termonline.cn/search?k=%s")
                ("求闻百科"      "https://www.qiuwenbaike.cn/index.php?search=%s"))))

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


;; ─── Org 实时预览 ────────────────────────────────────────────
;;
;; M-x my/org-live-preview  启动当前 Org buffer 的实时预览
;; M-x my/org-live-preview  再次执行即停止
;;
;; 机制：导出 → HTTP+SSE 服务器 → 浏览器实时刷新

(defvar my/org-live--dir  nil)
(defvar my/org-live--proc nil)
(defvar my/org-live--url  nil)
(defvar my/org-live-server-py
  (expand-file-name "scripts/org-live-server.py" doom-user-dir))
(defvar my/org-live-python
  (or (executable-find "python3") (executable-find "python")))

(define-minor-mode my/org-live-mode
  "Org HTML 实时预览 minor mode。开启 → 导出 → 启动服务器 → 打开浏览器。
关闭 → 清理进程和临时文件。"
  :lighter " Live"
  :global nil
  (if my/org-live-mode
      (my/org-live--open)
    (my/org-live--close)))

(defun my/org-live--open ()
  (unless (derived-mode-p 'org-mode)
    (setq my/org-live-mode nil)
    (user-error "Not an Org buffer"))
  (unless (file-exists-p my/org-live-server-py)
    (setq my/org-live-mode nil)
    (user-error "缺少 %s" my/org-live-server-py))
  (unless my/org-live-python
    (setq my/org-live-mode nil)
    (user-error "Python 3 未找到"))
  (let* ((dir (make-temp-file "org-live-" t))
         (url (my/org-live--start-server dir)))
    (setq my/org-live--dir dir
          my/org-live--url url)
    (my/org-live--export)
    (add-hook 'after-save-hook #'my/org-live--on-save nil t)
    (add-hook 'kill-buffer-hook #'my/org-live-mode nil t)
    (browse-url url)
    (message "🍅 Live preview: %s" url)))

(defun my/org-live--close ()
  (when my/org-live--proc
    (delete-process my/org-live--proc)
    (setq my/org-live--proc nil))
  (when my/org-live--dir
    (delete-directory my/org-live--dir t)
    (setq my/org-live--dir nil))
  (setq my/org-live--url nil)
  (remove-hook 'after-save-hook #'my/org-live--on-save t)
  (remove-hook 'kill-buffer-hook #'my/org-live-mode t)
  (message "🍅 Live preview stopped"))

(defun my/org-live-preview ()
  "Toggle Org live preview."
  (interactive)
  (my/org-live-mode 'toggle))

(defun my/org-live--on-save ()
  (when my/org-live--dir (my/org-live--export)))

(defun my/org-live--export ()
  (let ((output (expand-file-name "index.html" my/org-live--dir)))
    (condition-case err
        (progn
          (org-export-to-file 'html output nil nil nil nil nil nil)
          (my/org-live--copy-css output)
          (my/org-live--fix-css-paths output)
          (my/org-live--inject-script output)
          (with-temp-file (expand-file-name ".live" my/org-live--dir)))
      (error (message "🍅 Export failed: %s" (error-message-string err)) (ding)))))

(defun my/org-live--copy-css (output)
  (let ((dst (expand-file-name "css" (file-name-directory output)))
        (src (expand-file-name "css" my/org-export-assets-dir)))
    (when (and (file-exists-p src) (not (file-exists-p dst)))
      (copy-directory src dst t t t))))

(defun my/org-live--fix-css-paths (file)
  (with-temp-buffer
    (insert-file-contents file)
    (goto-char (point-min))
    (let ((abs-pat (concat "href=\""
                           (regexp-quote
                            (file-name-as-directory
                             (expand-file-name "css" my/org-export-assets-dir))))))
      (while (re-search-forward abs-pat nil t)
        (replace-match "href=\"css/")))
    (write-region (point-min) (point-max) file nil 'silent)))

(defun my/org-live--inject-script (file)
  (with-temp-buffer
    (insert-file-contents file)
    (when (re-search-forward "</body>" nil t)
      (goto-char (match-beginning 0))
      (insert "<script>new EventSource('/live').onmessage=()=>location.reload()</script>")
      (write-region (point-min) (point-max) file nil 'silent))))

(defun my/org-live--start-server (dir)
  (let* ((buf (get-buffer-create "*org-live-httpd*"))
         proc port)
    (with-current-buffer buf (erase-buffer))
    (setq proc (make-process
                :name "org-live-httpd" :buffer buf :noquery t
                :command (list my/org-live-python my/org-live-server-py "--dir" dir)
                :connection-type 'pipe
                :sentinel (lambda (p e)
                            (when (and (not (process-live-p p)) (eq p my/org-live--proc))
                              (setq my/org-live--proc nil my/org-live--dir nil my/org-live--url nil)
                              (when my/org-live-mode
                                (my/org-live-mode -1))
                              (message "🍅 Live server stopped")))))
    (setq my/org-live--proc proc)
    (with-current-buffer buf
      (while (and (process-live-p proc) (not port))
        (accept-process-output proc 0.5)
        (goto-char (point-min))
        (when (re-search-forward "^PORT:\\([0-9]+\\)$" nil t)
          (setq port (string-to-number (match-string 1)))))
      (unless port
        (delete-process proc)
        (error "org-live-server failed: %s"
               (truncate-string-to-width (buffer-string) 200 nil nil t))))
    (format "http://127.0.0.1:%d/" port)))


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


;; （笔记模块已移至 :tools notes 模块）


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
    ;; Guarded filter-return: only expand pure-ASCII-letter components,
    ;; preventing "Regular expression too big" from huge char classes
    ;; on empty, numeric, mixed, or very long input.
    (defun my/orderless-regexp-pinyin (regex)
      (if (and (bound-and-true-p evil-pinyin-mode)
               (stringp regex)
               (not (string-empty-p regex))
               (string-match-p "\\`[a-zA-Z]+\\'" regex)
               (< (length regex) 10))
          (evil-pinyin--build-regexp-string regex)
        regex))
    (advice-remove #'orderless-regexp #'evil-pinyin--build-regexp-string)
    (advice-add #'orderless-regexp :filter-return #'my/orderless-regexp-pinyin))
  :config (evil-pinyin-mode 1))

(use-package! ace-pinyin
  :commands ace-pinyin-global-mode
  :after-call avy-goto-char-timer
  :init (setq ace-pinyin-use-avy t)
  :config (ace-pinyin-global-mode t))

;; （CJK 字符统计已移至 :tools cjk 模块）

;; 词典功能（萌典 + mapull）已移至 :tools cjk 模块

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
    (with-demoted-errors "Full reload: %S" (doom/reload-autoloads)))
  (when (fboundp 'doom/reload-packages)
    (with-demoted-errors "Full reload: %S" (doom/reload-packages)))
  (when (fboundp 'doom/reload)
    (with-demoted-errors "Full reload: %S" (doom/reload))))

(map! :leader
      :desc "Full reload" "h r R" #'my/doom-full-reload)

;; ─── 私人配置惰性编译（交互式 Emacs 空闲时）────────────────────
;; CLI 环境缺少宏所需第三方包（general 等），无法编译配置 .el 文件，
;; 因此在交互式 Emacs 完全初始化后，用轻量时间戳检查代替 SHA-256。

(defun my/private-config--collect ()
  (let (files seen)
    (dolist (file (doom-module-locate-paths (doom-module-list) "config.el"))
      (when (and (file-in-directory-p file doom-user-dir)
                 (not (member file seen)))
        (push file seen)
        (push file files)))
    (nreverse files)))

(defun my/private-config--byte-compile ()
  (dolist (file (my/private-config--collect))
    (let ((elc (byte-compile-dest-file file)))
      (unless (and (file-exists-p elc)
                   (not (file-newer-than-file-p file elc)))
        (with-demoted-errors "Private config compile: %S"
          (byte-compile-file file))))))

(add-hook 'doom-after-init-hook
          (lambda ()
            (run-with-idle-timer 3 nil #'my/private-config--byte-compile)))

;;（cnotify/random 模块路径已移至 :tools pomodoro）

;;（番茄钟/计时器/密码工具已移至 :tools pomodoro 模块）

;; ─── Wayland 剪贴板（C 模块，直接走 wayland-client 协议）────────
(when (and (getenv "WAYLAND_DISPLAY")
           (file-exists-p (expand-file-name "c-modules/clipboard-wl.so" doom-user-dir)))
  (module-load (expand-file-name "c-modules/clipboard-wl.so" doom-user-dir))
  (setq interprogram-cut-function
        (lambda (text &optional push)
          (ignore push)
          (when (fboundp 'clipboard-set)
            (condition-case nil (clipboard-set "text/plain" text) (error nil)))))
  (setq interprogram-paste-function
        (lambda ()
          (when (fboundp 'clipboard-get)
            (condition-case nil (clipboard-get "text/plain") (error nil)))))
  (message "🔧 Wayland clipboard: loaded"))

;; ─── 禁止 ispell 补全（未启用 :checkers spell 模块）─────────────
;; Emacs 29+ 自动在 text-mode 缓冲区启用 `ispell-completion-at-point`，
;; 但对中文环境（无对应字典）会触发 (setting-constant nil) 错误。
;; Doom corfu 模块虽有错误处理，但 Corfu 的 `corfu--debug` 仍会先
;; 打印错误。此处直接移除 ispell 的 completion-at-point 函数。
(after! text-mode
  (setq text-mode-ispell-word-completion nil)
  (remove-hook 'completion-at-point-functions #'ispell-completion-at-point))
