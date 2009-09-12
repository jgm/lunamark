#!/usr/bin/env lua

require "luarocks.require"
require "lunamark"

-- from Programming Lua
local function expandTabs(s, tab)
  tabstop = tabstop or 4
  local corr = 0
  s = string.gsub(s, "()\t", function(p)
          local sp = tab - (p - 1 + corr)%tab
          corr = corr - 1 + sp
          return string.rep(" ",sp)
        end)
  return s
end

numargs = table.getn(arg)
if numargs > 0 then
  io.input(arg[1])
end

local inp = io.read("*a") .. "\n\n"  -- added because markdown test suite demands it
inp = expandTabs(inp,4)                   -- again, because test suite demands it

lunamark.converter("markdown", "html").write(io.stdout, inp)

