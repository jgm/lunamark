-- (c) 2009-2011 John MacFarlane, Khaled Hosny, Hans Hagen.
-- Released under MIT license. See the file LICENSE in the source for details.

module("lunamark.writer.context", package.seeall)

local tex = require("lunamark.writer.tex")
local util = require("lunamark.util")
local gsub = string.gsub
local format = string.format

function new(options)
  local ConTeXt = tex.new(options)

  -- we don't try to escape utf-8 characters in context
  function ConTeXt.string(s)
    return s:gsub(".",ConTeXt.escaped)
  end

  function ConTeXt.singlequoted(s)
    return format("\\quote{%s}",s)
  end

  function ConTeXt.doublequoted(s)
    return format("\\quotation{%s}",s)
  end

  function ConTeXt.code(s)
    return format("\\type{%s}", s)  -- escape here?
  end

  function ConTeXt.link(lab,src,tit)
    return format("\\goto{%s}[url(%s)]",lab, ConTeXt.string(src))
  end

  function ConTeXt.image(lab,src,tit)
    return format("\\externalfigure[%s]", ConTeXt.string(src))
  end

  function ConTeXt.listitem(s)
    return format("\\item %s\n",s)
  end

  function ConTeXt.bulletlist(s,tight)
    local opt = ""
    if tight then opt = "[packed]" end
    return format("\\startitemize%s\n%s\\stopitemize",opt,s)
  end

  function ConTeXt.orderedlist(s,tight,startnum)
    local tightstr = ""
    if tight then tightstr = ",packed" end
    local opt = string.format("[%d%s]",(ConTeXt.options.startnum and startnum) or 1, tightstr)
    return format("\\startitemize%s\n%s\\stopitemize",opt,s)
  end

  function ConTeXt.emphasis(s)
    return format("{\\em %s}",s)
  end

  function ConTeXt.strong(s)
    return format("{\\bf %s}",s)
  end

  function ConTeXt.blockquote(s)
    return format("\\startblockquote\n%s\\stopblockquote", s)
  end

  function ConTeXt.verbatim(s)
    return format("\\starttyping\n%s\\stoptyping", s)  -- escape here?
  end

  function ConTeXt.section(s,level,contents)
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
    return format("%s{%s}%s%s", cmd, s, ConTeXt.interblocksep, contents)
  end

  ConTeXt.hrule = "\\hairline"

  return ConTeXt
end
