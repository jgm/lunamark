-- (c) 2009-2011 John MacFarlane. Released under MIT license.
-- See the file LICENSE in the source for details.

--- Generic XML writer for lunamark.
-- It extends [lunamark.writer.generic] and is extended by
-- [lunamark.writer.html] and [lunamark.writer.docbook].

local M = {}

local gsub = string.gsub
local generic = require("lunamark.writer.generic")

--- Returns a new XML writer.
-- For a list of fields, see [lunamark.writer.generic].
function M.new(options)
  local options = options or {}
  local Xml = generic.new(options)

  Xml.linebreak = "<linebreak />"

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

  return Xml
end

return M
