module(..., package.seeall)

local lpeg = require "lpeg"
local util = require "lunamark.util"

local c = lpeg.C
local _ = lpeg.V
local p = lpeg.P
local r = lpeg.R

spacechar = lpeg.S("\t ")
newline = p"\r"^-1 * p"\n"
nonspacechar = p(1) - (spacechar + newline)
sp = spacechar^0
space = spacechar^1
eof = -p(1)
nonindentspace = (p" ")^-3
blankline = sp * c(newline)
skipblanklines = (sp * newline)^0
linechar = p(1 - newline)
indent = p"    " + (nonindentspace * p"\t") / ""
indentedline = indent * c(linechar^1 * (newline + eof))
optionallyindentedline = indent^-1 * c(linechar^1 * (newline + eof))
spnl = sp * (newline * sp)^-1
specialchar = lpeg.S("*_`*&[]<!\\")
normalchar = p(1) - (specialchar + spacechar + newline)
alphanumeric = lpeg.R("AZ","az","09")
line = c((p(1) - newline)^0 * newline) + c(p(1)^1 * eof)
nonemptyline = (p(1) - newline)^1 * newline
quoted = function(open, close) return (p(open) * c((p(1) - (blankline + p(close)))^0) * p(close)) end
htmlattributevalue = (quoted("'","'") + quoted("\"","\"")) + (p(1) - lpeg.S("\t >"))^1
htmlattribute = (alphanumeric + lpeg.S("_-"))^1 * spnl * (p"=" * spnl * htmlattributevalue)^-1 * spnl
htmlcomment = p"<!--" * (p(1) - p"-->")^0 * p"-->"
htmltag = p"<" * spnl * p"/"^-1 * alphanumeric^1 * spnl * htmlattribute^0 * p"/"^-1 * spnl * p">" 
lineof = function(c) return (nonindentspace * (p(c) * sp)^3 * newline * blankline^1) end
bullet = nonindentspace * (p"+" + (p"*" - lineof"*") + (p"-" - lineof"-")) * space
enumerator = nonindentspace * r"09"^1 * p"." * space

openticks = lpeg.Cg(p"`"^1, "ticks")
closeticks = p" "^-1 * lpeg.Cmt(c(p"`"^1) * lpeg.Cb("ticks"), function(s,i,a,b) return string.len(a) == string.len(b) and i end)
intickschar = (p(1) - lpeg.S(" \n\r`")) +
              (newline * -blankline) +
              (p" " - closeticks) +
              (p("`")^1 - closeticks)
inticks = openticks * p(" ")^-1 * c(intickschar^1) * closeticks

blocktags = { address = true, blockquote = true, center = true, dir = true, div = true, dl = true,
                    fieldset = true, form = true, h1 = true, h2 = true, h3 = true, h4 = true, h5 = true,
                    h6 = true, hr = true, isindex = true, menu = true, noframes = true, noscript = true,
                    ol = true, p = true, pre = true, table = true, ul = true, dd = true, ht = true,
                    frameset = true, li = true, tbody = true, td = true, tfoot = true, th = true,
                    thead = true, tr = true, script = true }

blocktag = lpeg.Cmt(c(alphanumeric^1), function(s,i,a) return blocktags[string.lower(a)] and i, a end)
openblocktag = p"<" * spnl * lpeg.Cg(blocktag, "opentag") * spnl * htmlattribute^0 * p">"
closeblocktag = p"<" * spnl * p"/" * lpeg.Cmt(c(alphanumeric^1) * lpeg.Cb("opentag"), function(s,i,a,b) return string.lower(a) == string.lower(b) and i end) * spnl * p">"
selfclosingblocktag = p"<" * spnl * p"/"^-1 * blocktag * spnl * htmlattribute^0 * p"/" * spnl * p">"

choice = function(parsers) local res = lpeg.S""; for k,p in pairs(parsers) do res = res + p end; return res end

-- yields a blank line unless we're at the beginning of the document
interblockspace = lpeg.Cmt(blankline^0, function(s,i) if i == 1 then return i, "" else return i, "\n" end end)
