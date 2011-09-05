-- (c) 2009-2011 John MacFarlane, Khaled Hosny, Hans Hagen.
-- Released under MIT license. See the file LICENSE in the source for details.

local M = {}

local tex = require("lunamark.writer.tex")
local util = require("lunamark.util")
local gsub = string.gsub
local format = string.format

function M.new(options)
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

  local function listitem(s)
    return format("\\item %s\n",s)
  end

  function ConTeXt.bulletlist(items,tight)
    local opt = ""
    if tight then opt = "[packed]" end
    local buffer = {}
    for _,item in ipairs(items) do
      buffer[#buffer + 1] = listitem(item)
    end
    local contents = table.concat(buffer)
    return format("\\startitemize%s\n%s\\stopitemize",opt,contents)
  end

  function ConTeXt.orderedlist(items,tight,startnum)
    local tightstr = ""
    if tight then tightstr = ",packed" end
    local opt = string.format("[%d%s]", startnum or 1, tightstr)
    local buffer = {}
    for _,item in ipairs(items) do
      buffer[#buffer + 1] = listitem(item)
    end
    local contents = table.concat(buffer)
    return format("\\startitemize%s\n%s\\stopitemize",opt,contents)
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
    return format("\\starttyping\n%s\\stoptyping", s)
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

  function ConTeXt.note(contents)
    return format("\\footnote{%s}", contents)
  end

  function ConTeXt.definitionlist(items)
    local buffer = {}
    for _,item in ipairs(items) do
      buffer[#buffer + 1] = format("\\startdescription{%s}\n%s\n\\stopdescription",
        item.term, table.concat(item.definitions, ConTeXt.interblocksep))
    end
    local contents = table.concat(buffer, ConTeXt.containersep)
    return contents
  end

  return ConTeXt
end

return M
