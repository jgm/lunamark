standard = require("luadoc.doclet.html")
lunamark = require("lunamark")

local writer = lunamark.writer.html
local markdown = lunamark.reader.markdown.new(writer,{})

local function markdownify(t)
  for k,v in pairs(t) do
    if type(v) == "table" then
      markdownify(v)
    elseif type(v) == "string" then
      if k == "summary" or k == "description" then
        t[k] = markdown(v)
      end
    end
  end
end

local oldstart = standard.start
local mydoclet = standard

function mydoclet.start(doc)
  markdownify(doc)
  -- print_r(doc)
  return oldstart(doc)
end

return mydoclet
