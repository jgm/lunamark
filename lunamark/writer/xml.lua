-- (c) 2009-2011 John MacFarlane. Released under MIT license.
-- See the file LICENSE in the source for details.

local gsub = string.gsub
local util = require("lunamark.util")

local Xml = {}

Xml.options = { containers = false }

Xml.linebreak = "<linebreak />"

Xml.sep = { interblock = {compact = "\n", default = "\n\n", minimal = ""},
             container = { compact = "\n", default = "\n", minimal = ""}
          }

Xml.interblocksep = Xml.sep.interblock.default

Xml.containersep = Xml.sep.container.default

Xml.space = " "

Xml.ellipsis = "&#8230;"

Xml.mdash = "&#8212;"

Xml.ndash = "&#8211;"

function Xml.singlequoted(s)
  return string.format("&#8216;%s&#8217;",s)
end

function Xml.doublequoted(s)
  return string.format("&#8220;%s&#8221;",s)
end


local escaped = {
   ["<" ] = "&lt;",
   [">" ] = "&gt;",
   ["&" ] = "&amp;",
   ["\"" ] = "&quot;",
   ["'" ] = "&#39;"
}

function Xml.string(s)
  return s:gsub(".",escaped)
end

function Xml.start_document()
  return ""
end

function Xml.stop_document()
  return ""
end

function Xml.plain(s)
  return s
end

local meta = {}
meta.__index =
  function(_, key)
    io.stderr:write(string.format("WARNING: Undefined writer function '%s'\n",key))
    return (function(...) return table.concat(arg," ") end)
  end
setmetatable(Xml, meta)

return Xml
