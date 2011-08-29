-- (c) 2009-2011 John MacFarlane. Released under MIT license.
-- See the file LICENSE in the source for details.

module("lunamark.writer.latex", package.seeall)

local tex = require("lunamark.writer.tex")
local util = require("lunamark.util")
local gsub = string.gsub
local format = string.format

function new(options)
  local LaTeX = tex.new(options)

  function LaTeX.code(s)
    return format("\\texttt{%s}", LaTeX.string(s))
  end

  function LaTeX.link(lab,src,tit)
    return format("\\href{%s}{%s}", LaTeX.string(src), lab)
  end

  function LaTeX.image(lab,src,tit)
    return format("\\includegraphics{%s}", LaTeX.string(src))
  end

  function LaTeX.listitem(s)
    return format("\\item %s\n",s)
  end

  function LaTeX.bulletlist(s)
    return format("\\begin{itemize}\n%s\n\\end{itemize}",s)
  end

  function LaTeX.orderedlist(s)
    return format("\\begin{enumerate}\n%s\n\\end{enumerate}",s)
  end

  function LaTeX.emphasis(s)
    return format("\\emph{%s}",s)
  end

  function LaTeX.strong(s)
    return format("\\textbf{%s}",s)
  end

  function LaTeX.blockquote(s)
    return format("\\begin{quote}\n%s\n\\end{quote}", s)
  end

  function LaTeX.verbatim(s)
    return format("\\begin{verbatim}\n%s\\end{verbatim}", s)
  end

  function LaTeX.section(s,level,contents)
    local cmd
    if level == 1 then
      cmd = "\\section"
    elseif level == 2 then
      cmd = "\\subsection"
    elseif level == 3 then
      cmd = "\\subsubsection"
    elseif level == 4 then
      cmd = "\\paragraph"
    elseif level == 5 then
      cmd = "\\subparagraph"
    else
      cmd = ""
    end
    return format("%s{%s}%s%s", cmd, s, LaTeX.interblocksep, contents)
  end

  LaTeX.hrule = "\\hspace{\\fill}\\rule{.6\\linewidth}{0.4pt}\\hspace{\\fill}"

  return LaTeX
end
