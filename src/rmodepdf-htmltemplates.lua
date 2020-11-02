local xmltransform = require "rmodepdf-xmlproc.lua"

xmltransform.add_action("html", [[
\documentclass{article}
\begin{document}
%s
\end{document}
]])

xmltransform.add_action("p", [[

]])

return xmltransform
