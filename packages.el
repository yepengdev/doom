;; -*- no-byte-compile: t; -*-
;;; $DOOMDIR/packages.el

;; 中文输入
(package! fcitx)

;; 界面
(package! spacious-padding)

;; 笔记 / 卡片盒笔记法
(package! denote)
(package! denote-org)
(package! denote-sequence)
(package! denote-explore)
(package! denote-journal)        ;; denote 日记扩展
(package! denote-menu)           ;; denote 菜单/浏览界面
(package! consult-notes)         ;; 通过 consult 搜索笔记

;; 阅读
(package! nov)                   ;; EPUB 阅读器
(package! org-pdftools)          ;; 在 Org 中内嵌 PDF

;; 写作
(package! super-save)
(package! palimpsest)

;; 中文感知导航与补全
(package! ace-pinyin)
(package! evil-pinyin)
