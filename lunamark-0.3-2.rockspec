package = "lunamark"
version = "0.3-2"
source = {
  url = "git://github.com/jgm/lunamark.git",
  tag = "0.3",
}
description = {
   summary = "General markup format converter using lpeg.",
   detailed = [[
     Lunamark is a lua library and command-line program for conversion of
     markdown to other textual formats. Currently HTML, Docbook, ConTeXt,
     LaTeX, dzslides, and Groff man are the supported output formats,
     but it is easy to add new writers or modify existing ones.
     The markdown parser is written using a PEG grammar and can also
     be modified by the user.
   ]],
   homepage = "http://jgm.github.com/lunamark",
   license = "MIT/X11",
}
dependencies = {
   "lua >= 5.1",
   "lpeg >= 0.10",
   "cosmo >= 10.0",
   "alt-getopt >= 0.7",
   "slnunicode >= 1.1",
}
build = {
   type = "none",
   install = {
     bin = {
       ["lunamark"]                 = "bin/lunamark",
       ["lunadoc"]                  = "bin/lunadoc",
       },
     lua = {
       ["lunamark"]                 = "lunamark.lua",
       ["lunamark.util"]            = "lunamark/util.lua",
       ["lunamark.entities"]        = "lunamark/entities.lua",
       ["lunamark.writer"]          = "lunamark/writer.lua",
       ["lunamark.writer.generic"]  = "lunamark/writer/generic.lua",
       ["lunamark.writer.xml"]      = "lunamark/writer/xml.lua",
       ["lunamark.writer.docbook"]  = "lunamark/writer/docbook.lua",
       ["lunamark.writer.html"]     = "lunamark/writer/html.lua",
       ["lunamark.writer.html5"]    = "lunamark/writer/html5.lua",
       ["lunamark.writer.dzslides"] = "lunamark/writer/dzslides.lua",
       ["lunamark.writer.tex"]      = "lunamark/writer/tex.lua",
       ["lunamark.writer.latex"]    = "lunamark/writer/latex.lua",
       ["lunamark.writer.context"]  = "lunamark/writer/context.lua",
       ["lunamark.writer.groff"]    = "lunamark/writer/groff.lua",
       ["lunamark.writer.man"]      = "lunamark/writer/man.lua",
       ["lunamark.reader"]          = "lunamark/reader.lua",
       ["lunamark.reader.markdown"] = "lunamark/reader/markdown.lua",
       },
   }
}

