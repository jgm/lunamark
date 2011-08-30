--- This program reads a number of source files, scans them
-- for special comment blocks, and produces an HTML file with
-- documentation for each module and the functions contained in it.
--
-- Lunadoc processes only comment blocks that start with '---'.
--
-- If the comment block immediately precedes a function definition,
-- the name of the function is extracted automatically.

lunamark = require("lunamark")

local function extract_comments(f)
  local commentlines = {}
  local chunks = {}
  local collect = false
  local fun
  io.input(f)
  for l in io.lines() do
    local m = l:match("^%-%-%-%s?(.*)")
    if m then
      collect = true
      table.insert(commentlines,m)
    elseif collect then
      local n = l:match("^%-%-%s?(.*)")
      if n then
        table.insert(commentlines,n)
      else
        collect = false
        fun = l:match("function [^%.]*%.([%a_]+%([^%)]*%))")
        table.insert(chunks, { contents = table.concat(commentlines,"\n"), fun = fun })
        commentlines = {}
      end
    end
  end
  return chunks
end

local converter = lunamark.reader.markdown.new(lunamark.writer.html.new(),{smart=true})

for i=1,#arg do
  local f = arg[i]
  local chunks = extract_comments(f)
  local modname = f:gsub("%.lua$",""):gsub("/",".")
  io.write("<div id=\"" .. modname .. "\">\n<h1 class=\"module\">" .. modname .. "</h1>\n")
  for _,chunk in ipairs(chunks) do
    local fun = chunk.fun
    local funid = fun and fun:match("^[^%(]*")
    local inp = lunamark.util.get_input(chunk.contents)
    if fun then
      io.write("<div id=\"" .. funid .. "\">\n<h2 class=\"function\">" .. chunk.fun .. "</h2>\n")
    end
    io.write(converter(inp))
    if fun then
      io.write("\n</div>\n")
    end
  end
  io.write("\n</div>\n\n")
end


