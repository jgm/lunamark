-- (c) 2009-2011 John MacFarlane. Released under MIT license.
-- See the file LICENSE in the source for details.

--- Generic groff writer for lunamark.
-- This is currently used as the basis for [lunamark.writer.man].
-- In principle other groff-based writers could also extend it.

local M = {}

local format = string.format
local gsub = string.gsub
local generic = require("lunamark.writer.generic")
local entities = require("lunamark.entities")

--- Returns a new Groff writer.
-- For a list of all fields, see [lunamark.writer.generic].
function M.new(options)
  local options = options or {}
  local Groff = generic.new(options)

  Groff.interblocksep = "\n\n"  -- insensitive to layout

  Groff.containersep = "\n"

  Groff.linebreak = ".br\n"

  Groff.ellipsis = "\\&..."

  Groff.mdash = "\\[em]"

  Groff.ndash = "\\[en]"

  function Groff.singlequoted(s)
    return format("`%s'",s)
  end

  function Groff.doublequoted(s)
    return format("\\[lq]%s\\[rq]",s)
  end

  Groff.escaped = {
     ["@"] = "\\@",
     ["\\"] = "\\\\",
   }

  local escaped_utf8_triplet = {
    ["\226\128\156"] = "\\[lq]",
    ["\226\128\157"] = "\\[rq]",
    ["\226\128\152"] = "`",
    ["\226\128\153"] = "'",
    ["\226\128\148"] = "\\[em]",
    ["\226\128\147"] = "\\[en]",
  }

  function Groff.string(s)
    return s:gsub(".",Groff.escaped):gsub("\226\128.",escaped_utf8_triplet):gsub("\194\160","\\ ")
  end

  function Groff.inline_html(s)
  end

  function Groff.display_html(s)
  end

  function Groff.code(s)
    return format("\\f[C]%s\\f[]",s)
  end

  function Groff.emphasis(s)
    return format("\\f[I]%s\\f[]",s)
  end

  function Groff.strong(s)
    return format("\\f[B]%s\\f[]",s)
  end

  return Groff
end

return M
