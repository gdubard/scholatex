\NeedsTeXFormat{LaTeX2e}
\ProvidesClass{scholatex}[2026-07-03 v2.5 A tag-based language for print-ready teaching worksheets]
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
% precision: default number of decimals a computed #{...} value is rounded
% to for display. -1 means "no rounding" (print the number as computed).
\DeclareStringOption[-1]{precision}
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
\usepgfplotslibrary{fillbetween}
\setlength{\JustifyingParindent}{0pt}
\newlength{\scholatextab}
\setlength{\scholatextab}{\scholatex@tabwidth mm}
\newlength{\scholatexline}
\setlength{\scholatexline}{\scholatex@lineheight mm}
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
\directlua{scholatex = require("scholatex")}
\directlua{scholatex.config = scholatex.config or {}; scholatex.config.padding = "\scholatex@padding"; scholatex.config.lang = "\scholatex@lang"; scholatex.config.precision = tonumber("\scholatex@precision")}
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
\AtBeginDocument{%
	\providecommand\fint{}%
	\renewcommand\fint{\mathchoice
		{\rlap{\,\,\raisebox{0.32em}{\scalebox{0.7}{$-$}}}\!\int}%
		{\rlap{\,\,\raisebox{0.30em}{\scalebox{0.6}{$-$}}}\!\int}%
		{\rlap{\,\raisebox{0.28em}{\scalebox{0.5}{$-$}}}\!\int}%
		{\rlap{\,\raisebox{0.28em}{\scalebox{0.5}{$-$}}}\!\int}}%
	% U+25B1 (parallelogram) is missing from Latin Modern Math, and
	% unicode-math binds \parallelogram to that absent glyph as a math char
	% (not a redefinable macro). The module emits \scholatexparallelogram
	% instead, drawn with tikz (already loaded via pgfplots/tcolorbox).
	\providecommand\scholatexparallelogram{\mathord{\tikz[baseline=-0.5ex,%
		line width=0.5pt]{\draw (0,0) -- (0.28,0) -- (0.36,0.22)%
		-- (0.08,0.22) -- cycle;}}}%
}
\setlength{\parindent}{0pt}
\setlength{\parskip}{0.5em}
\linespread{\scholatex@linespread}
\setlength{\lineskiplimit}{3pt}
\setlength{\lineskip}{3pt}
\AtBeginDocument{%
	\directlua{
	% At this point the file LuaTeX is reading IS the main document, so
	% status.filename names it exactly -- robust against -jobname=..., a
	% .ltx extension, or spaces. jobname .. ".tex" stays as the fallback.
	local path = status and status.filename
	local f = path and io.open(path, "r")
	if not f then
	path = tex.jobname .. ".tex"
	f = io.open(path, "r")
	end
	if not f then
	tex.error("scholatex.cls: cannot reopen the source file to read the body"
	.. " (tried '" .. tostring(path) .. "'). If you used -jobname, the"
	.. " class still needs to find the actual .tex source")
	else
	local whole = f:read("*a"); f:close()
	local body, tail = whole:match("\string\\begin{document}(.-)\string\\end{document}(.*)$")
	if not body then
	tex.error("scholatex.cls: begin/end document not found")
	else
	% The match is non-greedy: a literal \end{document} mentioned in the
	% body (a document ABOUT LaTeX) would silently truncate everything
	% after it. Detect the leftover and say so instead of staying quiet.
	if tail and tail:find("\string\\end{document}", 1, true) then
	texio.write_nl("term and log", "scholatex: warning: another"
	.. " \string\\end{document} appears after the first one; the body was"
	.. " cut at the FIRST occurrence. If you meant to mention the token"
	.. " in prose, break it up (e.g. \string\\end{doc*ument}).")
	end
	scholatex.inject(body)
	end
	end
}%
\end{document}%
}
