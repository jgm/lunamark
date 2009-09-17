module (..., package.seeall)

local lpeg = require "lpeg"
local util = require "lunamark.util"
local generic = require "lunamark.parser.generic"

local c = lpeg.C
local _ = lpeg.V
local p = lpeg.P
local r = lpeg.R

local references = {}

function parser(writerfn, opts)
  local options = opts or {}
  local writer = writerfn(parser, options)
  local modify_syntax = options.modify_syntax or function(a) return a end

  local syntax = {
    "Doc"; -- initial

    Doc = #(lpeg.Cmt(_"References", function(s,i,a) return i end)) * 
           lpeg.Ct((generic.interblockspace *  _"Block")^0) * generic.blankline^0 * generic.eof,


    References = (_"Reference" / function(ref) references[ref.key] = ref end + (generic.nonemptyline^1 * generic.blankline^1) + generic.line)^0 * generic.blankline^0 * generic.eof,

    Block =
    ( _"Blockquote"
    + _"Verbatim"
    + _"Reference" / {} 
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

    AtxEnd = generic.sp * p"#"^0 * generic.sp * generic.newline * generic.blankline^0,

    AtxHeading = _"AtxStart" * generic.sp * lpeg.Ct(_"AtxInline"^1) * _"AtxEnd" / writer.heading,

    SetextHeading = _"SetextHeading1" + _"SetextHeading2",

    SetextHeading1 = lpeg.Ct((_"Inline" - _"Endline")^1) * generic.newline * p("=")^3 * generic.newline * generic.blankline^0 / function(c) return writer.heading(1,c) end,

    SetextHeading2 = lpeg.Ct((_"Inline" - _"Endline")^1) * generic.newline * p("-")^3 * generic.newline * generic.blankline^0 / function(c) return writer.heading(2,c) end,

    BulletList = _"BulletListTight" + _"BulletListLoose",
    
    BulletListTight = lpeg.Ct((generic.bullet * _"ListItem")^1) * generic.blankline^0 * -generic.bullet / writer.bulletlist.tight,

    BulletListLoose = lpeg.Ct((generic.bullet * _"ListItem" * c(generic.blankline^0) / function(a,b) return (a..b) end)^1) / writer.bulletlist.loose,

    OrderedList = _"OrderedListTight" + _"OrderedListLoose",
    
    OrderedListTight = lpeg.Ct((generic.enumerator * _"ListItem")^1) * generic.blankline^0 * -generic.enumerator / writer.orderedlist.tight,

    OrderedListLoose = lpeg.Ct((generic.enumerator * _"ListItem" * c(generic.blankline^0) / function(a,b) return (a..b) end)^1) / writer.orderedlist.loose,

    ListItem = lpeg.Ct(_"ListBlock" * (_"NestedList" + _"ListContinuationBlock"^0)) / table.concat,

    ListBlock = lpeg.Ct(generic.line * _"ListBlockLine"^0) / table.concat,

    ListContinuationBlock = generic.blankline^0 * generic.indent * _"ListBlock",

    NestedList = lpeg.Ct((generic.optionallyindentedline - (generic.bullet + generic.enumerator))^1) / function(a) return ("\001" .. table.concat(a)) end,

    ListBlockLine = -generic.blankline * -(generic.indent^-1 * (generic.bullet + generic.enumerator)) * generic.optionallyindentedline,

    InBlockTags = generic.openblocktag * (_"HtmlBlock" + (p(1) - generic.closeblocktag))^0 * generic.closeblocktag,

    HtmlBlock = c(_"InBlockTags" + generic.selfclosingblocktag + generic.htmlcomment) * generic.blankline^1 / function(a) return writer.rawhtml(a .. "\n") end,

    BlockquoteLine = ( (generic.nonindentspace * p(">") * p(" ")^-1 * c(generic.linechar^0) * generic.newline)^1
    * ((c(generic.linechar^1) - generic.blankline) * generic.newline)^0 
    * c(generic.blankline)^0 )^1,
    Blockquote = lpeg.Ct((_"BlockquoteLine" - generic.blankline)^1) / writer.blockquote,

    VerbatimChunk = generic.blankline^0 * (generic.indentedline - generic.blankline)^1,

    Verbatim = lpeg.Ct(_"VerbatimChunk"^1) * (generic.blankline^1 + generic.eof) / writer.verbatim,

    Label = p"[" * lpeg.Cf(lpeg.Cc("") * #((c(_"Label" + _"Inline") - p"]")^1), function(accum, s) return accum .. s end) * 
             lpeg.Ct((_"Label" / function(a) return {"[",a.inlines,"]"} end + _"Inline" - p"]")^1) * p"]" /
             function(a,b) return {raw = a, inlines = b} end,

    RefTitle = p"\"" * c((p(1) - (p"\""^-1 * generic.blankline))^0) * p"\"" +
               p"'"  * c((p(1) - (p"'"^-1 * generic.blankline))^0) * p"'" +
               p"("  * c((p(1) - (p")" * generic.blankline))^0) * p")" +
               lpeg.Cc(""),

    RefSrc = c(generic.nonspacechar^1),

    Reference = generic.nonindentspace * _"Label" * p":" * generic.spnl * _"RefSrc" * generic.spnl * _"RefTitle" * generic.blankline^0 / writer.reference,

    HorizontalRule = (generic.lineof("*") + generic.lineof("-") + generic.lineof("_")) / writer.hrule,

    Para = generic.nonindentspace * lpeg.Ct(_"Inline"^1) * generic.newline * generic.blankline^1 / writer.para,

    Plain = lpeg.Ct(_"Inline"^1) / writer.plain,

    Inline = _"Str"
    + _"Endline"
    + _"UlOrStarLine"
    + _"Space"
    + _"Strong"
    + _"Emph"
    + _"Image"
    + _"Link"
    + _"Code"
    + _"RawHtml"
    + _"Entity"
    + _"EscapedChar"
    + _"Symbol",

    RawHtml = c(generic.htmlcomment + generic.htmltag) / writer.rawhtml,

    EscapedChar = p"\\" * c(p(1 - generic.newline)) / writer.str,

    Entity = _"HexEntity" + _"DecEntity" + _"CharEntity" / writer.entity,

    HexEntity = c(p"&" * p"#" * lpeg.S("Xx") * r("09", "af", "AF")^1 * p";"),

    DecEntity = c(p"&" * p"#" * r"09"^1 * p";"),

    CharEntity = c(p"&" * generic.alphanumeric^1 * p";"),

    Endline = _"LineBreak" + _"TerminalEndline" + _"NormalEndline",

    NormalEndline = generic.sp * generic.newline *
    -( generic.blankline 
    + p">"
    + _"AtxStart"
    + ( generic.line * (p"==="^3 + p"---"^3) * generic.newline )
    ) / writer.space,

    TerminalEndline = generic.sp * generic.newline * generic.eof / "",

    LineBreak = p"  " * _"NormalEndline" / writer.linebreak,

    Code = generic.inticks / writer.code,

    -- This keeps the parser from getting bogged down on long strings of '*' or '_'
    UlOrStarLine = p"*"^4 + p"_"^4 + (generic.space * lpeg.S("*_")^1 * #generic.space) / writer.str,

    Emph = _"EmphStar" + _"EmphUl",

    EmphStar = p"*" * -(generic.spacechar + generic.newline) * lpeg.Ct((_"Inline" - p"*")^1) * p"*" / writer.emph,

    EmphUl = p"_" * -(generic.spacechar + generic.newline) * lpeg.Ct((_"Inline" - p"_")^1) * p"_" / writer.emph,

    Strong = _"StrongStar" + _"StrongUl",

    StrongStar = p"**" * -(generic.spacechar + generic.newline) * lpeg.Ct((_"Inline" - p"**")^1) * p"**" / writer.strong,

    StrongUl = p"__" * -(generic.spacechar + generic.newline) * lpeg.Ct((_"Inline" - p"__")^1) * p"__" / writer.strong,

    Image = p"!" * (_"ExplicitLink" + _"ReferenceLink") / writer.image,

    Link =  _"ExplicitLink" / writer.link + _"ReferenceLink" / writer.link + _"AutoLinkUrl" + _"AutoLinkEmail",

    ReferenceLink = _"ReferenceLinkDouble" + _"ReferenceLinkSingle",

    ReferenceLinkDouble = _"Label" * generic.spnl * lpeg.Cmt(_"Label", function(s,i,l) local key = util.normalize_label(l.raw); if references[key] then return i, references[key].source, references[key].title else return false end end),

    ReferenceLinkSingle = lpeg.Cmt(_"Label", function(s,i,l) local key = util.normalize_label(l.raw); if references[key] then return i, l, references[key].source, references[key].title else return false end end) * (generic.spnl * p"[]")^-1,

    AutoLinkUrl = p"<" * c(generic.alphanumeric^1 * p"://" * (p(1) - (generic.newline + p">"))^1) * p">" / function(a) return writer.link({inlines = writer.str(a)}, a, "") end,

    AutoLinkEmail = p"<" * c((generic.alphanumeric + lpeg.S("-_+"))^1 * p"@" * (p(1) - (generic.newline + p">"))^1) * p">" / writer.email_link,

    BasicSource  = (generic.nonspacechar - lpeg.S("()>"))^1 + (p"(" * _"Source" * p")")^1 + p"",

    AngleSource = p"<" * c(_"BasicSource") * p">",

    Source = _"AngleSource" + c(_"BasicSource"), 

    LinkTitle = p"\"" * c((p(1) - (p"\"" * generic.sp * p")"))^0) * p"\"" +
                p"'" * c((p(1) - (p"'" * generic.sp * p")"))^0) * p"'" +
                lpeg.Cc(""),

    ExplicitLink = _"Label" * generic.spnl * p"(" * generic.sp * _"Source" * generic.spnl * _"LinkTitle" * generic.sp * p")",

    Str = c(generic.normalchar^1) / writer.str,

    Space = generic.spacechar^1 / writer.space,

    Symbol = c(generic.specialchar) / writer.str
    }

  return function(inp) return util.to_string(lpeg.match(p(modify_syntax(syntax)), inp)) end
end
