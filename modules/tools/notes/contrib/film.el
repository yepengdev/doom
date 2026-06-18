;;; modules/tools/notes/contrib/film.el -*- lexical-binding: t; -*-
;;;###if (modulep! +film)

;; ─── 快速录入（Org-Capture）─────────────────────────────────────────
;; 极简字段：仅影片名 + 导演 + 年份。评分/国家等详细信息在
;; Denote 笔记中填写。

(after! org-capture
  (add-to-list 'org-capture-templates
               '("f" "观影快记" entry
                 (file+datetree "~/org/film-diary.org" "观影日记")
                 "* %^{影片名称}    :film:
:PROPERTIES:
:DIRECTOR: %^{导演}
:YEAR:     %^{年份}
:END:

%?"
                 :empty-lines 1
                 :jump-to-captured t)
               t))

;; ─── 键绑定 ─────────────────────────────────────────────────────────
;;
;; SPC r d v = Film→Writing，与 notes 模块的 SPC r d 前缀自然融合。
;; v = video，表示观影。
;; 新增 m/M 一键迁移旧笔记，e 导出写作素材。

(map! :leader
      (:prefix-map ("r d v" . "Film→Writing")
       :desc "New film note"         "n" #'my/denote-new-film
       :desc "Search film"           "s" #'my/denote-find-film
       :desc "Open index"            "i" #'my/open-film-index
       :desc "Add to index"          "a" #'my/film-add-to-index
       :desc "Film stats"            "c" #'my/film-stats
       :desc "Migrate this note"     "m" #'my/film-migrate-note
       :desc "Migrate all notes"     "M" #'my/film-migrate-all
       :desc "Export writing notes"  "e" #'my/film-export-writing-notes))
