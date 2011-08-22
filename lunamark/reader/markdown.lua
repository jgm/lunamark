--[[
Copyright (C) 2009-2011 John MacFarlane / Khaled Hosny / Hans Hagen

This is a complete rewrite of the lunamark 0.1 parser.  Hans Hagen
helped a lot to make the parser faster, more robust, and less stack-hungry.
The parser is also more accurate than before.

]]--

local lpeg = require("lpeg")
local entities = require("lunamark.entities")
local lower, upper, gsub, rep, gmatch, format, length =
  string.lower, string.upper, string.gsub, string.rep, string.gmatch,
  string.format, string.len
local concat = table.concat
local P, R, S, V, C, Ct, Cg, Cb, Cmt, Cc, Cf, Cs =
  lpeg.P, lpeg.R, lpeg.S, lpeg.V, lpeg.C, lpeg.Ct, lpeg.Cg, lpeg.Cb,
  lpeg.Cmt, lpeg.Cc, lpeg.Cf, lpeg.Cs
local lpegmatch = lpeg.match

local function markdown(writer, options)

  if not options then options = {} end

  ------------------------------------------------------------------------------

  local syntax
  local docsyntax
  local inlinessyntax
  local docparser
  local inlinesparser

  docparser =
    function(str)
      local res = lpegmatch(docsyntax, str)
      if res == nil
        then error(format("docparser failed on:\n%s", str:sub(1,20)))
        else return res
        end
    end

  inlinesparser =
    function(str)
      local res = lpegmatch(inlinessyntax, str)
      if res == nil
        then error(format("inlinesparser failed on:\n%s", str:sub(1,20)))
        else return res
        end
    end

  ------------------------------------------------------------------------------
  -- Generic parsers
  ------------------------------------------------------------------------------

  local asterisk               = P("*")
  local dash                   = P("-")
  local plus                   = P("+")
  local underscore             = P("_")
  local period                 = P(".")
  local hash                   = P("#")
  local ampersand              = P("&")
  local backtick               = P("`")
  local less                   = P("<")
  local more                   = P(">")
  local space                  = P(" ")
  local squote                 = P("'")
  local dquote                 = P('"')
  local lparent                = P("(")
  local rparent                = P(")")
  local lbracket               = P("[")
  local rbracket               = P("]")
  local slash                  = P("/")
  local equal                  = P("=")
  local colon                  = P(":")
  local semicolon              = P(";")
  local exclamation            = P("!")

  local digit                  = R("09")
  local hexdigit               = R("09","af","AF")
  local letter                 = R("AZ","az")
  local alphanumeric           = R("AZ","az","09")
  local keyword                = letter * alphanumeric^0

  local doubleasterisks        = P("**")
  local doubleunderscores      = P("__")
  local fourspaces             = P("    ")

  local any                    = P(1)
  local always                 = P("")

  local escapable              = S("\\`*_{}[]()+_.!<>#-")
  local anyescaped             = P("\\") / "" * escapable
                               + any

  local tab                    = P("\t")
  local spacechar              = S("\t ")
  local spacing                = S(" \n\r\t")
  local newline                = P("\n")
  local spaceornewline         = spacechar + newline
  local nonspacechar           = any - spaceornewline
  local blocksep               = P("\001")
  local specialchar            = S("*_`&[]<!\\")
  local normalchar             = any - (specialchar + spaceornewline + blocksep)
  local optionalspace          = spacechar^0
  local spaces                 = spacechar^1
  local eof                    = - any
  local nonindentspace         = space^-3 * - spacechar
  local indent                 = fourspaces + (nonindentspace * tab) / ""
  local linechar               = P(1 - newline)

  local blankline              = optionalspace * newline / "\n"
  local blanklines             = blankline^0
  local skipblanklines         = (optionalspace * newline)^0
  local indentedline           = indent    /"" * C(linechar^1 * (newline + eof))
  local optionallyindentedline = indent^-1 /"" * C(linechar^1 * (newline + eof))
  local spnl                   = optionalspace * (newline * optionalspace)^-1
  local line                   = (any - newline)^0 * newline
                               + (any - newline)^1 * eof
  local nonemptyline           = line - blankline

  -- parser succeeds if condition evaluates to true
  local function guard(condition)
    return Cmt(P(0), function(s,pos) return condition and pos end) end

  -----------------------------------------------------------------------------
  -- Parsers used for markdown lists
  -----------------------------------------------------------------------------

  -- gobble spaces to make the whole bullet or enumerator four spaces wide:
  local function gobbletofour(s,pos,c)
      if length(c) >= 3
         then return lpegmatch(space^-1,s,pos)
      elseif length(c) == 2
         then return lpegmatch(space^-2,s,pos)
      else return lpegmatch(space^-3,s,pos)
      end
  end

  local bulletchar = plus + asterisk + dash

  local bullet     = ( bulletchar * #spacing * space^-3
                     + space * bulletchar * #spacing * space^-2
                     + space * space * bulletchar * #spacing * space^-1
                     + space * space * space * bulletchar * #spacing
                     ) * -bulletchar

  local enumerator = digit^3 * period * #spacing
                   + digit^2 * period * #spacing * space^1
                   + digit * period * #spacing * space^-2
                   + space * digit^2 * period * #spacing
                   + space * digit * period * #spacing * space^-1
                   + space * space * digit^1 * period * #spacing

  -----------------------------------------------------------------------------
  -- Parsers used for markdown code spans
  -----------------------------------------------------------------------------

  local openticks   = Cg(backtick^1, "ticks")

  local closeticks  = space^-1 *
                      Cmt(C(backtick^1) * Cb("ticks"),
                          function(s,i,a,b)
                            return #a == #b and i
                          end)

  local intickschar = (any - S(" \n\r`"))
                    + (newline * -blankline)
                    + (space - closeticks)
                    + (backtick^1 - closeticks)

  local inticks     = openticks * space^-1 * C(intickschar^1) * closeticks

  -----------------------------------------------------------------------------
  -- Parsers used for markdown tags and links
  -----------------------------------------------------------------------------

  local leader        = space^-3

  -- in balanced brackets, parentheses, quotes:
  local bracketed     = P{ lbracket
                         * ((anyescaped - (lbracket + rbracket)) + V(1))^0
                         * rbracket }

  local inparens      = P{ lparent
                         * ((anyescaped - (lparent + rparent)) + V(1))^0
                         * rparent }

  local squoted       = P{ squote * alphanumeric
                         * ((anyescaped-squote) + V(1))^0
                         * squote }

  local dquoted       = P{ dquote * alphanumeric
                         * ((anyescaped-dquote) + V(1))^0
                         * dquote }

  -- bracketed 'tag' for markdown links, allowing nested brackets:
  local tag           = lbracket
                      * Cs((alphanumeric^1
                           + bracketed
                           + inticks
                           + (anyescaped-rbracket))^0)
                      * rbracket

  -- url for markdown links, allowing balanced parentheses:
  local url           = less * Cs((anyescaped-more)^0) * more
                      + Cs((inparens + (anyescaped-spacing-rparent))^1)

  -- quoted text possibly with nested quotes:
  local title_s       = squote  * Cs(((anyescaped-squote) + squoted)^0) * squote

  local title_d       = dquote  * Cs(((anyescaped-dquote) + dquoted)^0) * dquote

  local title_p       = lparent
                      * Cs((inparens + (anyescaped-rparent))^0)
                      * rparent

  local title         = title_d + title_s + title_p

  local optionaltitle = spnl^-1 * title * spacechar^0
                      + Cc("")

  ------------------------------------------------------------------------------
  -- Helpers for links and references
  ------------------------------------------------------------------------------

  -- List of references defined in the document
  local references = {}

  -- markdown reference tags are case-insensitive
  local function normalize_tag(tag)
      return lower(gsub(tag, "[ \n\r\t]+", " "))
  end

  -- add a reference to the list
  local function register_link(tag,url,title)
      references[normalize_tag(tag)] = { url = url, title = title }
  end

  -- parse a reference definition:  [foo]: /bar "title"
  local define_reference_parser =
    leader * tag * colon * spacechar^0 * url * optionaltitle * blankline^0

  local referenceparser =
    -- need the Ct or we get a stack overflow
    Ct((define_reference_parser / register_link + nonemptyline^1 + blankline^1)^0)

  -- lookup link reference and return either a link or image.
  -- if the reference is not found, return the bracketed label.
  local function indirect_link(img,label,sps,tag)
      local tagpart
      if not tag then
          tag = label
          tagpart = ""
      elseif tag == "" then
          tag = label
          tagpart = "[]"
      else
          tagpart = "[" .. inlinesparser(tag) .. "]"
      end
      if sps then
        tagpart = sps .. tagpart
      end
      local r = references[normalize_tag(tag)]
      if r and img then
        return writer.image(inlinesparser(label), r.url, r.title)
      elseif r and not img then
        return writer.link(inlinesparser(label), r.url, r.title)
      else
        return ("[" .. inlinesparser(label) .. "]" .. tagpart)
      end
  end

  local function direct_link(img,label,url,title)
    if img then
      return writer.image(label,url,title)
    else
      return writer.link(label,url,title)
    end
  end

  -- parse an exclamation mark and return true, or return false
  local image_marker = (exclamation / function() return true end) + Cc(false)

  ------------------------------------------------------------------------------
  -- HTML
  ------------------------------------------------------------------------------

  -- case-insensitive match
  local function keyword_exact(s)
    local parser = P(0)
    s = lower(s)
    for i=1,#s do
      local c = s:sub(i,i)
      local m = c .. upper(c)
      parser = parser * S(m)
    end
    return parser
  end

  local block_keyword =
      keyword_exact("address") + keyword_exact("blockquote") +
      keyword_exact("center") + keyword_exact("dir") + keyword_exact("div") +
      keyword_exact("p") + keyword_exact("pre") + keyword_exact("li") +
      keyword_exact("ol") + keyword_exact("ul") + keyword_exact("dl") +
      keyword_exact("dd") + keyword_exact("form") + keyword_exact("fieldset") +
      keyword_exact("isindex") + keyword_exact("menu") + keyword_exact("noframes") +
      keyword_exact("frameset") + keyword_exact("h1") + keyword_exact("h2") +
      keyword_exact("h3") + keyword_exact("h4") + keyword_exact("h5") +
      keyword_exact("h6") + keyword_exact("hr") + keyword_exact("script") +
      keyword_exact("noscript") + keyword_exact("table") + keyword_exact("tbody") +
      keyword_exact(  "tfoot") + keyword_exact("thead") + keyword_exact("th") +
      keyword_exact("td") + keyword_exact("tr")

  -- There is no reason to support bad html, so we expect quoted attributes
  local htmlattributevalue  = squote * (any - (blankline + squote))^0 * squote
                            + dquote * (any - (blankline + dquote))^0 * dquote

  local htmlattribute       = (alphanumeric + S("_-"))^1 * spnl * equal
                            * spnl * htmlattributevalue * spnl

  local htmlcomment         = P("<!--") * (any - P("-->"))^0 * P("-->")

  local htmlinstruction     = P("<?")   * (any - P("?>" ))^0 * P("?>" )

  local openelt_any = less * keyword * spnl * htmlattribute^0 * more

  local function openelt_exact(s)
    return (less * keyword_exact(s) * spnl * htmlattribute^0 * more)
  end

  local openelt_block = less * block_keyword * spnl * htmlattribute^0 * more

  local closeelt_any = less * slash * keyword * spnl * more

  local function closeelt_exact(s)
    return (less * slash * keyword_exact(s) * spnl * more)
  end

  local closeelt_block = less * slash * block_keyword * spnl * more

  local emptyelt_any = less * keyword * spnl * htmlattribute^0 * slash * more

  local function emptyelt_exact(s)
    return (less * keyword_exact(s) * spnl * htmlattribute^0 * slash * more)
  end

  local emptyelt_block = less * block_keyword * spnl * htmlattribute^0 * slash * more

  local displaytext         = (any - less)^1

  -- return content between two matched HTML tags that match t
  local function in_matched(s)
    return { openelt_exact(s)
           * (V(1) + displaytext + (less - closeelt_exact(s)))^0
           * closeelt_exact(s) }
  end

  local displayhtml = htmlcomment
                    + emptyelt_block
                    + openelt_exact("hr")
                    + Cmt(#openelt_block,
                      function(s,pos)
                        local t = lpegmatch(less * C(keyword),s,pos)
                        return lpegmatch(in_matched(t),s,pos)
                      end)
                    + htmlinstruction

  local inlinehtml  = emptyelt_any
                    + htmlcomment
                    + htmlinstruction
                    + openelt_any
                    + closeelt_any

  ------------------------------------------------------------------------------
  -- Entities
  ------------------------------------------------------------------------------

  local hexentity = ampersand * hash * S("Xx") * C(hexdigit    ^1) * semicolon
  local decentity = ampersand * hash           * C(digit       ^1) * semicolon
  local tagentity = ampersand *                  C(alphanumeric^1) * semicolon

  ------------------------------------------------------------------------------
  -- Inline elements
  ------------------------------------------------------------------------------

  local Inline    = V("Inline")

  local Str       = normalchar^1 / writer.string

  local Symbol    = (specialchar - blocksep) / writer.string

  local Code      = inticks / writer.code

  local Endline   = newline * -( -- newline, but not before...
                        blankline -- paragraph break
                      + blocksep  -- nested list
                      + eof       -- end of document
                      + more      -- blockquote
                      + hash      -- atx header
                      + ( line * (equal^1 + dash^1)
                        * optionalspace * newline )  -- setext header
                    ) / writer.space

  local Space     = spacechar^2 * Endline / writer.linebreak
                  + spacechar^1 * Endline^-1 * eof / ""
                  + spacechar^1 * Endline^-1 * optionalspace / writer.space

  -- parse many p between starter and ender
  local function between(p, starter, ender)
      local ender2 = lpeg.B(nonspacechar) * ender
      return (starter * #nonspacechar * Cs(p * (p - ender2)^0) * ender2)
  end

  local Strong = ( between(Inline, doubleasterisks, doubleasterisks)
                 + between(Inline, doubleunderscores, doubleunderscores)
                 ) / writer.strong

  local Emph   = ( between(Inline, asterisk, asterisk)
                 + between(Inline, underscore, underscore)
                 ) / writer.emphasis

  local urlchar = anyescaped - newline - more

  local AutoLinkUrl   = less
                      * C(alphanumeric^1 * P("://") * urlchar^1)
                      * more
                      / function(url) return writer.link(url,url) end

  local AutoLinkEmail = less
                      * C((alphanumeric + S("-._+"))^1 * P("@") * urlchar^1)
                      * more
                      / function(email) return writer.link(email,"mailto:"..email) end

  local DirectLink    = image_marker 
                      * (tag / inlinesparser)
                      * spnl^-1
                      * lparent
                      * (url + Cc(""))  -- link can be empty [foo]()
                      * optionaltitle
                      * rparent
                      / direct_link

   local IndirectLink = image_marker
                      * tag
                      * (C(spnl^-1) * tag)^-1
                      / indirect_link

  -- parse a link or image (direct or indirect)
  local Link          = DirectLink + IndirectLink

  -- avoid parsing long strings of * or _ as emph/strong
  local UlOrStarLine  = asterisk^4 + underscore^4 / writer.string

  local EscapedChar   = S("\\") * C(escapable) / writer.string

  local InlineHtml    = C(inlinehtml) / writer.inline_html

  local HtmlEntity    = hexentity / entities.hex_entity  / writer.string
                      + decentity / entities.dec_entity  / writer.string
                      + tagentity / entities.char_entity / writer.string

  ------------------------------------------------------------------------------
  -- Block elements
  ------------------------------------------------------------------------------

  local Block          = V("Block")

  local DisplayHtml    = C(displayhtml) / writer.display_html

  local Verbatim       = Cs((blanklines * (indentedline - blankline)^1)^1)
                       / writer.verbatim

  -- strip off leading > and indents, and run through docparser
  local Blockquote     = Cs((
            ((nonindentspace * more * space^-1)/"" * linechar^0 * newline)^1
          * ((linechar - blankline)^1 * newline)^0
          * blankline^0
          )^1) / docparser / writer.blockquote

  local function lineof(c)
      return (nonindentspace * (P(c) * optionalspace)^3 * newline * blankline^1)
  end

  local HorizontalRule = ( lineof(asterisk)
                         + lineof(dash)
                         + lineof(underscore)
                         ) / writer.hrule

  local Reference      = define_reference_parser / ""

  local Paragraph      = nonindentspace * Cs(Inline^1) * newline * blankline^1
                       / writer.paragraph

  local Plain          = Cs(Inline^1) / writer.plain

  ------------------------------------------------------------------------------
  -- Lists
  ------------------------------------------------------------------------------

  local starter = bullet + enumerator

  -- we use \001 as a blocksep between a tight list item and a
  -- nested list under it.
  local NestedList            = Cs((optionallyindentedline - starter)^1)
                              / function(a) return "\001"..a end

  local ListBlockLine         = optionallyindentedline
                                - blankline - (indent^-1 * starter)

  local ListBlock             = line * ListBlockLine^0

  local ListContinuationBlock = blanklines * (indent / "") * ListBlock

  local function TightListItem(starter)
      return (starter * Cs(ListBlock * NestedList^-1)
              * -(blanklines * indent) / docparser / writer.listitem)
  end

  local function LooseListItem(starter)
      return (starter * Cs(ListBlock * Cc("\n")
             * (NestedList + ListContinuationBlock^0)
             * (blanklines / "\n\n")) / docparser / writer.listitem)
  end

  local BulletList = bullet *
                     ( Cs(TightListItem(P(0)) * TightListItem(bullet)^0)
                       * Cc(true) * skipblanklines * -bullet
                     + Cs(LooseListItem(P(0)) * LooseListItem(bullet)^0)
                       * Cc(false) * skipblanklines ) / writer.bulletlist

  local OrderedList = Cg(enumerator / tonumber, "startnum") *
                      ( Cs(TightListItem(P(0)) * TightListItem(enumerator)^0)
                        * Cc(true) * skipblanklines * -enumerator
                      + Cs(LooseListItem(P(0)) * LooseListItem(enumerator)^0)
                        * Cc(false) * skipblanklines
                      ) * Cb("startnum") / writer.orderedlist

  ------------------------------------------------------------------------------
  -- Headers
  ------------------------------------------------------------------------------

  -- parse Atx heading start and return level
  local function HeadingStart(maxlev)
    return (#hash * C(hash^-(maxlev)) * -hash / length)
  end

  -- optional end of Atx header ### header ###
  local HeadingStop = optionalspace * hash^0 * optionalspace * newline

  -- parse setext header ending of max level maxlev and return level
  local function HeadingLevel(maxlev)
    if maxlev == 1 then
      return (equal^1 * Cc(1))
    elseif maxlev == 2 then
      return (equal^1 * Cc(1) + dash^1 * Cc(2))
    else
      error("Illegal level for setext heading")
    end
  end

  -- parse atx header of maximum level maxlev
  local function AtxHeader(maxlev)
    return ( Cg(HeadingStart(maxlev),"level")
           * optionalspace
           * Cs((Inline - HeadingStop)^1)
           * Cb("level")
           * HeadingStop )
  end

  -- parse setext header of maximum level maxlev
  local function SetextHeader(maxlev)
    local markers
    if maxlev == 1 then markers = "=" else markers = "=-" end
    return (#(line * S(markers)) * Cs(line / inlinesparser)
            * HeadingLevel(maxlev) *  optionalspace * newline)
  end

  -- parse a heading of level maxlev or lower
  local function Header(maxlev)
    if maxlev <= 2 then
      return (AtxHeader(maxlev) + SetextHeader(maxlev))
    else
      return AtxHeader(maxlev)
    end
  end

  local function SectionMax(maxlev)
     return (Header(maxlev) * Cs((Block - Header(maxlev))^0) / writer.section)
  end

  local Section = SectionMax(1) + SectionMax(2) + SectionMax(3) +
                  SectionMax(4) + SectionMax(5) + SectionMax(6)

  ------------------------------------------------------------------------------
  -- Syntax specification
  ------------------------------------------------------------------------------

  syntax =
    { "Document",

      Document              = Block^0,

      Block                 = blankline^1 / ""
                            + blocksep / "\n"
                            + Blockquote
                            + Verbatim
                            + HorizontalRule
                            + BulletList
                            + OrderedList
                            + Section
                            + DisplayHtml
                            + Reference
                            + Paragraph
                            + Plain,

      Inline                = Str
                            + Space
                            + Endline
                            + UlOrStarLine
                            + Strong
                            + Emph
                            + Link
                            + Code
                            + AutoLinkUrl
                            + AutoLinkEmail
                            + InlineHtml
                            + HtmlEntity
                            + EscapedChar
                            + Symbol,
    }

  docsyntax = Cs(syntax)

  inlinessyntax = Cs({ "Inlines",
                       Inlines = Inline^0,
                       Inline = syntax.Inline })

  ------------------------------------------------------------------------------
  -- Exported conversion function
  ------------------------------------------------------------------------------

  -- inp is a string; line endings are assumed to be LF (unix-style)
  -- and tabs are assumed to be expanded.
  local function convert(inp)
      references = {}
      lpegmatch(referenceparser,inp)
      local result = writer.start_document() .. docparser(inp)
                       .. writer.stop_document()
      return result
  end

  return convert

end

return markdown
