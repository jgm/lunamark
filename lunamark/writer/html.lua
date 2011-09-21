-- (c) 2009-2011 John MacFarlane. Released under MIT license.
-- See the file LICENSE in the source for details.

--- HTML writer for lunamark.
-- Extends [lunamark.writer.xml].

local M = {}

local xml = require("lunamark.writer.xml")
local util = require("lunamark.util")
local gsub = string.gsub

--- Return a new HTML writer.
-- For a list of all fields in the writer, see [lunamark.writer.generic].
--
--`options` is a table that can contain the following fields:
--
-- `containers`
-- :   Put sections in `<div>` tags.
--
-- `slides`
-- :   Do not allow containers to nest; when a subsection begins,
--     close the section's container and start a new one.
--
-- `layout`
-- :   `minimize` removes semantically insignificant white space.
-- :   `compact` removes unneeded blank lines.
-- :   `default` puts blank lines between block elements.
function M.new(options)
  local options = options or {}
  local Html = xml.new(options)
  local options = options or {}
  local endnotes = {}
  local containersep = Html.containersep
  local interblocksep = Html.interblocksep

  Html.container = "div"
  Html.linebreak = "<br/>"

  function Html.code(s)
    return "<code>" .. Html.string(s) .. "</code>"
  end

  function Html.link(lab,src,tit)
    local titattr
    if type(tit) == "string" and #tit > 0
       then titattr = " title=\"" .. Html.string(tit) .. "\""
       else titattr = ""
       end
    return "<a href=\"" .. Html.string(src) .. "\"" .. titattr .. ">" .. lab .. "</a>"
  end

  function Html.image(lab,src,tit)
    local titattr, altattr
    if type(tit) == "string" and #tit > 0
       then titattr = " title=\"" .. Html.string(tit) .. "\""
       else titattr = ""
       end
    return "<img src=\"" .. Html.string(src) .. "\" alt=\"" .. Html.string(lab) .. "\"" .. titattr .. " />"
  end

  function Html.paragraph(s)
    return "<p>" .. s .. "</p>"
  end

  local function listitem(s)
    return "<li>" .. s .. "</li>"
  end

  function Html.bulletlist(items,tight)
    local buffer = {}
    for _,item in ipairs(items) do
      buffer[#buffer + 1] = listitem(item)
    end
    local contents = table.concat(buffer,Html.containersep)
    return "<ul>" .. containersep .. contents .. containersep .. "</ul>"
  end

  function Html.orderedlist(items,tight,startnum)
    local start = ""
    if startnum and startnum ~= 1 then
      start = " start=\"" .. startnum .. "\""
    end
    local buffer = {}
    for _,item in ipairs(items) do
      buffer[#buffer + 1] = listitem(item)
    end
    local contents = table.concat(buffer,Html.containersep)
    return "<ol" .. start .. ">" .. containersep .. contents .. containersep .. "</ol>"
  end

  function Html.inline_html(s)
    return s
  end

  function Html.display_html(s)
    return s
  end

  function Html.emphasis(s)
    return "<em>" .. s .. "</em>"
  end

  function Html.strong(s)
    return "<strong>" .. s .. "</strong>"
  end

  function Html.blockquote(s)
    return "<blockquote>" .. containersep .. s .. containersep .. "</blockquote>"
  end

  function Html.verbatim(s)
    return "<pre><code>" .. Html.string(s) .. "</code></pre>"
  end

  function Html.header(s,level)
    local sep = ""
    local stop
    if options.slides or options.containers then
      local lev = (options.slides and 1) or level
      local stop = Html.stop_section(lev)
      if stop ~= "" then
        stop = stop .. Html.interblocksep
      end
      sep = stop .. Html.start_section(lev) .. Html.containersep
    end
    return sep .. "<h" .. level .. ">" .. s .. "</h" .. level .. ">"
  end

  Html.hrule = "<hr />"

  function Html.note(contents)
    local num = #endnotes + 1
    local backref = ' <a href="#fnref' .. num .. '" class="footnoteBackLink">↩</a>'
    local adjusted = gsub(contents, "</p>$", backref .. "</p>")
    endnotes[num] = '<li id="fn' .. num .. '">' .. adjusted .. '</li>'
    return '<sup><a href="#fn' .. num .. '" class="footnoteRef" id="fnref' .. num .. '">' .. num .. '</a></sup>'
  end

  function Html.start_document()
    endnotes = {}
    return ""
  end

  function Html.stop_document()
    local stop = Html.stop_section(1) -- close section containers
    if stop ~= "" then stop = Html.containersep .. stop end
    if #endnotes == 0 then
      return stop
    else
      return stop .. interblocksep .. '<hr />' .. interblocksep .. '<ol class="notes">' ..
         containersep .. table.concat(endnotes, interblocksep) .. containersep .. '</ol>'
    end
  end

  function Html.definitionlist(items, tight)
    local buffer = {}
    local sep
    if tight then sep = "" else sep = Html.containersep end
    for _,item in ipairs(items) do
      local defs = {}
      for _,def in ipairs(item.definitions) do
        defs[#defs + 1] = "<dd>" .. sep .. def .. sep .. "</dd>"
      end
      buffer[#buffer + 1] = "<dt>" .. item.term .. "</dt>" .. containersep .. table.concat(defs, containersep)
    end
    local contents = table.concat(buffer, Html.containersep)
    return "<dl>" .. containersep .. contents .. containersep .. "</dl>"
  end

  Html.template = [[
<html>
<head>
<meta http-equiv="Content-Type" content="text/html; charset=utf-8" />
<title>$title</title>
</head>
<body>
$body
</body>
</html>
]]

  return Html
end

return M
