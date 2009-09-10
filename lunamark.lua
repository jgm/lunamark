module(..., package.seeall)

local html_writer = require "lunamark.html_writer"
local markdown_parser = require "lunamark.markdown_parser"

writer = { html = html_writer.writer }
parser = { markdown = markdown_parser.parser }

function converter(in_format, out_format, options)
  assert(parser[in_format], "input format " .. in_format .. " not defined")
  assert(writer[out_format], "output format " .. out_format .. " not defined")
  return parser[in_format](writer[out_format], options)
end

