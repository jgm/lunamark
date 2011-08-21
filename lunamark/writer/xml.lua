-- Generic XML writer for lunamark

local gsub = string.gsub
local util = require("lunamark.util")

local Xml = {}

Xml.options = { minimize   = false,
                blanklines = true,
                containers = false }

Xml.firstline = true
Xml.formats = {}

local format = function(...) return util.format(Xml,...) end

Xml.linebreak = "<linebreak />"

Xml.space = " "

function Xml.string(s)
  local escaped = {
   ["<" ] = "&lt;",
   [">" ] = "&gt;",
   ["&" ] = "&amp;",
   ["\"" ] = "&quot;",
   ["'" ] = "&#39;" }
  return s:gsub(".",escaped)
end

function Xml.hex_entity(s)
  return format("&#x%s;",s)
end

function Xml.dec_entity(s)
  return format("&#%s;",s)
end

function Xml.tag_entity(s)
  return format("&%s;",s)
end

function Xml.start_document()
  Xml.firstline = true
  return ""
end

function Xml.stop_document()
  return ""
end

local meta = {}
meta.__index =
  function(_, key)
    io.stderr:write(string.format("WARNING: Undefined writer function '%s'\n",key))
    return (function(...) return table.concat(arg," ") end)
  end
setmetatable(Xml, meta)

return Xml
