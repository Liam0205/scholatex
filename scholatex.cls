\NeedsTeXFormat{LaTeX2e}
\ProvidesClass{scholatex}[2026-06-23 v2.1 A tag-based language for print-ready teaching worksheets]
% scholatex --- a lightweight tag-based markup language for LuaLaTeX
% Copyright (C) 2026 DUBARD Gérard
%
% This program is free software: you can redistribute it and/or modify it
% under the terms of the GNU General Public License version 3 as published
% by the Free Software Foundation. This program is distributed WITHOUT ANY
% WARRANTY. See the LICENSE file or <https://www.gnu.org/licenses/> for
% the full text of the license.
%
\RequirePackage{kvoptions}
\SetupKeyvalOptions{family=scholatex, prefix=scholatex@}
\DeclareStringOption[20]{margins}
\DeclareStringOption[Latin Modern Roman]{font}
\DeclareStringOption[11]{size}
\DeclareStringOption[Latin Modern Math]{mathfont}
\DeclareStringOption[img]{imgdir}
\DeclareStringOption[8]{tabwidth}
\DeclareStringOption[8]{lineheight}
\DeclareStringOption[1.0]{linespread}
\DeclareStringOption[100]{scriptscale}
\DeclareStringOption[2]{padding}
\DeclareStringOption[fr]{lang}
\DeclareBoolOption[false]{untrusted}
\DeclareDefaultOption{\PassOptionsToClass{\CurrentOption}{extarticle}}
\ProcessKeyvalOptions*
\LoadClass[\scholatex@size pt, a4paper]{extarticle}
\RequirePackage{amsmath}
\RequirePackage{array}
\RequirePackage{graphicx}
\RequirePackage[export]{adjustbox}
\RequirePackage{xstring}
\IfEndWith{\scholatex@imgdir}{/}{%
	\edef\scholatex@imgpath{\scholatex@imgdir}%
}{%
	\edef\scholatex@imgpath{\scholatex@imgdir/}%
}
\def\scholatex@graphicspaths{{./}}
\@for\scholatex@dir:=\scholatex@imgdir\do{%
	\StrDel{\scholatex@dir}{ }[\scholatex@dir]%
	\IfEndWith{\scholatex@dir}{/}{%
		\edef\scholatex@graphicspaths{\scholatex@graphicspaths{\scholatex@dir}}%
	}{%
		\edef\scholatex@graphicspaths{\scholatex@graphicspaths{\scholatex@dir/}}%
	}%
}
\expandafter\graphicspath\expandafter{\scholatex@graphicspaths}
\RequirePackage{tabularx}
\RequirePackage{tabularray}
\RequirePackage{multirow}
\RequirePackage[svgnames]{xcolor}
\RequirePackage{colortbl}
\RequirePackage{enumitem}
\RequirePackage{amssymb}
\RequirePackage{ragged2e}
\RequirePackage{needspace}
\RequirePackage[skins,breakable,raster]{tcolorbox}
\tcbuselibrary{poster}
\RequirePackage{tkz-tab}
\RequirePackage{pgfplots}
\pgfplotsset{compat=1.18}
\setlength{\JustifyingParindent}{0pt}
\newlength{\scholatextab}
\setlength{\scholatextab}{\scholatex@tabwidth mm}
\newlength{\scholatexline}
\setlength{\scholatexline}{\scholatex@lineheight mm}
% Headings carry no extra space above or below: only the normal interline
% spacing separates them from surrounding text, identical for every level.
% Their appearance (colour, size, a preceding line skip) is set per document
% with a style alias, e.g. let s1 = <line navy b section>.
\RequirePackage{titlesec}
\titlespacing*{\section}      {0pt}{0pt}{0pt}
\titlespacing*{\subsection}   {0pt}{0pt}{0pt}
\titlespacing*{\subsubsection}{0pt}{0pt}{0pt}
\edef\scholatex@scriptfactor{\strip@pt\dimexpr\scholatex@scriptscale pt/100\relax}
\newcommand{\scholatexscript}[2]{\raisebox{#1}{\scalebox{\scholatex@scriptfactor}{#2}}}
\RequirePackage{fontspec}
\RequirePackage{unicode-math}
\RequirePackage{geometry}
\StrCount{\scholatex@margins}{,}[\scholatex@ncommas]
\ifnum\scholatex@ncommas>0\relax
\StrCut{\scholatex@margins}{,}\scholatex@mt\scholatex@mrest
\StrCut{\scholatex@mrest}{,}\scholatex@mr\scholatex@mrest
\StrCut{\scholatex@mrest}{,}\scholatex@mb\scholatex@ml
\geometry{top=\scholatex@mt mm, right=\scholatex@mr mm, bottom=\scholatex@mb mm, left=\scholatex@ml mm}%
\else
\geometry{margin=\scholatex@margins mm}%
\fi
% Les couleurs suivent une règle unique : une couleur est l'un des 151 noms
% CSS / svgnames écrit en CamelCase (Navy, Red, Gray, SteelBlue...). Aucun
% raccourci minuscule n'est défini.
\directlua{scholatex = require("scholatex")}
\directlua{scholatex.config = scholatex.config or {}; scholatex.config.padding = "\scholatex@padding"; scholatex.config.lang = "\scholatex@lang"}
\ifscholatex@untrusted
  \directlua{scholatex.config.untrusted = true}
\else
  \directlua{scholatex.config.untrusted = false}
\fi
\IfFontExistsTF{\scholatex@font}{%
	\setmainfont{\scholatex@font}%
}{%
	\directlua{scholatex.respace("scholatex@font")}%
	\IfFontExistsTF{\scholatex@font}{%
		\setmainfont{\scholatex@font}%
	}{%
		\ClassWarningNoLine{scholatex}{Font '\scholatex@font' not found, falling back to Latin Modern Roman}%
		\setmainfont{Latin Modern Roman}%
	}%
}
\IfFontExistsTF{\scholatex@mathfont}{%
	\setmathfont{\scholatex@mathfont}%
}{%
	\directlua{scholatex.respace("scholatex@mathfont")}%
	\IfFontExistsTF{\scholatex@mathfont}{%
		\setmathfont{\scholatex@mathfont}%
	}{%
		\ClassWarningNoLine{scholatex}{Math font '\scholatex@mathfont' not found, falling back to Latin Modern Math}%
		\setmathfont{Latin Modern Math}%
	}%
}
% unicode-math provides \int \iint \iiint \oint \sum \prod natively.
% Latin Modern Math has no average-integral glyph (U+2A0F), so \fint is
% built: an integral sign crossed by a short horizontal bar. Avoids
% esint/commath, which clash with unicode-math.
\AtBeginDocument{%
	\providecommand\fint{}%
	\renewcommand\fint{\mathchoice
		{\rlap{\,\,\raisebox{0.32em}{\scalebox{0.7}{$-$}}}\!\int}%
		{\rlap{\,\,\raisebox{0.30em}{\scalebox{0.6}{$-$}}}\!\int}%
		{\rlap{\,\raisebox{0.28em}{\scalebox{0.5}{$-$}}}\!\int}%
		{\rlap{\,\raisebox{0.28em}{\scalebox{0.5}{$-$}}}\!\int}}%
}
\setlength{\parindent}{0pt}
\setlength{\parskip}{0.5em}
% Keep tall lines (fractions, integrals) from touching the line above: if two
% consecutive lines would come closer than 3pt, TeX inserts that much glue.
% Ordinary text is unaffected (its lines are already further apart); only
% lines with tall maths get the extra air, automatically.
% Optional global line spacing (1.0 = default, 1.5 = one-and-a-half, etc.).
% This is the manual control; \lineskiplimit above is the automatic floor that
% keeps tall lines from touching even at linespread=1.0.
\linespread{\scholatex@linespread}
\setlength{\lineskiplimit}{3pt}
\setlength{\lineskip}{3pt}
\AtBeginDocument{%
	\directlua{
	local f = io.open(tex.jobname .. ".tex", "r")
	local whole = f:read("*a"); f:close()
	local body = whole:match("\string\\begin{document}(.-)\string\\end{document}")
	if not body then
	tex.error("scholatex.cls: begin/end document not found")
	else
	scholatex.inject(body)
	end
}%
\end{document}%
}