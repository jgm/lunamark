#!/usr/bin/env lua

--[[
Copyright (C) 2009-2011 John MacFarlane / Khaled Hosny / Hans Hagen

This is a complete rewrite of the lunamark 0.1 parser.  Hans Hagen
helped a lot to make the parser faster, more robust, and less stack-hungry.
The parser is also more accurate than before.

]]--

-- local prof = require("profiler")

local myname = ...

local M = {}

-- apply a function to chunks from a string separated by a pattern
-- based on split from http://lua-users.org/wiki/SplitJoin
-- Compatibility: Lua-5.1
local function dochunks(str, pat, f)
   local fpat = "(.-)" .. pat
   local last_end = 1
   local s, e, cap = str:find(fpat, 1)
   while s do
      if s ~= 1 or cap ~= "" then
        f(cap)
      end
      last_end = e+1
      s, e, cap = str:find(fpat, last_end)
   end
   if last_end <= #str then
      cap = str:sub(last_end)
      f(cap)
   end
end


function M.read_markdown(writer, options)

  if not options then options = {} end

  ------------------------------------------------------------------------------

  local lpeg = require("lpeg")
  local lower, upper, gsub, rep, gmatch, format, length =
    string.lower, string.upper, string.gsub, string.rep, string.gmatch,
    string.format, string.len
  local concat = table.concat
  local P, R, S, V, C, Ct, Cg, Cb, Cmt, Cc, Cf, Cs =
    lpeg.P, lpeg.R, lpeg.S, lpeg.V, lpeg.C, lpeg.Ct, lpeg.Cg, lpeg.Cb,
    lpeg.Cmt, lpeg.Cc, lpeg.Cf, lpeg.Cs
  local lpegmatch = lpeg.match

  ------------------------------------------------------------------------------

  local function if_option(opt)
    return Cmt(P(0), function(s,pos) if options[opt] then return pos else return false end end)
  end

  local function unless_option(opt)
    return Cmt(P(0), function(s,pos) if options[opt] then return false else return pos end end)
  end

  local function diagnostic(x)
    print(format("|%s|",x))
    return x
  end

  ------------------------------------------------------------------------------

  local nestedparser
  local syntax

  nestedparser =
    function(str)
      local res = lpegmatch(Cs(syntax),str)
      if res == nil
        then error(format("nestedparser failed on:\n%s", str:sub(1,20)))
        else return res
        end
    end

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
  local kw                     = letter * alphanumeric^0

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
  local specialchar            = S("*_`*&[]<!\\")
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
  local nonemptyline           = (any - newline)^1 * newline
                               + (any - newline)^1 * eof

  ------------------------------------------------------------------------------

  local function lineof(c)
      return (nonindentspace * (P(c) * optionalspace)^3 * newline * blankline^1)
  end

  local lineof_asterisks       = lineof(asterisk)
  local lineof_dashes          = lineof(dash)
  local lineof_underscores     = lineof(underscore)

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
  local bullet  =  ( bulletchar * #spacing * space^-3
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

  ------------------------------------------------------------------------------

  local openticks              = Cg(backtick^1, "ticks")
  local closeticks             = space^-1 * Cmt(C(backtick^1) * Cb("ticks"), function(s,i,a,b) return #a == #b and i end)
  local intickschar            = (any - S(" \n\r`"))
                               + (newline * -blankline)
                               + (space - closeticks)
                               + (backtick^1 - closeticks)
  local inticks                = openticks * space^-1 * C(intickschar^1) * closeticks

  ------------------------------------------------------------------------------

  local leader        = space^-3
  local bracketed     = P{ lbracket * ((anyescaped - (lbracket + rbracket)) + V(1))^0 * rbracket }
  local inparens      = P{ lparent * ((anyescaped - (lparent + rparent)) + V(1))^0 * rparent }
  local squoted       = P{ squote * alphanumeric * ((anyescaped-squote) + V(1))^0 * squote }
  local dquoted       = P{ dquote * alphanumeric * ((anyescaped-dquote) + V(1))^0 * dquote }

  local tag           = lbracket * Cs((alphanumeric^1 + bracketed + inticks + (anyescaped-rbracket))^0) * rbracket
  local url           = less * Cs((anyescaped-more)^0) * more
                      + Cs((inparens + (anyescaped-spacing-rparent))^1)
  local title_s       = squote  * Cs(((anyescaped-squote) + squoted)^0) * squote
  local title_d       = dquote  * Cs(((anyescaped-dquote) + dquoted)^0) * dquote
  local title_p       = lparent * Cs((inparens + (anyescaped-rparent))^0) * rparent
  local title         = title_s + title_d + title_p
  local optionaltitle = (spnl^-1 * title * spacechar^0) + Cc("")

  ------------------------------------------------------------------------------
  -- References
  ------------------------------------------------------------------------------

  local refs = {}
  local references = {}

  local function normalize_tag(tag)
      return lower(gsub(tag, "[ \n\r\t]+", " "))
  end

  local function register_link(tag,url,title)
      local ref = normalize_tag(tag)
      -- references[ref] = { url = url, title = title }
      -- Don't insert by key here, it builds up the stack for some reason
      table.insert(refs, { tag = tag, url = url, title = title })
  end

  local define_reference_parser = (leader * tag * colon * spacechar^0 * url * optionaltitle * blankline^0) / register_link

  -- local rparser = (define_reference_parser + nonemptyline^1 + blankline^1)^0
  -- We can simplify since we know we're breaking into chunks:
  local rparser = define_reference_parser^0

  local function referenceparser(str)
      -- we process in chunks to avoid stack buildup:
      dochunks(str, "\n[\n \t]*\n", function(x) lpegmatch(rparser,x) end)
      for _,v in ipairs(refs) do
        references[v.tag] = { url = v.url, title = v.title}
      end
  end

  ------

  local function indirect_link(_,pos,label,tag)
      if not tag or tag == "" then
          tag = label
      end
      local r = references[normalize_tag(tag)]
      if r then
          return pos, label, r.url, r.title
      else
          return false
      end
  end

  local link_parser             = Cg(tag,"label") *
                                  ( Cb("label") / nestedparser * spnl^-1 * lparent * (url + Cc("")) * optionaltitle * rparent
                                  + Cmt(Cb("label") / nestedparser  * spnl^-1 * tag, indirect_link)
                                  + Cmt(Cb("label") / nestedparser * Cb("label"), indirect_link) )

  ------------------------------------------------------------------------------
  -- HTML
  ------------------------------------------------------------------------------

  local function isblocktag(s)
      local x = lower(s)
      return (x == "address" or x == "blockquote"  or x == "center" or
              x == "dir" or x == "div" or x == "p" or x == "pre" or
              x == "li" or x == "ol" or x == "ul" or x == "dl" or
              x == "dd" or x == "form" or x == "fieldset" or
              x == "isindex" or x == "menu" or x == "noframes" or
              x == "frameset" or x == "h1" or x == "h2" or x == "h3" or
              x == "h4" or x == "h5" or x == "h6" or x == "hr" or
              x == "ht" or x == "script" or x == "noscript" or
              x == "table" or x == "tbody" or x == "tfoot" or
              x == "thead" or x == "th" or x == "td" or x == "tr")
  end

  -- case insensitive string (from http://lua-users.org/lists/lua-l/2010-11/msg01120.html)
  function kw_pattern(keyword)
    return Cmt(P(#kw), function (str,pos)
          return (keyword == str:sub(pos-#keyword,pos-1):lower())
        end)
  end

  local function kw_matches(f)
    return (Cmt(kw / lower,
      function(s,pos,c)
        if f(c) then return pos
        else return false
        end
      end))
  end

  local isany = function(c) return true end
  local function is(c)
    return function(x) return x == c end
  end

  -- There is no reason to support bad html, so we expect quoted attributes
  local htmlattributevalue     = squote * (any - (blankline + squote))^0 * squote
                               + dquote * (any - (blankline + dquote))^0 * dquote

  local htmlattribute          = (alphanumeric + S("_-"))^1 * spnl * equal * spnl * htmlattributevalue * spnl

  local htmlcomment            = P("<!--") * (any - P("-->"))^0 * P("-->")

  local htmlinstruction        = P("<?")   * (any - P("?>" ))^0 * P("?>" )

  local function openelt(f)
    return (less * kw_matches(f) * spnl * htmlattribute^0 * more)
  end

  local function closeelt(f)
    return (less * slash * kw_matches(f) * spnl * more)
  end

  local function emptyelt(f)
    return (less * kw_matches(f) * spnl * htmlattribute^0 * slash * more)
  end

  local displaytext            = (any - less)^1

  local function in_matched(t)
    local p = { openelt(is(t)) * (V(1) + displaytext + (less - closeelt(is(t))))^0 * closeelt(is(t)) }
    return p
  end

  local displayhtml = htmlcomment + htmlinstruction + emptyelt(isblocktag) + openelt(is("hr")) +
                         Cmt(#(openelt(isblocktag)), function(s,pos) local t = lpegmatch(C(less * kw),s,pos) ; t = t:sub(2); return lpegmatch(in_matched(t),s,pos) end)

  local inlinehtml             = emptyelt(isany) + htmlcomment + htmlinstruction + openelt(isany) + closeelt(isany)

  local hexentity = ampersand * hash * S("Xx") * C(hexdigit    ^1) * semicolon
  local decentity = ampersand * hash           * C(digit       ^1) * semicolon
  local tagentity = ampersand *                  C(alphanumeric^1) * semicolon

  ------------------------------------------------------------------------------

  local Str              = normalchar^1 / writer.string

  local Symbol           = (specialchar - blocksep) / writer.string
  local Code             = inticks      / writer.code

  local HeadingStart     = C(hash * hash^-5) / length
  local HeadingStop      = optionalspace * hash^0 * optionalspace * newline
  local HeadingLevel     = equal^1 * Cc(1)
                         + dash ^1 * Cc(2)

  local Endline          = newline * -(
                               blankline
                             + blocksep
                             + eof
                             + more
                             + HeadingStart
                             + ( line * (P("===")^3 + P("---")^3) * newline )
                           ) / writer.space

  local Space            = spacechar / "" *
                         ( spacechar^1 * Endline / writer.linebreak
                         + spacechar^0 * Endline^-1 * eof / ""
                         + spacechar^0 * Endline^-1 * optionalspace / writer.space
                         )

  local function between(p, starter, ender)
      local ender2 = lpeg.B(nonspacechar) * ender
      return (starter * #nonspacechar * Cs(p * (p - ender2)^0) * ender2)
  end

  local Strong = ( between(V("Inline"), doubleasterisks, doubleasterisks)
                 + between(V("Inline"), doubleunderscores, doubleunderscores) ) / writer.strong

  local Emph   = ( between(V("Inline"), asterisk, asterisk)
                 + between(V("Inline"), underscore, underscore)) / writer.emphasis

  local AutoLinkUrl      = less * C(alphanumeric^1 * P("://") * (anyescaped - (newline + more))^1)       * more / writer.url_link

  local AutoLinkEmail    = less * C((alphanumeric + S("-._+"))^1 * P("@") * (anyescaped - (newline + more))^1) * more / writer.email_link

  local Link             = link_parser / writer.link

  local Image            = exclamation * link_parser / writer.image

  local UlOrStarLine     = asterisk^4
                         + underscore^4
                         + (spaces * S("*_")^1 * #spaces) / writer.string

  local EscapedChar      = S("\\") * C(escapable) / writer.string

  local InlineHtml       = C(inlinehtml)  / writer.inline_html
  local DisplayHtml      = C(displayhtml) / writer.display_html
  local HtmlEntity       = hexentity / writer.hex_entity
                         + decentity / writer.dec_entity
                         + tagentity / writer.tag_entity

  local Verbatim         = Cs((blanklines * (indentedline - blankline)^1)^1)  / writer.verbatim

  local Blockquote       = Cs((
                              ((nonindentspace * more * space^-1)/"" * linechar^0 * newline)^1
                            * ((linechar - blankline)^1 * newline)^0
                            * blankline^0
                           )^1) / nestedparser / writer.blockquote

  local HorizontalRule   = (lineof_asterisks + lineof_dashes + lineof_underscores) / writer.hrule

  local Reference        = define_reference_parser / ""

  local Paragraph        = nonindentspace * Cs(V("Inline")^1) * newline * blankline^1 / writer.paragraph

  ------------------------------------------------------------------------------
  -- Lists
  ------------------------------------------------------------------------------

  local NestedList            = Cs((optionallyindentedline - (bullet + enumerator))^1) / function(a) return "\001"..a end
  local ListBlockLine         = -blankline * -(indent^-1 * (bullet + enumerator)) * optionallyindentedline
  local ListBlock             = line * ListBlockLine^0
  local ListContinuationBlock = blanklines * (indent / "") * ListBlock

  local function TightListItem(starter)
      return (starter * Cs(ListBlock * NestedList^-1) * -(blanklines * indent) / nestedparser / writer.listitem)
  end

  local function LooseListItem(starter)
      return (starter * Cs(ListBlock * Cc("\n") * (NestedList + ListContinuationBlock^0) * (blanklines / "\n\n")) / nestedparser / writer.listitem)
  end

  BulletList = Cs(TightListItem(bullet)^1)  * Cc(true) * skipblanklines * -bullet    / writer.bulletlist
             + Cs(LooseListItem(bullet)^1)  * Cc(false) * skipblanklines             / writer.bulletlist
  OrderedList = Cs(TightListItem(enumerator)^1) * Cc(true) * skipblanklines * -enumerator  / writer.orderedlist
              + Cs(LooseListItem(enumerator)^1) * Cc(false) * skipblanklines         / writer.orderedlist

  ------------------------------------------------------------------------------
  -- Headers
  ------------------------------------------------------------------------------

  local AtxHeader = HeadingStart * optionalspace * Cs((V("Inline") - HeadingStop)^1) * HeadingStop / writer.heading
  local SetextHeader = #(line * S("=-")) * Cs(line / nestedparser)
                         * HeadingLevel *  optionalspace * newline / function(a,b) return writer.heading(b,a) end

  ------------------------------------------------------------------------------
  -- Syntax specification
  ------------------------------------------------------------------------------

  syntax = { "Document",

      Document              = V("Block")^0,

      Block                 = blankline^1 / ""
                            + blocksep / "\n"
                            + Blockquote
                            + Verbatim
                            + HorizontalRule
                            + BulletList
                            + OrderedList
                            + AtxHeader
                            + DisplayHtml
                            + SetextHeader
                            + Reference
                            + Paragraph
                            + Cs(V("Inline")^1),

      Inline                = Str
                            + Space
                            + Endline
                            + UlOrStarLine
                            + Strong
                            + Emph
                            + Image
                            + Link
                            + Code
                            + AutoLinkUrl
                            + AutoLinkEmail
                            + InlineHtml
                            + HtmlEntity
                            + EscapedChar
                            + Symbol,

  }

  ------------------------------------------------------------------------------
  -- Conversion function
  ------------------------------------------------------------------------------

  local function convert(str)
      references = {}
      referenceparser(str)
      local result = writer.start_document() .. nestedparser(str) .. writer.stop_document()
      return result
  end

  return convert

end

------------------------------------------------------------------------------
-- Utility functions
------------------------------------------------------------------------------

-- from Programming Lua
local function expandTabs(s, tabstop)
  local tab = tabstop or 4
  local corr = 0
  return (string.gsub(s, "()\t", function(p)
          local sp = tab - (p - 1 + corr)%tab
          corr = corr - 1 + sp
          return string.rep(" ",sp)
        end))
end

local function read_and_expand_tabs()
  local buffer = {}
  for line in io.lines() do
    table.insert(buffer, expandTabs(line,4))
  end
  -- need blank line at end to emulate Markdown.pl
  table.insert(buffer, "\n")
  return table.concat(buffer,"\n")
end

local write_html = require("writer.html")
M.writers = { html = write_html }

------------------------------------------------------------------------------
-- Main program - act as module if 'required', else as program.
------------------------------------------------------------------------------

-- http://lua-users.org/lists/lua-l/2007-02/msg00125.html
if type(package.loaded[myname]) == "userdata" then
    return M  -- put module stuff here
  else
--    prof.start()
    lapp = require("pl.lapp")
    local args = lapp [[
    Testing parameter handling
        -t (default html) Output format.
        <input> (default stdin)  File to convert.
    ]]

    local writer
    if not args.t or args.t == "html" then
      writer = M.writers.html
    else
      print("Unknown writer: " .. args.t)
      os.exit(3)
    end
    writer.options.minimize = false
    writer.options.blanklines = false
    io.input(args.input)
    io.write(M.read_markdown(writer,{})(read_and_expand_tabs()))
  end

