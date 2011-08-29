-- (c) 2009-2011 John MacFarlane. Released under MIT license.
-- See the file LICENSE in the source for details.

module("lunamark.writer.generic",package.seeall)

local util = require("lunamark.util")

local W = {}

local meta = {}
meta.__index =
  function(_, key)
    io.stderr:write(string.format("WARNING: Undefined writer function '%s'\n",key))
    return (function(...) return table.concat(arg," ") end)
  end
setmetatable(W, meta)

function new()
  return util.table_copy(W)
end
