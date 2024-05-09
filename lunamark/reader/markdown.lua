-- (c) 2009-2011 John MacFarlane, Hans Hagen.  Released under MIT license.
-- See the file LICENSE in the source for details.

local util = require("lunamark.util")
local lpeg = require("lpeg")
local entities = require("lunamark.entities")
local lower, upper, gsub, format, length =
  string.lower, string.upper, string.gsub, string.format, string.len
local P, R, S, V, C, Cg, Cb, Cmt, Cc, Ct, B, Cs, Cf =
  lpeg.P, lpeg.R, lpeg.S, lpeg.V, lpeg.C, lpeg.Cg, lpeg.Cb,
  lpeg.Cmt, lpeg.Cc, lpeg.Ct, lpeg.B, lpeg.Cs, lpeg.Cf
local lpegmatch = lpeg.match
local expand_tabs_in_line = util.expand_tabs_in_line
local utf8_lower do
  if pcall(require, "lua-utf8") then -- try luautf8
    local luautf8 = require("lua-utf8")
    utf8_lower = luautf8.lower
  elseif pcall(require, "unicode") then -- try slnunicode
    local slnunicde = require "unicode"
    utf8_lower = slnunicde.utf8.lower
  else
    error "no unicode library found"
  end
end

local load = load -- lua 5.2/5.3 style `load` function
if _VERSION == "Lua 5.1" then
  function load(ld, source, mode, env)
    assert(mode == "t")
    if ld:sub(1,1) == "\27" then
      error("attempt to load a binary chunk (mode is 'text')")
    end
    local chunk, msg = loadstring(ld, source)
    if not chunk then
      return chunk, msg
    end
    if env ~= nil then
      setfenv(chunk, env)
    end
    return chunk
  end
end

local M = {}

local rope_to_string = util.rope_to_string

-- Normalize a markdown reference tag.  (Make lowercase, and collapse
-- adjacent whitespace characters.)
local function normalize_tag(tag)
  return utf8_lower(gsub(rope_to_string(tag), "[ \n\r\t]+", " "))
end

------------------------------------------------------------------------------

local parsers                  = {}

------------------------------------------------------------------------------
-- Basic parsers
------------------------------------------------------------------------------

parsers.percent                = P("%")
parsers.at                     = P("@")
parsers.comma                  = P(",")
parsers.asterisk               = P("*")
parsers.dash                   = P("-")
parsers.plus                   = P("+")
parsers.underscore             = P("_")
parsers.period                 = P(".")
parsers.hash                   = P("#")
parsers.ampersand              = P("&")
parsers.backtick               = P("`")
parsers.less                   = P("<")
parsers.more                   = P(">")
parsers.space                  = P(" ")
parsers.squote                 = P("'")
parsers.dquote                 = P('"')
parsers.lparent                = P("(")
parsers.rparent                = P(")")
parsers.lbracket               = P("[")
parsers.rbracket               = P("]")
parsers.circumflex             = P("^")
parsers.slash                  = P("/")
parsers.equal                  = P("=")
parsers.colon                  = P(":")
parsers.semicolon              = P(";")
parsers.exclamation            = P("!")
parsers.pipe                   = P("|")
parsers.tilde                  = P("~")
parsers.tab                    = P("\t")
parsers.newline                = P("\n")
parsers.tightblocksep          = P("\001")

parsers.digit                  = R("09")
parsers.hexdigit               = R("09","af","AF")
parsers.letter                 = R("AZ","az")
parsers.alphanumeric           = R("AZ","az","09")
parsers.keyword                = parsers.letter
                               * parsers.alphanumeric^0
parsers.citation_chars         = parsers.alphanumeric
                               + S("#$%&-+<>~/_")
parsers.internal_punctuation   = S(":;,.?")

parsers.doubleasterisks        = P("**")
parsers.doubleequals           = P("==")
parsers.doubleunderscores      = P("__")
parsers.doubletildes           = P("~~")
parsers.fourspaces             = P("    ")

parsers.any                    = P(1)
parsers.fail                   = parsers.any - 1

parsers.escapable              = S("\\`*_{}[]()+_.!<>#-~:^@;")
parsers.anyescaped             = P("\\") / "" * parsers.escapable
                               + parsers.any

parsers.spacechar              = S("\t ")
parsers.spacing                = S(" \n\r\t")
parsers.nonspacechar           = parsers.any - parsers.spacing
parsers.optionalspace          = parsers.spacechar^0

parsers.eof                    = -parsers.any
parsers.nonindentspace         = parsers.space^-3 * -parsers.spacechar
parsers.indent                 = parsers.space^-3 * parsers.tab
                               + parsers.fourspaces / ""
parsers.linechar               = P(1 - parsers.newline)

parsers.blankline              = parsers.optionalspace
                               * parsers.newline / "\n"
parsers.blanklines             = parsers.blankline^0
parsers.skipblanklines         = (parsers.optionalspace * parsers.newline)^0
parsers.indentedline           = parsers.indent    /""
                               * C(parsers.linechar^1 * parsers.newline^-1)
parsers.optionallyindentedline = parsers.indent^-1 /""
                               * C(parsers.linechar^1 * parsers.newline^-1)
parsers.sp                     = parsers.spacing^0
parsers.spnl                   = parsers.optionalspace
                               * (parsers.newline * parsers.optionalspace)^-1
parsers.line                   = parsers.linechar^0 * parsers.newline
parsers.nonemptyline           = parsers.line - parsers.blankline

parsers.chunk                  = parsers.line * (parsers.optionallyindentedline
                                                - parsers.blankline)^0

-- block followed by 0 or more optionally
-- indented blocks with first line indented.
parsers.indented_blocks = function(bl)
  return Cs( bl
         * (parsers.blankline^1 * parsers.indent * -parsers.blankline * bl)^0
         *  parsers.blankline^1 )
end

-- Attributes list as in Pandoc {#id .class .class-other key=value key2="value 2"}
--   Note: Pandoc has the same identifier definitions, but its interpretation
--   of a letter (and by extension an alphanumeric value) extends to alphabetic
--   *Unicode* characters.
parsers.attrid      = parsers.letter
                      * (parsers.alphanumeric + S("_-:."))^0

parsers.attrvalue   = (parsers.dquote
                      * C((parsers.anyescaped - parsers.dquote)^0)
                      * parsers.dquote)
                    + (parsers.squote
                      * C((parsers.anyescaped - parsers.squote)^0)
                      * parsers.squote)
                    + C((parsers.anyescaped - parsers.dquote - parsers.space - P("}"))^1)

parsers.attrpair    = Cg(C(parsers.attrid)
                      * parsers.optionalspace * parsers.equal * parsers.optionalspace
                      * parsers.attrvalue)
                      * parsers.optionalspace^-1
parsers.attrlist    = Cf(Ct("") * parsers.attrpair^0, rawset)

parsers.class       = (P("-") * Cc("unnumbered")) + (parsers.period * C((parsers.attrid)^1))
parsers.classes     = (parsers.class * parsers.optionalspace)^0

parsers.hashid      = parsers.hash * C((parsers.alphanumeric + S("-_:."))^1)

parsers.attributes  = P("{") * parsers.optionalspace
                      * Cg(parsers.hashid^-1) * parsers.optionalspace
                      * Ct(parsers.classes) * Cg(parsers.attrlist)
                      * parsers.optionalspace * P("}")
                      / function (hashid, classes, attr)
                          attr.id = hashid ~= "" and hashid or nil
                          attr.class = table.concat(classes or {}, " ")
                          return attr
                        end
-- Raw attributes similar to Pandoc (=format key=value key2="value 2")
parsers.rawid            = parsers.alphanumeric + S("_-")
parsers.raw              = parsers.equal * C((parsers.rawid)^1) * parsers.optionalspace
parsers.rawattributes    = P("{") * parsers.optionalspace
                          * parsers.raw * Cg(parsers.attrlist)
                          * parsers.optionalspace * P("}")

-----------------------------------------------------------------------------
-- Parsers used for markdown lists
-----------------------------------------------------------------------------

parsers.bulletchar = C(parsers.plus + parsers.asterisk + parsers.dash)

parsers.bullet     = ( parsers.bulletchar * #parsers.spacing
                                          * (parsers.tab + parsers.space^-3)
                     + parsers.space * parsers.bulletchar * #parsers.spacing
                                     * (parsers.tab + parsers.space^-2)
                     + parsers.space * parsers.space * parsers.bulletchar
                                     * #parsers.spacing
                                     * (parsers.tab + parsers.space^-1)
                     + parsers.space * parsers.space * parsers.space
                                     * parsers.bulletchar * #parsers.spacing
                     )

-----------------------------------------------------------------------------
-- Parsers used for markdown code spans
-----------------------------------------------------------------------------

parsers.openticks   = Cg(parsers.backtick^1, "ticks")

local function captures_equal_length(_,i,a,b)
  return #a == #b and i
end

parsers.closeticks  = parsers.space^-1
                    * Cmt(C(parsers.backtick^1)
                    * Cb("ticks"), captures_equal_length)

parsers.intickschar = (parsers.any - S(" \n\r`"))
                    + (parsers.newline * -parsers.blankline)
                    + (parsers.space - parsers.closeticks)
                    + (parsers.backtick^1 - parsers.closeticks)

parsers.inticks     = parsers.openticks * parsers.space^-1
                    * C(parsers.intickschar^1) * parsers.closeticks

-----------------------------------------------------------------------------
-- Parsers used for fenced code blocks
-----------------------------------------------------------------------------

local function captures_geq_length(_,i,a,b)
  return #a >= #b and i
end

parsers.tilde_infostring
                    = C((parsers.linechar
                       - (parsers.spacechar^1 * parsers.newline))^0)
                    * parsers.optionalspace
                    * (parsers.newline + parsers.eof)

parsers.backtick_infostring
                    = C((parsers.linechar
                       - (parsers.backtick
                         + parsers.spacechar^1 * parsers.newline))^0)
                    * parsers.optionalspace
                    * (parsers.newline + parsers.eof)

local fenceindent
parsers.fencehead   = function(char, infostring)
  return              C(parsers.nonindentspace) / function(s)
                                                    fenceindent = #s
                                                  end
                    * Cg(char^3, "fencelength")
                    * parsers.optionalspace * infostring
end

parsers.fencetail   = function(char)
  return              parsers.nonindentspace
                    * Cmt(C(char^3) * Cb("fencelength"), captures_geq_length)
                    * parsers.optionalspace * (parsers.newline + parsers.eof)
end

parsers.fencedline  = function(char)
  return              C(parsers.line - parsers.fencetail(char))
                    / function(s)
                        return s:gsub("^" .. string.rep(" ?", fenceindent), "")
                       end
end

------------------------------------------------------------------------------
-- Parsers used for fenced divs
------------------------------------------------------------------------------

parsers.fenced_div_infostring
                         = C((parsers.linechar
                            - ( parsers.spacechar^1
                              * parsers.colon^1))^1)

parsers.fenced_div_begin = parsers.nonindentspace
                         * parsers.colon^3
                         * parsers.optionalspace
                         * parsers.fenced_div_infostring
                         * ( parsers.spacechar^1
                           * parsers.colon^1)^0
                         * parsers.optionalspace
                         * (parsers.newline + parsers.eof)

parsers.fenced_div_end   = parsers.nonindentspace
                         * parsers.colon^3
                         * parsers.optionalspace
                         * (parsers.newline + parsers.eof)

-----------------------------------------------------------------------------
-- Parsers used for markdown tags and links
-----------------------------------------------------------------------------

parsers.leader      = parsers.space^-3

-- in balanced brackets, parentheses, quotes:
parsers.bracketed   = P{ parsers.lbracket
                       * ((parsers.anyescaped - (parsers.lbracket
                                                + parsers.rbracket
                                                + parsers.blankline^2)
                          ) + V(1))^0
                       * parsers.rbracket }

parsers.inparens    = P{ parsers.lparent
                       * ((parsers.anyescaped - (parsers.lparent
                                                 + parsers.rparent
                                                 + parsers.blankline^2)
                          ) + V(1))^0
                       * parsers.rparent }

parsers.squoted     = P{ parsers.squote * parsers.alphanumeric
                       * ((parsers.anyescaped - (parsers.squote
                                                 + parsers.blankline^2)
                          ) + V(1))^0
                       * parsers.squote }

parsers.dquoted     = P{ parsers.dquote * parsers.alphanumeric
                       * ((parsers.anyescaped - (parsers.dquote
                                                + parsers.blankline^2)
                          ) + V(1))^0
                       * parsers.dquote }

-- bracketed 'tag' for markdown links, allowing nested brackets:
parsers.tag         = parsers.lbracket
                    * Cs((parsers.alphanumeric^1
                         + parsers.bracketed
                         + parsers.inticks
                         + (parsers.anyescaped - (parsers.rbracket
                                                 + parsers.blankline^2)))^0)
                    * parsers.rbracket

-- url for markdown links, allowing balanced parentheses:
parsers.url         = parsers.less * Cs((parsers.anyescaped-parsers.more)^0)
                                   * parsers.more
                    + Cs((parsers.inparens + (parsers.anyescaped
                                             -parsers.spacing-parsers.rparent))^1)

-- quoted text possibly with nested quotes:
parsers.title_s     = parsers.squote * Cs(((parsers.anyescaped-parsers.squote)
                                          + parsers.squoted)^0)
                                     * parsers.squote

parsers.title_d     = parsers.dquote  * Cs(((parsers.anyescaped-parsers.dquote)
                                           + parsers.dquoted)^0)
                                      * parsers.dquote

parsers.title_p     = parsers.lparent
                    * Cs((parsers.inparens + (parsers.anyescaped-parsers.rparent))^0)
                    * parsers.rparent

parsers.title       = parsers.title_d + parsers.title_s + parsers.title_p

parsers.optionaltitle
                    = parsers.spnl * parsers.title * parsers.spacechar^0
                    + Cc("")

------------------------------------------------------------------------------
-- Parsers used for citations
------------------------------------------------------------------------------

parsers.citation_name = Cs(parsers.dash^-1) * parsers.at
                      * Cs(parsers.citation_chars
                          * (((parsers.citation_chars + parsers.internal_punctuation
                              - parsers.comma - parsers.semicolon)
                             * -#((parsers.internal_punctuation - parsers.comma
                                  - parsers.semicolon)^0
                                 * -(parsers.citation_chars + parsers.internal_punctuation
                                    - parsers.comma - parsers.semicolon)))^0
                            * parsers.citation_chars)^-1)

parsers.citation_body_prenote
                    = Cs((parsers.alphanumeric^1
                         + parsers.bracketed
                         + parsers.inticks
                         + (parsers.anyescaped
                           - (parsers.rbracket + parsers.blankline^2))
                         - (parsers.spnl * parsers.dash^-1 * parsers.at))^0)

parsers.citation_body_postnote
                    = Cs((parsers.alphanumeric^1
                         + parsers.bracketed
                         + parsers.inticks
                         + (parsers.anyescaped
                           - (parsers.rbracket + parsers.semicolon
                             + parsers.blankline^2))
                         - (parsers.spnl * parsers.rbracket))^0)

parsers.citation_body_chunk
                    = parsers.citation_body_prenote
                    * parsers.spnl * parsers.citation_name
                    * ((parsers.internal_punctuation - parsers.semicolon)
                      * parsers.spnl)^-1
                    * parsers.citation_body_postnote

parsers.citation_body
                    = parsers.citation_body_chunk
                    * (parsers.semicolon * parsers.spnl
                      * parsers.citation_body_chunk)^0

parsers.citation_headless_body
                    = Cs((parsers.alphanumeric^1
                         + parsers.bracketed
                         + parsers.inticks
                         + (parsers.anyescaped
                           - (parsers.rbracket + parsers.at
                             + parsers.semicolon + parsers.blankline^2))
                         - (parsers.spnl * parsers.rbracket))^0)
                    * (parsers.sp * parsers.semicolon * parsers.spnl
                      * parsers.citation_body_chunk)^0

------------------------------------------------------------------------------
-- Parsers used for footnotes
------------------------------------------------------------------------------

local function strip_first_char(s)
  return s:sub(2)
end

parsers.RawNoteRef = #(parsers.lbracket * parsers.circumflex)
                   * parsers.tag / strip_first_char

------------------------------------------------------------------------------
-- Parsers used for HTML
------------------------------------------------------------------------------

-- case-insensitive match (we assume s is lowercase). must be single byte encoding
parsers.keyword_exact = function(s)
  local parser = P(0)
  for i=1,#s do
    local c = s:sub(i,i)
    local m = c .. upper(c)
    parser = parser * S(m)
  end
  return parser
end

parsers.block_keyword =
    parsers.keyword_exact("address") + parsers.keyword_exact("blockquote") +
    parsers.keyword_exact("center") + parsers.keyword_exact("del") +
    parsers.keyword_exact("dir") + parsers.keyword_exact("div") +
    parsers.keyword_exact("p") + parsers.keyword_exact("pre") +
    parsers.keyword_exact("li") + parsers.keyword_exact("ol") +
    parsers.keyword_exact("ul") + parsers.keyword_exact("dl") +
    parsers.keyword_exact("dd") + parsers.keyword_exact("form") +
    parsers.keyword_exact("fieldset") + parsers.keyword_exact("isindex") +
    parsers.keyword_exact("ins") + parsers.keyword_exact("menu") +
    parsers.keyword_exact("noframes") + parsers.keyword_exact("frameset") +
    parsers.keyword_exact("h1") + parsers.keyword_exact("h2") +
    parsers.keyword_exact("h3") + parsers.keyword_exact("h4") +
    parsers.keyword_exact("h5") + parsers.keyword_exact("h6") +
    parsers.keyword_exact("hr") + parsers.keyword_exact("script") +
    parsers.keyword_exact("noscript") + parsers.keyword_exact("table") +
    parsers.keyword_exact("tbody") + parsers.keyword_exact("tfoot") +
    parsers.keyword_exact("thead") + parsers.keyword_exact("th") +
    parsers.keyword_exact("td") + parsers.keyword_exact("tr") +
    parsers.keyword_exact("style")

-- There is no reason to support bad html, so we expect quoted attributes
parsers.htmlattributevalue
                          = parsers.squote * (parsers.any - (parsers.blankline
                                                            + parsers.squote))^0
                                           * parsers.squote
                          + parsers.dquote * (parsers.any - (parsers.blankline
                                                            + parsers.dquote))^0
                                           * parsers.dquote

parsers.htmlattribute     = parsers.spacing^1
                          * (parsers.alphanumeric + S("_-"))^1
                          * parsers.sp * parsers.equal * parsers.sp
                          * parsers.htmlattributevalue

parsers.htmlcomment       = P("<!--") * (parsers.any - P("-->"))^0 * P("-->")

parsers.htmlinstruction   = P("<?")   * (parsers.any - P("?>" ))^0 * P("?>" )

parsers.openelt_any = parsers.less * parsers.keyword * parsers.htmlattribute^0
                    * parsers.sp * parsers.more

parsers.openelt_exact = function(s)
  return parsers.less * parsers.sp * parsers.keyword_exact(s)
       * parsers.htmlattribute^0 * parsers.sp * parsers.more
end

parsers.openelt_block = parsers.sp * parsers.block_keyword
                      * parsers.htmlattribute^0 * parsers.sp * parsers.more

parsers.closeelt_any = parsers.less * parsers.sp * parsers.slash
                     * parsers.keyword * parsers.sp * parsers.more

parsers.closeelt_exact = function(s)
  return parsers.less * parsers.sp * parsers.slash * parsers.keyword_exact(s)
       * parsers.sp * parsers.more
end

parsers.emptyelt_any = parsers.less * parsers.sp * parsers.keyword
                     * parsers.htmlattribute^0 * parsers.sp * parsers.slash
                     * parsers.more

parsers.emptyelt_block = parsers.less * parsers.sp * parsers.block_keyword
                       * parsers.htmlattribute^0 * parsers.sp * parsers.slash
                       * parsers.more

parsers.displaytext = (parsers.any - parsers.less)^1

-- return content between two matched HTML tags
parsers.in_matched = function(s)
  return { parsers.openelt_exact(s)
         * (V(1) + parsers.displaytext
           + (parsers.less - parsers.closeelt_exact(s)))^0
         * parsers.closeelt_exact(s) }
end

local function parse_matched_tags(s,pos)
  local t = lower(lpegmatch(C(parsers.keyword),s,pos))
  return lpegmatch(parsers.in_matched(t),s,pos-1)
end

parsers.in_matched_block_tags = parsers.less
                              * Cmt(#parsers.openelt_block, parse_matched_tags)

parsers.displayhtml = parsers.htmlcomment
                    + parsers.emptyelt_block
                    + parsers.openelt_exact("hr")
                    + parsers.in_matched_block_tags
                    + parsers.htmlinstruction

parsers.inlinehtml  = parsers.emptyelt_any
                    + parsers.htmlcomment
                    + parsers.htmlinstruction
                    + parsers.openelt_any
                    + parsers.closeelt_any

------------------------------------------------------------------------------
-- Parsers used for HTML entities
------------------------------------------------------------------------------

parsers.hexentity = parsers.ampersand * parsers.hash * S("Xx")
                  * C(parsers.hexdigit^1) * parsers.semicolon
parsers.decentity = parsers.ampersand * parsers.hash
                  * C(parsers.digit^1) * parsers.semicolon
parsers.tagentity = parsers.ampersand * C(parsers.alphanumeric^1)
                  * parsers.semicolon

------------------------------------------------------------------------------
-- Helpers for links and references
------------------------------------------------------------------------------

-- parse a reference definition:  [foo]: /bar "title"
parsers.define_reference_parser = parsers.leader * parsers.tag * parsers.colon
                                * parsers.spacechar^0 * parsers.url
                                * parsers.optionaltitle * parsers.blankline^1

------------------------------------------------------------------------------
-- Inline elements
------------------------------------------------------------------------------

parsers.Inline       = V("Inline")

parsers.squote_start = parsers.squote * -parsers.spacing

parsers.squote_end   = parsers.squote * B(parsers.nonspacechar*1, 2)

parsers.Apostrophe   = parsers.squote * B(parsers.nonspacechar*1, 2) / "’"

-- parse many p between starter and ender
parsers.between = function(p, starter, ender)
  local ender2 = B(parsers.nonspacechar) * ender
  return (starter * #parsers.nonspacechar * Ct(p * (p - ender2)^0) * ender2)
end

parsers.urlchar = parsers.anyescaped - parsers.newline - parsers.more

------------------------------------------------------------------------------
-- Block elements
------------------------------------------------------------------------------

parsers.Block        = V("Block")

parsers.TildeFencedCodeBlock
                     = parsers.fencehead(parsers.tilde,
                                         parsers.tilde_infostring)
                     * Cs(parsers.fencedline(parsers.tilde)^0)
                     * parsers.fencetail(parsers.tilde)

parsers.BacktickFencedCodeBlock
                     = parsers.fencehead(parsers.backtick,
                                         parsers.backtick_infostring)
                     * Cs(parsers.fencedline(parsers.backtick)^0)
                     * parsers.fencetail(parsers.backtick)

parsers.lineof = function(c)
    return (parsers.leader * (P(c) * parsers.optionalspace)^3
           * parsers.newline * parsers.blankline^1)
end

------------------------------------------------------------------------------
-- Lists
------------------------------------------------------------------------------

parsers.defstartchar = S("~:")
parsers.defstart     = ( parsers.defstartchar * #parsers.spacing
                                              * (parsers.tab + parsers.space^-3)
                     + parsers.space * parsers.defstartchar * #parsers.spacing
                                     * (parsers.tab + parsers.space^-2)
                     + parsers.space * parsers.space * parsers.defstartchar
                                     * #parsers.spacing
                                     * (parsers.tab + parsers.space^-1)
                     + parsers.space * parsers.space * parsers.space
                                     * parsers.defstartchar * #parsers.spacing
                     )

parsers.dlchunk = Cs(parsers.line * (parsers.indentedline - parsers.blankline)^0)

------------------------------------------------------------------------------
-- Pandoc title block parser
------------------------------------------------------------------------------

parsers.pandoc_author = parsers.spacechar * parsers.optionalspace
                      * C((parsers.anyescaped
                         - parsers.newline
                         - parsers.semicolon)^0)
                      * (parsers.semicolon + parsers.newline)

------------------------------------------------------------------------------
-- Headers
------------------------------------------------------------------------------

-- parse Atx heading start and return level
parsers.HeadingStart = #parsers.hash * C(parsers.hash^-6)
                     * -parsers.hash / length

-- parse setext header ending and return level
parsers.HeadingLevel = parsers.equal^1 * Cc(1) + parsers.dash^1 * Cc(2)

local function strip_atx_end(s)
  return s:gsub("[#%s]*[\n]*$","")
end


--- Create a new markdown parser.
--
-- *   `writer` is a writer table (see [lunamark.writer.generic]).
--
-- *   `options` is a table with parsing options.
--     The following fields are significant:
--
--     `alter_syntax`
--     :   Function from syntax table to syntax table,
--         allowing the user to change or extend the markdown syntax.
--         For an example, see the documentation for `lunamark`.
--
--     `references`
--     :   A table of references to be used in resolving links
--         in the document.  The keys should be all lowercase, with
--         spaces and newlines collapsed into single spaces.
--         Example:
--
--             { foo: { url = "/url", title = "my title" },
--               bar: { url = "http://fsf.org" } }
--
--     `preserve_tabs`
--     :   Preserve tabs instead of converting to spaces.
--
--     `smart`
--     :   Parse quotation marks, dashes, ellipses intelligently.
--
--     `startnum`
--     :   Make the opening number in an ordered list significant.
--
--     `notes`
--     :   Enable footnotes as in pandoc.
--
--     `inline_notes`
--     :  Inline footnotes. An inline footnote is like a markdown bracketed
--        reference, but preceded with a circumflex (`^`).
--
--     `definition_lists`
--     :   Enable definition lists as in pandoc.
--
--     `citations`
--     :   Enable citations as in pandoc.
--
--     `fenced_code_blocks`
--     :   Enable fenced code blocks.
--
--     `pandoc_title_blocks`
--     :   Parse pandoc-style title block at the beginning of document:
--
--             % Title
--             % Author1; Author2
--             % Date
--
--     `lua_metadata`
--     :   Enable lua metadata.  This is an HTML comment block
--         that starts with `<!--@` and contains lua code.
--         The lua code is interpreted in a sandbox, and
--         any variables defined are added to the metadata.
--         The function `markdown` (also `m`) is defined and can
--         be used to ensure that string fields are parsed
--         as markdown; otherwise, they will be read literally.
--
--     `require_blank_before_blockquote`
--     :   Require a blank line between a paragraph and a following
--         block quote.
--
--     `require_blank_before_header`
--     :   Require a blank line between a paragraph and a following
--         header.
--
--     `require_blank_before_fenced_code_block`
--     :   Require a blank line between a paragraph and a following
--         fenced code block.
--
--     `hash_enumerators`
--     :   Allow `#` instead of a digit for an ordered list enumerator
--         (equivalent to `1`).
--
--     `task_list`
--     :   GitHub-Flavored Markdown (GFM) task list extension to standard
--         bullet lists. Items starting with `[ ]`, `[x]` or `[X]` after the
--         bullet are processed as first-class structures by the Markdown reader
--         when this option is enabled, possibly allowing writers to handle
--         them more efficiently with a finer-grain logic.
--
--     `fancy_lists`
--     :   Allow ordered list items to use a roman number or a letter
--         as anumerator, instead of a digit, and to use a closing parenthesis
--         as end delimiter, instead of a period.
--
--         Depending on the selected writer, the numbering scheme and delimeter
--         may be honored or just ignored.
--
--         If the `startnum` option is enabled, the starting value is converted
--         to decimal, when necessary, so that the list at least starts at the
--         appropriate value.
--
--         So in the minimal case, this option allows such lists to be processed,
--         albeit rendered as regular ordered lists.
--
--         Compared to the Pandoc option by the same name, the implementation
--         does not support currently list markers enclosed in parentheses.
--
--     `strikeout`
--     :   Enable strike-through support for a text enclosed within double
--         tildes, as in `~~deleted~~`.
--
--     `mark`
--     :   Enable highlighting support for a text enclosed within double
--         equals, as in `==marked==`.
--
--     `superscript`
--     :   Enable superscript support. Superscripts may be written by surrounding
--         the superscripted text by `^` characters, as in `2^10^.
--
--         The text thus marked may not contain spaces or newlines.
--         If the superscripted text contains spaces, these spaces must be escaped
--         with backslashes.
--
--     `subscript`
--     :   Enable superscript support. Superscripts may be written by surrounding
--         the subscripted text by `~` characters, as in `2~10~`.
--
--         The text thus marked may not contain spaces or newlines.
--         If the supbscripted text contains spaces, these spaces must be escaped
--         with backslashes.
--
--     `bracketed_spans`
--     :   When enabled, a bracketed sequence of inlines (as one would use to
--         begin a link), is treated as a Span with attributes if it is
--         followed immediately by attributes, e.g. `[text]{.class key=value}`.
--
--     `fenced_divs`
--     :   Allow special fenced syntax for native Div blocks. A Div starts with a
--         fence containing at least three consecutive colons plus some attributes.
--
--         The Div ends with another line containing a string of at least
--         three consecutive colons. The fenced Div should be separated by blank
--         lines from preceding and following blocks.
--
--         Current implementation restrictions and differences with the Pandoc
--         option by the same name: fenced Divs cannot be nested, the attributes
--         cannot be followed by another optional string of consecutive colons,
--         attributes have to be in curly braces (and cannot be a single unbraced
--         word.
--
--     `raw_attribute`
--     :   When enabled, inline code and fenced code blocks with a special kind
--         of attribute will be parsed as raw content with the designated format,
--         e.g. `{=format}`. Writers may pass relevant raw content to the
--         target formatter.
--
--         To use a raw attribute with fenced code blocks, `fenced_code_blocks`
--         must be enabled.
--
--         As opposed to the Pandoc option going by the same name, raw
--         attributes can be continued with key=value pairs.
--
--         How these constructs are honored depends on the writer. In the
--         minimal case, they are ignored, as if they were stripped from
--         the input.
--
--     `fenced_code_attributes`
--     :   Allow attaching attributes to fenced code blocks, if the latter.
--         are enabled.
--
--         Current implementation restrictions and differences with the Pandoc
--         option by the same name: attributes can only be set on fenced
--         code blocks.
--
--     `link_attributes`
--     :   Allow attaching attributes to direct images.
--
--         Current implementation restrictions and differences with the Pandoc
--         option by the same name: attributes cannot be set on links
--         and indirect images (i.e. only direct images support them).
--
--     `pipe_tables`
--     :   Support "Pipe Tables", as with Pandoc's option by the same name,
--         following the syntax introduced in PHP Markdown Extra.
--
--     `table_captions`
--     :   Enable the Pandoc `table_captions` syntax extension for
--         tables.
--
--     `header_attributes`
--     :   Headings can be assigned attributes at the end of the line containing
--         the heading text.
--
--     `line_blocks`
--     :   A line block is a sequence of lines beginning with a vertical bar
--         followed by a space. The division into lines will be preserved in the
--         output, as will any leading spaces; otherwise, the lines will be
--         formatted as Markdown.
--
--         Inline formatting (such as emphasis) is allowed
--         in the content, but not block-level formatting (such as block quotes or
--         lists).
--
--         The lines can be hard-wrapped if needed, but the continuation line must
--         begin with a space.
--
--     `escaped_line_breaks`
--     :   When enabled, a backslash followed by a newline is also a hard line
--         break. This is a nice alternative to Markdown's "invisible" way of
--         indicating hard line breaks using two trailing spaces at the end of
--         a line.
--
-- *   Returns a converter function that converts a markdown string
--     using `writer`, returning the parsed document as first result,
--     and a table containing any extracted metadata as the second
--     result. The converter assumes that the input has unix
--     line endings (newline).  If the input might have DOS
--     line endings, a simple `gsub("\r","")` should take care of them.
function M.new(writer, options)
  options = options or {}
  local larsers = {} -- locally defined parsers

  local function expandtabs(s)
    if s:find("\t") then
      return s:gsub("[^\n]*",expand_tabs_in_line)
    else
      return s
    end
  end

  if options.preserve_tabs then
    expandtabs = function(s) return s end
  end

  ------------------------------------------------------------------------------
  -- Top-level parser functions
  ------------------------------------------------------------------------------

  local function create_parser(name, grammar)
    return function(str)
      local res = lpeg.match(grammar(), str)
      if res == nil then
        error(format("%s failed on:\n%s", name, str:sub(1,20)))
      else
        return res
      end
    end
  end

  local parse_blocks
    = create_parser("parse_blocks",
                    function()
                      return larsers.blocks
                    end)

  local parse_inlines
    = create_parser("parse_inlines",
                    function()
                      return larsers.inlines
                    end)

  local parse_inlines_no_link
    = create_parser("parse_inlines_no_link",
                    function()
                      return larsers.inlines_no_link
                    end)

  local parse_inlines_no_inline_note
    = create_parser("parse_inlines_no_inline_note",
                    function()
                      return larsers.inlines_no_inline_note
                    end)

  local parse_inlines_nbsp
    = create_parser("parse_inlines_nbsp",
                    function()
                      return larsers.inlines_nbsp
                    end)

  local parse_markdown

  ------------------------------------------------------------------------------
  -- Basic parsers (local)
  ------------------------------------------------------------------------------

  local specials = "*_~`&[]<!\\-@^"
  if options.smart then
    specials = specials .. "'.\""
  end
  if options.mark then
    specials = specials .. "="
  end
  larsers.specialchar         = S(specials)

  larsers.normalchar          = parsers.any - (larsers.specialchar
                                                + parsers.spacing
                                                + parsers.tightblocksep)

  -----------------------------------------------------------------------------
  -- Parsers used for markdown lists (local)
  -----------------------------------------------------------------------------

  if options.hash_enumerators then
    larsers.dig = parsers.digit + parsers.hash
  else
    larsers.dig = parsers.digit
  end

  larsers.numdelim = parsers.period
  if options.fancy_lists then
    larsers.dig = larsers.dig + parsers.letter
    larsers.numdelim = larsers.numdelim + parsers.rparent
  end

  larsers.enumerator = C(larsers.dig^3 * larsers.numdelim) * #parsers.spacing
                     + C(larsers.dig^2 * larsers.numdelim) * #parsers.spacing
                                       * (parsers.tab + parsers.space^1)
                     + C(larsers.dig * larsers.numdelim) * #parsers.spacing
                                     * (parsers.tab + parsers.space^-2)
                     + parsers.space * C(larsers.dig^2 * larsers.numdelim)
                                     * #parsers.spacing
                     + parsers.space * C(larsers.dig * larsers.numdelim)
                                     * #parsers.spacing
                                     * (parsers.tab + parsers.space^-1)
                     + parsers.space * parsers.space * C(larsers.dig^1
                                     * larsers.numdelim) * #parsers.spacing

  ------------------------------------------------------------------------------
  -- Parsers used for citations (local)
  ------------------------------------------------------------------------------

  larsers.citations = function(text_cites, raw_cites)
      local function normalize(str)
          if str == "" then
              str = nil
          else
              str = (options.citation_nbsps and parse_inlines_nbsp or
                parse_inlines)(str)
          end
          return str
      end

      local cites = {}
      for i = 1,#raw_cites,4 do
          cites[#cites+1] = {
              prenote = normalize(raw_cites[i]),
              suppress_author = raw_cites[i+1] == "-",
              name = writer.citation(raw_cites[i+2]),
              postnote = normalize(raw_cites[i+3]),
          }
      end
      return writer.citations(text_cites, cites)
  end

  ------------------------------------------------------------------------------
  -- Parsers used for footnotes (local)
  ------------------------------------------------------------------------------

  local rawnotes = {}

  -- like indirect_link
  local function lookup_note(ref)
    return function()
      local found = rawnotes[normalize_tag(ref)]
      if found then
        return writer.note(parse_blocks(found))
      else
        return {"[", parse_inlines("^" .. ref), "]"}
      end
    end
  end

  local function register_note(ref,rawnote)
    rawnotes[normalize_tag(ref)] = rawnote
    return ""
  end

  larsers.NoteRef    = parsers.RawNoteRef / lookup_note

  larsers.NoteBlock  = parsers.leader * parsers.RawNoteRef * parsers.colon
                     * parsers.spnl * parsers.indented_blocks(parsers.chunk)
                     / register_note

  larsers.InlineNote = parsers.circumflex
                     * (parsers.tag / parse_inlines_no_inline_note) -- no notes inside notes
                     / writer.note

  ------------------------------------------------------------------------------
  -- Helpers for links and references (local)
  ------------------------------------------------------------------------------

  -- List of references defined in the document
  local references

  -- add a reference to the list
  local function register_link(tag,url,title)
      references[normalize_tag(tag)] = { url = url, title = title }
      return ""
  end

  -- lookup link reference and return either
  -- the link or nil and fallback text.
  local function lookup_reference(label,sps,tag)
      local tagpart
      if not tag then
          tag = label
          tagpart = ""
      elseif tag == "" then
          tag = label
          tagpart = "[]"
      else
          tagpart = {"[", parse_inlines(tag), "]"}
      end
      if sps then
        tagpart = {sps, tagpart}
      end
      local r = references[normalize_tag(tag)]
      if r then
        return r
      else
        return nil, {"[", parse_inlines(label), "]", tagpart}
      end
  end

  -- lookup link reference and return a link, if the reference is found,
  -- or a bracketed label otherwise.
  local function indirect_link(label,sps,tag)
    return function()
      local r,fallback = lookup_reference(label,sps,tag)
      if r then
        return writer.link(parse_inlines_no_link(label), r.url, r.title)
      else
        return fallback
      end
    end
  end

  -- lookup image reference and return an image, if the reference is found,
  -- or a bracketed label otherwise.
  local function indirect_image(label,sps,tag)
    return function()
      local r,fallback = lookup_reference(label,sps,tag)
      if r then
        return writer.image(writer.string(label), r.url, r.title)
      else
        return {"!", fallback}
      end
    end
  end

  ------------------------------------------------------------------------------
  -- Inline elements (local)
  ------------------------------------------------------------------------------

  larsers.Str      = larsers.normalchar^1 / writer.string

  larsers.Ellipsis = P("...") / writer.ellipsis

  larsers.Dash     = P("---") * -parsers.dash / writer.mdash
                   + P("--") * -parsers.dash / writer.ndash
                   + P("-") * #parsers.digit * B(parsers.digit*1, 2)
                   / writer.ndash

  larsers.DoubleQuoted = parsers.dquote * Ct((parsers.Inline - parsers.dquote)^1)
                       * parsers.dquote / writer.doublequoted

  larsers.SingleQuoted = parsers.squote_start
                       * Ct((parsers.Inline - parsers.squote_end)^1)
                       * parsers.squote_end / writer.singlequoted

  larsers.Smart        = larsers.Ellipsis + larsers.Dash + larsers.SingleQuoted
                       + larsers.DoubleQuoted + parsers.Apostrophe

  larsers.Symbol       = (larsers.specialchar - parsers.tightblocksep)
                       / writer.string

  larsers.RawInLine    = parsers.inticks * parsers.rawattributes
                       / writer.rawinline

  larsers.Code         = parsers.inticks / writer.code

  if options.require_blank_before_blockquote then
    larsers.bqstart = parsers.fail
  else
    larsers.bqstart = parsers.more
  end

  if options.require_blank_before_header then
    larsers.headerstart = parsers.fail
  else
    larsers.headerstart = parsers.hash
                        + (parsers.line * (parsers.equal^1 + parsers.dash^1)
                        * parsers.optionalspace * parsers.newline)
  end

  if not options.fenced_code_blocks or options.require_blank_before_fenced_code_blocks then
    larsers.fencestart = parsers.fail
  else
    larsers.fencestart = parsers.fencehead(parsers.backtick,
                                           parsers.backtick_infostring)
                       + parsers.fencehead(parsers.tilde,
                                           parsers.tilde_infostring)
  end

  if options.fenced_divs then
    local function check_div_level(s, i, current_level) -- luacheck: ignore s i
      current_level = tonumber(current_level)
      return current_level > 0
    end

    local is_inside_div = Cmt(Cb("div_level"), check_div_level)

    larsers.fenced_div_out = is_inside_div  -- break out of a paragraph when we
                                            -- are inside a div and see a closing tag
                           * parsers.fenced_div_end

    larsers.fencestart = larsers.fencestart
                       + larsers.fenced_div_out
  else
    larsers.fenced_div_out = parsers.fail
  end

  larsers.Endline   = parsers.newline * -( -- newline, but not before...
                        parsers.blankline -- paragraph break
                      + parsers.tightblocksep  -- nested list
                      + parsers.eof       -- end of document
                      + larsers.bqstart
                      + larsers.headerstart
                      + larsers.fencestart
                    ) * parsers.spacechar^0 / writer.space

  larsers.linebreak = parsers.spacechar^2 * larsers.Endline
  if options.escaped_line_breaks then
    larsers.linebreak = larsers.linebreak
                      + P("\\") * larsers.Endline
  end

  larsers.Space     = larsers.linebreak / writer.linebreak
                    + parsers.spacechar^1 * larsers.Endline^-1 * parsers.eof /""
                    + parsers.spacechar^1 * larsers.Endline^-1
                                          * parsers.optionalspace / writer.space

  larsers.NonbreakingEndline
                    = parsers.newline * -( -- newline, but not before...
                        parsers.blankline -- paragraph break
                      + parsers.tightblocksep  -- nested list
                      + parsers.eof       -- end of document
                      + larsers.bqstart
                      + larsers.headerstart
                      + larsers.fencestart
                    ) * parsers.spacechar^0 / writer.nbsp

  larsers.NonbreakingSpace
                    = larsers.linebreak / writer.linebreak
                    + parsers.spacechar^1 * larsers.Endline^-1 * parsers.eof /""
                    + parsers.spacechar^1 * larsers.Endline^-1
                                          * parsers.optionalspace / writer.nbsp

  larsers.Strong = ( parsers.between(parsers.Inline, parsers.doubleasterisks,
                                     parsers.doubleasterisks)
                   + parsers.between(parsers.Inline, parsers.doubleunderscores,
                                     parsers.doubleunderscores)
                   ) / writer.strong

  larsers.Emph   = ( parsers.between(parsers.Inline, parsers.asterisk,
                                   parsers.asterisk)
                   + parsers.between(parsers.Inline, parsers.underscore,
                                   parsers.underscore)
                   ) / writer.emphasis

  larsers.Strikeout
                 = ( parsers.between(parsers.Inline, parsers.doubletildes,
                                   parsers.doubletildes)
                   ) / writer.strikeout

  larsers.Mark = parsers.between(parsers.Inline, parsers.doubleequals,
                                 parsers.doubleequals)
               / function (inlines)
                   return writer.span(inlines, { class="mark" })
                 end

  larsers.Span   = ( parsers.between(parsers.Inline, parsers.lbracket,
                                   parsers.rbracket) ) * ( parsers.attributes )
                   / writer.span

  larsers.subsuperscripttext  = ( larsers.Str + P("\\ ") / writer.space )^1

  larsers.Subscript   = ( parsers.between(larsers.subsuperscripttext, parsers.tilde, parsers.tilde) )
                        / writer.subscript

  larsers.Superscript = ( parsers.between(larsers.subsuperscripttext, parsers.circumflex, parsers.circumflex) )
                         / writer.superscript

  larsers.AutoLinkUrl   = parsers.less
                        * C(parsers.alphanumeric^1 * P("://") * parsers.urlchar^1)
                        * parsers.more
                        / function(url)
                            return writer.link(writer.string(url),url)
                          end

  larsers.AutoLinkEmail = parsers.less
                        * C((parsers.alphanumeric + S("-._+"))^1
                        * P("@") * parsers.urlchar^1) * parsers.more
                        / function(email)
                            return writer.link(writer.string(email),"mailto:"..email)
                          end

  larsers.DirectLink    = (parsers.tag / parse_inlines_no_link)  -- no links inside links
                        * parsers.spnl
                        * parsers.lparent
                        * (parsers.url + Cc(""))  -- link can be empty [foo]()
                        * parsers.optionaltitle
                        * parsers.rparent
                        / writer.link

  larsers.IndirectLink  = parsers.tag * (C(parsers.spnl) * parsers.tag)^-1
                        / indirect_link

  -- parse a link or image (direct or indirect)
  larsers.Link          = larsers.DirectLink + larsers.IndirectLink

  if options.link_attributes then
    -- Support additional attributes
    larsers.DirectImage   = parsers.exclamation
                          * (parsers.tag / parse_inlines)
                          * parsers.spnl
                          * parsers.lparent
                          * (parsers.url + Cc(""))  -- link can be empty [foo]()
                          * parsers.optionaltitle
                          * parsers.rparent
                          * (parsers.attributes + Ct(""))
                          / writer.image
  else
    larsers.DirectImage   = parsers.exclamation
                          * (parsers.tag / parse_inlines)
                          * parsers.spnl
                          * parsers.lparent
                          * (parsers.url + Cc(""))  -- link can be empty [foo]()
                          * parsers.optionaltitle
                          * parsers.rparent
                          / writer.image
  end

  larsers.IndirectImage = parsers.exclamation * parsers.tag
                        * (C(parsers.spnl) * parsers.tag)^-1 / indirect_image

  larsers.Image         = larsers.DirectImage + larsers.IndirectImage

  larsers.TextCitations = Ct(Cc("")
                        * parsers.citation_name
                        * ((parsers.spnl
                           * parsers.lbracket
                           * parsers.citation_headless_body
                           * parsers.rbracket) + Cc("")))
                        / function(raw_cites)
                            return larsers.citations(true, raw_cites)
                          end

  larsers.ParenthesizedCitations
                        = Ct(parsers.lbracket
                        * parsers.citation_body
                        * parsers.rbracket)
                        / function(raw_cites)
                            return larsers.citations(false, raw_cites)
                          end

  larsers.Citations     = larsers.TextCitations + larsers.ParenthesizedCitations

  -- avoid parsing long strings of * or _ as emph/strong
  larsers.UlOrStarLine  = parsers.asterisk^4 + parsers.underscore^4
                        / writer.string

  larsers.EscapedChar   = S("\\") * C(parsers.escapable) / writer.string

  larsers.InlineHtml    = C(parsers.inlinehtml) / writer.inline_html

  larsers.HtmlEntity    = parsers.hexentity / entities.hex_entity  / writer.string
                        + parsers.decentity / entities.dec_entity  / writer.string
                        + parsers.tagentity / entities.char_entity / writer.string

  ------------------------------------------------------------------------------
  -- Block elements (local)
  ------------------------------------------------------------------------------

  larsers.DisplayHtml  = C(parsers.displayhtml)
                       / expandtabs / writer.display_html

  larsers.Verbatim     = Cs( (parsers.blanklines
                           * ((parsers.indentedline - parsers.blankline))^1)^1
                           ) / expandtabs / writer.verbatim

  larsers.FencedCodeBlock
                       = (parsers.TildeFencedCodeBlock
                         + parsers.BacktickFencedCodeBlock)
                       / function(infostring, code)
                           if options.raw_attribute then
                             local raw, attr = lpeg.match(parsers.rawattributes, infostring)
                             if raw then
                              return writer.rawblock(code, raw, attr)
                             end
                           end
                           if options.fenced_code_attributes then
                             local attr = lpeg.match(parsers.attributes, infostring)
                             if attr then
                              return writer.fenced_code(expandtabs(code),
                                  attr.class, attr)
                             end
                           end
                           return writer.fenced_code(expandtabs(code),
                                                     writer.string(infostring))
                         end

  local function increment_div_level(increment)
    local function update_div_level(s, i, current_level) -- luacheck: ignore s i
      current_level = tonumber(current_level)
      local next_level = tostring(current_level + increment)
      return true, next_level
    end

    return Cg( Cmt(Cb("div_level"), update_div_level)
             , "div_level")
  end

  larsers.FencedDiv = parsers.fenced_div_begin * increment_div_level(1)
                    * parsers.skipblanklines
                    * Ct( (V("Block") - parsers.fenced_div_end)^-1
                        * ( V("Blank")^0 / writer.interblocksep
                          * (V("Block") - parsers.fenced_div_end))^0)
                    * V("Blank")^0
                    * parsers.fenced_div_end * increment_div_level(-1)
                    / function (infostring, div)
                        local attr = lpeg.match(Cg(parsers.attributes), infostring)
                        if attr == nil then
                          attr = {class=infostring}
                        end
                        return div, attr
                      end
                    / writer.div

  -- strip off leading > and indents, and run through blocks
  larsers.Blockquote  = Cs((((parsers.leader * parsers.more * parsers.space^-1)/""
                             * parsers.linechar^0 * parsers.newline)^1
                            * (-(parsers.leader * parsers.more
                                + parsers.blankline
                                + larsers.fenced_div_out) * parsers.linechar^1
                              * parsers.newline)^0 * parsers.blankline^0
                           )^1) / parse_blocks / writer.blockquote

  larsers.HorizontalRule = ( parsers.lineof(parsers.asterisk)
                           + parsers.lineof(parsers.dash)
                           + parsers.lineof(parsers.underscore)
                           ) / writer.hrule

  larsers.Reference    = parsers.define_reference_parser / register_link

  larsers.Paragraph    = parsers.nonindentspace * Ct(parsers.Inline^1)
                       * parsers.newline
                       * ( parsers.blankline^1
                         + #parsers.hash
                         + #(parsers.leader * parsers.more * parsers.space^-1)
                         )
                       / writer.paragraph

  larsers.Plain        = parsers.nonindentspace * Ct(parsers.Inline^1)
                       / writer.plain

  larsers.LineBlock   = Ct(
                        (Cs(
                          ( (parsers.pipe * parsers.space)/""
                          * ((parsers.space)/entities.char_entity("nbsp"))^0
                          * parsers.linechar^0 * (parsers.newline/""))
                          * (-parsers.pipe
                            * (parsers.space^1/" ")
                            * parsers.linechar^1
                            * (parsers.newline/"")
                            )^0
                          * (parsers.blankline/"")^0
                        ) / parse_inlines)^1) / writer.lineblock

  ------------------------------------------------------------------------------
  -- Lists (local)
  ------------------------------------------------------------------------------

  larsers.taskbullet  = ( parsers.bullet * parsers.optionalspace
                        * C(parsers.lbracket * (S("xX ")) * parsers.rbracket) )
                      / function (_, checked) -- first arg is the bullet
                          return checked:upper() -- Just normalize it in uppercase
                        end

  if options.task_list then
    larsers.starter = larsers.taskbullet + parsers.bullet + larsers.enumerator
  else
    larsers.starter = parsers.bullet + larsers.enumerator
  end

  -- we use \001 as a separator between a tight list item and a
  -- nested list under it.
  larsers.NestedList            = Cs((parsers.optionallyindentedline
                                     - larsers.starter)^1)
                                / function(a) return "\001"..a end

  larsers.ListBlockLine         = parsers.optionallyindentedline
                                - parsers.blankline - (parsers.indent^-1
                                                      * larsers.starter)

  larsers.ListBlock             = parsers.line * larsers.ListBlockLine^0

  larsers.ListContinuationBlock = parsers.blanklines * (parsers.indent / "")
                                * larsers.ListBlock

  larsers.TightListItem = function(starter)
      return -larsers.HorizontalRule
             * (Cs(starter / "" * larsers.ListBlock * larsers.NestedList^-1)
               / parse_blocks)
             * -(parsers.blanklines * parsers.indent)
  end

  larsers.LooseListItem = function(starter)
      return -larsers.HorizontalRule
             * Cs( starter / "" * larsers.ListBlock * Cc("\n")
               * (larsers.NestedList + larsers.ListContinuationBlock^0)
               * (parsers.blanklines / "\n\n")
               ) / parse_blocks
  end

  larsers.BulletList = ( Ct(larsers.TightListItem(parsers.bullet)^1) * Cc(true)
                       * parsers.skipblanklines * -parsers.bullet
                       + Ct(larsers.LooseListItem(parsers.bullet)^1) * Cc(false)
                       * parsers.skipblanklines )
                     / writer.bulletlist

  local function ordered_list(s,tight,start)
    local startnum, numstyle, numdelim = util.order_to_numberstyle(start)
    return writer.orderedlist(s,tight,
                              options.startnum and startnum,
                              options.fancy_lists and numstyle or "Decimal",
                              options.fancy_lists and numdelim or "Default")
  end

  larsers.OrderedList = Cg(larsers.enumerator, "listtype") *
                      ( Ct(larsers.TightListItem(Cb("listtype"))
                          * larsers.TightListItem(larsers.enumerator)^0)
                      * Cc(true) * parsers.skipblanklines * -larsers.enumerator
                      + Ct(larsers.LooseListItem(Cb("listtype"))
                          * larsers.LooseListItem(larsers.enumerator)^0)
                      * Cc(false) * parsers.skipblanklines
                      ) * Cb("listtype") / ordered_list

  local function gather_ticklist_item(checked, blocks)
    return { checked, parse_blocks(blocks) }
  end

  -- Note: there could have been some code factorization with bullet lists,
  -- but this is becoming tricky so let's not risk breaking what works.
  larsers.TightTaskListItem = function(starter)
    return -larsers.HorizontalRule
           * Cs(starter) * Cs(larsers.ListBlock * larsers.NestedList^-1)
             / gather_ticklist_item
           * -(parsers.blanklines * parsers.indent)
  end
  larsers.LooseTaskListItem = function(starter)
      return -larsers.HorizontalRule
            * Cs(starter) * Cs(larsers.ListBlock * Cc("\n")
              * (larsers.NestedList + larsers.ListContinuationBlock^0)
              * (parsers.blanklines / "\n\n")
              ) / gather_ticklist_item
  end

  larsers.TaskList = ( Ct(larsers.TightTaskListItem(larsers.taskbullet)^1) * Cc(true)
                        * parsers.skipblanklines * -larsers.taskbullet
                        + Ct(larsers.LooseTaskListItem(larsers.taskbullet)^1) * Cc(false)
                        * parsers.skipblanklines
                      ) / writer.tasklist

  local function definition_list_item(term, defs)
    return { term = parse_inlines(term), definitions = defs }
  end

  larsers.DefinitionListItemLoose = C(parsers.line) * parsers.skipblanklines
                                  * Ct((parsers.defstart
                                      * parsers.indented_blocks(parsers.dlchunk)
                                      / parse_blocks)^1)
                                  * Cc(false) / definition_list_item

  larsers.DefinitionListItemTight = C(parsers.line)
                                  * Ct((parsers.defstart * parsers.dlchunk
                                      / parse_blocks)^1)
                                  * Cc(true)  / definition_list_item

  larsers.DefinitionList = ( Ct(larsers.DefinitionListItemLoose^1) * Cc(false)
                           + Ct(larsers.DefinitionListItemTight^1)
                           * (parsers.skipblanklines
                             * -larsers.DefinitionListItemLoose * Cc(true))
                           ) / writer.definitionlist

  ------------------------------------------------------------------------------
  -- Lua metadata (local)
  ------------------------------------------------------------------------------

  local function lua_metadata(s)  -- run lua code in comment in sandbox
    local env = { m = parse_markdown, markdown = parse_blocks }
    local scode = s:match("^<!%-%-@%s*(.*)%-%->")
    local untrusted_table, message = load(scode, nil, "t", env)
    if not untrusted_table then
      util.err(message, 37)
    end
    local ok, msg = pcall(untrusted_table)
    if not ok then
      util.err(msg)
    end
    for k,v in pairs(env) do
      writer.set_metadata(k,v)
    end
    return ""
  end

  if options.lua_metadata then
    larsers.LuaMeta = #P("<!--@") * parsers.htmlcomment / lua_metadata
  else
    larsers.LuaMeta = parsers.fail
  end

  ------------------------------------------------------------------------------
  -- Pandoc title block parser (local)
  ------------------------------------------------------------------------------

  larsers.pandoc_title  = parsers.percent * parsers.optionalspace
                        * C(parsers.line
                           * (parsers.spacechar * parsers.nonemptyline)^0)
                        / parse_inlines

  larsers.pandoc_authors = parsers.percent * Ct((parsers.pandoc_author
                                                / parse_inlines)^0)
                         * parsers.newline^-1

  larsers.pandoc_date = parsers.percent * parsers.optionalspace
                      * C(parsers.line) / parse_inlines

  larsers.pandoc_title_block = (larsers.pandoc_title + Cc(""))
                             * (larsers.pandoc_authors + Cc({}))
                             * (larsers.pandoc_date + Cc(""))
                             * C(P(1)^0)

  ------------------------------------------------------------------------------
  -- Blank (local)
  ------------------------------------------------------------------------------

  larsers.Blank        = parsers.blankline / ""
                       + larsers.LuaMeta
                       + larsers.NoteBlock
                       + larsers.Reference
                       + (parsers.tightblocksep / "\n")

  ------------------------------------------------------------------------------
  -- Headers (local)
  ------------------------------------------------------------------------------

  if options.header_attributes then
    larsers.atxHeadLine     = ((parsers.linechar - (parsers.attributes * parsers.newline))^0
                                / strip_atx_end / parse_inlines
                              * Cg(parsers.attributes + Ct(""), "attrs"))
                              * parsers.newline
    larsers.setextHeadLine  = ((parsers.linechar - (parsers.attributes * parsers.newline))^0 / parse_inlines
                              * Cg(parsers.attributes + Ct(""), "attrs"))
                              * parsers.newline
    -- parse atx header
    larsers.AtxHeader = Cg(parsers.HeadingStart,"level")
                        * parsers.optionalspace
                        * larsers.atxHeadLine
                        * Cb("level")
                        * Cb("attrs")
                        / writer.header

    -- parse setext header
    larsers.SetextHeader = #(parsers.line * S("=-"))
                          * (larsers.setextHeadLine)
                          * parsers.HeadingLevel
                          * parsers.optionalspace * parsers.newline
                          * Cb("attrs")
                          / writer.header
  else
    -- parse atx header
    larsers.AtxHeader = Cg(parsers.HeadingStart,"level")
                        * parsers.optionalspace
                        * (C(parsers.line) / strip_atx_end / parse_inlines)
                        * Cb("level")
                        * Ct("")
                        / writer.header

    -- parse setext header
    larsers.SetextHeader = #(parsers.line * S("=-"))
                        * Ct(parsers.line / parse_inlines)
                        * parsers.HeadingLevel
                        * parsers.optionalspace * parsers.newline
                        * Ct("")
                        / writer.header
  end

  ------------------------------------------------------------------------------
  -- PipeTable
  ------------------------------------------------------------------------------

  local function make_pipe_table_rectangular(rows)
    local num_columns = #rows[2]
    local rectangular_rows = {}
    for i = 1, #rows do
      local row = rows[i]
      local rectangular_row = {}
      for j = 1, num_columns do
        rectangular_row[j] = row[j] or ""
      end
      table.insert(rectangular_rows, rectangular_row)
    end
    return rectangular_rows
  end

  local function pipe_table_row(allow_empty_first_column
                                , nonempty_column
                                , column_separator
                                , column)
    local row_beginning
    if allow_empty_first_column then
      row_beginning = -- empty first column
                      #(parsers.spacechar^4
                        * column_separator)
                    * parsers.optionalspace
                    * column
                    * parsers.optionalspace
                    -- non-empty first column
                    + parsers.nonindentspace
                    * nonempty_column^-1
                    * parsers.optionalspace
    else
      row_beginning = parsers.nonindentspace
                    * nonempty_column^-1
                    * parsers.optionalspace
    end

    return Ct(row_beginning
              * (-- single column with no leading pipes
                #(column_separator
                  * parsers.optionalspace
                  * parsers.newline)
                * column_separator
                * parsers.optionalspace
                -- single column with leading pipes or
                -- more than a single column
                + (column_separator
                  * parsers.optionalspace
                  * column
                  * parsers.optionalspace)^1
                * (column_separator
                  * parsers.optionalspace)^-1))
  end

  larsers.table_hline_separator = parsers.pipe + parsers.plus

  larsers.table_hline_column = (parsers.dash
                            - #(parsers.dash
                                * (parsers.spacechar
                                  + larsers.table_hline_separator
                                  + parsers.newline)))^1
                          * (parsers.colon * Cc("r")
                            + parsers.dash * Cc("d"))
                          + parsers.colon
                          * (parsers.dash
                            - #(parsers.dash
                                * (parsers.spacechar
                                  + larsers.table_hline_separator
                                  + parsers.newline)))^1
                          * (parsers.colon * Cc("c")
                            + parsers.dash * Cc("l"))

  larsers.table_hline = pipe_table_row(false
                                    , larsers.table_hline_column
                                    , larsers.table_hline_separator
                                    , larsers.table_hline_column)

  larsers.table_caption_beginning = parsers.skipblanklines
                                * parsers.nonindentspace
                                * (P("Table")^-1 * parsers.colon)
                                * parsers.optionalspace

  larsers.table_row = pipe_table_row(true
                                  , (C((parsers.linechar - parsers.pipe)^1)
                                    / parse_inlines)
                                  , parsers.pipe
                                  , (C((parsers.linechar - parsers.pipe)^0)
                                    / parse_inlines))

  if options.table_captions then
    larsers.table_caption = #larsers.table_caption_beginning
                  * larsers.table_caption_beginning
                  * Ct(parsers.Inline^1) -- N.B. CAVEAT: It was IndentedInline in witiko/markdown
                  * parsers.newline
  else
    larsers.table_caption = parsers.fail
  end

  larsers.PipeTable = Ct(larsers.table_row * parsers.newline
                    * larsers.table_hline
                    * (parsers.newline * larsers.table_row)^0)
                  / make_pipe_table_rectangular
                  * larsers.table_caption^-1
                  / writer.table

  ------------------------------------------------------------------------------
  -- Parser state initialization
  ------------------------------------------------------------------------------

  larsers.InitializeState = Cg(Ct("") / "0", "div_level") -- initialize named groups

  ------------------------------------------------------------------------------
  -- Syntax specification
  ------------------------------------------------------------------------------

  local syntax =
    { "Blocks",

      Blocks                = larsers.InitializeState
                            * larsers.Blank^0 * parsers.Block^-1
                            * (larsers.Blank^0 / function()
                                                   return writer.interblocksep
                                                 end
                              * parsers.Block)^0
                            * larsers.Blank^0 * parsers.eof,

      Blank                 = larsers.Blank,

      Block                 = V("Blockquote")
                            + V("PipeTable")
                            + V("Verbatim")
                            + V("FencedCodeBlock")
                            + V("FencedDiv")
                            + V("HorizontalRule")
                            + V("TaskList") -- Must have precedence over BulletList
                            + V("BulletList")
                            + V("OrderedList")
                            + V("Header")
                            + V("DefinitionList")
                            + V("DisplayHtml")
                            + V("LineBlock")
                            + V("Paragraph")
                            + V("Plain"),

      Blockquote            = larsers.Blockquote,
      Verbatim              = larsers.Verbatim,
      FencedCodeBlock       = larsers.FencedCodeBlock,
      FencedDiv             = larsers.FencedDiv,
      HorizontalRule        = larsers.HorizontalRule,
      TaskList              = larsers.TaskList,
      BulletList            = larsers.BulletList,
      OrderedList           = larsers.OrderedList,
      Header                = larsers.AtxHeader + larsers.SetextHeader,
      DefinitionList        = larsers.DefinitionList,
      DisplayHtml           = larsers.DisplayHtml,
      Paragraph             = larsers.Paragraph,
      PipeTable             = larsers.PipeTable,
      LineBlock             = larsers.LineBlock,
      Plain                 = larsers.Plain,

      Inline                = V("Str")
                            + V("Space")
                            + V("Endline")
                            + V("UlOrStarLine")
                            + V("Strong")
                            + V("Emph")
                            + V("Span")
                            + V("Strikeout")
                            + V("Mark")
                            + V("Subscript")
                            + V("Superscript")
                            + V("InlineNote")
                            + V("NoteRef")
                            + V("Citations")
                            + V("Link")
                            + V("Image")
                            + V("RawInLine") -- Must have precedence over Code
                            + V("Code")
                            + V("AutoLinkUrl")
                            + V("AutoLinkEmail")
                            + V("InlineHtml")
                            + V("HtmlEntity")
                            + V("EscapedChar")
                            + V("Smart")
                            + V("Symbol"),

      Str                   = larsers.Str,
      Space                 = larsers.Space,
      Endline               = larsers.Endline,
      UlOrStarLine          = larsers.UlOrStarLine,
      Strong                = larsers.Strong,
      Emph                  = larsers.Emph,
      Span                  = larsers.Span,
      Strikeout             = larsers.Strikeout,
      Mark                  = larsers.Mark,
      Subscript             = larsers.Subscript,
      Superscript           = larsers.Superscript,
      InlineNote            = larsers.InlineNote,
      NoteRef               = larsers.NoteRef,
      Citations             = larsers.Citations,
      Link                  = larsers.Link,
      Image                 = larsers.Image,
      Code                  = larsers.Code,
      RawInLine             = larsers.RawInLine,
      AutoLinkUrl           = larsers.AutoLinkUrl,
      AutoLinkEmail         = larsers.AutoLinkEmail,
      InlineHtml            = larsers.InlineHtml,
      HtmlEntity            = larsers.HtmlEntity,
      EscapedChar           = larsers.EscapedChar,
      Smart                 = larsers.Smart,
      Symbol                = larsers.Symbol,
    }

  if not options.definition_lists then
    syntax.DefinitionList = parsers.fail
  end

  if not options.fenced_code_blocks then
    syntax.FencedCodeBlock = parsers.fail
  end

  if not options.citations then
    syntax.Citations = parsers.fail
  end

  if not options.notes then
    syntax.NoteRef = parsers.fail
  end

  if not options.inline_notes then
    syntax.InlineNote = parsers.fail
  end

  if not options.smart then
    syntax.Smart = parsers.fail
  end

  if not options.superscript then
    syntax.Superscript = parsers.fail
  end

  if not options.subscript then
    syntax.Subscript = parsers.fail
  end

  if not options.strikeout then
    syntax.Strikeout = parsers.fail
  end

  if not options.mark then
    syntax.Mark = parsers.fail
  end

  if not options.raw_attribute then
    syntax.RawInLine = parsers.fail
  end

  if not options.bracketed_spans then
    syntax.Span = parsers.fail
  end

  if not options.fenced_divs then
    syntax.FencedDiv = parsers.fail
  end

  if not options.task_list then
    syntax.TaskList = parsers.fail
  end

  if not options.pipe_tables then
    syntax.PipeTable = parsers.fail
  end

  if not options.line_blocks then
    syntax.LineBlock = parsers.fail
  end

  if options.alter_syntax and type(options.alter_syntax) == "function" then
    syntax = options.alter_syntax(syntax)
  end

  larsers.blocks = Ct(syntax)

  local inlines_t = util.table_copy(syntax)
  inlines_t[1] = "Inlines"
  inlines_t.Inlines = larsers.InitializeState
                    * parsers.Inline^0
                    * (parsers.spacing^0
                      * parsers.eof / "")
  larsers.inlines = Ct(inlines_t)

  local inlines_no_link_t = util.table_copy(inlines_t)
  inlines_no_link_t.Link = parsers.fail
  larsers.inlines_no_link = Ct(inlines_no_link_t)

  local inlines_no_inline_note_t = util.table_copy(inlines_t)
  inlines_no_inline_note_t.InlineNote = parsers.fail
  larsers.inlines_no_inline_note = Ct(inlines_no_inline_note_t)

  local inlines_nbsp_t = util.table_copy(inlines_t)
  inlines_nbsp_t.Endline = larsers.NonbreakingEndline
  inlines_nbsp_t.Space = larsers.NonbreakingSpace
  larsers.inlines_nbsp = Ct(inlines_nbsp_t)

  ------------------------------------------------------------------------------
  -- Exported conversion function
  ------------------------------------------------------------------------------

  -- inp is a string; line endings are assumed to be LF (unix-style)
  -- and tabs are assumed to be expanded.
  parse_markdown =
    function(inp)
      references = options.references or {}
      if options.pandoc_title_blocks then
        local title, authors, date, rest = lpegmatch(larsers.pandoc_title_block, inp)
        writer.set_metadata("title",title)
        writer.set_metadata("author",authors)
        writer.set_metadata("date",date)
        inp = rest
      end
      local result = { writer.start_document(), parse_blocks(inp), writer.stop_document() }
      return writer.rope_to_output(result), writer.get_metadata()
    end

  return parse_markdown
end

return M
