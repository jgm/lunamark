-- (c) 2009-2011 John MacFarlane. Released under MIT license.
-- See the file LICENSE in the source for details.

--- Groff man writer for lunamark.
-- Extends the groff writer.
-- @see lunamark.writer.groff
--
-- Note: continuation paragraphs in lists are not
-- handled properly.

local M = {}

local groff = require("lunamark.writer.groff")
local util = require("lunamark.util")
local gsub = string.gsub
local format = string.format

--- Returns a new groff writer.
-- @see lunamark.writer.generic
function M.new(options)
  local options = options or {}
  local Man = groff.new(options)

  local endnotes = {}

  function Man.link(lab,src,tit)
    return format("%s (%s)",lab,src)
  end

  function Man.image(lab,src,tit)
    return format("[IMAGE (%s)]",lab)
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
    return format(".PP\n%s", contents)
  end

  function Man.bulletlist(items,tight)
    local buffer = {}
    for _,item in ipairs(items) do
      buffer[#buffer + 1] = format(".IP \[bu] 2\n%s",item)
    end
    return table.concat(buffer, Man.containersep)
  end

  function Man.orderedlist(items,tight,startnum)
    local buffer = {}
    local num = startnum or 1
    for _,item in ipairs(items) do
      buffer[#buffer + 1] = format(".IP \"%d.\" 4\n%s",num,item)
      num = num + 1
    end
    return table.concat(buffer, Man.containersep)
  end

  function Man.blockquote(s)
    return format(".RS\n%s\n.RE", s)
  end

  function Man.verbatim(s)
    return format(".IP\n.nf\n\\f[C]\n%s.fi",s)
  end

  function Man.section(s,level,contents)
    local hcode = ".SS"
    if level == 1 then hcode = ".SH" end
    return format("%s %s\n%s", hcode, s, contents)
  end

  Man.hrule = ".PP\n * * * * *"

  function Man.note(contents)
    local num = #endnotes + 1
    endnotes[num] = format('.SS [%d]\n%s', num, contents)
    return format('[%d]', num)
  end

  function Man.definitionlist(items)
    local buffer = {}
    for _,item in ipairs(items) do
      buffer[#buffer + 1] = format(".TP\n.B %s\n%s\n.RS\n.RE",
        item.term, table.concat(item.definitions, "\n.RS\n.RE\n"))
    end
    local contents = table.concat(buffer, "\n")
    return contents
  end

  function Man.start_document()
    endnotes = {}
    return ""
  end

  function Man.stop_document()
    if #endnotes == 0 then
      return ""
    else
      return format('\n.SH NOTES\n%s', table.concat(endnotes, "\n"))
    end
  end

  return Man
end

return M
