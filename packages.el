;; -*- no-byte-compile: t; -*-
;;; $DOOMDIR/packages.el

;; 中文输入
(package! fcitx)

;; 界面
(package! spacious-padding)

;; 阅读
(package! nov)                   ;; EPUB 阅读器
(package! org-pdftools)          ;; 在 Org 中内嵌 PDF
(package! djvu)                  ;; DJVU 文档支持

;; 写作
(package! super-save)
(package! palimpsest)
(package! olivetti)

;; 中文感知导航与补全
(package! ace-pinyin)
(package! evil-pinyin)

;; 萌典使用 Emacs 内置 sqlite，无外部包依赖。
