# Lunamark

Lunamark is a lua library and command-line program for conversion of markdown
to other textual formats. Currently HTML, [dzslides] (HTML5 slides),
Docbook, ConTeXt, LaTeX, and Groff man are the supported output formats, but
it is easy to add new writers or modify existing ones. The markdown parser is
written using a PEG grammar and can also be modified by the user.

The library is as portable as lua and has very good performance.
It is slightly faster than the author's own C library
[peg-markdown](http://github.com/jgm/peg-markdown), an order of
magnitude faster than pandoc, two orders of magnitude
faster than `Markdown.pl`, and three orders of magnitude
faster than `markdown.lua`.

# Links

+ [Source code repository]
+ [Issue tracker]
+ [Website]
+ [API documentation]
+ [lunamark(1)]
+ [lunadoc(1)]

[Source code repository]: https://github.com/jgm/lunamark
[Issue tracker]: https://github.com/jgm/lunamark/issues
[Website]: http:jgm.github.com/lunamark
[API documentation]: http://jgm.github.com/lunamark/doc/
[lunamark(1)]: http://jgm.github.com/lunamark/lunamark.1.html
[lunadoc(1)]: http://jgm.github.com/lunamark/lunadoc.1.html
[dzslides]: http://paulrouget.com/dzslides/ 

# Extensions

Lunamark's markdown parser currently supports the following extensions (which
can be turned on or off individually):

  - Smart typography (fancy quotes, dashes, ellipses)
  - Significant start numbers in ordered lists
  - Footnotes
  - Definition lists
  - Pandoc-style title blocks
  - Flexible metadata using lua declarations

More extensions will be supported in later versions.

# Benchmarks

Benchmarks (converting a 1M test file consisting of 25 copies of the
markdown test suite concatenated together):

* `discount` 0.14s
* `lunamark` 0.42s
* `peg-markdown` 0.50s
* `pandoc` 4.97s
* `Markdown.pl` (1.0.2b8) 56.75s
* `markdown.lua` 996.14s

It is very easy to extend the library by modifying the writers,
adding new writers, and even modifying the markdown parser. Some
simple examples are given in the [API documentation].

# Installing

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

# Using the library

Simple usage example:

    local lunamark = require("lunamark")
    local opts = { }
    local writer = lunamark.writer.html.new(opts)
    local parse = lunamark.reader.markdown.new(writer, opts)
    print(parse("Here's my *text*"))

For more examples, see [API documentation].

# The `lunamark` executable

The `lunamark` executable allows easy markdown conversion from the command
line.  For usage instructions, see the [lunamark(1)] man page.

# The `lunadoc` executable

Lunamark comes with a simple lua library documentation tool, `lunadoc`.
For usage instructions, see the [lunadoc(1)] man page.
`lunadoc` reads source files and parses specially marked markdown
comment blocks.  [Here][API documentation] is an example of the result.

# Tests

The source directory contains a large test suite in `tests`.
This includes existing Markdown and PHP Markdown tests, plus more
tests for lunamark-specific features and additional corner cases.

To run the tests, use `bin/shtest`.

    bin/shtest --help            # get usage
    bin/shtest                   # run all tests
    bin/shtest indent            # run all tests matching "indent"
    bin/shtest -p Markdown.pl -n # run all tests using Markdown.pl, and normalizing whitespace & entities

Lunamark currently fails a few of the PHP Markdown tests.
In most cases I disagree with the interpretation of markdown
syntax that these tests reflect.

# Authors

lunamark is released under the MIT license.

Most of the library is written by John MacFarlane.  Hans Hagen
made some major performance improvements.  Khaled Hosny added the
original ConTeXt writer.

The [dzslides] HTML, CSS, and javascript code is by Paul Rouget, released under
the DWTFYWT Public License.

