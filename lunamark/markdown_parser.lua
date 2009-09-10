module(..., package.seeall)

local lpeg = require "lpeg"
local util = require "lunamark.util"

local c = lpeg.C
local _ = lpeg.V
local p = lpeg.P
local r = lpeg.R

local spacechar = lpeg.S("\t ")
local newline = p"\r"^-1 * p"\n"
local nonspacechar = p(1) - (spacechar + newline)
local sp = spacechar^0
local space = spacechar^1
local eof = -p(1)
local nonindentspace = (p" ")^-3
local blankline = sp * c(newline)
local skipblanklines = (sp * newline)^0
local linechar = p(1 - newline)
local indent = p"    " + (nonindentspace * p"\t") / ""
local indentedline = indent * c(linechar^1 * (newline + eof))
local optionallyindentedline = indent^-1 * c(linechar^1 * (newline + eof))
local spnl = sp * (newline * sp)^-1
local specialchar = lpeg.S("*_`*&[]<!\\")
local normalchar = p(1) - (specialchar + spacechar + newline)
local alphanumeric = lpeg.R("AZ","az","09")
local line = c((p(1) - newline)^0 * newline) + c(p(1)^1 * eof)
local nonemptyline = (p(1) - newline)^1 * newline
local quoted = function(open, close) return (p(open) * c((p(1) - (blankline + p(close)))^0) * p(close)) end
local htmlattributevalue = (quoted("'","'") + quoted("\"","\"")) + (p(1) - spacechar)^1
local htmlattribute = (alphanumeric + lpeg.S("_-"))^1 * spnl * (p"=" * spnl * htmlattributevalue)^-1 * spnl
local htmlcomment = p"<!--" * (p(1) - p"-->")^0 * p"-->"
local htmltag = p"<" * spnl * p"/"^-1 * alphanumeric^1 * spnl * htmlattribute^0 * p"/"^-1 * spnl * p">" 
local lineof = function(c) return (nonindentspace * (p(c) * sp)^3 * newline * blankline^1) end
local bullet = nonindentspace * (p"+" + (p"*" - lineof"*") + (p"-" - lineof"-")) * space
local enumerator = nonindentspace * r"09"^1 * p"." * space

local openticks = lpeg.Cg(p"`"^1, "ticks")
local closeticks = sp * lpeg.Cmt(c(p"`"^1) * lpeg.Cb("ticks"), function(s,i,a,b) return string.len(a) == string.len(b) and i end)
local inticks = openticks * sp * c((p(1) - (blankline + closeticks))^1) * closeticks

local blocktags = { address = true, blockquote = true, center = true, dir = true, div = true, dl = true,
                    fieldset = true, form = true, h1 = true, h2 = true, h3 = true, h4 = true, h5 = true,
                    h6 = true, hr = true, isindex = true, menu = true, noframes = true, noscript = true,
                    ol = true, p = true, pre = true, table = true, ul = true, dd = true, ht = true,
                    frameset = true, li = true, tbody = true, td = true, tfoot = true, th = true,
                    thead = true, tr = true, script = true }

local blocktag = lpeg.Cmt(c(alphanumeric^1), function(s,i,a) return blocktags[string.lower(a)] and i, a end)
local openblocktag = p"<" * spnl * lpeg.Cg(blocktag, "opentag") * spnl * htmlattribute^0 * p">"
local closeblocktag = p"<" * spnl * p"/" * lpeg.Cmt(c(alphanumeric^1) * lpeg.Cb("opentag"), function(s,i,a,b) return string.lower(a) == string.lower(b) and i end) * spnl * p">"
local selfclosingblocktag = p"<" * spnl * p"/"^-1 * blocktag * spnl * htmlattribute^0 * p"/" * spnl * p">"
local inblocktags = openblocktag * (_"HtmlBlock" + (p(1) - closeblocktag))^0 * closeblocktag

local choice = function(parsers) local res = lpeg.S""; for k,p in pairs(parsers) do res = res + p end; return res end

-- yields a blank line unless we're at the beginning of the document
local interblockspace = lpeg.Cmt(blankline^0, function(s,i) if i == 1 then return i, "" else return i, "\n" end end)

local strcat = function(accum,s) return (accum .. s) end 

function parser(writerfn, opts, refs)
  local options = opts or {}
  local references = refs or {}
  local writer = writerfn(parser, options, references)

  local parser = p{
    "Doc"; -- initial

    Doc = #(lpeg.Cmt(_"References", function(s,i,a) writer = writerfn(parser, options, references); return i end)) * 
            lpeg.Ct((interblockspace *  _"Block")^0) * blankline^0 * eof,


    References = (_"Reference" / function(ref) references[ref.key] = ref end + (nonemptyline^1 * blankline^1) + line)^0 * blankline^0 * eof,

    Block =
    ( _"Blockquote"
    + _"Verbatim"
    + _"Reference" / {} 
    -- + _"Note"
    + _"HorizontalRule"
    + _"Heading"
    + _"OrderedList"
    + _"BulletList"
    + _"HtmlBlock"
    + _"Para"
    + _"Plain"
    ),

    Heading = _"AtxHeading" + _"SetextHeading", 

    AtxStart = c(p"#" * p"#"^-5) / string.len,

    AtxInline = _"Inline" - _"AtxEnd",

    AtxEnd = sp * p"#"^0 * sp * newline * blankline^0,

    AtxHeading = _"AtxStart" * sp * lpeg.Ct(_"AtxInline"^1) * _"AtxEnd" / writer.heading,

    SetextHeading = _"SetextHeading1" + _"SetextHeading2",

    SetextHeading1 = lpeg.Ct((_"Inline" - _"Endline")^1) * newline * p("=")^3 * newline * blankline^0 / function(c) return writer.heading(1,c) end,

    SetextHeading2 = lpeg.Ct((_"Inline" - _"Endline")^1) * newline * p("-")^3 * newline * blankline^0 / function(c) return writer.heading(2,c) end,

    BulletList = _"BulletListTight" + _"BulletListLoose",
    
    BulletListTight = lpeg.Ct((bullet * _"ListItem")^1) * blankline^0 * -bullet / writer.bulletlist.tight,

    BulletListLoose = lpeg.Ct((bullet * _"ListItem" * c(blankline^0) / function(a,b) return (a..b) end)^1) / writer.bulletlist.loose,

    OrderedList = _"OrderedListTight" + _"OrderedListLoose",
    
    OrderedListTight = lpeg.Ct((enumerator * _"ListItem")^1) * blankline^0 * -enumerator / writer.orderedlist.tight,

    OrderedListLoose = lpeg.Ct((enumerator * _"ListItem" * c(blankline^0) / function(a,b) return (a..b) end)^1) / writer.orderedlist.loose,

    ListItem = lpeg.Ct(_"ListBlock" * (_"NestedList" + _"ListContinuationBlock"^0)) / table.concat,

    ListBlock = lpeg.Ct(line * _"ListBlockLine"^0) / table.concat,

    ListContinuationBlock = blankline^0 * indent * _"ListBlock",

    NestedList = lpeg.Ct((optionallyindentedline - (bullet + enumerator))^1) / function(a) return ("\001" .. table.concat(a)) end,

    ListBlockLine = -blankline * -(indent^-1 * (bullet + enumerator)) * optionallyindentedline,

    HtmlBlock = c(inblocktags + selfclosingblocktag + htmlcomment) * blankline^1 / function(a) return writer.rawhtml(a .. "\n") end,

    BlockquoteLine = ( (nonindentspace * p(">") * p(" ")^-1 * c(linechar^0) * newline)^1
    * ((c(linechar^1) - blankline) * newline)^0 
    * c(blankline)^0 )^1,
    Blockquote = lpeg.Ct((_"BlockquoteLine" - blankline)^1) / writer.blockquote,

    VerbatimChunk = blankline^0 * (indentedline - blankline)^1,

    Verbatim = lpeg.Ct(_"VerbatimChunk"^1) * (blankline^1 + eof) / writer.verbatim,

    -- TODO when notes are added, need to exclude label starting with ^
    Label = p"[" * lpeg.Cf(lpeg.Cc("") * #((c(_"Label" + _"Inline") - p"]")^1), strcat) * 
             lpeg.Ct((_"Label" / function(a) return {"[",a.inlines,"]"} end + _"Inline" - p"]")^1) * p"]" /
             function(a,b) return {raw = a, inlines = b} end,

    RefTitle = p"\"" * c((p(1) - (p"\""^-1 * blankline))^0) * p"\"" +
               p"'"  * c((p(1) - (p"'"^-1 * blankline))^0) * p"'" +
               p"("  * c((p(1) - (p")" * blankline))^0) * p")" +
               lpeg.Cc(""),

    RefSrc = c(nonspacechar^1),

    Reference = nonindentspace * _"Label" * p":" * spnl * _"RefSrc" * spnl * _"RefTitle" * blankline^0 / writer.reference,

    HorizontalRule = (lineof("*") + lineof("-") + lineof("_")) / writer.hrule,

    Para = nonindentspace * lpeg.Ct(_"Inline"^1) * newline * blankline^1 / writer.para,

    Plain = lpeg.Ct(_"Inline"^1) / writer.plain,

    Inline = _"Str"
    + _"Endline"
    + _"UlOrStarLine"
    + _"Space"
    + _"Strong"
    + _"Emph"
    + _"Image"
    + _"Link"
    -- + _"NoteReference"
    -- + _"InlineNote"
    + _"Code"
    + _"RawHtml"
    + _"Entity"
    + _"EscapedChar"
    -- + _"Smart"
    + _"Symbol",

    RawHtml = c(htmlcomment + htmltag) / writer.rawhtml,

    EscapedChar = p"\\" * c(p(1 - newline)) / writer.str,

    Entity = _"HexEntity" + _"DecEntity" + _"CharEntity" / writer.entity,

    HexEntity = c(p"&" * p"#" * lpeg.S("Xx") * r("09", "af", "AF")^1 * p";"),

    DecEntity = c(p"&" * p"#" * r"09"^1 * p";"),

    CharEntity = c(p"&" * alphanumeric^1 * p";"),

    Endline = _"LineBreak" + _"TerminalEndline" + _"NormalEndline",

    NormalEndline = sp * newline *
    -( blankline 
    + p">"
    + _"AtxStart"
    + ( line * (p"==="^3 + p"---"^3) * newline )
    ) / writer.space,

    TerminalEndline = sp * newline * eof / writer.null,

    LineBreak = p"  " * _"NormalEndline" / writer.linebreak,

    Code = inticks / writer.code,

    -- This keeps the parser from getting bogged down on long strings of '*' or '_'
    UlOrStarLine = p"*"^4 + p"_"^4 + (space * lpeg.S("*_")^1 * #space) / writer.str,

    Emph = _"EmphStar" + _"EmphUl",

    EmphStar = p"*" * -(spacechar + newline) * lpeg.Ct((_"Inline" - p"*")^1) * p"*" / writer.emph,

    EmphUl = p"_" * -(spacechar + newline) * lpeg.Ct((_"Inline" - p"_")^1) * p"_" / writer.emph,

    Strong = _"StrongStar" + _"StrongUl",

    StrongStar = p"**" * -(spacechar + newline) * lpeg.Ct((_"Inline" - p"**")^1) * p"**" / writer.strong,

    StrongUl = p"__" * -(spacechar + newline) * lpeg.Ct((_"Inline" - p"__")^1) * p"__" / writer.strong,

    Image = p"!" * (_"ExplicitLink" + _"ReferenceLink") / writer.image,

    Link =  _"ExplicitLink" / writer.link + _"ReferenceLink" / writer.link + _"AutoLinkUrl" + _"AutoLinkEmail",

    ReferenceLink = _"ReferenceLinkDouble" + _"ReferenceLinkSingle",

    ReferenceLinkDouble = _"Label" * spnl * lpeg.Cmt(_"Label", function(s,i,l) local key = util.normalize_label(l.raw); if references[key] then return i, references[key].source, references[key].title else return false end end),

    ReferenceLinkSingle = lpeg.Cmt(_"Label", function(s,i,l) local key = util.normalize_label(l.raw); if references[key] then return i, l, references[key].source, references[key].title else return false end end) * (spnl * p"[]")^-1,

    AutoLinkUrl = p"<" * c(alphanumeric^1 * p"://" * (p(1) - (newline + p">"))^1) * p">" / function(a) return writer.link({inlines = writer.str(a)}, a, "") end,

    AutoLinkEmail = p"<" * c((alphanumeric + lpeg.S("-_+"))^1 * p"@" * (p(1) - (newline + p">"))^1) * p">" / writer.email_link,

    BasicSource  = (nonspacechar - lpeg.S("()>"))^1 + (p"(" * _"Source" * p")")^1 + p"",

    AngleSource = p"<" * c(_"BasicSource") * p">",

    Source = _"AngleSource" + c(_"BasicSource"), 

    LinkTitle = p"\"" * c((p(1) - (p"\"" * sp * p")"))^0) * p"\"" +
                p"'" * c((p(1) - (p"'" * sp * p")"))^0) * p"'" +
                lpeg.Cc(""),

    ExplicitLink = _"Label" * spnl * p"(" * sp * _"Source" * spnl * _"LinkTitle" * sp * p")",

    Str = c(normalchar^1) / writer.str,

    Space = spacechar^1 / writer.space,

    Symbol = c(specialchar) / writer.str
    }

  local parse = function(inp) return lpeg.match(parser, inp) end

  return {
    writer = writer,
    options = options,
    parse = parse,
    to_string = function(inp) return util.to_string(parse(inp)) end,
    write = function(f, inp) return util.to_file(f, parse(inp)) end
    }
end

