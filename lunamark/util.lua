-- some miscellaneous helper functions

local M = {}

-- override string.format so that \n is a variable
-- newline (depending on the 'minimize' option).
-- formats are memoized after conversion.
function M.format(self,fmt,...)
  local newfmt = self.formats[fmt]
  if not newfmt then
    newfmt = fmt
    if self.options.minimize then
      newfmt = newfmt:gsub("\n","")
    end
    local starts_with_nl = newfmt:byte(1) == 10
    if starts_with_nl and not self.options.blanklines then
      newfmt = newfmt:sub(2)
      starts_with_nl = false
    end
    self.formats[fmt] = newfmt
    -- don't memoize this change, just on first line
    if starts_with_nl and self.firstline then
      newfmt = newfmt:sub(2)
    end
    if self.firstline then
      self.firstline = false
    end
  end
  return string.format(newfmt,...)
end

-- extend(t) returns a table that falls back to t for non-found values
function M.extend(prototype)
  local newt = {}
  local metat = { __index = function(t,key)
                              return prototype[key]
                            end }
  setmetatable(newt, metat)
  return newt
end

-- error message and exit
function M.err(msg, exit_code)
  io.stderr:write("lunamark: " .. msg .. "\n")
  os.exit(exit_code or 1)
end

-- shallow table copy including metatables
function M.table_copy(t)
  local u = { }
  for k, v in pairs(t) do u[k] = v end
  return setmetatable(u, getmetatable(t))
end

-- map function over elements of table
function M.map(f, t)
  local newt = {}
  for i,v in pairs(t) do
    newt[i] = f(v)
  end
  return newt
end

-- left fold: f(accumulator, table-element)
function M.fold(f, acc, t)
  for _,v in pairs(t) do
    acc = f(acc,v)
  end
  return acc
end

-- from Programming Lua
function M.expand_tabs_in_line(s, tabstop)
  local tab = tabstop or 4
  local corr = 0
  return (string.gsub(s, "()\t", function(p)
          local sp = tab - (p - 1 + corr)%tab
          corr = corr - 1 + sp
          return string.rep(" ",sp)
        end))
end

-- Get input, converting line endings to LF and optionally expanding tabs.
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
        table.insert(buffer, M.expand_tabs_in_line(line,tapstop))
      else
        table.insert(buffer, line)
      end
    end
  end
  if inptype == "table" and #inp > 0 then
    for _,f in ipairs(inp) do
      addlines(io.lines(f))
    end
  elseif inptype == "string" then
    local s = self
    if not s:find("\n$") then s = s.."\n" end
    addlines(s:gfind("([^\n]*)\n"))
  else
    addlines(io.lines())
  end
  -- need blank line at end to emulate Markdown.pl
  table.insert(buffer, "\n")
  return table.concat(buffer,"\n")
end

return M
