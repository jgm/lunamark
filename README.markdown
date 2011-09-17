# Lunamark

Lunamark is a lua library and command-line program for conversion of markdown
to other textual formats. Currently HTML, dzslides (HTML5 slides),
Docbook, ConTeXt, LaTeX, and Groff man are the supported output formats, but
it is easy to add new writers or modify existing ones. The markdown parser is
written using a PEG grammar and can also be modified by the user.

Lunamark's markdown parser currently supports the following extensions (which
can be turned on or off individually):

  - Smart typography (fancy quotes, dashes, ellipses)
  - Significant start numbers in ordered lists
  - Footnotes
  - Definition lists

More extensions will be supported in later versions.

The library is as portable as lua and has very good performance.
It is slightly faster than the author's own C library
[peg-markdown](http://github.com/jgm/peg-markdown), an order of
magnitude faster than pandoc, two orders of magnitude
faster than `Markdown.pl`, and three orders of magnitude
faster than `markdown.lua`.

Benchmarks (converting a 1M test file consisting of 25 copies of the
markdown test suite concatenated together):

* `discount` 0.14s
* `lunamark` 0.43s
* `peg-markdown` 0.50s
* `pandoc` 4.97s
* `Markdown.pl` (1.0.2b8) 56.75s
* `markdown.lua` 996.14s

It is very easy to extend the library by modifying the writers,
adding new writers, and even modifying the markdown parser. Some
simple examples are given in the [API documentation].

## Installing

You can install the latest development version of
lunamark using [luarocks](http://www.luarocks.org):

    git pull http://github.com/jgm/lunamark.git
    cd lunamark
    luarocks make

Released versions will be uploaded to the luarocks
repository, so you should be able to install them using:

    luarocks install lunamark

There may be a short delay between the release and the
luarocks upload.

## Using the library

Simple usage example:

    local lunamark = require("lunamark")
    local opts = { }
    local writer = lunamark.writer.html.new(opts)
    local parse = lunamark.reader.markdown.new(writer, opts)
    print(parse("Here's my *text*"))

For more examples, see [API documentation].

## The lunamark executable

The `lunamark` executable allows easy markdown conversion from the command
line.  For usage instructions, do `lunamark --help`.

Usage examples:

    lunamark

reads markdown from stdin and writes html to stdout.

    lunamark -t man -s -o prog.1 -Xsmart,notes prog.txt

converts `prog.txt` from markdown to groff man (`-t man`),
producing a standalone file with header and footer (`-s`)
called `prog.1` (`-o prog.1`), and enabling the
smart typography and notes extensions `-Xsmart,notes`.

    lunamark -t man -o prog.1 --template custom \
      -d section=1,date="July 2011" -Xsmart,notes prog.txt

As before, but uses the custom template `custom.man`
(which it will seek first in the working directory,
then in `templates`, then in `~/.lunamark/templates`),
setting the `section` variable to `1` and the
`date` variable to `July 2011`.

# Authors

lunamark is released under the MIT license.

Most of the library is written by John MacFarlane.  Hans Hagen
made some major performance improvements.  Khaled Hosny added the
original ConTeXt writer.

The dzslides HTML, CSS, and javascript code is by Paul Rouget, released under
the DWTFYWT Public License.

[API documentation]: jgm.github.com/lunamark/doc/

