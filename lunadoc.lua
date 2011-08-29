-- This program reads a number of source files, scans them
-- for multiline comment sections beginning with |,
-- and parses these as markdown, one big HTML file with sections
-- for each module.

lunamark = require("lunamark")

local function extract_comments(f)
  local commentlines = {}
  local collect = false
  io.input(f)
  for l in io.lines() do
    if l:sub(1,5) == "--[[|" then
      collect = true
    elseif l:sub(1,4) == "--]]" then
      collect = false
      table.insert(commentlines,"")
    elseif collect then
      table.insert(commentlines,l)
    end
  end
  return table.concat(commentlines,"\n")
end

local converter = lunamark.reader.markdown.new(lunamark.writer.html.new(),{smart=true})

for i=1,#arg do
  local f = arg[i]
  local comments = extract_comments(f)
  local modname = f:gsub("%.lua$",""):gsub("/",".")
  local inp = lunamark.util.get_input(comments)
  io.write("<div id=\"" .. modname .. "\">\n<h1>" .. modname .. "</h1>\n")
  io.write(converter(inp))
  io.write("\n</div>\n\n")
end


