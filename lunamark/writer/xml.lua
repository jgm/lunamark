-- (c) 2009-2011 John MacFarlane. Released under MIT license.
-- See the file LICENSE in the source for details.

module("lunamark.writer.xml", package.seeall)

local gsub = string.gsub
local generic = require("lunamark.writer.generic")

function new(options)
  local Xml = generic.new(options)

  Xml.linebreak = "<linebreak />"

  Xml.sep = { interblock = {compact = "\n", default = "\n\n", minimal = ""},
               container = { compact = "\n", default = "\n", minimal = ""}
            }

  Xml.interblocksep = Xml.sep.interblock.default

  Xml.containersep = Xml.sep.container.default

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

  return Xml
end
