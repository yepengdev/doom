\NeedsTeXFormat{LaTeX2e}
\ProvidesClass{ctexbook-org}[2025/01/01 Custom ctexbook class for Org export]

\LoadClass[UTF8,scheme=chinese,fontset=fandol,11pt,a4paper,twoside]{ctexbook}

%% ─── 全部不编号（保留目录/PDF 书签）────────────
\setcounter{secnumdepth}{0}

%% ─── 颜色（TODO 关键词着色）────────────────────
\RequirePackage{xcolor}

%% ─── 微排版（XeLaTeX 下仅支持 protrusion）─────
\RequirePackage[final]{microtype}

%% ─── 现代排版：句末单空格 ───────────────────────
\frenchspacing

%% ─── 页面布局 ───────────────────────────────────
\RequirePackage[top=2.5cm,bottom=2.5cm,inner=3cm,outer=2cm,headheight=14pt]{geometry}

%% ─── 页眉页脚 ───────────────────────────────────
\RequirePackage{fancyhdr}
\pagestyle{fancy}
\fancyhf{}
\fancyhead[LE]{\leftmark}
\fancyhead[RO]{\rightmark}
\fancyfoot[LE,RO]{\thepage}
\renewcommand{\headrulewidth}{0.4pt}

%% ─── 章节标题 ───────────────────────────────────
\ctexset{
  chapter={
    format={\huge\bfseries},
    name={},
    number={},
    beforeskip=1.5em,
    afterskip=1em,
    fixskip=true,
  },
  section={
    format={\Large\bfseries\raggedright},
    beforeskip=1em plus .2em minus .1em,
    afterskip=.5em plus .1em,
  },
  subsection={
    format={\large\bfseries\raggedright},
    beforeskip=.8em plus .2em minus .1em,
    afterskip=.4em plus .1em,
  },
}

%% ─── 超链接 ─────────────────────────────────────
\RequirePackage{hyperref}
\hypersetup{
  colorlinks=true,
  linkcolor=blue!70!black,
  citecolor=teal!80!black,
  urlcolor=blue!70!black,
}
\RequirePackage{xurl}

%% ─── 代码环境 ──────────────────────────────────
\RequirePackage{fvextra}
\DefineVerbatimEnvironment{verbatim}{Verbatim}{
  breaklines=true,
  breakanywhere=true,
  breaksymbol={},
  breakautoindent=false
}
\RequirePackage{minted}
\setminted{
  fontsize=\footnotesize,
  linenos,
  breaklines,
  frame=leftline,
  framesep=2mm,
  bgcolor=lightgray!10,
}

%% ─── 表格 ───────────────────────────────────────
\RequirePackage{booktabs}

%% ─── 图表标题 ───────────────────────────────────
\RequirePackage[font=small,labelfont=bf]{caption}

%% ─── 列表间距 ──────────────────────────────────
\RequirePackage{enumitem}
\setlist{nosep}

%% ─── 行距 ──────────────────────────────────────
\linespread{1.3}
\endinput
