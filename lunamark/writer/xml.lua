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

function Xml.code(s)
  return format("<code>%s</code>",Xml.string(s))
end

function Xml.link(lab,src,tit)
  local titattr
  if string.len(tit) > 0
     then titattr = format(" title=\"%s\"", Xml.string(tit))
     else titattr = ""
     end
  return format("<link href=\"%s\"%s>%s</link>",Xml.string(src),titattr,lab)
end

function Xml.image(lab,src,tit)
  local titattr, altattr
  if tit and string.len(tit) > 0
     then titattr = format(" title=\"%s\"", Xml.string(tit))
     else titattr = ""
     end
  return format("<image src=\"%s\" label=\"%s\"%s />",Xml.string(src),Xml.string(lab),titattr)
end

function Xml.email_link(address)
  return format("<link href=\"mailto:%s\">%s</a>",Xml.string(address),Xml.string(address))
end

function Xml.url_link(url)
  return format("<link href=\"%s\">%s</a>",Xml.string(url),Xml.string(url))
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

function Xml.paragraph(s)
  return format("\n<paragraph>%s</paragraph>\n",s)
end

function Xml.listitem(s)
  return format("<item>%s</item>\n",s)
end

function Xml.bulletlist(s)
  return format("\n<bulletlist>\n%s</bulletlist>\n",s)
end

function Xml.orderedlist(s)
  return format("\n<orderedlist>\n%s</orderedlist>\n",s)
end

function Xml.inline_html(s)
  return format("<inlinehtml>%s</inlinehtml>",s)
end

function Xml.display_html(s)
  return format("\n<displayhtml>\n%s</displayhtml>\n",s)
end

function Xml.emphasis(s)
  return format("<emphasis>%s</emphasis>",s)
end

function Xml.strong(s)
  return format("<strong>%s</strong>",s)
end

function Xml.blockquote(s)
  return format("\n<blockquote>\n%s</blockquote>\n", s)
end

function Xml.verbatim(s)
  return format("\n<verbatim>%s</verbatim>\n", Xml.string(s))
end

function Xml.section(s,level,contents)
  return format("\n<section>\n<heading level=\"%d\">%s</heading>\n%s</section>\n",level,s,level,contents)
end

Xml.hrule = format("\n<hrule />\n")

local meta = {}
meta.__index =
  function(_, key)
    io.stderr:write(string.format("WARNING: Undefined writer function '%s'\n",key))
    return (function(...) return table.concat(arg," ") end)
  end
setmetatable(Xml, meta)

return Xml
