-- LaTeX writer for lunamark

local Tex = require("lunamark.writer.tex")
local util = require("lunamark.util")

local gsub = string.gsub

local Latex = util.table_copy(Tex)

local format = string.format

Latex.options = { }

function Latex.code(s)
  return format("\\texttt{%s}", Latex.string(s))
end

function Latex.link(lab,src,tit)
  return format("\\href{%s}{%s}", Latex.string(src), lab)
end

function Latex.image(lab,src,tit)
  return format("\\includegraphics{%s}", Latex.string(src))
end

function Latex.listitem(s)
  return format("\\item %s\n",s)
end

function Latex.bulletlist(s)
  return format("\\begin{itemize}\n%s\n\\end{itemize}",s)
end

function Latex.orderedlist(s)
  return format("\\begin{enumerate}\n%s\n\\end{enumerate}",s)
end

function Latex.emphasis(s)
  return format("\\emph{%s}",s)
end

function Latex.strong(s)
  return format("\\textbf{%s}",s)
end

function Latex.blockquote(s)
  return format("\\begin{quote}\n%s\n\\end{quote}", s)
end

function Latex.verbatim(s)
  return format("\\begin{verbatim}\n%s\\end{verbatim}", s)
end

function Latex.section(s,level,contents)
  return format("\\%ssection{%s}%s%s", string.rep("sub",level-1), s,
          Latex.interblocksep, contents)
end

Latex.hrule = "\\hspace{\\fill}\\rule{.6\\linewidth}{0.4pt}\\hspace{\\fill}"

return Latex
