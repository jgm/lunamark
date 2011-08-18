-- some miscellaneous helper functions

local M = {}

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

--- return an interator over all lines in a string or file object
function M.lines(self)
  if type(self) == "file" then
    return io.lines(self)
  else
    if type(self) == "string" then
      local s = self
      if not s:find("\n$") then s = s.."\n" end
      return s:gfind("([^\n]*)\n")
    else
      return io.lines()
    end
  end
end

-- Expands tabs in a string or file object.
-- If no parameter supplied, uses stdin.
function M.expand_tabs(inp)
  local buffer = {}
  for line in M.lines(inp) do
    table.insert(buffer, M.expand_tabs_in_line(line,4))
  end
  -- need blank line at end to emulate Markdown.pl
  table.insert(buffer, "\n")
  return table.concat(buffer,"\n")
end

return M
