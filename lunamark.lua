-- (c) 2009-2011 John MacFarlane.  Released under MIT license.
-- See the file LICENSE in the source for details.

--- @copyright 2009-2011 John MacFarlane
-- Released under the MIT license. See LICENSE in the source
-- directory for details.

--- ## Description
--
-- Lunamark is a lua library for conversion between markup
-- formats. Currently Markdown and HTML are the only supported input
-- formats, and HTML, Docbook, ConTeXt, LaTeX, and Groff man
-- are the supported output formats, but lunamark's modular
-- architecture makes it easy to add new parsers and writers.
-- Parsers are written using a PEG grammar.
--
-- Lunamark's Markdown parser currently supports the following
-- extensions (which can be turned on or off individually):
--
--   - Smart typography (fancy quotes, dashes, ellipses)
--   - Significant start numbers in ordered lists
--   - Footnotes
--   - Definition lists
--
-- More extensions will be supported in later versions.
--
-- The library is as portable as lua and has very good performance.
-- It is slightly faster than the author's own C library
-- [peg-markdown](http://github.com/jgm/peg-markdown).
--
-- ## Simple usage example
--
--     local lunamark = require("lunamark")
--     local options = { smart = true, compact = true }
--     local writer = lunamark.writer.html.new(options)
--     local parse = lunamark.reader.markdown.new(writer, opts)
--     local result, metadata = parse("Here's my *text*")
--     print(result)
--
-- Note that `require("lunamark")` does not actually load any of
-- the reader or writer modules; these are loaded only when required.
-- So it is safe to `require("lunamark")` without worrying about
-- performance implications.
--
-- ## Customizing the writer
--
--     local mywriter = lunamark.writer.html.new(options)
--     local oldstring = mywriter.string
--     function mywriter.string(s)
--       return string.upper(oldstring(s))
--     end
--     local myparse = lunamark.reader.markdown.new(mywriter, opts)
--     local result, metadata = myparse("Here's my *text*")
--     print(result)
--
-- ## Customizing the reader
--
--     lpeg = require("lpeg")
--     local caps_header = C(lpeg.R("AZ ")^2) * optionalspace * newline * blankline
--                         / function(hdr) return writer.section(hdr,1) end
--     local myparse = lunamark.reader.markdown.new(mywriter, { custom_block = caps_header })
--     local result, metadata = myparse("SECTION ONE\n\nMy text\n")
--     print(result)

local G = {}

setmetatable(G,{ __index = function(t,name)
                             local mod = require("lunamark." .. name)
                             rawset(t,name,mod)
                             return t[name]
                            end })

return G
