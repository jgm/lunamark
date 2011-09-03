-- (c) 2009-2011 John MacFarlane. Released under MIT license.
-- See the file LICENSE in the source for details.

local M = {}

local gsub = string.gsub
local generic = require("lunamark.writer.generic")

function M.new(options)
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
