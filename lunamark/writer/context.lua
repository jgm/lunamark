-- ConTeX writer for lunamark

local Tex = require("lunamark.writer.tex")
local util = require("lunamark.util")

local gsub = string.gsub

local Context = util.table_copy(Tex)

local format = string.format

Context.options = { }

-- we don't try to escape utf-8 characters in context
function Context.string(s)
  return s:gsub(".",Context.escaped)
end

function Context.singlequoted(s)
  return format("\\quote{%s}",s)
end

function Context.doublequoted(s)
  return format("\\quotation{%s}",s)
end

function Context.code(s)
  return format("\\type{%s}", s)  -- escape here?
end

function Context.link(lab,src,tit)
  return format("\\goto{%s}[url(%s)]",lab, Context.string(src))
end

function Context.image(lab,src,tit)
  return format("\\externalfigure[%s]", Context.string(src))
end

function Context.listitem(s)
  return format("\\item %s\n",s)
end

function Context.bulletlist(s,tight)
  local opt = ""
  if tight then opt = "[packed]" end
  return format("\\startitemize%s\n%s\\stopitemize",opt,s)
end

function Context.orderedlist(s,tight,startnum)
  local tightstr = ""
  if tight then tightstr = ",packed" end
  local opt = string.format("[%d%s]",(Context.options.startnum and startnum) or 1, tightstr)
  return format("\\startitemize%s\n%s\\stopitemize",opt,s)
end

function Context.emphasis(s)
  return format("{\\em %s}",s)
end

function Context.strong(s)
  return format("{\\bf %s}",s)
end

function Context.blockquote(s)
  return format("\\startblockquote\n%s\\stopblockquote", s)
end

function Context.verbatim(s)
  return format("\\starttyping\n%s\\stoptyping", s)  -- escape here?
end

function Context.section(s,level,contents)
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
  return format("%s{%s}%s%s", cmd, s, Context.interblocksep, contents)
end

Context.hrule = "\\hairline"

return Context
