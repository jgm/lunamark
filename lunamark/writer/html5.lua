-- HTML5 writer for lunamark

local util = require("lunamark.util")
local Html = require("lunamark.writer.html")

local Html5 = util.table_copy(Html)

local format = Html.format

Html5.section = function(s,level,contents)
  return format("\n<section>\n<h%d>%s</h%d>\n%s</section>\n",level,s,level,contents)
end

return Html5
