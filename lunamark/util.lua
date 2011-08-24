-- some miscellaneous helper functions

local M = {}

-- Templates recognize the following constructs:
-- * ${var} - gets filled with the value of dict[var]
-- * $[if foo]{yes}{no} - yes if foo is true and not an empty array.
--   The {no} part may be omitted.
-- * $[for x in foo]{blah ${x}[, ]} - prints blah ${...} for every
--   value of foo, interposing ", ".  The interposed part may be
--   omitted.
function M.fill_template(template, dict)
  local function adjust_cond(s)
    return string.gsub(tostring(s),"^{\n?",""):gsub("\n?}$","")
  end
  local function conditional(test,yes,no)
    local cond = dict[test]
    if cond and not (type(cond) == "table" and #cond == 0) then
      return adjust_cond(yes)
    else -- count 0-length array as false
      return (no == nil and "") or adjust_cond(no)
    end
  end
  local function adjust_for(s)
    return adjust_cond(s):gsub("%b[]$","")
  end
  local function forloop(var,ary,contents)
    if not (dict[ary] and type(dict[ary]) == "table") then
      return ""
    end
    local items = dict[ary]
    local cont = adjust_for(contents)
    local result = ""
    local between = contents:match("%b[]}$")
    between = (not between and "") or between:sub(2, #between - 2)
    for i=1,#items do
      result = result .. M.fill_template(cont, { [var] = items[i] })
      if i ~= #items then
        result = result .. between
      end
    end
    return result
  end
  return template:gsub("%$%[if%s+(%a+)%]%s*(%b{})(%b{})", conditional):gsub("%$%[if%s+(%a+)%]%s*(%b{})", conditional):gsub("%$%[for%s+(%a+)%s+in%s+(%a+)%](%b{})", forloop):gsub("%${(%a+)}", dict)
end

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
