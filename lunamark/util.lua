-- (c) 2009-2011 John MacFarlane.  Released under MIT license.
-- See the file LICENSE in the source for details.

local M = {}

local rep  = string.rep
local insert = table.insert

--- Find a template and return its string contents.
-- If the template has no extension, an extension
-- is added based on the writer name.  Look first in ., then in
-- templates, then in ~/.lunamark/templates, then in APPDATA.
function M.find_template(name, format)
  if not name then name = "default" end
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
  if not file then
    M.err("Could not find template '" .. fname .. "'")
  else
    return file:read("*all")
  end
end

--- extend(t) returns a table that falls back to t for non-found values
function M.extend(prototype)
  local newt = {}
  local metat = { __index = function(t,key)
                              return prototype[key]
                            end }
  setmetatable(newt, metat)
  return newt
end

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

-- from Programming Lua
local function expand_tabs_in_line(s, tabstop)
  local tab = tabstop or 4
  local corr = 0
  return (s:gsub("()\t", function(p)
          local sp = tab - (p - 1 + corr)%tab
          corr = corr - 1 + sp
          return rep(" ",sp)
        end))
end

--- Get input, converting line endings to LF and optionally expanding tabs.
-- (Tabs are expanded if the optional tabstop argument is provided.)
-- If inp is a string, input is a string.
-- If inp is a nonempty array, elements are assumed to be
-- filenames and input is taken from them in sequence.
-- Otherwise, the current input handle is used.
function M.get_input(inp, tabstop)
  local buffer = {}
  local tabstop = 4
  local inptype = type(inp)
  local function addlines(iterator)
    for line in iterator do
      if tabstop then
        insert(buffer, expand_tabs_in_line(line,tabstop))
      else
        insert(buffer, line)
      end
    end
  end
  if inptype == "table" and #inp > 0 then
    for _,f in ipairs(inp) do
      addlines(io.lines(f))
    end
  elseif inptype == "string" then
    local s = inp
    if not s:find("\n$") then s = s.."\n" end
    addlines(s:gfind("([^\r\n]*)\r?\n"))
  else
    addlines(io.lines())
  end
  -- need blank line at end to emulate Markdown.pl
  insert(buffer, "\n")
  return table.concat(buffer,"\n")
end

return M
