-- HTML writer for lunamark

local gsub = string.gsub

local firstline = true

local formats = {}

local Html = {}

Html.options = { minimize   = false,
                 blanklines = true,
                 sectiondivs = false }

-- override string.format so that %n is a variable
-- newline (depending on the 'minimize' option).
-- formats are memoized after conversion.
local function format(fmt,...)
  local newfmt = formats[fmt]
  if not newfmt then
    newfmt = fmt
    local nl = "\n"
    if Html.options.minimize then nl = "" end
    newfmt = newfmt:gsub("\n",nl)
    local starts_with_nl = newfmt:byte(1) == 10
    if starts_with_nl and not Html.options.blanklines then
      newfmt  = newfmt:sub(2)
      starts_with_nl = false
    end
    formats[fmt] = newfmt
    -- don't memoize this change, just on first line
    if starts_with_nl and Html.options.firstline then
      newfmt = newfmt:sub(2)
      firstline = false
    end
  end
  return string.format(newfmt,...)
end

Html.format = format

Html.linebreak = "<br/>"

Html.space = " "

function Html.string(s)
  local escaped = {
   ["<" ] = "&lt;",
   [">" ] = "&gt;",
   ["&" ] = "&amp;",
   ["\"" ] = "&quot;",
   ["'" ] = "&#39;" }
  return s:gsub(".",escaped)
end

function Html.code(s)
  return format("<code>%s</code>",Html.string(s))
end

function Html.link(lab,src,tit)
  local titattr
  if string.len(tit) > 0
     then titattr = format(" title=\"%s\"", Html.string(tit))
     else titattr = ""
     end
  return format("<a href=\"%s\"%s>%s</a>",Html.string(src),titattr,lab)
end

function Html.image(lab,src,tit)
  local titattr, altattr
  if tit and string.len(tit) > 0
     then titattr = format(" title=\"%s\"", Html.string(tit))
     else titattr = ""
     end
  return format("<img src=\"%s\" alt=\"%s\"%s />",Html.string(src),Html.string(lab),titattr)
end

function Html.email_link(address)
  return format("<a href=\"mailto:%s\">%s</a>",Html.string(address),Html.string(address))
end

function Html.url_link(url)
  return format("<a href=\"%s\">%s</a>",Html.string(url),Html.string(url))
end

function Html.hex_entity(s)
  return format("&#x%s;",s)
end

function Html.dec_entity(s)
  return format("&#%s;",s)
end

function Html.tag_entity(s)
  return format("&%s;",s)
end

function Html.start_document()
  firstline = true
  return ""
end

function Html.stop_document()
  return ""
end

function Html.paragraph(s)
  return format("\n<p>%s</p>\n",s)
end

function Html.listitem(s)
  return format("<li>%s</li>\n",s)
end

function Html.bulletlist(s)
  return format("\n<ul>\n%s</ul>\n",s)
end

function Html.orderedlist(s)
  return format("\n<ol>\n%s</ol>\n",s)
end

function Html.inline_html(s)
  return s
end

function Html.display_html(s)
  return format("\n%s\n",s)
end

function Html.emphasis(s)
  return format("<em>%s</em>",s)
end

function Html.strong(s)
  return format("<strong>%s</strong>",s)
end

function Html.blockquote(s)
  return format("\n<blockquote>\n%s</blockquote>\n", s)
end

function Html.verbatim(s)
  return format("\n<pre><code>%s</code></pre>\n", Html.string(s))
end

function Html.section(s,level,contents)
  if Html.options.sectiondivs then
    return format("\n<div>\n<h%d>%s</h%d>\n%s</div>\n",level,s,level,contents)
  else
    return format("\n<h%d>%s</h%d>\n%s\n",level,s,level,contents)
  end
end

Html.hrule = format("\n<hr />\n")

local meta = {}
meta.__index =
  function(_, key)
    io.stderr:write(string.format("WARNING: Undefined writer function '%s'\n",key))
    return (function(...) return table.concat(arg," ") end)
  end
setmetatable(Html, meta)

return Html
