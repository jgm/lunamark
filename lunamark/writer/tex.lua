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
   ["<" ] = "&lt;",
   [">" ] = "&gt;",
   ["&" ] = "&amp;",
   ["\"" ] = "&quot;",
   ["'" ] = "&#39;" }
  return s:gsub(".",escaped)
end

-- need functions to convert these to utf-8 (borrow from context?)
function TeX.hex_entity(s)
  return entities.hex_ent(s)
end

function TeX.dec_entity(s)
  return entities.dec_ent(s)
end

function TeX.tag_entity(s)
  return entities.char_ent(s)
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
