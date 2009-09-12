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

local function read_and_expand_tabs()
  buffer = {}
  for line in io.lines() do
    table.insert(buffer, expandTabs(line,4).."\n")
  end
  return table.concat(buffer).."\n"
end

numargs = table.getn(arg)
if numargs > 0 then
  io.input(arg[1])
end

inp = read_and_expand_tabs()

lunamark.converter("markdown", "html").write(io.stdout, inp)

