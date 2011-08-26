-- Docbook writer for lunamark

local Xml = require("lunamark.writer.xml")
local util = require("lunamark.util")

local gsub = string.gsub

local Docbook = util.table_copy(Xml)

local format = function(...) return util.format(Docbook,...) end

Docbook.options = { minimize   = false,
                    blanklines = true,
                  }

Docbook.linebreak = "<literallayout>&#xA;</literallayout>"

function Docbook.code(s)
  return string.format("<literal>%s</literal>",Docbook.string(s))
end

function Docbook.link(lab,src,tit)
  local titattr
  -- if tit and string.len(tit) > 0
  --   then titattr = format(" xlink:title=\"%s\"", Docbook.string(tit))
  --   else titattr = ""
  --   end
  return string.format("<ulink url=\"%s\">%s</ulink>",Docbook.string(src),lab)
end

function Docbook.image(lab,src,tit)
  local titattr, altattr
  if tit and string.len(tit) > 0
     then titattr = string.format("<objectinfo><title>%s%</title></objectinfo>",
                      Docbook.string(tit))
     else titattr = ""
     end
  return string.format("<inlinemediaobject><imageobject>%s<imagedata fileref="%s" /></imageobject></inlinemediaobject>",titattr,Docbook.string(src))
end

function Docbook.paragraph(s)
  return format("\n<para>%s</para>\n",s)
end

Docbook.plain = Docbook.paragraph

function Docbook.listitem(s)
  return format("<listitem>%s</listitem>\n",s)
end

function Docbook.bulletlist(s)
  return format("\n<itemizedlist>\n%s</itemizedlist>\n",s)
end

function Docbook.orderedlist(s)
  return format("\n<orderedlist>\n%s</orderedlist>\n",s)
end

function Docbook.inline_html(s)
  return s
end

function Docbook.display_html(s)
  return format("\n%s\n",s)
end

function Docbook.emphasis(s)
  return string.format("<emphasis>%s</emphasis>",s)
end

function Docbook.strong(s)
  return string.format("<emphasis role=\"strong\">%s</emphasis>",s)
end

function Docbook.blockquote(s)
  return format("\n<blockquote>\n%s</blockquote>\n", s)
end

function Docbook.verbatim(s)
  return format("\n<programlisting>%s</programlisting>\n", Docbook.string(s))
end

function Docbook.section(s,level,contents)
  return format("\n<section>\n<title>%s</title>\n%s\n</section>\n",s,contents)
end

Docbook.hrule = ""

return Docbook
