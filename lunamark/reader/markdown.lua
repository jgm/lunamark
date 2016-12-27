-- (c) 2009-2011 John MacFarlane, Hans Hagen.  Released under MIT license.
-- See the file LICENSE in the source for details.

local util = require("lunamark.util")
local lpeg = require("lpeg")
local entities = require("lunamark.entities")
local lower, upper, gsub, format, length =
  string.lower, string.upper, string.gsub, string.format, string.len
local P, R, S, V, C, Cg, Cb, Cmt, Cc, Ct, B, Cs =
  lpeg.P, lpeg.R, lpeg.S, lpeg.V, lpeg.C, lpeg.Cg, lpeg.Cb,
  lpeg.Cmt, lpeg.Cc, lpeg.Ct, lpeg.B, lpeg.Cs
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
parsers.internal_punctuation   = S(":;,.#$%&-+?<>~/")

parsers.doubleasterisks        = P("**")
parsers.doubleunderscores      = P("__")
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
                               + parsers.linechar^1 * parsers.eof
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

local function captures_equal_length(s,i,a,b)
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

local function captures_geq_length(s,i,a,b)
  return #a >= #b and i
end

parsers.infostring  = (parsers.linechar - (parsers.backtick
                    + parsers.space^1 * parsers.newline))^0

local fenceindent
parsers.fencehead   = function(char)
  return              C(parsers.nonindentspace) / function(s)
                                                    fenceindent = #s
                                                  end
                    * Cg(char^3, "fencelength")
                    * parsers.optionalspace * C(parsers.infostring)
                    * parsers.optionalspace * parsers.newline + parsers.eof
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
                      * Cs(parsers.alphanumeric
                          * (parsers.alphanumeric + parsers.internal_punctuation
                            - parsers.comma - parsers.semicolon)^0)

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
                    * (parsers.comma * parsers.spnl)^-1
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
-- *   Returns a converter function that converts a markdown string
--     using `writer`, returning the parsed document as first result,
--     and a table containing any extracted metadata as the second
--     result. The converter assumes that the input has unix
--     line endings (newline).  If the input might have DOS
--     line endings, a simple `gsub("\r","")` should take care of them.
function M.new(writer, options)
  options = options or {}

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

--  local local_parsers         = {}
--  setmetatable(local_parsers, {__index = parsers}) -- look up globally
--  local parsers               = local_parsers -- but store locally
  local larsers               = {}

  ------------------------------------------------------------------------------
  -- Top-level parser functions (local)
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

  larsers.parse_blocks = create_parser("parse_blocks",
    function() return larsers.blocks end)
  larsers.parse_inlines = create_parser("parse_inlines",
    function() return larsers.inlines end)
  larsers.parse_inlines_no_link = create_parser("parse_inlines_no_link",
    function() return larsers.inlines_no_link end)
  larsers.parse_inlines_no_inline_note = create_parser(
    "parse_inlines_no_inline_note",
    function() return larsers.inlines_no_inline_note end)
  larsers.parse_inlines_nbsp = create_parser("parse_inlines_nbsp",
    function() return larsers.inlines_nbsp end)
  
  ------------------------------------------------------------------------------
  -- Basic parsers (local)
  ------------------------------------------------------------------------------

  if options.smart then
    larsers.specialchar       = S("*_`&[]<!\\'\"-.@^")
  else
    larsers.specialchar       = S("*_`&[]<!\\-@^")
  end

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

  larsers.enumerator = C(larsers.dig^3 * parsers.period) * #parsers.spacing
                     + C(larsers.dig^2 * parsers.period) * #parsers.spacing
                                       * (parsers.tab + parsers.space^1)
                     + C(larsers.dig * parsers.period) * #parsers.spacing
                                     * (parsers.tab + parsers.space^-2)
                     + parsers.space * C(larsers.dig^2 * parsers.period)
                                     * #parsers.spacing
                     + parsers.space * C(larsers.dig * parsers.period)
                                     * #parsers.spacing
                                     * (parsers.tab + parsers.space^-1)
                     + parsers.space * parsers.space * C(larsers.dig^1
                                     * parsers.period) * #parsers.spacing

  ------------------------------------------------------------------------------
  -- Parsers used for citations (local)
  ------------------------------------------------------------------------------

  larsers.citations = function(text_cites, raw_cites)
      local function normalize(str)
          if str == "" then
              str = nil
          else
              str = (options.citation_nbsps and larsers.parse_inlines_nbsp or
                larsers.parse_inlines)(str)
          end
          return str
      end

      local cites = {}
      for i = 1,#raw_cites,4 do
          cites[#cites+1] = {
              prenote = normalize(raw_cites[i]),
              suppress_author = raw_cites[i+1] == "-",
              name = writer.string(raw_cites[i+2]),
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
        return writer.note(larsers.parse_blocks(found))
      else
        return {"[", larsers.parse_inlines("^" .. ref), "]"}
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
                     * (parsers.tag / larsers.parse_inlines_no_inline_note) -- no notes inside notes
                     / writer.note

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
  local define_reference_parser = parsers.leader * parsers.tag * parsers.colon
                                * parsers.spacechar^0 * parsers.url
                                * parsers.optionaltitle * parsers.blankline^1

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
          tagpart = {"[", larsers.parse_inlines(tag), "]"}
      end
      if sps then
        tagpart = {sps, tagpart}
      end
      local r = references[normalize_tag(tag)]
      if r then
        return r
      else
        return nil, {"[", larsers.parse_inlines(label), "]", tagpart}
      end
  end

  -- lookup link reference and return a link, if the reference is found,
  -- or a bracketed label otherwise.
  local function indirect_link(label,sps,tag)
    return function()
      local r,fallback = lookup_reference(label,sps,tag)
      if r then
        return writer.link(larsers.parse_inlines_no_link(label), r.url, r.title)
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

  -- case-insensitive match (we assume s is lowercase). must be single byte encoding
  local function keyword_exact(s)
    local parser = P(0)
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
  local htmlattributevalue  = parsers.squote * (parsers.any - (parsers.blankline
                                                              + parsers.squote))^0
                                             * parsers.squote
                            + parsers.dquote * (parsers.any - (parsers.blankline
                                                              + parsers.dquote))^0
                                             * parsers.dquote

  local htmlattribute       = parsers.spacing^1 * (parsers.alphanumeric + S("_-"))^1
                            * parsers.sp * parsers.equal * parsers.sp
                            * htmlattributevalue

  local htmlcomment         = P("<!--") * (parsers.any - P("-->"))^0 * P("-->")

  local htmlinstruction     = P("<?")   * (parsers.any - P("?>" ))^0 * P("?>" )

  local openelt_any = parsers.less * parsers.keyword * htmlattribute^0
                    * parsers.sp * parsers.more

  local function openelt_exact(s)
    return parsers.less * parsers.sp * keyword_exact(s) * htmlattribute^0
         * parsers.sp * parsers.more
  end

  local openelt_block = parsers.sp * block_keyword * htmlattribute^0
                      * parsers.sp * parsers.more

  local closeelt_any = parsers.less * parsers.sp * parsers.slash
                     * parsers.keyword * parsers.sp * parsers.more

  local function closeelt_exact(s)
    return parsers.less * parsers.sp * parsers.slash * keyword_exact(s)
         * parsers.sp * parsers.more
  end

  local emptyelt_any = parsers.less * parsers.sp * parsers.keyword
                     * htmlattribute^0 * parsers.sp * parsers.slash
                     * parsers.more

  local emptyelt_block = parsers.less * parsers.sp * block_keyword
                       * htmlattribute^0 * parsers.sp * parsers.slash
                       * parsers.more

  local displaytext = (parsers.any - parsers.less)^1

  -- return content between two matched HTML tags
  local function in_matched(s)
    return { openelt_exact(s)
           * (V(1) + displaytext + (parsers.less - closeelt_exact(s)))^0
           * closeelt_exact(s) }
  end

  local function parse_matched_tags(s,pos)
    local t = lower(lpegmatch(C(parsers.keyword),s,pos))
    return lpegmatch(in_matched(t),s,pos-1)
  end

  local in_matched_block_tags = parsers.less * Cmt(#openelt_block, parse_matched_tags)

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

  local hexentity = parsers.ampersand * parsers.hash * S("Xx")
                  * C(parsers.hexdigit^1) * parsers.semicolon
  local decentity = parsers.ampersand * parsers.hash
                  * C(parsers.digit^1) * parsers.semicolon
  local tagentity = parsers.ampersand * C(parsers.alphanumeric^1)
                  * parsers.semicolon

  ------------------------------------------------------------------------------
  -- Inline elements
  ------------------------------------------------------------------------------

  local Inline    = V("Inline")

  local Str       = larsers.normalchar^1 / writer.string

  local Ellipsis  = P("...") / writer.ellipsis

  local Dash      = P("---") * -parsers.dash / writer.mdash
                  + P("--") * -parsers.dash / writer.ndash
                  + P("-") * #parsers.digit * B(parsers.digit*1, 2) / writer.ndash

  local DoubleQuoted = parsers.dquote * Ct((Inline - parsers.dquote)^1)
                     * parsers.dquote / writer.doublequoted

  local squote_start = parsers.squote * -parsers.spacing

  local squote_end = parsers.squote * B(parsers.nonspacechar*1, 2)

  local SingleQuoted = squote_start * Ct((Inline - squote_end)^1) * squote_end
                     / writer.singlequoted

  local Apostrophe = parsers.squote * B(parsers.nonspacechar*1, 2) / "’"

  local Smart      = Ellipsis + Dash + SingleQuoted + DoubleQuoted + Apostrophe

  local Symbol    = (larsers.specialchar - parsers.tightblocksep) / writer.string

  local Code      = parsers.inticks / writer.code

  local bqstart      = parsers.more
  local headerstart  = parsers.hash
                     + (parsers.line * (parsers.equal^1 + parsers.dash^1)
                             * parsers.optionalspace * parsers.newline)
  local fencestart   = parsers.fencehead(parsers.backtick)
                     + parsers.fencehead(parsers.tilde)

  if options.require_blank_before_blockquote then
    bqstart = parsers.fail
  end

  if options.require_blank_before_header then
    headerstart = parsers.fail
  end

  if not options.fenced_code_blocks or
    options.blank_before_fenced_code_blocks then
    fencestart = parsers.fail
  end

  local Endline   = parsers.newline * -( -- newline, but not before...
                        parsers.blankline -- paragraph break
                      + parsers.tightblocksep  -- nested list
                      + parsers.eof       -- end of document
                      + bqstart
                      + headerstart
                      + fencestart
                    ) * parsers.spacechar^0 / writer.space

  local Space     = parsers.spacechar^2 * Endline / writer.linebreak
                  + parsers.spacechar^1 * Endline^-1 * parsers.eof / ""
                  + parsers.spacechar^1 * Endline^-1
                                         * parsers.optionalspace / writer.space

  local NonbreakingEndline
                  = parsers.newline * -( -- newline, but not before...
                        parsers.blankline -- paragraph break
                      + parsers.tightblocksep  -- nested list
                      + parsers.eof       -- end of document
                      + bqstart
                      + headerstart
                      + fencestart
                    ) * parsers.spacechar^0 / writer.nbsp

  local NonbreakingSpace
                  = parsers.spacechar^2 * Endline / writer.linebreak
                  + parsers.spacechar^1 * Endline^-1 * parsers.eof / ""
                  + parsers.spacechar^1 * Endline^-1
                                         * parsers.optionalspace / writer.nbsp

  -- parse many p between starter and ender
  local function between(p, starter, ender)
      local ender2 = B(parsers.nonspacechar) * ender
      return (starter * #parsers.nonspacechar * Ct(p * (p - ender2)^0) * ender2)
  end

  local Strong = ( between(Inline, parsers.doubleasterisks, parsers.doubleasterisks)
                 + between(Inline, parsers.doubleunderscores, parsers.doubleunderscores)
                 ) / writer.strong

  local Emph   = ( between(Inline, parsers.asterisk, parsers.asterisk)
                 + between(Inline, parsers.underscore, parsers.underscore)
                 ) / writer.emphasis

  local urlchar = parsers.anyescaped - parsers.newline - parsers.more

  local AutoLinkUrl   = parsers.less
                      * C(parsers.alphanumeric^1 * P("://") * urlchar^1)
                      * parsers.more
                      / function(url) return writer.link(writer.string(url),url) end

  local AutoLinkEmail = parsers.less
                      * C((parsers.alphanumeric + S("-._+"))^1 * P("@") * urlchar^1)
                      * parsers.more
                      / function(email) return writer.link(writer.string(email),"mailto:"..email) end

  local DirectLink    = (parsers.tag / larsers.parse_inlines_no_link)  -- no links inside links
                      * parsers.spnl
                      * parsers.lparent
                      * (parsers.url + Cc(""))  -- link can be empty [foo]()
                      * parsers.optionaltitle
                      * parsers.rparent
                      / writer.link

  local IndirectLink  = parsers.tag * (C(parsers.spnl) * parsers.tag)^-1
                      / indirect_link

  -- parse a link or image (direct or indirect)
  local Link          = DirectLink + IndirectLink

  local DirectImage   = parsers.exclamation
                      * (parsers.tag / larsers.parse_inlines)
                      * parsers.spnl
                      * parsers.lparent
                      * (parsers.url + Cc(""))  -- link can be empty [foo]()
                      * parsers.optionaltitle
                      * parsers.rparent
                      / writer.image

  local IndirectImage = parsers.exclamation * parsers.tag
                      * (C(parsers.spnl) * parsers.tag)^-1 / indirect_image

  local Image         = DirectImage + IndirectImage

  local TextCitations = Ct(Cc("")
                      * parsers.citation_name
                      * ((parsers.spnl
                           * parsers.lbracket
                           * parsers.citation_headless_body
                           * parsers.rbracket) + Cc(""))) /
                        function(raw_cites)
                            return larsers.citations(true, raw_cites)
                        end

  local ParenthesizedCitations
                      = Ct(parsers.lbracket
                      * parsers.citation_body
                      * parsers.rbracket) /
                        function(raw_cites)
                            return larsers.citations(false, raw_cites)
                        end

  local Citations     = TextCitations + ParenthesizedCitations

  -- avoid parsing long strings of * or _ as emph/strong
  local UlOrStarLine  = parsers.asterisk^4 + parsers.underscore^4 / writer.string

  local EscapedChar   = S("\\") * C(parsers.escapable) / writer.string

  local InlineHtml    = C(inlinehtml) / writer.inline_html

  local HtmlEntity    = hexentity / entities.hex_entity  / writer.string
                      + decentity / entities.dec_entity  / writer.string
                      + tagentity / entities.char_entity / writer.string

  ------------------------------------------------------------------------------
  -- Block elements
  ------------------------------------------------------------------------------

  local Block          = V("Block")

  local DisplayHtml    = C(displayhtml) / expandtabs / writer.display_html

  local Verbatim       = Cs( (parsers.blanklines
                           * ((parsers.indentedline - parsers.blankline))^1)^1
                           ) / expandtabs / writer.verbatim

  local TildeFencedCodeBlock
                       = parsers.fencehead(parsers.tilde)
                       * Cs(parsers.fencedline(parsers.tilde)^0)
                       * parsers.fencetail(parsers.tilde)

  local BacktickFencedCodeBlock
                       = parsers.fencehead(parsers.backtick)
                       * Cs(parsers.fencedline(parsers.backtick)^0)
                       * parsers.fencetail(parsers.backtick)

  local FencedCodeBlock
                       = (TildeFencedCodeBlock + BacktickFencedCodeBlock)
                       / function(infostring, code)
                             return writer.fenced_code(
                                 expandtabs(code),
                                 writer.string(infostring))
                         end

  -- strip off leading > and indents, and run through blocks
  local Blockquote     = Cs((((parsers.leader * parsers.more * parsers.space^-1)/""
                             * parsers.linechar^0 * parsers.newline)^1
                            * (-parsers.blankline * parsers.linechar^1
                            * parsers.newline)^0 * parsers.blankline^0
                           )^1) / larsers.parse_blocks / writer.blockquote

  local function lineof(c)
      return (parsers.leader * (P(c) * parsers.optionalspace)^3
             * parsers.newline * parsers.blankline^1)
  end

  local HorizontalRule = ( lineof(parsers.asterisk)
                         + lineof(parsers.dash)
                         + lineof(parsers.underscore)
                         ) / writer.hrule

  local Reference      = define_reference_parser / register_link

  local Paragraph      = parsers.nonindentspace * Ct(Inline^1) * parsers.newline
                       * ( parsers.blankline^1
                         + #parsers.hash
                         + #(parsers.leader * parsers.more * parsers.space^-1)
                         )
                       / writer.paragraph

  local Plain          = parsers.nonindentspace * Ct(Inline^1) / writer.plain

  ------------------------------------------------------------------------------
  -- Lists
  ------------------------------------------------------------------------------

  local starter = parsers.bullet + larsers.enumerator

  -- we use \001 as a separator between a tight list item and a
  -- nested list under it.
  local NestedList            = Cs((parsers.optionallyindentedline - starter)^1)
                              / function(a) return "\001"..a end

  local ListBlockLine         = parsers.optionallyindentedline
                              - parsers.blankline - (parsers.indent^-1 * starter)

  local ListBlock             = parsers.line * ListBlockLine^0

  local ListContinuationBlock = parsers.blanklines * (parsers.indent / "")
                              * ListBlock

  local function TightListItem(starter)
      return -HorizontalRule
             * (Cs(starter / "" * ListBlock * NestedList^-1) / larsers.parse_blocks)
             * -(parsers.blanklines * parsers.indent)
  end

  local function LooseListItem(starter)
      return -HorizontalRule
             * Cs( starter / "" * ListBlock * Cc("\n")
               * (NestedList + ListContinuationBlock^0)
               * (parsers.blanklines / "\n\n")
               ) / larsers.parse_blocks
  end

  local BulletList = ( Ct(TightListItem(parsers.bullet)^1) * Cc(true)
                                                   * parsers.skipblanklines
                                                   * -parsers.bullet
                     + Ct(LooseListItem(parsers.bullet)^1) * Cc(false)
                                                   * parsers.skipblanklines )
                   / writer.bulletlist

  local function ordered_list(s,tight,startnum)
    if options.startnum then
      startnum = tonumber(startnum) or 1  -- fallback for '#'
    else
      startnum = nil
    end
    return writer.orderedlist(s,tight,startnum)
  end

  local OrderedList = Cg(larsers.enumerator, "listtype") *
                      ( Ct(TightListItem(Cb("listtype"))
                          * TightListItem(larsers.enumerator)^0)
                          * Cc(true) * parsers.skipblanklines * -larsers.enumerator
                      + Ct(LooseListItem(Cb("listtype"))
                          * LooseListItem(larsers.enumerator)^0)
                          * Cc(false) * parsers.skipblanklines
                      ) * Cb("listtype") / ordered_list

  local defstartchar = S("~:")
  local defstart     = ( defstartchar * #parsers.spacing
                                      * (parsers.tab + parsers.space^-3)
                     + parsers.space * defstartchar * #parsers.spacing
                                      * (parsers.tab + parsers.space^-2)
                     + parsers.space * parsers.space * defstartchar
                                      * #parsers.spacing
                                      * (parsers.tab + parsers.space^-1)
                     + parsers.space * parsers.space * parsers.space
                                      * defstartchar * #parsers.spacing
                     )

  local dlchunk = Cs(parsers.line * (parsers.indentedline - parsers.blankline)^0)

  local function definition_list_item(term, defs, tight)
    return { term = larsers.parse_inlines(term), definitions = defs }
  end

  local DefinitionListItemLoose = C(parsers.line) * parsers.skipblanklines
                           * Ct((defstart
                           * parsers.indented_blocks(dlchunk) / larsers.parse_blocks)^1)
                           * Cc(false)
                           / definition_list_item

  local DefinitionListItemTight = C(parsers.line)
                           * Ct((defstart * dlchunk / larsers.parse_blocks)^1)
                           * Cc(true)
                           / definition_list_item

  local DefinitionList =  ( Ct(DefinitionListItemLoose^1) * Cc(false)
                          +  Ct(DefinitionListItemTight^1)
                             * (parsers.skipblanklines * -DefinitionListItemLoose
                                                       * Cc(true))
                          ) / writer.definitionlist

  ------------------------------------------------------------------------------
  -- Lua metadata
  ------------------------------------------------------------------------------

  local function lua_metadata(s)  -- run lua code in comment in sandbox
    local env = { m = larsers.parse_markdown, markdown = larsers.parse_blocks }
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

  local LuaMeta = parsers.fail
  if options.lua_metadata then
    LuaMeta = #P("<!--@") * htmlcomment / lua_metadata
  end

  ------------------------------------------------------------------------------
  -- Pandoc title block parser
  ------------------------------------------------------------------------------

  local pandoc_title = parsers.percent * parsers.optionalspace
                     * C(parsers.line * (parsers.spacechar * parsers.nonemptyline)^0)
                     / larsers.parse_inlines

  local pandoc_author = parsers.spacechar * parsers.optionalspace
                      * C((parsers.anyescaped
                          - parsers.newline
                          - parsers.semicolon)^0)
                      * (parsers.semicolon + parsers.newline)

  local pandoc_authors = parsers.percent * Ct((pandoc_author
                                               / larsers.parse_inlines)^0)
                       * parsers.newline^-1

  local pandoc_date = parsers.percent * parsers.optionalspace
                    * C(parsers.line) / larsers.parse_inlines

  local pandoc_title_block =
      (pandoc_title + Cc(""))
    * (pandoc_authors + Cc({}))
    * (pandoc_date + Cc(""))
    * C(P(1)^0)

  ------------------------------------------------------------------------------
  -- Blank
  ------------------------------------------------------------------------------

  local Blank          = parsers.blankline / ""
                       + LuaMeta
                       + larsers.NoteBlock
                       + Reference
                       + (parsers.tightblocksep / "\n")

  ------------------------------------------------------------------------------
  -- Headers
  ------------------------------------------------------------------------------

  -- parse Atx heading start and return level
  local HeadingStart = #parsers.hash * C(parsers.hash^-6)
                     * -parsers.hash / length

  -- parse setext header ending and return level
  local HeadingLevel = parsers.equal^1 * Cc(1) + parsers.dash^1 * Cc(2)

  local function strip_atx_end(s)
    return s:gsub("[#%s]*\n$","")
  end

  -- parse atx header
  local AtxHeader = Cg(HeadingStart,"level")
                     * parsers.optionalspace
                     * (C(parsers.line) / strip_atx_end / larsers.parse_inlines)
                     * Cb("level")
                     / writer.header

  -- parse setext header
  local SetextHeader = #(parsers.line * S("=-"))
                     * Ct(parsers.line / larsers.parse_inlines)
                     * HeadingLevel
                     * parsers.optionalspace * parsers.newline
                     / writer.header

  ------------------------------------------------------------------------------
  -- Syntax specification
  ------------------------------------------------------------------------------

  larsers.syntax =
    { "Blocks",

      Blocks                = Blank^0 * Block^-1
                            * (Blank^0 / function() return writer.interblocksep end
                                       * Block)^0
                            * Blank^0 * parsers.eof,

      Blank                 = Blank,

      Block                 = V("Blockquote")
                            + V("Verbatim")
                            + V("FencedCodeBlock")
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
      FencedCodeBlock       = FencedCodeBlock,
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
                            + V("InlineNote")
                            + V("NoteRef")
                            + V("Citations")
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
      InlineNote            = larsers.InlineNote,
      NoteRef               = larsers.NoteRef,
      Citations             = Citations,
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
    larsers.syntax.DefinitionList = parsers.fail
  end

  if not options.fenced_code_blocks then
    larsers.syntax.FencedCodeBlock = parsers.fail
  end

  if not options.citations then
    larsers.syntax.Citations = parsers.fail
  end

  if not options.notes then
    larsers.syntax.NoteRef = parsers.fail
  end

  if not options.inline_notes then
    larsers.syntax.InlineNote = parsers.fail
  end

  if not options.smart then
    larsers.syntax.Smart = parsers.fail
  end

  if options.alter_syntax and type(options.alter_syntax) == "function" then
    larsers.syntax = options.alter_syntax(larsers.syntax)
  end

  larsers.blocks = Ct(larsers.syntax)

  local inlines_t = util.table_copy(larsers.syntax)
  inlines_t[1] = "Inlines"
  inlines_t.Inlines = Inline^0 * (parsers.spacing^0 * parsers.eof / "")
  larsers.inlines = Ct(inlines_t)

  local inlines_no_link_t = util.table_copy(inlines_t)
  inlines_no_link_t.Link = parsers.fail
  larsers.inlines_no_link = Ct(inlines_no_link_t)

  local inlines_no_inline_note_t = util.table_copy(inlines_t)
  inlines_no_inline_note_t.InlineNote = parsers.fail
  larsers.inlines_no_inline_note = Ct(inlines_no_inline_note_t)

  local inlines_nbsp_t = util.table_copy(inlines_t)
  inlines_nbsp_t.Endline = NonbreakingEndline
  inlines_nbsp_t.Space = NonbreakingSpace
  larsers.inlines_nbsp = Ct(inlines_nbsp_t)

  ------------------------------------------------------------------------------
  -- Exported conversion function
  ------------------------------------------------------------------------------

  -- inp is a string; line endings are assumed to be LF (unix-style)
  -- and tabs are assumed to be expanded.
  larsers.parse_markdown =
    function(inp)
      references = options.references or {}
      if options.pandoc_title_blocks then
        local title, authors, date, rest = lpegmatch(pandoc_title_block, inp)
        writer.set_metadata("title",title)
        writer.set_metadata("author",authors)
        writer.set_metadata("date",date)
        inp = rest
      end
      local result = { writer.start_document(), larsers.parse_blocks(inp), writer.stop_document() }
      return rope_to_string(result), writer.get_metadata()
    end

  return larsers.parse_markdown
end

return M
