Lunamark
========

Lunamark is a lua library for conversion between markup
formats. Currently markdown is the only supported input
format, and HTML and LaTeX are the only supported output
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

    require "luarocks.require"
    require "lunamark"

    -- read stdin
    local inp = io.read("*a")

    -- note: these are functions:
    local markdown2html_string = lunamark.converter("markdown", "html").to_string
    local write_markdown2latex = lunamark.converter("markdown", "latex").write

    -- return a string:
    output = markdown2html_string(inp)
    print(output)

    -- or, write directly to file:
    write_markdown2latex(io.stdout, inp)

