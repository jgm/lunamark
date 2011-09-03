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

  -- TODO need to add parameter for type (bullet, ordered, etc.)
  -- man has
  -- .IP "1." 3
  -- .IP \[bu] 2
  -- complication also for continuations:
  -- .IP \[bu] 2
  -- one
  -- .RS 2
  -- .PP
  -- cont
  -- .RE
  function Man.listitem(s)

  end

  function Man.bulletlist(s)
    return s
  end

  function Man.orderedlist(s)
    return s
  end

  function Man.blockquote(s)
    return format(".RS\n%s\n.RE", s)
  end

  function Man.verbatim(s)
    return format(".IP\n.nf\n\\f[C]\n%s\n.fi",s)
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
