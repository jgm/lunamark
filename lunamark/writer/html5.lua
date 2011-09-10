-- (c) 2009-2011 John MacFarlane. Released under MIT license.
-- See the file LICENSE in the source for details.

--- HTML 5 writer for lunamark.
-- Extends HTML writer, but uses `<section>` tags for sections
-- if `options.containers` is true.
-- @see lunamark.writer.html

local M = {}

local util = require("lunamark.util")
local html = require("lunamark.writer.html")
local format = string.format

--- Returns a new HTML 5 writer.
-- `options` is as in `lunamark.writer.html`.
-- @see lunamark.writer.html
-- @see lunamark.writer.generic
function M.new(options)
  local options = options or {}
  local Html5 = html.new(options)

  function Html5.section(s,level,contents)
    if options.containers then
      return format("<section>%s<h%d>%s</h%d>%s%s%s</section>", Html5.containersep, level, s, level, Html5.interblocksep, contents, Html5.containersep)
    else
      return format("<h%d>%s</h%d>%s%s",level,s,level,Html5.interblocksep,contents)
    end
  end

  Html5.template = [[
<html>
<head>
<title>$title</title>
<meta charset="utf-8" />
</head>
<body>
$body
</body>
</html>
]]

  return Html5
end

return M
