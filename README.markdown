Lunamark
========

Lunamark is a lua library for conversion between markup
formats. Currently markdown is the only supported input
format, and HTML, LaTeX and ConTeXt are the only supported output
formats.  But lunamark's modular architecture makes it
easy to add new parsers and writers. Parsers are written
using a PEG grammar.

Installing
----------

Lunamark can be installed using [luarocks](http://www.luarocks.org):

    git pull http://github.com/jgm/lunamark.git
    cd lunamark
    luarocks make

Using
-----

    lunamark.converter(in_format, out_format, options)

returns a function from string to string.  `in_format` is currently
limited to `markdown`; `out_format` can be `html`, `latex` or `context`.
`options` is a table; currently the only supported option is
`modify_syntax`, a function from a grammar table to a grammar
table that can ring changes on the standard markdown syntax.

    require "luarocks.require"
    require "lunamark"

    -- read stdin
    inp = io.read("*a")

    -- note: these are functions:
    markdown2html = lunamark.converter("markdown", "html")
    markdown2latex = lunamark.converter("markdown", "latex")
    -- this one changes the syntax definition:
    markdown2htmlCAPS = lunamark.converter("markdown", "html",
                         { modify_syntax = function(t) t.Str = t.Str / string.upper; return t end })

    io.write("HTML:\n",markdown2html(inp))
    io.write("-----\n")
    io.write("LaTeX:\n",markdown2latex(inp))
    io.write("-----\n")
    io.write("HTML CAPS:\n",markdown2htmlCAPS(inp))
