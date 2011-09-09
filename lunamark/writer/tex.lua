-- (c) 2009-2011 John MacFarlane. Released under MIT license.
-- See the file LICENSE in the source for details.

--- Generic TeX writer for lunamark.
-- This is the basis of the LaTeX and ConTeXt writers.
-- It extends the generic writer.
-- @see lunamark.writer.generic
-- @see lunamark.writer.latex
-- @see lunamark.writer.context

local M = {}

local gsub = string.gsub
local generic = require("lunamark.writer.generic")
local entities = require("lunamark.entities")
local format = string.format

--- Returns a new TeX writer.
-- @see lunamark.writer.generic
function M.new(options)
  local options = options or {}
  local TeX = generic.new(options)

  TeX.interblocksep = "\n\n"  -- insensitive to layout

  TeX.containersep = "\n"

  TeX.linebreak = "\\\\"

  TeX.ellipsis = "\ldots{}"

  TeX.mdash = "---"

  TeX.ndash = "--"

  function TeX.singlequoted(s)
    return format("`%s'",s)
  end

  function TeX.doublequoted(s)
    return format("``%s''",s)
  end

  TeX.escaped = {
     ["{"] = "\\{",
     ["}"] = "\\}",
     ["$"] = "\\$",
     ["%"] = "\\%",
     ["&"] = "\\&",
     ["_"] = "\\_",
     ["#"] = "\\#",
     ["^"] = "\\^{}",
     ["\\"] = "\\char92{}",
     ["~"] = "\\char126{}",
     ["|"] = "\\char124{}",
     ["<"] = "\\char60{}",
     [">"] = "\\char62{}",
     ["["] = "{[}", -- to avoid interpretation as optional argument
     ["]"] = "{]}",
   }

  local escaped_utf8_triplet = {
    ["\226\128\156"] = "``",
    ["\226\128\157"] = "''",
    ["\226\128\152"] = "`",
    ["\226\128\153"] = "'",
    ["\226\128\148"] = "---",
    ["\226\128\147"] = "--",
  }

  function TeX.string(s)
    return s:gsub(".",TeX.escaped):gsub("\226\128.",escaped_utf8_triplet):gsub("\194\160","~")
  end

  function TeX.inline_html(s)
  end

  function TeX.display_html(s)
  end

  function TeX.paragraph(s)
    return s
  end

  return TeX
end

return M
