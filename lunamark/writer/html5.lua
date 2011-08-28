-- (c) 2009-2011 John MacFarlane. Released under MIT license.
-- See the file LICENSE in the source for details.

local util = require("lunamark.util")
local Html = require("lunamark.writer.html")

local Html5 = util.table_copy(Html)

local format = string.format

function Html5.section(s,level,contents)
  if Html5.options.containers then
    return format("<section>%s<h%d>%s</h%d>%s%s%s</section>", Html5.containersep, level, s, level, Html5.interblocksep, contents, Html5.containersep)
  else
    return format("<h%d>%s</h%d>%s%s",level,s,level,Html5.interblocksep,contents)
  end
end

return Html5
