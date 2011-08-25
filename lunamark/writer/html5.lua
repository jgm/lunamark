-- HTML5 writer for lunamark

local util = require("lunamark.util")
local Html = require("lunamark.writer.html")

local Html5 = util.table_copy(Html)

local format = string.format

function Html5.section(s,level,contents)
  if Html5.options.containers then
    return format("<section>\n<h%d>%s</h%d>\n%s</section>\n",level,s,level,contents)
  else
    return format("<h%d>%s</h%d>\n%s",level,s,level,contents)
  end
end

return Html5
