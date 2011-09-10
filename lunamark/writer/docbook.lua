-- (c) 2009-2011 John MacFarlane. Released under MIT license.
-- See the file LICENSE in the source for details.

--- DocBook writer for lunamark.
-- Extends XML writer.
-- @see lunamark.writer.xml

local M = {}

local xml = require("lunamark.writer.xml")
local util = require("lunamark.util")
local gsub = string.gsub
local format = string.format

--- Returns a new DocBook writer.
-- @see lunamark.writer.generic
function M.new(options)
  local options = options or {}
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

  local function listitem(s)
    return format("<listitem>%s</listitem>",s)
  end

  function Docbook.bulletlist(items)
    local buffer = {}
    for _,item in ipairs(items) do
      buffer[#buffer + 1] = listitem(item)
    end
    local contents = table.concat(buffer, Docbook.containersep)
    return format("<itemizedlist>%s%s%s</itemizedlist>",Docbook.containersep,
            contents, Docbook.containersep)
  end

  function Docbook.orderedlist(items)
    local buffer = {}
    for _,item in ipairs(items) do
      buffer[#buffer + 1] = listitem(item)
    end
    local contents = table.concat(buffer, Docbook.containersep)
    return format("<orderedlist>%s%s%s</orderedlist>",Docbook.containersep,
            contents, Docbook.containersep)
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
                Docbook.containersep)
  end

  Docbook.hrule = ""

  function Docbook.note(contents)
    return format("<footnote>%s%s%s</footnote>", Docbook.containersep, contents,
                Docbook.containersep)
  end

  function Docbook.definitionlist(items)
    local buffer = {}
    for _,item in ipairs(items) do
      local defs = {}
      for _,def in ipairs(item.definitions) do
        defs[#defs + 1] = format("<listitem>%s%s%s</listitem>", Docbook.containersep, def, Docbook.containersep)
      end
      buffer[#buffer + 1] = format("<varlistentry>%s<term>%s</term>%s%s%s</varlistentry>", Docbook.containersep,
         item.term, Docbook.containersep, table.concat(defs, Docbook.containersep), Docbook.containersep)
    end
    local contents = table.concat(buffer, Docbook.containersep)
    return format("<variablelist>%s%s%s</variablelist>",Docbook.containersep, contents, Docbook.containersep)
  end

  Docbook.template = [[
<?xml version="1.0" encoding="utf-8" ?>
<!DOCTYPE article PUBLIC "-//OASIS//DTD DocBook XML V4.4//EN" "http://www.oasis-open.org/docbook/xml/4.4/docbookx.dtd">
<article>
<articleinfo>
<title>$title</title>
</articleinfo>
$body
</article>
]]

  return Docbook
end

return M
