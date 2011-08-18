-- HTML5 writer for lunamark

Html = require("lunamark.writer.html")

Html5 = Html

local format = Html.format

function Html5.section(s,level,contents)
  return format("\n<section>\n<h%d>%s</h%d>\n%s</section>\n",level,s,level,contents)
end

return Html5
