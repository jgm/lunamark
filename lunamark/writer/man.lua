-- (c) 2009-2011 John MacFarlane. Released under MIT license.
-- See the file LICENSE in the source for details.

local M = {}

local groff = require("lunamark.writer.groff")
local util = require("lunamark.util")
local gsub = string.gsub
local format = string.format

function M.new(options)
  local Man = groff.new(options)

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

  return Man
end

return M
