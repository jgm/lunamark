# Lunamark

Lunamark is a lua library for conversion between markup
formats. Currently markdown is the only supported input
format, and HTML, Docbook, ConTeXt and LaTeX are the supported output
formats.  But lunamark's modular architecture makes it
easy to add new parsers and writers. Parsers are written
using a PEG grammar.

The library is as portable as lua and has very good performance.
It is slightly faster than the author's own C library
[peg-markdown](http://github.com/jgm/peg-markdown).

## Installing

Lunamark can be installed using [luarocks](http://www.luarocks.org):

    git pull http://github.com/jgm/lunamark.git
    cd lunamark
    luarocks make

## The lunamark executable

The library comes with an executable, lunamark.  For usage
instructions, do `lunamark --help`.

## Using the library

Simple usage example:

    local lunamark = require("lunamark")
    local opts = { }
    local convert = lunamark.reader.markdown(lunamark.writer.html, opts)
    print(convert("Here's my *text*"))

For a more complex example, see the source for the
[lunamark executable](https://github.com/jgm/lunamark/blob/master/bin/lunamark).

# Authors

Most of the library is written by John MacFarlane.  Hans Hagen
made some major performance improvements.  Khaled Hosny added a
ConTeXt writer.

The `htmlparser` module is (c) 2009 by Christopher E. Moore, MIT licensed.
It has been modified slightly by John MacFarlane.
