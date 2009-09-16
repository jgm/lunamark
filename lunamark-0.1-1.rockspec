package = "lunamark"
version = "0.1-1"
source = {
   url = "http://github.com/jgm/lunamark/tarball/0.1"
}
description = {
   summary = "General markup format converter using lpeg.",
   detailed = [[
      lunamark is a lua library for converting between markup
      formats.  Currently markdown is the only supported input format,
      and HTML and LaTeX the only supported output formats, but lunamark's
      modular structure makes it easy to add new parsers and writers.
      Parsers are written using a PEG grammar.
   ]],
   homepage = "http://github.com/jgm/lunamark",
   license = "MIT",
}
dependencies = {
   "lua >= 5.1",
   "lpeg >= 0.9"
}
build = {
   type = "builtin",
   modules = {
      lunamark = "lunamark.lua",
      ["lunamark.util"] = "lunamark/util.lua",
      ["lunamark.writer"] = "lunamark/writer.lua",
      ["lunamark.writer.html"] = "lunamark/writer/html.lua",
      ["lunamark.writer.latex"] = "lunamark/writer/latex.lua",
      ["lunamark.parser"] = "lunamark/parser.lua",
      ["lunamark.parser.markdown"] = "lunamark/parser/markdown.lua",
      ["lunamark.parser.generic"] = "lunamark/parser/generic.lua",
   }
}

