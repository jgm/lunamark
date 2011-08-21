-- Generic TeX writer for lunamark

local gsub = string.gsub
local entities = require("lunamark.entities")

local TeX = {}

TeX.options = { minimize   = false,
                blanklines = true,
                containers = false }

TeX.firstline = true
TeX.formats = {}

local format = string.format

TeX.linebreak = "\\\n"

TeX.space = " "

function TeX.string(s)
  -- str = function(s) return (string.gsub(s, "[{}$%%&_#^\\~|<>]", function(c) return "\\char`\\"..c end)) end,
  local escaped = {
   ["{"] = "\\{",
   ["}"] = "\\}",
   ["$"] = "\\$",
   ["%"] = "\\%",
   ["&"] = "\\&",
   ["_"] = "\\_",
   ["#"] = "\\#",
   ["^"] = "{\\^}",
   ["\\"] = "{\\textbackslash}",
   ["~"] = "{\\ensuremath{\\sim}}",
   ["|"] = "{\\textbar}",
   ["<"] = "{\\textless}",
   [">"] = "{\\textgreater}",
   ["["] = "{[}", -- to avoid interpretation as optional argument
   ["]"] = "{]}",
   ["\160"] = "~",
   ["\0x2018"] = "`",
   ["\0x2019"] = "'",
   ["\0x201C"] = "``",
   ["\0x201D"] = "''",
 }
  return s:gsub(".",escaped)
end

function TeX.start_document()
  TeX.firstline = true
  return ""
end

function TeX.stop_document()
  return ""
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
