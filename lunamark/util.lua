-- (c) 2009-2011 John MacFarlane.  Released under MIT license.
-- See the file LICENSE in the source for details.

--- Utility functions for lunamark.

local M = {}
local cosmo = require("cosmo")
local rep  = string.rep
local insert = table.insert
local lpeg = require("lpeg")
local Cs, P, S, lpegmatch = lpeg.Cs, lpeg.P, lpeg.S, lpeg.match
local any = lpeg.P(1)

--- Find a template and return its contents (or `false` if
-- not found). The template is sought first in the
-- working directory, then in `templates`, then in
-- `$HOME/.lunamark/templates`, then in the Windows
-- `APPDATA` directory.
function M.find_template(name)
  local base, ext = name:match("([^%.]*)(.*)")
  if (not ext or ext == "") and format then ext = "." .. format end
  local fname = base .. ext
  local file = io.open(fname, "read")
  if not file then
    file = io.open("templates/" .. fname, "read")
  end
  if not file then
    local home = os.getenv("HOME")
    if home then
      file = io.open(home .. "/.lunamark/templates/" .. fname, "read")
    end
  end
  if not file then
    local appdata = os.getenv("APPDATA")
    if appdata then
      file = io.open(appdata .. "/lunamark/templates/" .. fname, "read")
    end
  end
  if file then
    return file:read("*all")
  else
    return false, "Could not find template '" .. fname .. "'"
  end
end

--- Implements a `sepby` directive for cosmo templates.
-- `$sepby{ myarray }[[$it]][[, ]]` will render the elements
-- of `myarray` separated by commas. If `myarray` is a string,
-- it will be treated as an array with one element.  If it is
-- `nil`, it will be treated as an empty array.
function M.sepby(arg)
  local a = arg[1]
  if not a then
    a = {}
  elseif type(a) ~= "table" then
    a = {a}
  end
  for i,v in ipairs(a) do
     if i > 1 then cosmo.yield{_template=2} end
     cosmo.yield{it = a[i], _template=1}
  end
end

--[[
-- extend(t) returns a table that falls back to t for non-found values
function M.extend(prototype)
  local newt = {}
  local metat = { __index = function(t,key)
                              return prototype[key]
                            end }
  setmetatable(newt, metat)
  return newt
end
--]]

--- Print error message and exit.
function M.err(msg, exit_code)
  io.stderr:write("lunamark: " .. msg .. "\n")
  os.exit(exit_code or 1)
end

--- Shallow table copy including metatables.
function M.table_copy(t)
  local u = { }
  for k, v in pairs(t) do u[k] = v end
  return setmetatable(u, getmetatable(t))
end

--- Expand tabs in a line of text.
-- `s` is assumed to be a single line of text.
-- From *Programming Lua*.
function M.expand_tabs_in_line(s, tabstop)
  local tab = tabstop or 4
  local corr = 0
  return (s:gsub("()\t", function(p)
          local sp = tab - (p - 1 + corr)%tab
          corr = corr - 1 + sp
          return rep(" ",sp)
        end))
end

--- Given a table `escapes` of escapable characters (or
-- byte sequences) and their escaped versions,
-- returns a function that escapes a string.
-- This function uses lpeg and is faster than gsub.
function M.escaper(escapes)
  local escapable = any
  for k,v in pairs(escapes) do
    escapable = P(k) / v + escapable
  end
  local escape_string = Cs(escapable^0)
  return function(s) return lpegmatch(escape_string, s) end
end

return M
