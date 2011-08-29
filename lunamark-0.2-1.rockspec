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
      formats.  Currently markdown and HTML are the supported input formats,
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
   "bit32",  -- this can go away when we require lua 5.2
   "alt-getopt >= 0.7",
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
       ["lunamark.htmlparser"]      = "lunamark/htmlparser.lua",
       ["lunamark.writer"]          = "lunamark/writer.lua",
       ["lunamark.writer.generic"]  = "lunamark/writer/generic.lua",
       ["lunamark.writer.xml"]      = "lunamark/writer/xml.lua",
       ["lunamark.writer.docbook"]  = "lunamark/writer/docbook.lua",
       ["lunamark.writer.html"]     = "lunamark/writer/html.lua",
       ["lunamark.writer.html5"]    = "lunamark/writer/html5.lua",
       ["lunamark.writer.tex"]      = "lunamark/writer/tex.lua",
       ["lunamark.writer.latex"]    = "lunamark/writer/latex.lua",
       ["lunamark.writer.context"]  = "lunamark/writer/context.lua",
       ["lunamark.reader"]          = "lunamark/reader.lua",
       ["lunamark.reader.markdown"] = "lunamark/reader/markdown.lua",
       ["lunamark.reader.html"]     = "lunamark/reader/html.lua",
       },
   }
}

