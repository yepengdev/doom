;;; $DOOMDIR/modules/tools/jieba/doctor.el -*- lexical-binding: t; -*-

(assert! (file-exists-p (expand-file-name "c-modules/jieba-module.so" doom-user-dir))
          "jieba-module.so 不存在。请执行 make -C c-modules/ jieba 编译。")
