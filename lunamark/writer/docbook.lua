-- (c) 2009-2011 John MacFarlane. Released under MIT license.
-- See the file LICENSE in the source for details.

local M = {}

local xml = require("lunamark.writer.xml")
local util = require("lunamark.util")
local gsub = string.gsub
local format = string.format

function M.new(options)
  local Docbook = xml.new(options)

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
    return format("<para>%s</para>",s)
  end

  Docbook.plain = Docbook.paragraph

  function Docbook.listitem(s)
    return format("<listitem>%s</listitem>%s",s,Docbook.containersep)
  end

  function Docbook.bulletlist(s)
    return format("<itemizedlist>%s%s%s</itemizedlist>",Docbook.containersep,
            s, Docbook.containersep)
  end

  function Docbook.orderedlist(s)
    return format("<orderedlist>%s%s%s</orderedlist>",Docbook.containersep,
            s, Docbook.containersep)
  end

  function Docbook.inline_html(s)
    return s
  end

  function Docbook.display_html(s)
    return format("%s",s)
  end

  function Docbook.emphasis(s)
    return string.format("<emphasis>%s</emphasis>",s)
  end

  function Docbook.strong(s)
    return string.format("<emphasis role=\"strong\">%s</emphasis>",s)
  end

  function Docbook.blockquote(s)
    return format("<blockquote>%s%s%s</blockquote>", Docbook.containersep, s,
             Docbook.containersep)
  end

  function Docbook.verbatim(s)
    return format("<programlisting>%s</programlisting>", Docbook.string(s))
  end

  function Docbook.section(s,level,contents)
    return format("<section>%s<title>%s</title>%s%s%s</section>",
                Docbook.containersep, s, Docbook.containersep, contents,
                Docbook.containersep )
  end

  Docbook.hrule = ""

  return Docbook
end

return M
