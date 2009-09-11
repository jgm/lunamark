package = "lunamark"
version = "0.1-1"
source = {
   url = ""
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
   homepage = "",
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
      ["lunamark.html_writer"] = "lunamark/html_writer.lua",
      ["lunamark.latex_writer"] = "lunamark/latex_writer.lua",
      ["lunamark.markdown_parser"] = "lunamark/markdown_parser.lua"
   }
}

