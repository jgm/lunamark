-- (c) 2009-2011 John MacFarlane. Released under MIT license.
-- See the file LICENSE in the source for details.

local util = require("lunamark.util")
local M = {}
local W = {}

local meta = {}
meta.__index =
  function(_, key)
    io.stderr:write(string.format("WARNING: Undefined writer function '%s'\n",key))
    return (function(...) return table.concat(arg," ") end)
  end
setmetatable(W, meta)

function M.new(options)

  W.options = options or {}

  W.space = " "

  function W.start_document()
    return ""
  end

  function W.stop_document()
    return ""
  end

  function W.plain(s)
    return s
  end

  W.linebreak = "\n"

  W.sep = { interblock = {compact = "\n", default = "\n\n", minimal = ""},
            container = { compact = "\n", default = "\n", minimal = ""}
          }

  W.interblocksep = W.sep.interblock.default

  W.containersep = W.sep.container.default

  W.ellipsis = "…"

  W.mdash = "—"

  W.ndash = "–"

  function W.singlequoted(s)
    return string.format("‘%s’",s)
  end

  function W.doublequoted(s)
    return string.format("“%s”",s)
  end

  function W.string(s)
    return s
  end

  function W.code(s)
    return s
  end

  function W.link(lab,src,tit)
    return lab
  end

  function W.image(lab,src,tit)
    return lab
  end

  function W.paragraph(s)
    return s
  end

  function W.listitem(s)
    return s
  end

  function W.bulletlist(s,tight)
    return s
  end

  function W.orderedlist(s,tight,startnum)
    return s
  end

  function W.inline_html(s)
    return ""
  end

  function W.display_html(s)
    return ""
  end

  function W.emphasis(s)
    return s
  end

  function W.strong(s)
    return s
  end

  function W.blockquote(s)
    return s
  end

  function W.verbatim(s)
    return s
  end

  function W.section(s,level,contents)
    if contents then
      return s .. W.interblocksep .. contents
    else
      return s
    end
  end

  W.hrule = ""

  return util.table_copy(W)
end

return M
