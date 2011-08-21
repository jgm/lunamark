package = "lunamark"
version = "0.2-1"
source = {
   url = "http://github.com/jgm/lunamark/tarball/0.2",
--   md5 = "",
--   file = "jgm-lunamark-43bf6475ac5c9600dcdd66f34afb29bc8d48a50a.tar.gz"
}
description = {
   summary = "General markup format converter using lpeg.",
   detailed = [[
      lunamark is a lua library for converting between markup
      formats.  Currently markdown is the only supported input format,
      and HTML, HTML5, LaTeX, ConTeXt, and DocBook the supported output formats,
      but lunamark's modular structure makes it easy to add new parsers
      and writers.  Parsers are written using a PEG grammar.
   ]],
   homepage = "http://github.com/jgm/lunamark",
   license = "MIT/X11",
}
dependencies = {
   "lua >= 5.1",
   "lpeg >= 0.10",
   "luabitop > 1.0",
}
build = {
   type = "none",
   install = {
     bin = {
       ["lunamark"]                 = "bin/lunamark",
       },
     lua = {
       ["lunamark"]                 = "lunamark.lua",
       ["lunamark.util"]            = "lunamark/util.lua",
       ["lunamark.entities"]        = "lunamark/entities.lua",
       ["lunamark.cmdopts"]         = "lunamark/cmdopts.lua",
       ["lunamark.writer"]          = "lunamark/writer.lua",
       ["lunamark.writer.xml"]      = "lunamark/writer/xml.lua",
       ["lunamark.writer.docbook"]  = "lunamark/writer/docbook.lua",
       ["lunamark.writer.html"]     = "lunamark/writer/html.lua",
       ["lunamark.writer.html5"]    = "lunamark/writer/html5.lua",
       ["lunamark.writer.tex"]      = "lunamark/writer/tex.lua",
       ["lunamark.writer.latex"]    = "lunamark/writer/latex.lua",
       ["lunamark.writer.contex"]   = "lunamark/writer/latex.lua",
       ["lunamark.reader"]          = "lunamark/reader.lua",
       ["lunamark.reader.markdown"] = "lunamark/reader/markdown.lua",
       },
   }
}

