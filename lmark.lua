#!/usr/bin/env lua
-- lunamark program

local lunamark = require("lunamark")
local cmdopts = require("lunamark.cmdopts")
local args = cmdopts.getargs({
   "lunamark [options] file - convert text from markdown",
   to = {shortform = true, arg = "format", description = "Target format"},
   }, { to = "html" } )
local writer_name = args.to
local writer = require(lunamark.writers[writer_name:lower()])
if not writer then
  util.err("Unknown writer: " .. tostring(args.to), 3)
end
writer.options.minimize = false
writer.options.blanklines = false
io.input(args[1])
io.write(lunamark.markdown(writer,{})(io.stdin))
