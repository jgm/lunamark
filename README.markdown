# Lunamark

Lunamark is a lua library for conversion between markup
formats. Currently Markdown and HTML are the only supported input
formats, and HTML, Docbook, ConTeXt, LaTeX, and Groff man
are the supported output formats, but lunamark's modular
architecture makes it easy to add new parsers and writers.
Parsers are written using a PEG grammar.

Lunamark's Markdown parser currently supports the following
extensions (which can be turned on or off individually):

  - Smart typography (fancy quotes, dashes, ellipses)
  - Significant start numbers in ordered lists
  - Footnotes

More extensions will be supported in later versions.

The library is as portable as lua and has very good performance.
It is slightly faster than the author's own C library
[peg-markdown](http://github.com/jgm/peg-markdown).

Benchmarks (converting a 685K test file consisting of 25 copies of
the markdown syntax documentation concatenated together):

* `discount` 0.082s
* `lunamark` 0.254s
* `peg-markdown` 0.321s
* `pandoc --strict` 1.748s
* `Markdown.pl` (1.0.2b8) 15.084s
* `markdown.lua` 3m6.997s

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
    local writer = lunamark.writer.html.new(opts)
    local parse = lunamark.reader.markdown.new(writer, opts)
    print(parse("Here's my *text*"))

For a more complex example, see the source for the
[lunamark executable](https://github.com/jgm/lunamark/blob/master/bin/lunamark).

# Authors

Most of the library is written by John MacFarlane.  Hans Hagen
made some major performance improvements.  Khaled Hosny added a
ConTeXt writer.

The `htmlparser` module is (c) 2009 by Christopher E. Moore, MIT licensed.
It has been modified slightly by John MacFarlane.
