;;; $DOOMDIR/cli.el -*- lexical-binding: t; -*-
;;;
;;; 在 `doom sync' 等 CLI 操作中被 Doom 自动加载（通过 bin/doom:300）。
;;; 在普通 Emacs 会话中不加载，除非通过 autoload 触发的命令。
;;;
;;; 本文件仅作记录。编译逻辑已迁移到 config.el，因为编译需要在 Emacs
;;; 启动后进行（模块宏就绪），而 CLI 上下文中模块宏不可用。
;;;
;;; 关键文件：
;;;   config.el            —— 编译逻辑入口 + doom-after-init-hook 注册
;;;   ~/.local/etc/private-config-hashes —— SHA-256 缓存
