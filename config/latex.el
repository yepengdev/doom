;;; $DOOMDIR/config/latex.el -*- lexical-binding: t; -*-

;; ─── AUCTeX ──────────────────────────────────────────────────────
;; XeLaTeX as default engine (for Chinese / OpenType font support)
(setq-default TeX-engine 'xetex)

;; ─── Org → LaTeX Export (ox-latex) ───────────────────────────────
(defun my/org-latex-format-headline (todo todo-type priority text tags _info)
  "Format headline with refined styling for LaTeX export.
Uses \\texorpdfstring so PDF bookmarks don't leak raw color code."
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
  ;; latexmk: intelligent multi-pass, avoids manual 4-step process
  (org-latex-pdf-process
   '("latexmk -xelatex -shell-escape -interaction=nonstopmode -f -output-directory=%o %f"))
  (org-latex-logfiles-extensions
   '("lof" "lot" "tex~" "aux" "idx" "log" "out" "toc" "nav" "snm"
     "vrb" "dvi" "fdb_latexmk" "blg" "brf" "fls" "entoc" "ps" "spl" "bbl" "tex" "bcf"))
  ;; Remove XeLaTeX-incompatible / redundant default packages.
  ;; inputenc/fontenc → not needed (XeLaTeX handles UTF-8/OpenType natively).
  ;; hyperref → loaded manually in template for precise placement.
  (org-latex-default-packages-alist
   (cl-remove '("" "hyperref" t)
    (cl-remove '("T1" "fontenc" t)
     (cl-remove '("AUTO" "inputenc" t)
                org-latex-default-packages-alist
                :test #'equal)
              :test #'equal)
            :test #'equal))
  :config
  (add-to-list 'org-latex-classes
               '("ctexbook"
                 "\\documentclass[UTF8,scheme=chinese,fontset=fandol,11pt,a4paper,twoside]{ctexbook}

%% ─── 全部不编号（保留目录/PDF 书签）─────────────
\\setcounter{secnumdepth}{0}

%% ─── 颜色（TODO 关键词着色）────────────────────
\\usepackage{xcolor}

%% ─── 微排版（XeLaTeX 下仅支持 protrusion）─────
\\usepackage[final]{microtype}

%% ─── 现代排版：句末单空格 ───────────────────────
\\frenchspacing

%% ─── 页面布局 ───────────────────────────────────
\\usepackage[top=2.5cm,bottom=2.5cm,inner=3cm,outer=2cm,headheight=14pt]{geometry}

%% ─── 页眉页脚 ───────────────────────────────────
\\usepackage{fancyhdr}
\\pagestyle{fancy}
\\fancyhf{}
\\fancyhead[LE]{\\leftmark}
\\fancyhead[RO]{\\rightmark}
\\fancyfoot[LE,RO]{\\thepage}
\\renewcommand{\\headrulewidth}{0.4pt}

%% ─── 章节标题 ───────────────────────────────────
\\ctexset{
  chapter={
    format={\\huge\\bfseries},
    name={},
    number={},
    beforeskip=1.5em,
    afterskip=1em,
    fixskip=true,
  },
  section={
    format={\\Large\\bfseries\\raggedright},
    beforeskip=1em plus .2em minus .1em,
    afterskip=.5em plus .1em,
  },
  subsection={
    format={\\large\\bfseries\\raggedright},
    beforeskip=.8em plus .2em minus .1em,
    afterskip=.4em plus .1em,
  },
}

[DEFAULT-PACKAGES]
[PACKAGES]

%% ─── 超链接 ─────────────────────────────────────
\\usepackage{hyperref}
\\hypersetup{
  colorlinks=true,
  linkcolor=blue!70!black,
  citecolor=teal!80!black,
  urlcolor=blue!70!black,
}
\\usepackage{xurl}

%% ─── 代码环境 ──────────────────────────────────
\\usepackage{fvextra}
\\DefineVerbatimEnvironment{verbatim}{Verbatim}{
  breaklines=true,
  breakanywhere=true,
  breaksymbol={},
  breakautoindent=false
}
\\usepackage{minted}
\\setminted{
  fontsize=\\footnotesize,
  linenos,
  breaklines,
  frame=leftline,
  framesep=2mm,
  bgcolor=lightgray!10,
}

%% ─── 表格 ───────────────────────────────────────
\\usepackage{booktabs}

%% ─── 图表标题 ───────────────────────────────────
\\usepackage[font=small,labelfont=bf]{caption}

%% ─── 列表间距 ──────────────────────────────────
\\usepackage{enumitem}
\\setlist{nosep}

%% ─── 行距 ──────────────────────────────────────
\\linespread{1.3}"
                 ("\\chapter{%s}" . "\\chapter*{%s}")
                 ("\\section{%s}" . "\\section*{%s}")
                 ("\\subsection{%s}" . "\\subsection*{%s}")))
  (setq org-latex-default-class "ctexbook"))
