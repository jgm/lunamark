-- (c) 2009-2011 John MacFarlane. Released under MIT license.
-- See the file LICENSE in the source for details.

--- Groff man writer for lunamark.
-- Extends [lunamark.writer.groff].
--
-- Note: continuation paragraphs in lists are not
-- handled properly.

local M = {}

local groff = require("lunamark.writer.groff")
local util = require("lunamark.util")
local gsub = string.gsub
local map, intersperse = util.map, util.intersperse

--- Returns a new groff writer.
-- For a list of fields, see [lunamark.writer.generic].
function M.new(options)
  local options = options or {}
  local Man = groff.new(options)

  local endnotes = {}

  function Man.link(lab,src,tit)
    return {lab, "(", Man.string(src), ")"}
  end

  function Man.image(lab,src,tit)
    return {"[IMAGE (", lab, ")]"}
  end

  -- TODO handle continuations properly.
  -- pandoc does this:
  -- .IP \[bu] 2
  -- one
  -- .RS 2
  -- .PP
  -- cont
  -- .RE

  function Man.paragraph(contents)
    return {".PP\n", contents}
  end

  function Man.bulletlist(items,tight)
    return intersperse(map(items, function(s) return {".IP \\[bu] 2\n", s} end))
  end

  function Man.orderedlist(items,tight,startnum)
    local buffer = {}
    local num = startnum or 1
    for _,item in ipairs(items) do
      buffer[#buffer + 1] = {".IP \"", num, "\" 4\n", item}
      num = num + 1
    end
    return intersperse(buffer, Man.containersep)
  end

  function Man.blockquote(s)
    return {".RS\n", s, ".RE"}
  end

  function Man.verbatim(s)
    return {".IP\n.nf\n\\f[C]\n",s,".fi"}
  end

  function Man.header(s,level)
    local hcode = ".SS "
    if level == 1 then hcode = ".SH " end
    return {hcode, s}
  end

  Man.hrule = ".PP\n * * * * *"

  function Man.note(contents)
    return function()
      local num = #endnotes + 1
      endnotes[num] = {'.SS [' .. num .. ']\n', contents}
      return '[' .. tostring(num) .. ']'
    end
  end

  function Man.definitionlist(items,tight)
    local buffer = {}
    for _,item in ipairs(items) do
      if tight then
        buffer[#buffer + 1] = {".TP\n.B ", item.term, "\n", intersperse(item.definitions, "\n.RS\n.RE"), "\n.RS\n.RE"}
      else
        buffer[#buffer + 1] = {".TP\n.B ", item.term, "\n.RS\n", intersperse(item.definitions, "\n.RS\n.RE"), "\n.RE"}
      end
    end
    return intersperse(buffer, "\n")
  end

  function Man.start_document()
    endnotes = {}
    return ""
  end

  function Man.stop_document()
    return function()
      if #endnotes == 0 then
        return ""
      else
        return {'\n.SH NOTES\n', intersperse(endnotes, '\n')}
      end
    end
  end

  Man.template = [===[
.TH "$title" "$section" "$date" "$left_footer" "$center_header"
$body
]===]

  return Man
end

return M
