local util = require "lunamark.util"

local function writer(parser, options)
  local escape = function(s) return (string.gsub(s, "[{}$%%&_#^\\~|<>]", function(c) return "\\char`\\"..c end)) end
  local spliton1 = function(s) local t = {}; for m in string.gmatch(s, "([^\001]+)") do table.insert(t,m) end; return t end
  local listitem = function(c) return {"\\item ", util.map(parser(writer, options), spliton1(c)), "\n"} end
  return {
  rawhtml = function(c) return "" end, -- XXX
  linebreak = function() return "\\\\\n" end, -- XXX
  str = escape,
  entity = function(c) return "?" end, -- XXX
  space = function() return " " end,
  emph = function(c) return {"\\dontleavehmode{\\em ", c, "}"} end,
  code = function(c) return {"\\type{", c, "}"} end,
  strong = function(c) return {"\\dontleavehmode{\\bf ", c, "}"} end,
  heading = function(lev,c) return {"\\", string.rep("sub",lev - 1), "section{", c, "}\n"} end,
  bulletlist = { tight = function(c) return {"\\startitemize[packed]\n", util.map(listitem, c), "\\stopitemize\n"} end,
                 loose = function(c) return {"\\startitemize\n", util.map(listitem, c), "\\stopitemize\n"} end },
  orderedlist = { tight = function(c) return {"\\startitemize[n,packed]\n", util.map(listitem, c), "\\stopitemize\n"} end,
                  loose = function(c) return {"\\startitemize[n]\n", util.map(listitem, c), "\\stopitemize\n"} end },
  para = function(c) return {c, "\n"} end,
  plain = function(c) return c end,
  blockquote = function(c) return {"\\startblockquote\n", parser(writer, options)(table.concat(c,"\n")), "\\stopblockquote\n"} end,
  verbatim = function(c) return {"\\starttyping\n", table.concat(c), "\\stoptyping\n"} end,
  hrule = function() return "\\hairline\n" end,
  link = function(lab,src,tit) return {"\\goto{", lab.inlines, "}[url(", src, ")]"} end,
  image = function(lab,src,tit) return {"\\externalfigure[", src, "]"} end,
  email_link = function(addr) return link(addr,"mailto:"..addr) end,
  reference = function(lab,src,tit)
                return {key = util.normalize_label(lab.raw), label = lab.inlines, source = src, title = tit}
              end
  }
end

return writer
