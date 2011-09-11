-- (c) 2009-2011 John MacFarlane.  Released under MIT license.
-- See the file LICENSE in the source for details.

--- Utility functions for lunamark.

local M = {}
local rep  = string.rep
local insert = table.insert

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

return M
