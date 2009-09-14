module(..., package.seeall)

local writer = require "lunamark.writer"
local parser = require "lunamark.parser"

function converter(in_format, out_format, options)
  assert(parser[in_format], string.format("input format `%s' not defined", in_format))
  assert(writer[out_format], string.format("output format `%s' not defined", out_format))
  return parser[in_format](writer[out_format], options)
end

