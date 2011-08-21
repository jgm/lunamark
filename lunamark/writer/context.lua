-- ConTeX writer for lunamark

local Tex = require("lunamark.writer.tex")
local util = require("lunamark.util")

local gsub = string.gsub

local Context = util.table_copy(Tex)

local format = string.format

Context.options = { }

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
  return format("\\startitemize%s\n%s\\stopitemize\n\n",opt,s)
end

function Context.orderedlist(s,tight)
  local opt = "[1]"
  if tight then opt = "[1,packed]" end
  return format("\\startitemize%s\n%s\\stopitemize\n\n",opt,s)
end

function Context.emphasis(s)
  return format("{\\em %s}",s)
end

function Context.strong(s)
  return format("{\\bf %s}",s)
end

function Context.blockquote(s)
  return format("\\startblockquote\n%s\\stopblockquote\n\n", s)
end

function Context.verbatim(s)
  return format("\\starttyping\n%s\\stoptyping\n\n", s)  -- escape here?
end

function Context.section(s,level,contents)
  return format("\\%ssection{%s}\n\n%s", string.rep("sub",level-1), s, contents)
end

Context.hrule = "\\hairline\n"

return Context
