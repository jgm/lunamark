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

local converter = lunamark.reader.markdown(lunamark.writer.html,{smart=true})

for i=1,#arg do
  local f = arg[i]
  local comments = extract_comments(f)
  local modname = f:gsub("%.lua$",""):gsub("/",".")
  local inp = lunamark.util.get_input(comments)
  io.write("<h2 id=" .. modname .. ">" .. modname .. "</h2>\n\n")
  io.write(converter(inp))
  io.write("\n\n")
end


