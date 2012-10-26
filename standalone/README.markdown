# Lunamark

Lunamark is a command-line program for conversion of markdown
to other textual formats. Currently HTML, [dzslides] (HTML5 slides),
Docbook, ConTeXt, LaTeX, and Groff man are the supported output formats, but
it is easy to add new writers or modify existing ones. The markdown parser is
written using a PEG grammar and can also be modified by the user.

This is a "standalone" version of lunamark. (See also the [lua library
version](https://github.com/jgm/lunamark).) It is written in ANSI C and lua,
and compiles to an executable with no external dependencies. It is as portable
as lua and has very good performance. It is about the same speed as the
author's own C library [peg-markdown](http://github.com/jgm/peg-markdown), an
order of magnitude faster than pandoc, two orders of magnitude faster than
`Markdown.pl`, and three orders of magnitude faster than `markdown.lua`.

# Extensions

Lunamark's markdown parser currently supports a number of extensions
(which can be turned on or off individually), including:

  - Smart typography (fancy quotes, dashes, ellipses)
  - Significant start numbers in ordered lists
  - Footnotes
  - Definition lists
  - Pandoc-style title blocks
  - Flexible metadata using lua declarations

See the lunamark man page for a complete list.

It is very easy to extend the library by modifying the writers,
adding new writers, and even modifying the markdown parser. Some
simple examples are given in the [API documentation].

# Benchmarks

Benchmarks (converting a 1M test file consisting of 25 copies of the
markdown test suite concatenated together):

         0.03s   sundown
         0.13s   redcarpet
         0.14s   discount
     ->  0.35s   lunamark + luajit
         0.50s   peg-markdown
     ->  0.63s   lunamark + lua
         2.79s   PHP Markdown
         4.74s   RedCloth
         4.97s   pandoc
        56.75s   Markdown.pl
       996.14s   markdown.lua

Benchmarks on a 42K file (where startup time becomes significant):

        0.008s   sundown
        0.011s   discount
    ->  0.030s   lunamark + luajit
        0.037s   peg-markdown
    ->  0.046s   lunamark + lua
        0.111s   redcarpet
        0.292s   pandoc
        0.294s   Markdown.pl
        0.402s   RedCloth
        0.961s   markdown.lua

# Installing

On a linux, mac osx, or freebsd system, just Get the source and type 'make'.

    git clone http://github.com/jgm/lunamark-standalone.git
    cd lunamark-standalone
    make

This should produce an executable `lunamark` and a man page `lunamark.1`.
You should copy these to appropriate locations.

# Tests

The source directory contains a large test suite in `tests`.
This includes existing Markdown and PHP Markdown tests, plus more
tests for lunamark-specific features and additional corner cases.

To run the tests, use `scripts/shtest`.

    scripts/shtest --help            # get usage
    scripts/shtest                   # run all tests
    scripts/shtest indent            # run all tests matching "indent"
    scripts/shtest -p Markdown.pl -t # run all tests using Markdown.pl, and normalize using 'tidy'

Lunamark currently fails four of the PHP Markdown tests:

  * `tests/PHP_Markdown/Quotes in attributes.test`: The HTML is
    semantically equivalent; using the `-t/--tidy` option to `bin/shtest` makes
    the test pass.

  * `tests/PHP_Markdown/Email auto links.test`: The HTML is
    semantically equivalent. PHP markdown does entity obfuscation, and
    lunamark does not. This feature could be added easily enough, but the test
    would still fail, because the obfuscation involves randomness. Again,
    using the `-t/--tidy` option makes the test pass.

*   `tests/PHP_Markdown/Ins & del.test`:  PHP markdown puts extra `<p>`
    tags around `<ins>hello</ins>`, while lunamark does not.  It's hard
    to tell from the markdown spec which behavior is correct.

*   `tests/PHP_Markdown/Emphasis.test`:  A bunch of corner cases with nested
    strong and emphasized text.  These corner cases are left undecided by
    the markdown spec, so in my view the PHP test suite is not normative here;
    I think lunamark's behavior is perfectly reasonable, and I see no reason
    to change.

# Authors

lunamark is released under the MIT license.

Most of the library is written by John MacFarlane.  Hans Hagen
made some major performance improvements.  Khaled Hosny added the
original ConTeXt writer.

The [dzslides] HTML, CSS, and javascript code is by Paul Rouget, released under
the DWTFYWT Public License.

