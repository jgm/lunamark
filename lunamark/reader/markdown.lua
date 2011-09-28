-- (c) 2009-2011 John MacFarlane, Hans Hagen.  Released under MIT license.
-- See the file LICENSE in the source for details.

local util = require("lunamark.util")
local lpeg = require("lpeg")
local entities = require("lunamark.entities")
local lower, upper, gsub, rep, gmatch, format, length =
  string.lower, string.upper, string.gsub, string.rep, string.gmatch,
  string.format, string.len
local concat = table.concat
local P, R, S, V, C, Cg, Cb, Cmt, Cc, Cf, Ct, B, Cs =
  lpeg.P, lpeg.R, lpeg.S, lpeg.V, lpeg.C, lpeg.Cg, lpeg.Cb,
  lpeg.Cmt, lpeg.Cc, lpeg.Cf, lpeg.Ct, lpeg.B, lpeg.Cs
local lpegmatch = lpeg.match
local expand_tabs_in_line = util.expand_tabs_in_line
local unicode = require("unicode")
local utf8 = unicode.utf8

local M = {}

local rope_to_string = util.rope_to_string

-- Normalize a markdown reference tag.  (Make lowercase, and collapse
-- adjacent whitespace characters.)
local function normalize_tag(tag)
  return utf8.lower(gsub(rope_to_string(tag), "[ \n\r\t]+", " "))
end

local any                = P(1)
local fail               = any - 1
local eof                = - any


local L = {}
L.PERCENT                = P("%")
L.ASTERISK               = P("*")
L.DASH                   = P("-")
L.PLUS                   = P("+")
L.UNDERSCORE             = P("_")
L.PERIOD                 = P(".")
L.HASH                   = P("#")
L.AMPERSAND              = P("&")
L.BACKTICK               = P("`")
L.LESS                   = P("<")
L.MORE                   = P(">")
L.SPACE                  = P(" ")
L.SQUOTE                 = P("'")
L.DQUOTE                 = P('"')
L.LPARENT                = P("(")
L.RPARENT                = P(")")
L.LBRACKET               = P("[")
L.RBRACKET               = P("]")
L.CIRCUMFLEX             = P("^")
L.SLASH                  = P("/")
L.EQUAL                  = P("=")
L.COLON                  = P(":")
L.SEMICOLON              = P(";")
L.EXCLAMATION            = P("!")
L.DIGIT                  = R("09")
L.HEXDIGIT               = R("09","af","AF")
L.LETTER                 = R("AZ","az")
L.ALPHANUMERIC           = R("AZ","az","09")
L.DOUBLEASTERISKS        = P("**")
L.DOUBLEUNDERSCORES      = P("__")
L.TAB                    = P("\t")
L.SPACECHAR              = S("\t ")
L.SPACING                = S(" \n\r\t")
L.NEWLINE                = P("\n")
L.NONSPACECHAR           = any - L.SPACING
L.OPTIONALSPACE          = L.SPACECHAR^0
L.NONINDENTSPACE         = L.SPACE^-3 * - L.SPACECHAR
L.INDENT                 = L.SPACE^-3 * L.TAB + P("    ") / ""
L.LINECHAR               = P(1 - L.NEWLINE)
L.BLANKLINE              = L.OPTIONALSPACE * L.NEWLINE / "\n"
L.BLANKLINES             = L.BLANKLINE^0
L.SKIPBLANKLINES         = (L.OPTIONALSPACE * L.NEWLINE)^0
L.INDENTEDLINE           = L.INDENT    /"" * C(L.LINECHAR^1 * L.NEWLINE^-1)
L.OPTIONALLYINDENTEDLINE = L.INDENT^-1 /"" * C(L.LINECHAR^1 * L.NEWLINE^-1)
L.SP                     = L.SPACING^0
L.SPNL                   = L.OPTIONALSPACE * (L.NEWLINE * L.OPTIONALSPACE)^-1
L.LINE                   = L.LINECHAR^0 * L.NEWLINE
                         + L.LINECHAR^1 * eof
L.NONEMPTYLINE           = L.LINE - L.BLANKLINE
L.CHUNK                  = L.LINE * (L.OPTIONALLYINDENTEDLINE - L.BLANKLINE)^0


------------------------------------------------------------------------------
-- HTML
------------------------------------------------------------------------------

local H = {}
-- case-insensitive match (we assume s is lowercase)
local function keyword_exact(s)
  local parser = P(0)
  s = utf8.lower(s)
  for i=1,#s do
    local c = s:sub(i,i)
    local m = c .. upper(c)
    parser = parser * S(m)
  end
  return parser
end

local keyword       = L.LETTER * L.ALPHANUMERIC^0

local block_keyword =
    keyword_exact("address") + keyword_exact("blockquote") +
    keyword_exact("center") + keyword_exact("del") +
    keyword_exact("dir") + keyword_exact("div") +
    keyword_exact("p") + keyword_exact("pre") + keyword_exact("li") +
    keyword_exact("ol") + keyword_exact("ul") + keyword_exact("dl") +
    keyword_exact("dd") + keyword_exact("form") + keyword_exact("fieldset") +
    keyword_exact("isindex") + keyword_exact("ins") +
    keyword_exact("menu") + keyword_exact("noframes") +
    keyword_exact("frameset") + keyword_exact("h1") + keyword_exact("h2") +
    keyword_exact("h3") + keyword_exact("h4") + keyword_exact("h5") +
    keyword_exact("h6") + keyword_exact("hr") + keyword_exact("script") +
    keyword_exact("noscript") + keyword_exact("table") +
    keyword_exact("tbody") + keyword_exact("tfoot") +
    keyword_exact("thead") + keyword_exact("th") +
    keyword_exact("td") + keyword_exact("tr")

-- There is no reason to support bad html, so we expect quoted attributes
local htmlattributevalue  = L.SQUOTE * (any - (L.BLANKLINE + L.SQUOTE))^0 * L.SQUOTE
                          + L.DQUOTE * (any - (L.BLANKLINE + L.DQUOTE))^0 * L.DQUOTE

local htmlattribute       = L.SPACING^1 * (L.ALPHANUMERIC + S("_-"))^1 * L.SP * L.EQUAL
                          * L.SP * htmlattributevalue

local htmlcomment         = P("<!--") * (any - P("-->"))^0 * P("-->")

local htmlinstruction     = P("<?")   * (any - P("?>" ))^0 * P("?>" )

local openelt_any = L.LESS * keyword * htmlattribute^0 * L.SP * L.MORE

local function openelt_exact(s)
  return (L.LESS * L.SP * keyword_exact(s) * htmlattribute^0 * L.SP * L.MORE)
end

local openelt_block = L.LESS * L.SP * block_keyword * htmlattribute^0 * L.SP * L.MORE

local closeelt_any = L.LESS * L.SP * L.SLASH * keyword * L.SP * L.MORE

local function closeelt_exact(s)
  return (L.LESS * L.SP * L.SLASH * keyword_exact(s) * L.SP * L.MORE)
end

local emptyelt_any = L.LESS * L.SP * keyword * htmlattribute^0 * L.SP * L.SLASH * L.MORE

local function emptyelt_exact(s)
  return (L.LESS * L.SP * keyword_exact(s) * htmlattribute^0 * L.SP * L.SLASH * L.MORE)
end

local emptyelt_block = L.LESS * L.SP * block_keyword * htmlattribute^0 * L.SP * L.SLASH * L.MORE

local displaytext         = (any - L.LESS)^1

-- return content between two matched L.HTML tags
local function in_matched(s)
  return { openelt_exact(s)
         * (V(1) + displaytext + (L.LESS - closeelt_exact(s)))^0
         * closeelt_exact(s) }
end

local function parse_matched_tags(s,pos)
  local t = utf8.lower(lpegmatch(L.LESS * C(keyword),s,pos))
  return lpegmatch(in_matched(t),s,pos)
end

local in_matched_block_tags = Cmt(#openelt_block, parse_matched_tags)

H.displayhtml = htmlcomment
              + emptyelt_block
              + openelt_exact("hr")
              + in_matched_block_tags
              + htmlinstruction

H.inlinehtml  = emptyelt_any
              + htmlcomment
              + htmlinstruction
              + openelt_any
              + closeelt_any


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
--     `definition_lists`
--     :   Enable definition lists as in pandoc.
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
--     `citeproc`
--     :   Automatic citations as in pandoc.  Requires installation of
--         the standalone `citeproc` executable.  The bibliography
--         or bibliographies must be specified using the `bibliography`
--         variable or metadata.  (The bibliography can be
--         MODS, BibTeX, BibLaTeX, RIS, EndNote, EndNote XML, ISI,
--         MEDLINE, Copac, or JSON citeproc.)  The CSL stylesheet must
--         be specified using the `csl` variable or metadata. A
--         primer on creating and modifying CSL styles can be found
--         at <http://citationstyles.org/downloads/primer.html>.
--         A repository of CSL styles can be found at
--         <https://github.com/citation-style-language/styles>. See also
--         <http://zotero.org/styles> for easy browsing.
--
--         Citations go inside square brackets and are separated by semicolons.
--         Each citation must have a key, composed of '@' + the citation
--         identifier from the database, and may optionally have a prefix,
--         a locator, and a suffix.  Here are some examples:
--
--             Blah blah [see @doe99, pp. 33-35; also @smith04, ch. 1].
--
--             Blah blah [@doe99, pp. 33-35, 38-39 and *passim*].
--
--             Blah blah [@smith04; @doe99].
--
--         A minus sign (`-`) before the `@` will suppress mention of
--         the author in the citation.  This can be useful when the
--         author is already mentioned in the text:
--
--             Smith says blah [-@smith04].
--
--         You can also write an in-text citation, as follows:
--
--             @smith04 says blah.
--
--             @smith04 [p. 33] says blah.
--
--         If the style calls for a list of works cited, it will replace the
--         template variable `references`.
--
--     `require_blank_before_blockquote`
--     :   Require a blank line between a paragraph and a following
--         block quote.
--
--     `require_blank_before_header`
--     :   Require a blank line between a paragraph and a following
--         header.
--
--     `hash_enumerators`
--     :   Allow `#` instead of a digit for an ordered list enumerator
--         (equivalent to `1`).
--
-- *   Returns a converter function that converts a markdown string
--     using `writer`, returning the parsed document as first result,
--     and a table containing any extracted metadata as the second
--     result. The converter assumes that the input has unix
--     line endings (newline).  If the input might have DOS
--     line endings, a simple `gsub("\r","")` should take care of them.
function M.new(writer, options)
  local options = options or {}

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

  local syntax
  local blocks
  local inlines

  parse_blocks =
    function(str)
      local res = lpegmatch(blocks, str)
      if res == nil
        then error(format("parse_blocks failed on:\n%s", str:sub(1,20)))
        else return res
        end
    end

  parse_inlines =
    function(str)
      local res = lpegmatch(inlines, str)
      if res == nil
        then error(format("parse_inlines failed on:\n%s", str:sub(1,20)))
        else return res
        end
    end

  parse_inlines_no_link =
    function(str)
      local res = lpegmatch(inlines_no_link, str)
      if res == nil
        then error(format("parse_inlines_no_link failed on:\n%s", str:sub(1,20)))
        else return res
        end
    end

  ------------------------------------------------------------------------------
  -- Generic parsers
  ------------------------------------------------------------------------------

  -- block followed by 0 or more optionally
  -- indented blocks with first line indented.
  local function indented_blocks(bl)
    return Cs( bl
             * (L.BLANKLINE^1 * L.INDENT * -L.BLANKLINE * bl)^0
             * L.BLANKLINE^1 )
  end

  local escapable              = S("\\`*_{}[]()+_.!<>#-~:^")
  local anyescaped             = P("\\") / "" * escapable
                               + any

  local tightblocksep          = P("\001")

  local specialchar
  if options.smart then
    specialchar                = S("*_`&[]<!\\'\"-.")
  else
    specialchar                = S("*_`&[]<!\\")
  end

  local normalchar             = any -
                                 (specialchar + L.SPACING + tightblocksep)
  -----------------------------------------------------------------------------
  -- Parsers used for markdown lists
  -----------------------------------------------------------------------------

  -- gobble spaces to make the whole bullet or enumerator four spaces wide:
  local function gobbletofour(s,pos,c)
      if length(c) >= 3
         then return lpegmatch(L.SPACE^-1,s,pos)
      elseif length(c) == 2
         then return lpegmatch(L.SPACE^-2,s,pos)
      else return lpegmatch(L.SPACE^-3,s,pos)
      end
  end

  local bulletchar = C(L.PLUS + L.ASTERISK + L.DASH)

  local bullet     = ( bulletchar * #L.SPACING * (L.TAB + L.SPACE^-3)
                     + L.SPACE * bulletchar * #L.SPACING * (L.TAB + L.SPACE^-2)
                     + L.SPACE * L.SPACE * bulletchar * #L.SPACING * (L.TAB + L.SPACE^-1)
                     + L.SPACE * L.SPACE * L.SPACE * bulletchar * #L.SPACING
                     ) * -bulletchar

  if options.hash_enumerators then
    dig = L.DIGIT + L.HASH
  else
    dig = L.DIGIT
  end

  local enumerator = C(dig^3 * L.PERIOD) * #L.SPACING
                   + C(dig^2 * L.PERIOD) * #L.SPACING * (L.TAB + L.SPACE^1)
                   + C(dig * L.PERIOD) * #L.SPACING * (L.TAB + L.SPACE^-2)
                   + L.SPACE * C(dig^2 * L.PERIOD) * #L.SPACING
                   + L.SPACE * C(dig * L.PERIOD) * #L.SPACING * (L.TAB + L.SPACE^-1)
                   + L.SPACE * L.SPACE * C(dig^1 * L.PERIOD) * #L.SPACING

  -----------------------------------------------------------------------------
  -- Parsers used for markdown code spans
  -----------------------------------------------------------------------------

  local openticks   = Cg(L.BACKTICK^1, "ticks")

  local function captures_equal_length(s,i,a,b)
    return #a == #b and i
  end

  local closeticks  = L.SPACE^-1 *
                      Cmt(C(L.BACKTICK^1) * Cb("ticks"), captures_equal_length)

  local intickschar = (any - S(" \n\r`"))
                    + (L.NEWLINE * -L.BLANKLINE)
                    + (L.SPACE - closeticks)
                    + (L.BACKTICK^1 - closeticks)

  local inticks     = openticks * L.SPACE^-1 * C(intickschar^1) * closeticks

  -----------------------------------------------------------------------------
  -- Parsers used for markdown tags and links
  -----------------------------------------------------------------------------

  local leader        = L.SPACE^-3

  -- in balanced brackets, parentheses, quotes:
  local bracketed     = P{ L.LBRACKET
                         * ((anyescaped - (L.LBRACKET + L.RBRACKET + L.BLANKLINE^2)) + V(1))^0
                         * L.RBRACKET }

  local inparens      = P{ L.LPARENT
                         * ((anyescaped - (L.LPARENT + L.RPARENT + L.BLANKLINE^2)) + V(1))^0
                         * L.RPARENT }

  local squoted       = P{ L.SQUOTE * L.ALPHANUMERIC
                         * ((anyescaped - (L.SQUOTE + L.BLANKLINE^2)) + V(1))^0
                         * L.SQUOTE }

  local dquoted       = P{ L.DQUOTE * L.ALPHANUMERIC
                         * ((anyescaped - (L.DQUOTE + L.BLANKLINE^2)) + V(1))^0
                         * L.DQUOTE }

  -- bracketed 'tag' for markdown links, allowing nested brackets:
  local tag           = L.LBRACKET
                      * Cs((L.ALPHANUMERIC^1
                           + bracketed
                           + inticks
                           + (anyescaped - (L.RBRACKET + L.BLANKLINE^2)))^0)
                      * L.RBRACKET

  -- url for markdown links, allowing balanced parentheses:
  local url           = L.LESS * Cs((anyescaped-L.MORE)^0) * L.MORE
                      + Cs((inparens + (anyescaped-L.SPACING-L.RPARENT))^1)

  -- quoted text possibly with nested quotes:
  local title_s       = L.SQUOTE  * Cs(((anyescaped-L.SQUOTE) + squoted)^0) * L.SQUOTE

  local title_d       = L.DQUOTE  * Cs(((anyescaped-L.DQUOTE) + dquoted)^0) * L.DQUOTE

  local title_p       = L.LPARENT
                      * Cs((inparens + (anyescaped-L.RPARENT))^0)
                      * L.RPARENT

  local title         = title_d + title_s + title_p

  local optionaltitle = L.SPNL * title * L.SPACECHAR^0
                      + Cc("")

  ------------------------------------------------------------------------------
  -- Footnotes
  ------------------------------------------------------------------------------

  local rawnotes = {}

  local function strip_first_char(s)
    return s:sub(2)
  end

  -- like indirect_link
  local function lookup_note(ref)
    return function()
      local found = rawnotes[normalize_tag(ref)]
      if found then
        return writer.note(parse_blocks(found))
      else
        return {"[^", ref, "]"}
      end
    end
  end

  local function register_note(ref,rawnote)
    rawnotes[normalize_tag(ref)] = rawnote
    return ""
  end

  local RawNoteRef = #(L.LBRACKET * L.CIRCUMFLEX) * tag / strip_first_char

  local NoteRef    = RawNoteRef / lookup_note

  local NoteBlock

  if options.notes then
    NoteBlock = leader * RawNoteRef * L.COLON * L.SPNL * indented_blocks(L.CHUNK)
              / register_note
  else
    NoteBlock = fail
  end

  ------------------------------------------------------------------------------
  -- Helpers for links and references
  ------------------------------------------------------------------------------

  -- List of references defined in the document
  local references

  -- add a reference to the list
  local function register_link(tag,url,title)
      references[normalize_tag(tag)] = { url = url, title = title }
      return ""
  end

  -- parse a reference definition:  [foo]: /bar "title"
  local define_reference_parser =
    leader * tag * L.COLON * L.SPACECHAR^0 * url * optionaltitle * L.BLANKLINE^1

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
  -- Entities
  ------------------------------------------------------------------------------

  local hexentity = L.AMPERSAND * L.HASH * S("Xx") * C(L.HEXDIGIT    ^1) * L.SEMICOLON
  local decentity = L.AMPERSAND * L.HASH           * C(L.DIGIT       ^1) * L.SEMICOLON
  local tagentity = L.AMPERSAND *                  C(L.ALPHANUMERIC^1) * L.SEMICOLON

  ------------------------------------------------------------------------------
  -- Inline elements
  ------------------------------------------------------------------------------

  local Inline    = V("Inline")

  local Str       = normalchar^1 / writer.string

  local Ellipsis  = P("...") / writer.ellipsis

  local Dash      = P("---") * -L.DASH / writer.mdash
                  + P("--") * -L.DASH / writer.ndash
                  + P("-") * #L.DIGIT * B(L.DIGIT, 2) / writer.ndash

  local DoubleQuoted = L.DQUOTE * Ct((Inline - L.DQUOTE)^1) * L.DQUOTE
                     / writer.doublequoted

  local squote_start = L.SQUOTE * -L.SPACING

  local squote_end = L.SQUOTE * B(L.NONSPACECHAR, 2)

  local SingleQuoted = squote_start * Ct((Inline - squote_end)^1) * squote_end
                     / writer.singlequoted

  local Apostrophe = L.SQUOTE * B(L.NONSPACECHAR, 2) / "’"

  local Smart      = Ellipsis + Dash + SingleQuoted + DoubleQuoted + Apostrophe

  local Symbol    = (specialchar - tightblocksep) / writer.string

  local Code      = inticks / writer.code

  local bqstart      = L.MORE
  local headerstart  = L.HASH
                     + (L.LINE * (L.EQUAL^1 + L.DASH^1) * L.OPTIONALSPACE * L.NEWLINE)

  if options.require_blank_before_blockquote then
    bqstart = fail
  end

  if options.require_blank_before_header then
    headerstart = fail
  end

  local Endline   = L.NEWLINE * -( -- newline, but not before...
                        L.BLANKLINE -- paragraph break
                      + tightblocksep  -- nested list
                      + eof       -- end of document
                      + bqstart
                      + headerstart
                    ) * L.SPACECHAR^0 / writer.space

  local Space     = L.SPACECHAR^2 * Endline / writer.linebreak
                  + L.SPACECHAR^1 * Endline^-1 * eof / ""
                  + L.SPACECHAR^1 * Endline^-1 * L.OPTIONALSPACE / writer.space

  -- parse many p between starter and ender
  local function between(p, starter, ender)
      local ender2 = B(L.NONSPACECHAR) * ender
      return (starter * #L.NONSPACECHAR * Ct(p * (p - ender2)^0) * ender2)
  end

  local Strong = ( between(Inline, L.DOUBLEASTERISKS, L.DOUBLEASTERISKS)
                 + between(Inline, L.DOUBLEUNDERSCORES, L.DOUBLEUNDERSCORES)
                 ) / writer.strong

  local Emph   = ( between(Inline, L.ASTERISK, L.ASTERISK)
                 + between(Inline, L.UNDERSCORE, L.UNDERSCORE)
                 ) / writer.emphasis

  local urlchar = anyescaped - L.NEWLINE - L.MORE

  local AutoLinkUrl   = L.LESS
                      * C(L.ALPHANUMERIC^1 * P("://") * urlchar^1)
                      * L.MORE
                      / function(url) return writer.link(writer.string(url),url) end

  local AutoLinkEmail = L.LESS
                      * C((L.ALPHANUMERIC + S("-._+"))^1 * P("@") * urlchar^1)
                      * L.MORE
                      / function(email) return writer.link(writer.string(email),"mailto:"..email) end

  local DirectLink    = (tag / parse_inlines_no_link)  -- no links inside links
                      * L.SPNL
                      * L.LPARENT
                      * (url + Cc(""))  -- link can be empty [foo]()
                      * optionaltitle
                      * L.RPARENT
                      / writer.link

  local IndirectLink = tag * (C(L.SPNL) * tag)^-1 / indirect_link

  -- parse a link or image (direct or indirect)
  local Link          = DirectLink + IndirectLink

  local DirectImage   = L.EXCLAMATION
                      * (tag / parse_inlines)
                      * L.SPNL
                      * L.LPARENT
                      * (url + Cc(""))  -- link can be empty [foo]()
                      * optionaltitle
                      * L.RPARENT
                      / writer.image

  local IndirectImage  = L.EXCLAMATION * tag * (C(L.SPNL) * tag)^-1 / indirect_image

  local Image         = DirectImage + IndirectImage

  -- avoid parsing long strings of * or _ as emph/strong
  local UlOrStarLine  = L.ASTERISK^4 + L.UNDERSCORE^4 / writer.string

  local EscapedChar   = S("\\") * C(escapable) / writer.string

  local InlineHtml    = C(H.inlinehtml) / writer.inline_html

  local HtmlEntity    = hexentity / entities.hex_entity  / writer.string
                      + decentity / entities.dec_entity  / writer.string
                      + tagentity / entities.char_entity / writer.string

  ------------------------------------------------------------------------------
  -- Block elements
  ------------------------------------------------------------------------------

  local Block          = V("Block")

  local DisplayHtml    = C(H.displayhtml) / expandtabs / writer.display_html

  local Verbatim       = Cs( (L.BLANKLINES
                           * ((L.INDENTEDLINE - L.BLANKLINE))^1)^1
                           ) / expandtabs / writer.verbatim

  -- strip off leading > and indents, and run through blocks
  local Blockquote     = Cs((
            ((leader * L.MORE * L.SPACE^-1)/"" * L.LINECHAR^0 * L.NEWLINE)^1
          * (-L.BLANKLINE * L.LINECHAR^1 * L.NEWLINE)^0
          * L.BLANKLINE^0
          )^1) / parse_blocks / writer.blockquote

  local function lineof(c)
      return (leader * (P(c) * L.OPTIONALSPACE)^3 * L.NEWLINE * L.BLANKLINE^1)
  end

  local HorizontalRule = ( lineof(L.ASTERISK)
                         + lineof(L.DASH)
                         + lineof(L.UNDERSCORE)
                         ) / writer.hrule

  local Reference      = define_reference_parser / register_link

  local Paragraph      = L.NONINDENTSPACE * Ct(Inline^1) * L.NEWLINE
                       * ( L.BLANKLINE^1
                         + #L.HASH
                         + #(leader * L.MORE * L.SPACE^-1)
                         )
                       / writer.paragraph

  local Plain          = L.NONINDENTSPACE * Ct(Inline^1) / writer.plain

  ------------------------------------------------------------------------------
  -- Lists
  ------------------------------------------------------------------------------

  local starter = bullet + enumerator

  -- we use \001 as a separator between a tight list item and a
  -- nested list under it.
  local NestedList            = Cs((L.OPTIONALLYINDENTEDLINE - starter)^1)
                              / function(a) return "\001"..a end

  local ListBlockLine         = L.OPTIONALLYINDENTEDLINE
                                - L.BLANKLINE - (L.INDENT^-1 * starter)

  local ListBlock             = L.LINE * ListBlockLine^0

  local ListContinuationBlock = L.BLANKLINES * (L.INDENT / "") * ListBlock

  local function TightListItem(starter)
      return -HorizontalRule
             * (Cs(starter / "" * ListBlock * NestedList^-1) / parse_blocks)
             * -(L.BLANKLINES * L.INDENT)
  end

  local function LooseListItem(starter)
      return -HorizontalRule
             * Cs( starter / "" * ListBlock * Cc("\n")
               * (NestedList + ListContinuationBlock^0)
               * (L.BLANKLINES / "\n\n")
               ) / parse_blocks
  end

  local BulletList = ( Ct(TightListItem(bullet)^1)
                       * Cc(true) * L.SKIPBLANKLINES * -bullet
                     + Ct(LooseListItem(bullet)^1)
                       * Cc(false) * L.SKIPBLANKLINES ) / writer.bulletlist

  local function ordered_list(s,tight,startnum)
    if options.startnum then
      startnum = tonumber(listtype) or 1  -- fallback for '#'
    else
      startnum = nil
    end
    return writer.orderedlist(s,tight,startnum)
  end

  local OrderedList = Cg(enumerator, "listtype") *
                      ( Ct(TightListItem(Cb("listtype")) * TightListItem(enumerator)^0)
                        * Cc(true) * L.SKIPBLANKLINES * -enumerator
                      + Ct(LooseListItem(Cb("listtype")) * LooseListItem(enumerator)^0)
                        * Cc(false) * L.SKIPBLANKLINES
                      ) * Cb("listtype") / ordered_list

  local defstartchar = S("~:")
  local defstart     = ( defstartchar * #L.SPACING * (L.TAB + L.SPACE^-3)
                     + L.SPACE * defstartchar * #L.SPACING * (L.TAB + L.SPACE^-2)
                     + L.SPACE * L.SPACE * defstartchar * #L.SPACING * (L.TAB + L.SPACE^-1)
                     + L.SPACE * L.SPACE * L.SPACE * defstartchar * #L.SPACING
                     )

  local dlchunk = Cs(L.LINE * (L.INDENTEDLINE - L.BLANKLINE)^0)

  local function definition_list_item(term, defs, tight)
    return { term = parse_inlines(term), definitions = defs }
  end

  local DefinitionListItemLoose = C(L.LINE) * L.SKIPBLANKLINES
                           * Ct((defstart * indented_blocks(dlchunk) / parse_blocks)^1)
                           * Cc(false)
                           / definition_list_item

  local DefinitionListItemTight = C(L.LINE)
                           * Ct((defstart * dlchunk / parse_blocks)^1)
                           * Cc(true)
                           / definition_list_item

  local DefinitionList =  ( Ct(DefinitionListItemLoose^1) * Cc(false)
                          +  Ct(DefinitionListItemTight^1)
                             * (L.SKIPBLANKLINES * -DefinitionListItemLoose * Cc(true))
                          ) / writer.definitionlist

  ------------------------------------------------------------------------------
  -- Lua metadata
  ------------------------------------------------------------------------------

  local function lua_metadata(s)  -- run lua code in comment in sandbox
    local env = { m = parse_markdown, markdown = parse_blocks }
    local scode = s:match("^<!%-%-@%s*(.*)%-%->")
    local untrusted_table, message = loadstring(scode)
    if not untrusted_table then
      util.err(message, 37)
    end
    setfenv(untrusted_table, env)
    local ok, msg = pcall(untrusted_table)
    if not ok then
      util.err(msg)
    end
    for k,v in pairs(env) do
      writer.set_metadata(k,v)
    end
    return ""
  end

  local LuaMeta = fail
  if options.lua_metadata then
    LuaMeta = #P("<!--@") * htmlcomment / lua_metadata
  end

  ------------------------------------------------------------------------------
  -- Pandoc title block parser
  ------------------------------------------------------------------------------

  local pandoc_title =
      L.PERCENT * L.OPTIONALSPACE
    * C(L.LINE * (L.SPACECHAR * L.NONEMPTYLINE)^0) / parse_inlines
  local pandoc_author =
      L.SPACECHAR * L.OPTIONALSPACE
    * C((anyescaped - L.NEWLINE - L.SEMICOLON)^0)
    * (L.SEMICOLON + L.NEWLINE)
  local pandoc_authors =
    L.PERCENT * Cs((pandoc_author / parse_inlines)^0) * L.NEWLINE^-1
  local pandoc_date =
    L.PERCENT * L.OPTIONALSPACE * C(L.LINE) / parse_inlines
  local pandoc_title_block =
      (pandoc_title + Cc(""))
    * (pandoc_authors + Cc({}))
    * (pandoc_date + Cc(""))
    * C(P(1)^0)

  ------------------------------------------------------------------------------
  -- Blank
  ------------------------------------------------------------------------------

  local Blank          = L.BLANKLINE / ""
                       + LuaMeta
                       + NoteBlock
                       + Reference
                       + (tightblocksep / "\n")

  ------------------------------------------------------------------------------
  -- Headers
  ------------------------------------------------------------------------------

  -- parse Atx heading start and return level
  local HeadingStart = #L.HASH * C(L.HASH^-6) * -L.HASH / length

  -- parse setext header ending and return level
  local HeadingLevel = L.EQUAL^1 * Cc(1) + L.DASH^1 * Cc(2)

  local function strip_atx_end(s)
    return s:gsub("[#%s]*\n$","")
  end

  -- parse atx header
  local AtxHeader = Cg(HeadingStart,"level")
                     * L.OPTIONALSPACE
                     * (C(L.LINE) / strip_atx_end / parse_inlines)
                     * Cb("level")
                     / writer.header

  -- parse setext header
  local SetextHeader = #(L.LINE * S("=-"))
                     * (C(L.LINE) / parse_inlines)
                     * HeadingLevel
                     * L.OPTIONALSPACE * L.NEWLINE
                     / writer.header

  ------------------------------------------------------------------------------
  -- Syntax specification
  ------------------------------------------------------------------------------

  syntax =
    { "Blocks",

      Blocks                = Blank^0 *
                              Block^-1 *
                              (Blank^0 / function() return writer.interblocksep end * Block)^0 *
                              Blank^0 *
                              eof,

      Blank                 = Blank,

      Block                 = V("Blockquote")
                            + V("Verbatim")
                            + V("HorizontalRule")
                            + V("BulletList")
                            + V("OrderedList")
                            + V("Header")
                            + V("DefinitionList")
                            + V("DisplayHtml")
                            + V("Paragraph")
                            + V("Plain"),

      Blockquote            = Blockquote,
      Verbatim              = Verbatim,
      HorizontalRule        = HorizontalRule,
      BulletList            = BulletList,
      OrderedList           = OrderedList,
      Header                = AtxHeader + SetextHeader,
      DefinitionList        = DefinitionList,
      DisplayHtml           = DisplayHtml,
      Paragraph             = Paragraph,
      Plain                 = Plain,

      Inline                = V("Str")
                            + V("Space")
                            + V("Endline")
                            + V("UlOrStarLine")
                            + V("Strong")
                            + V("Emph")
                            + V("NoteRef")
                            + V("Link")
                            + V("Image")
                            + V("Code")
                            + V("AutoLinkUrl")
                            + V("AutoLinkEmail")
                            + V("InlineHtml")
                            + V("HtmlEntity")
                            + V("EscapedChar")
                            + V("Smart")
                            + V("Symbol"),

      Str                   = Str,
      Space                 = Space,
      Endline               = Endline,
      UlOrStarLine          = UlOrStarLine,
      Strong                = Strong,
      Emph                  = Emph,
      NoteRef               = NoteRef,
      Link                  = Link,
      Image                 = Image,
      Code                  = Code,
      AutoLinkUrl           = AutoLinkUrl,
      AutoLinkEmail         = AutoLinkEmail,
      InlineHtml            = InlineHtml,
      HtmlEntity            = HtmlEntity,
      EscapedChar           = EscapedChar,
      Smart                 = Smart,
      Symbol                = Symbol,
    }

  if not options.definition_lists then
    syntax.DefinitionList = fail
  end

  if not options.notes then
    syntax.NoteRef = fail
  end

  if not options.smart then
    syntax.Smart = fail
  end

  if options.alter_syntax and type(options.alter_syntax) == "function" then
    syntax = options.alter_syntax(syntax)
  end

  blocks = Ct(syntax)

  local inlines_t = util.table_copy(syntax)
  inlines_t[1] = "Inlines"
  inlines_t.Inlines = Inline^0 * (L.SPACING^0 * eof / "")
  inlines = Ct(inlines_t)

  inlines_no_link_t = util.table_copy(inlines_t)
  inlines_no_link_t.Link = fail
  inlines_no_link = Ct(inlines_no_link_t)

  ------------------------------------------------------------------------------
  -- Exported conversion function
  ------------------------------------------------------------------------------

  -- inp is a string; line endings are assumed to be LF (unix-style)
  -- and tabs are assumed to be expanded.
  return function(inp)
      references = options.references or {}
      if options.pandoc_title_blocks then
        local title, authors, date, rest = lpegmatch(pandoc_title_block, inp)
        writer.set_metadata("title",title)
        writer.set_metadata("author",authors)
        writer.set_metadata("date",date)
        inp = rest
      end
      local result = { writer.start_document(), parse_blocks(inp), writer.stop_document() }
      return rope_to_string(result), writer.get_metadata()
  end

end

return M
