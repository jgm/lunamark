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

  local PERCENT                = P("%")
  local ASTERISK               = P("*")
  local DASH                   = P("-")
  local PLUS                   = P("+")
  local UNDERSCORE             = P("_")
  local PERIOD                 = P(".")
  local HASH                   = P("#")
  local AMPERSAND              = P("&")
  local BACKTICK               = P("`")
  local LESS                   = P("<")
  local MORE                   = P(">")
  local SPACE                  = P(" ")
  local SQUOTE                 = P("'")
  local DQUOTE                 = P('"')
  local LPARENT                = P("(")
  local RPARENT                = P(")")
  local LBRACKET               = P("[")
  local RBRACKET               = P("]")
  local CIRCUMFLEX             = P("^")
  local SLASH                  = P("/")
  local EQUAL                  = P("=")
  local COLON                  = P(":")
  local SEMICOLON              = P(";")
  local EXCLAMATION            = P("!")

  local digit                  = R("09")
  local hexdigit               = R("09","af","AF")
  local letter                 = R("AZ","az")
  local alphanumeric           = R("AZ","az","09")
  local keyword                = letter * alphanumeric^0

  local doubleasterisks        = P("**")
  local doubleunderscores      = P("__")
  local fourspaces             = P("    ")

  local any                    = P(1)
  local fail                   = any - 1
  local always                 = P("")

  local escapable              = S("\\`*_{}[]()+_.!<>#-~:^")
  local anyescaped             = P("\\") / "" * escapable
                               + any

  local tab                    = P("\t")
  local spacechar              = S("\t ")
  local spacing                = S(" \n\r\t")
  local newline                = P("\n")
  local nonspacechar           = any - spacing
  local tightblocksep          = P("\001")

  local specialchar
  if options.smart then
    specialchar                = S("*_`&[]<!\\'\"-.")
  else
    specialchar                = S("*_`&[]<!\\")
  end

  local normalchar             = any -
                                 (specialchar + spacing + tightblocksep)
  local optionalspace          = spacechar^0
  local spaces                 = spacechar^1
  local eof                    = - any
  local nonindentspace         = SPACE^-3 * - spacechar
  local indent                 = SPACE^-3 * tab
                               + fourspaces / ""
  local linechar               = P(1 - newline)

  local blankline              = optionalspace * newline / "\n"
  local blanklines             = blankline^0
  local skipblanklines         = (optionalspace * newline)^0
  local indentedline           = indent    /"" * C(linechar^1 * newline^-1)
  local optionallyindentedline = indent^-1 /"" * C(linechar^1 * newline^-1)
  local sp                     = spacing^0
  local spnl                   = optionalspace * (newline * optionalspace)^-1
  local line                   = linechar^0 * newline
                               + linechar^1 * eof
  local nonemptyline           = line - blankline

  local chunk = line * (optionallyindentedline - blankline)^0

  -- block followed by 0 or more optionally
  -- indented blocks with first line indented.
  local function indented_blocks(bl)
    return Cs( bl
             * (blankline^1 * indent * -blankline * bl)^0
             * blankline^1 )
  end

  -----------------------------------------------------------------------------
  -- Parsers used for markdown lists
  -----------------------------------------------------------------------------

  -- gobble spaces to make the whole bullet or enumerator four spaces wide:
  local function gobbletofour(s,pos,c)
      if length(c) >= 3
         then return lpegmatch(SPACE^-1,s,pos)
      elseif length(c) == 2
         then return lpegmatch(SPACE^-2,s,pos)
      else return lpegmatch(SPACE^-3,s,pos)
      end
  end

  local bulletchar = C(PLUS + ASTERISK + DASH)

  local bullet     = ( bulletchar * #spacing * (tab + SPACE^-3)
                     + SPACE * bulletchar * #spacing * (tab + SPACE^-2)
                     + SPACE * SPACE * bulletchar * #spacing * (tab + SPACE^-1)
                     + SPACE * SPACE * SPACE * bulletchar * #spacing
                     ) * -bulletchar

  if options.hash_enumerators then
    dig = digit + HASH
  else
    dig = digit
  end

  local enumerator = C(dig^3 * PERIOD) * #spacing
                   + C(dig^2 * PERIOD) * #spacing * (tab + SPACE^1)
                   + C(dig * PERIOD) * #spacing * (tab + SPACE^-2)
                   + SPACE * C(dig^2 * PERIOD) * #spacing
                   + SPACE * C(dig * PERIOD) * #spacing * (tab + SPACE^-1)
                   + SPACE * SPACE * C(dig^1 * PERIOD) * #spacing

  -----------------------------------------------------------------------------
  -- Parsers used for markdown code spans
  -----------------------------------------------------------------------------

  local openticks   = Cg(BACKTICK^1, "ticks")

  local function captures_equal_length(s,i,a,b)
    return #a == #b and i
  end

  local closeticks  = SPACE^-1 *
                      Cmt(C(BACKTICK^1) * Cb("ticks"), captures_equal_length)

  local intickschar = (any - S(" \n\r`"))
                    + (newline * -blankline)
                    + (SPACE - closeticks)
                    + (BACKTICK^1 - closeticks)

  local inticks     = openticks * SPACE^-1 * C(intickschar^1) * closeticks

  -----------------------------------------------------------------------------
  -- Parsers used for markdown tags and links
  -----------------------------------------------------------------------------

  local leader        = SPACE^-3

  -- in balanced brackets, parentheses, quotes:
  local bracketed     = P{ LBRACKET
                         * ((anyescaped - (LBRACKET + RBRACKET + blankline^2)) + V(1))^0
                         * RBRACKET }

  local inparens      = P{ LPARENT
                         * ((anyescaped - (LPARENT + RPARENT + blankline^2)) + V(1))^0
                         * RPARENT }

  local squoted       = P{ SQUOTE * alphanumeric
                         * ((anyescaped - (SQUOTE + blankline^2)) + V(1))^0
                         * SQUOTE }

  local dquoted       = P{ DQUOTE * alphanumeric
                         * ((anyescaped - (DQUOTE + blankline^2)) + V(1))^0
                         * DQUOTE }

  -- bracketed 'tag' for markdown links, allowing nested brackets:
  local tag           = LBRACKET
                      * Cs((alphanumeric^1
                           + bracketed
                           + inticks
                           + (anyescaped - (RBRACKET + blankline^2)))^0)
                      * RBRACKET

  -- url for markdown links, allowing balanced parentheses:
  local url           = LESS * Cs((anyescaped-MORE)^0) * MORE
                      + Cs((inparens + (anyescaped-spacing-RPARENT))^1)

  -- quoted text possibly with nested quotes:
  local title_s       = SQUOTE  * Cs(((anyescaped-SQUOTE) + squoted)^0) * SQUOTE

  local title_d       = DQUOTE  * Cs(((anyescaped-DQUOTE) + dquoted)^0) * DQUOTE

  local title_p       = LPARENT
                      * Cs((inparens + (anyescaped-RPARENT))^0)
                      * RPARENT

  local title         = title_d + title_s + title_p

  local optionaltitle = spnl * title * spacechar^0
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

  local RawNoteRef = #(LBRACKET * CIRCUMFLEX) * tag / strip_first_char

  local NoteRef    = RawNoteRef / lookup_note

  local NoteBlock

  if options.notes then
    NoteBlock = leader * RawNoteRef * COLON * spnl * indented_blocks(chunk)
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
    leader * tag * COLON * spacechar^0 * url * optionaltitle * blankline^1

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
  -- HTML
  ------------------------------------------------------------------------------

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
  local htmlattributevalue  = SQUOTE * (any - (blankline + SQUOTE))^0 * SQUOTE
                            + DQUOTE * (any - (blankline + DQUOTE))^0 * DQUOTE

  local htmlattribute       = spacing^1 * (alphanumeric + S("_-"))^1 * sp * EQUAL
                            * sp * htmlattributevalue

  local htmlcomment         = P("<!--") * (any - P("-->"))^0 * P("-->")

  local htmlinstruction     = P("<?")   * (any - P("?>" ))^0 * P("?>" )

  local openelt_any = LESS * keyword * htmlattribute^0 * sp * MORE

  local function openelt_exact(s)
    return (LESS * sp * keyword_exact(s) * htmlattribute^0 * sp * MORE)
  end

  local openelt_block = LESS * sp * block_keyword * htmlattribute^0 * sp * MORE

  local closeelt_any = LESS * sp * SLASH * keyword * sp * MORE

  local function closeelt_exact(s)
    return (LESS * sp * SLASH * keyword_exact(s) * sp * MORE)
  end

  local emptyelt_any = LESS * sp * keyword * htmlattribute^0 * sp * SLASH * MORE

  local function emptyelt_exact(s)
    return (LESS * sp * keyword_exact(s) * htmlattribute^0 * sp * SLASH * MORE)
  end

  local emptyelt_block = LESS * sp * block_keyword * htmlattribute^0 * sp * SLASH * MORE

  local displaytext         = (any - LESS)^1

  -- return content between two matched HTML tags
  local function in_matched(s)
    return { openelt_exact(s)
           * (V(1) + displaytext + (LESS - closeelt_exact(s)))^0
           * closeelt_exact(s) }
  end

  local function parse_matched_tags(s,pos)
    local t = utf8.lower(lpegmatch(LESS * C(keyword),s,pos))
    return lpegmatch(in_matched(t),s,pos)
  end

  local in_matched_block_tags = Cmt(#openelt_block, parse_matched_tags)

  local displayhtml = htmlcomment
                    + emptyelt_block
                    + openelt_exact("hr")
                    + in_matched_block_tags
                    + htmlinstruction

  local inlinehtml  = emptyelt_any
                    + htmlcomment
                    + htmlinstruction
                    + openelt_any
                    + closeelt_any

  ------------------------------------------------------------------------------
  -- Entities
  ------------------------------------------------------------------------------

  local hexentity = AMPERSAND * HASH * S("Xx") * C(hexdigit    ^1) * SEMICOLON
  local decentity = AMPERSAND * HASH           * C(digit       ^1) * SEMICOLON
  local tagentity = AMPERSAND *                  C(alphanumeric^1) * SEMICOLON

  ------------------------------------------------------------------------------
  -- Inline elements
  ------------------------------------------------------------------------------

  local Inline    = V("Inline")

  local Str       = normalchar^1 / writer.string

  local Ellipsis  = P("...") / writer.ellipsis

  local Dash      = P("---") * -DASH / writer.mdash
                  + P("--") * -DASH / writer.ndash
                  + P("-") * #digit * B(digit, 2) / writer.ndash

  local DoubleQuoted = DQUOTE * Ct((Inline - DQUOTE)^1) * DQUOTE
                     / writer.doublequoted

  local squote_start = SQUOTE * -spacing

  local squote_end = SQUOTE * B(nonspacechar, 2)

  local SingleQuoted = squote_start * Ct((Inline - squote_end)^1) * squote_end
                     / writer.singlequoted

  local Apostrophe = SQUOTE * B(nonspacechar, 2) / "’"

  local Smart      = Ellipsis + Dash + SingleQuoted + DoubleQuoted + Apostrophe

  local Symbol    = (specialchar - tightblocksep) / writer.string

  local Code      = inticks / writer.code

  local bqstart      = MORE
  local headerstart  = HASH
                     + (line * (EQUAL^1 + DASH^1) * optionalspace * newline)

  if options.require_blank_before_blockquote then
    bqstart = fail
  end

  if options.require_blank_before_header then
    headerstart = fail
  end

  local Endline   = newline * -( -- newline, but not before...
                        blankline -- paragraph break
                      + tightblocksep  -- nested list
                      + eof       -- end of document
                      + bqstart
                      + headerstart
                    ) * spacechar^0 / writer.space

  local Space     = spacechar^2 * Endline / writer.linebreak
                  + spacechar^1 * Endline^-1 * eof / ""
                  + spacechar^1 * Endline^-1 * optionalspace / writer.space

  -- parse many p between starter and ender
  local function between(p, starter, ender)
      local ender2 = B(nonspacechar) * ender
      return (starter * #nonspacechar * Ct(p * (p - ender2)^0) * ender2)
  end

  local Strong = ( between(Inline, doubleasterisks, doubleasterisks)
                 + between(Inline, doubleunderscores, doubleunderscores)
                 ) / writer.strong

  local Emph   = ( between(Inline, ASTERISK, ASTERISK)
                 + between(Inline, UNDERSCORE, UNDERSCORE)
                 ) / writer.emphasis

  local urlchar = anyescaped - newline - MORE

  local AutoLinkUrl   = LESS
                      * C(alphanumeric^1 * P("://") * urlchar^1)
                      * MORE
                      / function(url) return writer.link(writer.string(url),url) end

  local AutoLinkEmail = LESS
                      * C((alphanumeric + S("-._+"))^1 * P("@") * urlchar^1)
                      * MORE
                      / function(email) return writer.link(writer.string(email),"mailto:"..email) end

  local DirectLink    = (tag / parse_inlines_no_link)  -- no links inside links
                      * spnl
                      * LPARENT
                      * (url + Cc(""))  -- link can be empty [foo]()
                      * optionaltitle
                      * RPARENT
                      / writer.link

  local IndirectLink = tag * (C(spnl) * tag)^-1 / indirect_link

  -- parse a link or image (direct or indirect)
  local Link          = DirectLink + IndirectLink

  local DirectImage   = EXCLAMATION
                      * (tag / parse_inlines)
                      * spnl
                      * LPARENT
                      * (url + Cc(""))  -- link can be empty [foo]()
                      * optionaltitle
                      * RPARENT
                      / writer.image

  local IndirectImage  = EXCLAMATION * tag * (C(spnl) * tag)^-1 / indirect_image

  local Image         = DirectImage + IndirectImage

  -- avoid parsing long strings of * or _ as emph/strong
  local UlOrStarLine  = ASTERISK^4 + UNDERSCORE^4 / writer.string

  local EscapedChar   = S("\\") * C(escapable) / writer.string

  local InlineHtml    = C(inlinehtml) / writer.inline_html

  local HtmlEntity    = hexentity / entities.hex_entity  / writer.string
                      + decentity / entities.dec_entity  / writer.string
                      + tagentity / entities.char_entity / writer.string

  ------------------------------------------------------------------------------
  -- Block elements
  ------------------------------------------------------------------------------

  local Block          = V("Block")

  local DisplayHtml    = C(displayhtml) / expandtabs / writer.display_html

  local Verbatim       = Cs( (blanklines
                           * ((indentedline - blankline))^1)^1
                           ) / expandtabs / writer.verbatim

  -- strip off leading > and indents, and run through blocks
  local Blockquote     = Cs((
            ((leader * MORE * SPACE^-1)/"" * linechar^0 * newline)^1
          * (-blankline * linechar^1 * newline)^0
          * blankline^0
          )^1) / parse_blocks / writer.blockquote

  local function lineof(c)
      return (leader * (P(c) * optionalspace)^3 * newline * blankline^1)
  end

  local HorizontalRule = ( lineof(ASTERISK)
                         + lineof(DASH)
                         + lineof(UNDERSCORE)
                         ) / writer.hrule

  local Reference      = define_reference_parser / register_link

  local Paragraph      = nonindentspace * Ct(Inline^1) * newline
                       * ( blankline^1
                         + #HASH
                         + #(leader * MORE * SPACE^-1)
                         )
                       / writer.paragraph

  local Plain          = nonindentspace * Ct(Inline^1) / writer.plain

  ------------------------------------------------------------------------------
  -- Lists
  ------------------------------------------------------------------------------

  local starter = bullet + enumerator

  -- we use \001 as a separator between a tight list item and a
  -- nested list under it.
  local NestedList            = Cs((optionallyindentedline - starter)^1)
                              / function(a) return "\001"..a end

  local ListBlockLine         = optionallyindentedline
                                - blankline - (indent^-1 * starter)

  local ListBlock             = line * ListBlockLine^0

  local ListContinuationBlock = blanklines * (indent / "") * ListBlock

  local function TightListItem(starter)
      return -HorizontalRule
             * (Cs(starter / "" * ListBlock * NestedList^-1) / parse_blocks)
             * -(blanklines * indent)
  end

  local function LooseListItem(starter)
      return -HorizontalRule
             * Cs( starter / "" * ListBlock * Cc("\n")
               * (NestedList + ListContinuationBlock^0)
               * (blanklines / "\n\n")
               ) / parse_blocks
  end

  local BulletList = ( Ct(TightListItem(bullet)^1)
                       * Cc(true) * skipblanklines * -bullet
                     + Ct(LooseListItem(bullet)^1)
                       * Cc(false) * skipblanklines ) / writer.bulletlist

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
                        * Cc(true) * skipblanklines * -enumerator
                      + Ct(LooseListItem(Cb("listtype")) * LooseListItem(enumerator)^0)
                        * Cc(false) * skipblanklines
                      ) * Cb("listtype") / ordered_list

  local defstartchar = S("~:")
  local defstart     = ( defstartchar * #spacing * (tab + SPACE^-3)
                     + SPACE * defstartchar * #spacing * (tab + SPACE^-2)
                     + SPACE * SPACE * defstartchar * #spacing * (tab + SPACE^-1)
                     + SPACE * SPACE * SPACE * defstartchar * #spacing
                     )

  local dlchunk = Cs(line * (indentedline - blankline)^0)

  local function definition_list_item(term, defs, tight)
    return { term = parse_inlines(term), definitions = defs }
  end

  local DefinitionListItemLoose = C(line) * skipblanklines
                           * Ct((defstart * indented_blocks(dlchunk) / parse_blocks)^1)
                           * Cc(false)
                           / definition_list_item

  local DefinitionListItemTight = C(line)
                           * Ct((defstart * dlchunk / parse_blocks)^1)
                           * Cc(true)
                           / definition_list_item

  local DefinitionList =  ( Ct(DefinitionListItemLoose^1) * Cc(false)
                          +  Ct(DefinitionListItemTight^1)
                             * (skipblanklines * -DefinitionListItemLoose * Cc(true))
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
      PERCENT * optionalspace
    * C(line * (spacechar * nonemptyline)^0) / parse_inlines
  local pandoc_author =
      spacechar * optionalspace
    * C((anyescaped - newline - SEMICOLON)^0)
    * (SEMICOLON + newline)
  local pandoc_authors =
    PERCENT * Cs((pandoc_author / parse_inlines)^0) * newline^-1
  local pandoc_date =
    PERCENT * optionalspace * C(line) / parse_inlines
  local pandoc_title_block =
      (pandoc_title + Cc(""))
    * (pandoc_authors + Cc({}))
    * (pandoc_date + Cc(""))
    * C(P(1)^0)

  ------------------------------------------------------------------------------
  -- Blank
  ------------------------------------------------------------------------------

  local Blank          = blankline / ""
                       + LuaMeta
                       + NoteBlock
                       + Reference
                       + (tightblocksep / "\n")

  ------------------------------------------------------------------------------
  -- Headers
  ------------------------------------------------------------------------------

  -- parse Atx heading start and return level
  local HeadingStart = #HASH * C(HASH^-6) * -HASH / length

  -- parse setext header ending and return level
  local HeadingLevel = EQUAL^1 * Cc(1) + DASH^1 * Cc(2)

  local function strip_atx_end(s)
    return s:gsub("[#%s]*\n$","")
  end

  -- parse atx header
  local AtxHeader = Cg(HeadingStart,"level")
                     * optionalspace
                     * (C(line) / strip_atx_end / parse_inlines)
                     * Cb("level")
                     / writer.header

  -- parse setext header
  local SetextHeader = #(line * S("=-"))
                     * (C(line) / parse_inlines)
                     * HeadingLevel
                     * optionalspace * newline
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
  inlines_t.Inlines = Inline^0 * (spacing^0 * eof / "")
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
