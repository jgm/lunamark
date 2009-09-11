module(..., package.seeall)

local util = require "lunamark.util"

function writer(parser, options, references)
  local escape_latex_char = function(c)
                              -- TODO
                              return(c)
                            end
  local escape = function(s) --[=[ return (string.gsub(s, specialchars --[[TODO]], escape_latex_char)) ]=] return(s) end
  local spliton1 = function(s) local t = {}; for m in string.gmatch(s, "([^\001]+)") do table.insert(t,m) end; return t end
  local listitem = function(c) return {"\\item ", util.map(parser(writer, options, references).parse, spliton1(c)), "\n"} end
  local list = { tight = function(items) return util.map(listitem, items) end,
                 loose = function(items) return util.map(function(c) return listitem(c .. "\n\n") end, items) end }
  return {
  rawhtml = function(c) return "" end,
  linebreak = function() return "\\\\\n" end,
  str = escape,
  entity = function(c) return "?" --[[TODO - convert entity to LaTeX]] end,
  space = function() return " " end,
  emph = function(c) return {"\\emph{", c, "}"} end,
  code = function(c) local delim = "!" --[[TODO - choose one not in c]] return {"\\verb", delim, c, delim} end,
  strong = function(c) return {"\\textbf{", c, "}"} end,
  heading = function(lev,c) return {"\\", string.rep("sub",lev - 1), "section{", c, "}\n"} end,
  bulletlist = { tight = function(c) return {"\\begin{itemize}\n", list.tight(c), "\\end{itemize}\n"} end,
                 loose = function(c) return {"\\begin{itemize}\n", list.loose(c), "\\end{itemize}\n"} end },
  orderedlist = { tight = function(c) return {"\\begin{enumerate}\n", list.tight(c), "\\end{enumerate}\n"} end,
                  loose = function(c) return {"\\end{enumerate}\n", list.loose(c), "\\end{enumerate}\n"} end },
  para = function(c) return {c, "\n"} end,
  plain = function(c) return c end,
  blockquote = function(c) return {"\\begin{quote}\n", parser(writer, options, references).parse(table.concat(c,"\n")), "\\end{quote}\n"} end,
  verbatim = function(c) return {"\\begin{verbatim}\n", escape(table.concat(c,"")), "\\end{verbatim}\n"} end,
  hrule = function() return "---\n" --[[TODO real hrule]] end,
  link = function(lab,src,tit)
           local a = "<a href=\"" .. escape(src) .. "\""
           if string.len(tit) > 0 then a = a .. " title=\"" .. escape(tit) .. "\"" end
           a = a .. ">"
           return {a, lab.inlines, "</a>"}
         end,
  image = function(lab,src,tit)
           local a = "<img src=\"" .. escape(src) .. "\" alt=\"" .. escape(lab.raw) .. "\""
           if string.len(tit) > 0 then a = a .. " title=\"" .. escape(tit) .. "\"" end
           a = a .. " />"
           return a
         end,
  email_link = function(addr)
                 local obfuscated_addr = obfuscate(addr)
                 return("<a href=\"" .. obfuscate("mailto:") .. obfuscated_addr .. "\">" .. obfuscated_addr .. "</a>")
               end,
  reference = function(lab,src,tit)
                return {key = util.normalize_label(lab.raw), label = lab.inlines, source = src, title = tit}
              end
  }
end

