-- Generic XML writer for lunamark

local gsub = string.gsub

local firstline = true

local formats = {}

local Xml = {}

Xml.options = { minimize   = false,
                blanklines = true,
                containers = false }

-- override string.format so that \n is a variable
-- newline (depending on the 'minimize' option).
-- formats are memoized after conversion.
local function format(fmt,...)
  local newfmt = formats[fmt]
  if not newfmt then
    newfmt = fmt
    if Xml.options.minimize then
      newfmt = newfmt:gsub("\n","")
    end
    local starts_with_nl = newfmt:byte(1) == 10
    if starts_with_nl and not Xml.options.blanklines then
      newfmt = newfmt:sub(2)
      starts_with_nl = false
    end
    formats[fmt] = newfmt
    -- don't memoize this change, just on first line
    if starts_with_nl and Xml.options.firstline then
      newfmt = newfmt:sub(2)
      firstline = false
    end
  end
  return string.format(newfmt,...)
end

Xml.format = format

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
  firstline = true
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
