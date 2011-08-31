--- This program reads a number of source files, scans them
-- for special comment blocks beginning with '---', and writes
-- an HTML file documenting each module to the doc directory.
-- If the comment block immediately precedes a function definition,
-- the name of the function is extracted automatically.
--
-- Each file is assumed to be a module.  The 'module' keyword need
-- not be used.
--
-- Documentation is parsed as markdown.

lunamark = require("lunamark")

local destdir = "doc"

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

local template = [[
<html>
<head>
<title>${modname}</title>
<meta http-equiv="Content-Type" content="text/html; charset=utf-8" />
<link rel="stylesheet" href="lunadoc.css" type="text/css" />
</head>
<body>
<div id="content">
<h1 class="module">${modname}</h1>
${contents}
</div>
<div id="index">
${index}
</div>
</body>
</html>
]]

local funtemplate = [[
<div id="${id}">
<h2 class="function">${name}</h2>
${contents}
</div>
]]

local css = [[
div#index { position: absolute; left: 1em; top: 1em; width:14em; border-right: 1px solid grey; }
div#content { position: absolute; left: 15em; top: 0em; padding-left: 2em; max-width: 40em; }
]]

local index_table = {}

local function get_modname(s)
  return s:gsub("%.lua$",""):gsub("/",".")
end

for i=1,#arg do
  local modname = get_modname(arg[i])
  table.insert(index_table, "<p><a href=\"" .. modname .. ".html\">" .. modname .. "</a></p>")
end

local index = table.concat(index_table,"\n")

local writer = lunamark.writer.html.new()
writer.link = new_link
local converter = lunamark.reader.markdown.new(writer,{smart=true})

for i=1,#arg do
  local f = arg[i]
  local chunks = extract_comments(f)
  local modname = get_modname(f)
  local funs = {}
  for _,chunk in ipairs(chunks) do
    local fun = chunk.fun
    local funid = fun and fun:match("^[^%(]*")
    local inp = lunamark.util.get_input(chunk.contents)
    if fun then
      local funtext = funtemplate:gsub("${(%w+)}", { name = fun, id = funid, contents = converter(inp) })
      table.insert(funs, funtext)
    else
      table.insert(funs, converter(inp))
    end
  end
  local page = template:gsub("${(%w+)}",{ modname = modname, index = index, contents = table.concat(funs) })
  local file = io.open(destdir .. "/" .. modname .. ".html", "w")
  file:write(page)
  file:close()
end

local file = io.open(destdir .. "/lunadoc.css", "w")
file:write(css)
file:close()
