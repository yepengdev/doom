;;; init.el -*- lexical-binding: t; -*-

;; 启用 use-package 载入统计（用于分析启动速度）

;; 此文件控制 Doom 启用哪些模块及其加载顺序。
;; 修改后请记得运行 'doom sync'！

;; 提示：按 'SPC h d h'（非 vim 用户按 'C-h d h'）查看 Doom 文档。
;;   那里有 Doom 模块索引的链接，列出了所有模块及其支持的标记。

;; 提示：将光标移到模块名称（或其标记）上，按 'K'（或
;;   'C-c c k'，非 vim 用户）查看文档。标记（以加号开头的符号）
;;   同样适用。
;;
;;   或者，在模块上按 'gd'（或 'C-c c d'）浏览其目录（方便查看源码）。

(doom! :input
       ;;bidi              ; 帮助你从右到左书写
       ;;chinese           ; 中文拼音首字母搜索 — 自己配置了 fcitx + evil-pinyin
       ;;japanese           ; 日语输入支持
       ;;layout            ; auie,ctsrnm 是更优秀的主行键位

       :completion
       ;;company           ; 终极代码补全后端
       (corfu +orderless +dabbrev)  ; 使用 cap(f)、cape 补全，如羽毛般轻盈！
       ;;helm              ; *另一个*寻找爱与生活的搜索引擎
       ;;ido               ; 另一个*另一个*搜索引擎……
       ;;ivy               ; 一个寻找爱与生活的搜索引擎
       (vertico +childframe +icons)           ; 未来的搜索引擎

       :ui
       deft              ; Emacs 版的 Notational Velocity
       doom              ; 让 DOOM 呈现其样貌的配置
       ;;dashboard         ; Emacs 的漂亮启动画面
       ;;doom-quit         ; 退出 Emacs 时的 DOOM 退出提示
       emoji             ; 🙂
       hl-todo           ; 高亮 TODO/FIXME/NOTE/DEPRECATED/HACK/REVIEW
       indent-guides     ; 高亮缩进列
       ;;ligatures         ; 连字和符号，让代码重新变漂亮
       ;;minimap           ; 在侧边显示代码缩略图
       modeline          ; 时尚的 Atom 风格模式行，带 API
       nav-flash         ; 大范围移动后闪烁光标所在行
       ;;neotree           ; 项目文件树，类似 vim 的 NERDTree
       ophints           ; 高亮操作所作用的区域
       (popup +defaults)   ; 驯服突然出现的临时窗口
       ;;smooth-scroll     ; 流畅丝滑，让你不相信这不是黄油
       ;;tabs              ; Emacs 标签栏
       treemacs           ; 项目文件树，比 neotree 更酷
       ;;unicode           ; 各种语言的扩展 Unicode 支持
       (vc-gutter +pretty) ; 边缘显示版本控制差异
       ;;vi-tilde-fringe   ; 在缓冲区末尾外显示波浪线
       (window-select +numbers)     ; 可视化切换窗口
       workspaces        ; 标签模拟、持久化及独立工作区

       zen               ; 无干扰编码或写作

       :editor
       (evil +everywhere); 加入黑暗面，我们有好吃的饼干
       file-templates    ; 空文件的自动模板片段
       fold              ; （近乎）通用的代码折叠
       (format +onsave)          ; 自动格式化（手动按 SPC m f）
       ;;god               ; 无需修饰键运行 Emacs 命令
       ;;lispy             ; 给不喜欢 vim 的人用的 lisp 模式
       multiple-cursors  ; 同时在多处编辑
       ;;objed             ; 面向无辜者的文本对象编辑
       ;;parinfer          ; 把 lisp 变成 python，差不多吧
       ;;rotate-text       ; 在光标处的文本候选项间循环切换
       snippets          ; 我的小精灵：它们打字，我不用动手
       (whitespace +guess +trim)  ; 空白字符管家
       ;;word-wrap         ; 感知语言缩进的软换行

       :emacs
       (dired +dirvish +icons)             ; 让 dired 变得漂亮且实用
       electric          ; 更智能的基于关键字的 electric-indent
       ;;eww               ; 互联网很糟糕
       (ibuffer +icons)           ; 交互式缓冲区管理
       tramp             ; 远程文件触手可及
       undo              ; 持久化、更智能的撤销
       vc                ; 版本控制与 Emacs 和谐共处

       :term
       eshell            ; 随处可用的 elisp shell
       ;;shell             ; Emacs 的简单 shell REPL
       ;;term              ; Emacs 的基本终端模拟器
       vterm             ; Emacs 中最好的终端模拟

       :checkers
       syntax              ; 为你遗漏的每个分号打你手心
       ;;(spell +flyspell) ; 为你拼错的每个单词打你手心
       ;;grammar           ; 为你犯的每个语法错误打你手心

       :tools
       ;;ansible            ; IT 自动化工具
       ;;biblio            ; 帮你写博士论文（需要引用）
       ;;collab            ; 与朋友共享缓冲区
       ;;debugger          ; 单步调试代码，帮你增加 bug
       ;;direnv             ; 自动加载环境变量
       ;;docker             ; 容器管理
       ;;editorconfig      ; 让别人争论制表符 vs 空格吧
       ;;ein               ; 用 Emacs 驯服 Jupyter 笔记本
       (eval +overlay)     ; 运行代码（还有 REPL）
       (lookup +dictionary +docsets)              ; 浏览代码及其文档
       ;;llm               ; 当我说你需要朋友时，我不是指……
       ;;(lsp +eglot)      ; 把 Emacs 变成 VS Code
       magit             ; Emacs 的 Git 前端
       ;;make              ; 从 Emacs 运行 make 任务
       notes      ; Denote + Deft 笔记系统（+film: 观影日记）
       ;;pass              ; 给极客用的密码管理器
       pdf               ; PDF 增强
       pomodoro          ; 番茄钟 + 计时器 + 桌面通知
       cjk               ; CJK 字符统计（纯 C 模块）
       jieba             ; 结巴中文分词 + TF-IDF 关键词提取
       ;;terraform         ; 基础设施即代码
       ;;tmux              ; 与 tmux 交互的 API
       tree-sitter       ; 语法解析，和谐共处……
       ;;upload            ; 通过 ssh/ftp 将本地项目映射到远程

       :lang

       :ffi
       dyncall            ; libffi 动态 FFI：在运行时调用任意 C 函数

       :os
       (:if (featurep :system 'macos) macos)  ; 改善 macOS 兼容性
       tty               ; 改善终端 Emacs 体验

       :lang
       ;;ada               ; 强类型，我们（盲目）信任
       ;;(agda +local)     ; 类型的类型的类型……
       ;;beancount         ; 注意会计准则
       ;;(cc +lsp)         ; C > C++ == 1
       ;;clojure           ; 带 lisp 的 Java
       ;;common-lisp       ; 如果你看过一种 lisp，就看过了所有
       ;;coq               ; 证明即程序
       ;;crystal           ; 有 C 速度的 Ruby
       ;;csharp            ; Unity、.NET 和 Mono 的把戏
       ;;data              ; 配置/数据格式
       ;;(dart +flutter)   ; 绘制 UI，没别的了
       ;;dhall              ; 类型安全的配置语言
       ;;elixir            ; 正确实现的 Erlang
       ;;elm               ; 来杯 TEA 吗？
       emacs-lisp        ; 淹没在括号的海洋里
       ;;erlang            ; 属于更文明时代的优雅语言
       ;;ess               ; Emacs 说统计学
       ;;factor             ; 栈式编程语言
       ;;faust             ; 数字信号处理，但保留你的灵魂
       ;;fortran           ; 在 FORTRAN 中，GOD 是 REAL（除非声明为 INTEGER）
       ;;fsharp            ; ML 代表微软语言
       ;;fstar             ;（依赖）类型、（单子）效应和 Z3
       ;;gdscript          ; 你翘首以盼的语言
       ;;(go +lsp)         ; 潮人方言
       ;;(graphql +lsp)    ; 让查询歇会儿吧
       ;;(haskell +lsp)    ; 一种比我更懒的语言
       ;;hy                ; Scheme 的可读性，Python 的速度
       ;;idris             ; 一种你可以信赖的语言
       ;;json              ; 至少不是 XML
       ;;janet             ; 有趣的事实：Janet 就是我！
       ;;(java +lsp)       ; 腕管综合症的代言人
       ;;javascript        ; 入此门者，当放弃一切希望
       ;;julia             ; 更好、更快的 MATLAB
       ;;kotlin            ; 更好、更流畅的 Java(Script)
       (latex +cdlatex +fold) ; 用 Emacs 写论文从未如此有趣
       ;;lean              ; 给需要证明太多东西的人
       ;;ledger            ; 做你可被审计的人
       ;;lua               ; 从 1 开始索引？对，从 1 开始
       markdown          ; 写文档供人们忽略
       ;;nim               ; 速度如 C 的 Python + Lisp
       ;;nix               ; 我在此宣布："nix 更厉害！"
       ;;ocaml             ; 一只客观的骆驼
       ;;odin              ; C，去掉了它的暗器
       (org +journal +noter +pretty +pandoc)               ; 用纯文本组织你的平淡生活
       ;;php               ; Perl 不安全的弟弟
       ;;plantuml          ; 用来让更多人困惑的图表
       ;;graphviz          ; 用来让自己更困惑的图表
       ;;purescript        ; JavaScript，但是函数式
       ;;python            ; 美丽胜于丑陋
       ;;qt                ; 史上最"可爱"的 GUI 框架
       ;;racket            ; 领域特定语言的领域特定语言
       ;;raku              ; 曾用名 perl6
       ;;rest              ; Emacs 作为 REST 客户端
       ;;rst               ; ReST in peace（安息吧，ReST）
       ;;(ruby +rails)     ; 1.step {|i| p "Ruby is #{i.even? ? 'love' : 'life'}"}
       ;;(rust +lsp)       ; Fe2O3.unwrap().unwrap().unwrap().unwrap()
       ;;scala             ; Java，但很好
       ;;(scheme +guile)   ; 一个完全狡黠的 lisp 家族
       (sh +fish)                ; 她在 C xor 上叫卖 {ba,z,fi}sh 贝壳
       ;;sml                ; 标准 ML 语言
       ;;solidity          ; 你需要区块链吗？不需要。
       ;;swift             ; 谁需要表情符号变量？
       ;;terra             ; 地球与月球对齐，追求极致性能
       ;;web               ; 网络管道
       ;;yaml              ; JSON，但可读
       ;;zig               ; C，但更简单

       :email
       ;;(mu4e +org +gmail)
       ;;notmuch
       ;;(wanderlust +gmail)

       :app
       ;;calendar           ; 日历应用
       ;;emms               ; Emacs 多媒体系统
       ;;everywhere        ; *离开* Emacs！？你一定是在开玩笑
       ;;irc               ; 极客们的社交方式
       ;;(rss +org)        ; Emacs 作为 RSS 阅读器

       :config
       ;;literate           ; 文式编程配置
       (default +bindings +smartparens))
