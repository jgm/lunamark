-- (c) 2009-2011 John MacFarlane. Released under MIT license.
-- See the file LICENSE in the source for details.

local gsub = string.gsub
local entities = require("lunamark.entities")

local TeX = {}

TeX.options = { containers = false }

TeX.sep = { interblock = {compact = "\n\n", default = "\n\n", minimal = "\n\n"},
             container = { compact = "\n", default = "\n", minimal = "\n"}
          }

TeX.interblocksep = TeX.sep.interblock.default

TeX.containersep = TeX.sep.container.default

TeX.linebreak = "\\\\"

TeX.space = " "

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

function TeX.start_document()
  return ""
end

function TeX.stop_document()
  return ""
end

function TeX.inline_html(s)
end

function TeX.display_html(s)
end

function TeX.paragraph(s)
  return s
end

function TeX.plain(s)
  return s
end

local meta = {}
meta.__index =
  function(_, key)
    io.stderr:write(string.format("WARNING: Undefined writer function '%s'\n",key))
    return (function(...) return table.concat(arg," ") end)
  end
setmetatable(TeX, meta)

return TeX
