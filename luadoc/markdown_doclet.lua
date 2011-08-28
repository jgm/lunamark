--[[ Note!  This requires a slightly patched luadoc.
--- util.lua.orig       2011-08-28 13:46:06.000000000 -0700
+++ util.lua    2011-08-28 13:46:11.000000000 -0700
@@ -52,7 +52,7 @@
        if str1 == nil or string.len(str1) == 0 then
                return str2
        else
-               return str1 .. " " .. str2
+               return str1 .. "\n" .. str2
        end
 end

I've suggested to the maintainers that they make this change.
--]]

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
  return oldstart(doc)
end

return mydoclet
