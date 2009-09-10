#!/usr/bin/env lua

require "luarocks.require"
require "lunamark"

local function detab(s, tabstop)
  return s:gsub("([^\n\r]-)\t", function(m) local l = string.len(m) % tabstop; return m .. string.rep(" ",4 - l)  end)
end

numargs = table.getn(arg)
if numargs > 0 then
  io.input(arg[1])
end

local inp = io.read("*a") .. "\n\n"  -- added because markdown test suite demands it
inp = detab(inp,4)                   -- again, because test suite demands it

lunamark.converter("markdown", "html").write(io.stdout, inp)

