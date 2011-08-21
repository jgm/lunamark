-- HTML writer for lunamark

local Xml = require("lunamark.writer.xml")
local util = require("lunamark.util")

local gsub = string.gsub

local Html = util.table_copy(Xml)

local format = function(...) return util.format(Html,...) end

Html.options = { minimize   = false,
                 blanklines = true,
                 containers = false }

Html.linebreak = "<br/>"

function Html.code(s)
  return format("<code>%s</code>",Html.string(s))
end

function Html.link(lab,src,tit)
  local titattr
  if tit and string.len(tit) > 0
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
  return Html.link(address,"mailto:" .. address)
end

function Html.url_link(url)
  return Html.link(url,url)
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
  if Html.options.containers then
    return format("\n<div>\n<h%d>%s</h%d>\n%s</div>\n",level,s,level,contents)
  else
    return format("\n<h%d>%s</h%d>\n%s",level,s,level,contents)
  end
end

Html.hrule = "\n<hr />\n"

return Html
