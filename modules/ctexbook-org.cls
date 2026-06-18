\NeedsTeXFormat{LaTeX2e}
\ProvidesClass{ctexbook-org}[2025/01/01 Custom ctexbook class for Org export]

\LoadClass[UTF8,scheme=chinese,fontset=none,11pt,a4paper,twoside]{ctexbook}

%% ─── 字体（手动配置，替代 fandol + Latin Modern）─
\setmainfont{TeX Gyre Termes}[NFSSFamily=ctexbook-termes]
\setmonofont{DejaVu Sans Mono}[NFSSFamily=ctexbook-dejavu-mono]
\setCJKmainfont{Noto Serif CJK SC}
\setCJKsansfont{Noto Sans CJK SC}
\setCJKmonofont{Noto Sans CJK SC}

%% Org 的 ox-latex 会在 preamble 中插入 \usepackage[T1]{fontenc}，
%% 覆盖 fontspec 的 TU 编码 → 字体回退 Computer Modern（缺 →，
%% microtype 崩溃）。提前注册 T1 字形避免回退。
\makeatletter
\newcommand*\ctexbook@DeclareT[2]{%
  \DeclareFontFamily{T1}{#1}{}%
  \DeclareFontShape{T1}{#1}{m}{n}  {<->"#2/OT:script=latn;"}{}%
  \DeclareFontShape{T1}{#1}{m}{it} {<->"#2/I/OT:script=latn;"}{}%
  \DeclareFontShape{T1}{#1}{b}{n}  {<->"#2/B/OT:script=latn;"}{}%
  \DeclareFontShape{T1}{#1}{b}{it} {<->"#2/BI/OT:script=latn;"}{}%
  \DeclareFontShape{T1}{#1}{bx}{n}  {<->ssub*#1/b/n}{}%
  \DeclareFontShape{T1}{#1}{bx}{it}{<->ssub*#1/b/it}{}%
}
\ctexbook@DeclareT{ctexbook-termes}{TeX Gyre Termes}
\ctexbook@DeclareT{ctexbook-dejavu-mono}{DejaVu Sans Mono}
\makeatother

%% 文档开头强制切回 TU 编码（抵消 fontenc[T1] 的影响）
\AtBeginDocument{%
  \ifxetex
    \renewcommand{\encodingdefault}{TU}%
    \fontencoding{TU}\selectfont
  \fi
}

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
