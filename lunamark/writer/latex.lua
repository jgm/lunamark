local util = require "lunamark.util"

local function writer(parser, options)
  local escape_latex_char = function(c)
                              if c == "{" or c == "}" or c == "$" or c == "%" or
                                 c == "&" or c == "_" or c == "#" then
                                 return("\\"..c)
                              elseif c == "^" then
                                 return("{\\^}")
                              elseif c == "\\" then
                                 return("{\\textbackslash}")
                              elseif c == "~" then
                                 return("\\ensuremath{\\sim}")
                              elseif c == "|" then
                                 return("{\\textbar}")
                              elseif c == "<" then
                                 return("{\\textless}")
                              elseif c == ">" then
                                 return("{\\textgreater}")
                              else
                                 return(c)
                              end
                            end
  local escape = function(s) return (string.gsub(s, "[{}$%&_#^\\~|<>]", escape_latex_char)) end
  local spliton1 = function(s) local t = {}; for m in string.gmatch(s, "([^\001]+)") do table.insert(t,m) end; return t end
  local listitem = function(c) return {"\\item ", util.map(parser(writer, options), spliton1(c)), "\n"} end
  local list = { tight = function(items) return util.map(listitem, items) end,
                 loose = function(items) return util.map(function(c) return listitem(c .. "\n\n") end, items) end }
  local symbolnotin = function(s)
                        local symbols = {"!","@","#","$","%","^","&","*","(",")","?","+",".",",",";","|"};
                        for k,v in pairs(symbols) do
                          if not string.find(s,"%"..v) then return v end
                        end
                        return "!"
                      end 
  return {
  rawhtml = function(c) return "" end,
  linebreak = function() return "\\\\\n" end,
  str = escape,
  entity = function(c) return "?" --[[TODO - convert entity to LaTeX]] end,
  space = function() return " " end,
  emph = function(c) return {"\\emph{", c, "}"} end,
  code = function(c) local delim = symbolnotin(c) return {"\\verb", delim, c, delim} end,
  strong = function(c) return {"\\textbf{", c, "}"} end,
  heading = function(lev,c) return {"\\", string.rep("sub",lev - 1), "section{", c, "}\n"} end,
  bulletlist = { tight = function(c) return {"\\begin{itemize}\n", list.tight(c), "\\end{itemize}\n"} end,
                 loose = function(c) return {"\\begin{itemize}\n", list.loose(c), "\\end{itemize}\n"} end },
  orderedlist = { tight = function(c) return {"\\begin{enumerate}\n", list.tight(c), "\\end{enumerate}\n"} end,
                  loose = function(c) return {"\\end{enumerate}\n", list.loose(c), "\\end{enumerate}\n"} end },
  para = function(c) return {c, "\n"} end,
  plain = function(c) return c end,
  blockquote = function(c) return {"\\begin{quote}\n", parser(writer, options)(table.concat(c,"\n")), "\\end{quote}\n"} end,
  verbatim = function(c) return {"\\begin{verbatim}\n", escape(table.concat(c,"")), "\\end{verbatim}\n"} end,
  hrule = function() return "\\begin{center}\\rule{3in}{0.4pt}\\end{center}\n" end,
  link = function(lab,src,tit)
           return {"\\href{", src, "}{", lab.inlines, "}"}
         end,
  image = function(lab,src,tit)
           return {"\\includegraphics{", src, "}"}
         end,
  email_link = function(addr) return link(addr,"mailto:"..addr) end,
  reference = function(lab,src,tit)
                return {key = util.normalize_label(lab.raw), label = lab.inlines, source = src, title = tit}
              end
  }
end

return writer
