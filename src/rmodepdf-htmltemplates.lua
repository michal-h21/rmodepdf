local xmltransform = require "rmodepdf-xmlproc.lua"

xmltransform.add_action("html", [[
\documentclass{article}
\usepackage{graphicx,csquotes,cals}
\begin{document}
%s
\end{document}
]])

-- this trick is used to print @{} in TeX: @@{}{}
xmltransform.add_action("head", [[
\noindent\begin{tabular}{@@{}{}p{.2\textwidth}p{.75\textwidth}@@{}{}}
%s
\end{tabular}\par\bigskip

\tableofcontents
]])

xmltransform.add_action("meta", [[\textbf{@{name}} & @{content}\\ ]])
xmltransform.add_action("title", [[\textbf{title} & %s\\ ]])
xmltransform.add_action("img", [[\includegraphics[width=\textwidth]{@{src}}]])

xmltransform.add_action("h1", [[\addcontentsline{toc}{section}{%s}\section*{%s}]])
xmltransform.add_action("h2", [[\addcontentsline{toc}{subsection}{%s}\subsection*{%s}]])
-- don't add lower sectioning level than subsection
xmltransform.add_action("h3", [[\addcontentsline{toc}{subsubsection}{%s}\subsubsection*{%s}]])
xmltransform.add_action("h4", [[\addcontentsline{toc}{subsubsection}{%s}\subsubsection*{%s}]])
xmltransform.add_action("h5", [[\addcontentsline{toc}{subsubsection}{%s}\subsubsection*{%s}]])
xmltransform.add_action("h6", [[\addcontentsline{toc}{subsubsection}{%s}\subsubsection*{%s}]])

xmltransform.add_action("i", [[\textit{%s}]])
xmltransform.add_action("em", [[\emph{%s}]])
xmltransform.add_action("b", [[\textbf{%s}]])
xmltransform.add_action("strong", [[\textbf{%s}]])
xmltransform.add_action("tt", [[\texttt{%s}]])
xmltransform.add_action("samp", [[\texttt{%s}]])
xmltransform.add_action("kbd", [[\texttt{%s}]])
xmltransform.add_action("var", [[\texttt{%s}]])
xmltransform.add_action("dfn", [[\texttt{%s}]])
xmltransform.add_action("code", [[\texttt{%s}]])
xmltransform.add_action("a", [[\textit{%s}\footnote{\texttt{@{href}}}]])


local itemize = [[
\begin{itemize}
%s
\end{itemize}
]]
xmltransform.add_action("ul", itemize)
xmltransform.add_action("menu", itemize)
xmltransform.add_action("ol", [[
\begin{enumerate}
%s
\end{enumerate}
]])

xmltransform.add_action("dl", [[
\begin{description}
%s
\end{description}
]])


xmltransform.add_action("li", "\\item %s\n")
xmltransform.add_action("dt", "\\item[%s] ")

local quote = [[
\begin{quotation}
%s
\end{quotation}
]]

xmltransform.add_action("blockquote", quote)
xmltransform.add_action("q", "\\enquote{%s}")
xmltransform.add_action("abbr", "%s\\footnote{@{title}}")
xmltransform.add_action("sup", "\\textsuperscript{%s}")
xmltransform.add_action("sub", "\\textsubscript{%s}")

xmltransform.add_action("table", [[
\begin{calstable}
%s
\end{calstable}
]])

xmltransform.add_action("tr", "\\brow %s \\erow")
xmltransform.add_action("td", "\\cell{%s}")
xmltransform.add_action("th", "\\cell{%s}")


-- we don't want to use verbatim, as all special characters are already escaped
-- we just need to use a trick to support spaces at the start of lines
xmltransform.add_action("pre", [[{\obeylines\ttfamily\catcode`\ =\active\def {\ }%%
%s}]])


xmltransform.add_action("p", [[%s
]])

return xmltransform