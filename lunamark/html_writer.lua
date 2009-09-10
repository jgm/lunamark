module(..., package.seeall)

local util = require "lunamark.util"

function writer(parser, options, references)
  local escape_html_char = function(c)
                             if c == "\"" then
                                return "&quot;"
                             elseif c == "<" then
                                return "&lt;"
                             elseif c == "&" then
                                 return "&amp;"
                             else return c
                             end
                           end
  local escape = function(s) return (string.gsub(s, "[\"&<]", escape_html_char)) end
  local obfuscate = function(s)
                      local fmt = function() if math.random(2) == 1 then return "&#x%x;" else return "&#%d;" end end
                      return string.gsub(s, "(.)", function(c) return string.format(fmt(),string.byte(c)) end)
                    end
  local spliton1 = function(s) local t = {}; for m in string.gmatch(s, "([^\001]+)") do table.insert(t,m) end; return t end
  local listitem = function(c) return {"<li>", util.map(parser(writer, options, references).parse, spliton1(c)), "</li>\n"} end
  local list = { tight = function(items) return util.map(listitem, items) end,
                 loose = function(items) return util.map(function(c) return listitem(c .. "\n\n") end, items) end }
  return {
  null = function() return "" end,
  rawhtml = function(c) return c end,
  linebreak = function() return "<br />\n" end,
  str = escape,
  entity = function(c) return c end,
  space = function() return " " end,
  emph = function(c) return {"<em>", c, "</em>"} end,
  code = function(c) return {"<code>", escape(c), "</code>"} end,
  strong = function(c) return {"<strong>", c, "</strong>"} end,
  heading = function(lev,c) return {"<h" .. lev .. ">", c, "</h" .. lev .. ">\n"} end,
  bulletlist = { tight = function(c) return {"<ul>\n", list.tight(c), "</ul>\n"} end,
                 loose = function(c) return {"<ul>\n", list.loose(c), "</ul>\n"} end },
  orderedlist = { tight = function(c) return {"<ol>\n", list.tight(c), "</ol>\n"} end,
                  loose = function(c) return {"<ol>\n", list.loose(c), "</ol>\n"} end },
  para = function(c) return {"<p>", c, "</p>\n"} end,
  plain = function(c) return c end,
  blockquote = function(c) return {"<blockquote>", parser(writer, options, references).parse(table.concat(c,"\n")), "</blockquote>\n"} end,
  verbatim = function(c) return {"<pre><code>", escape(table.concat(c,"")), "</code></pre>\n"} end,
  hrule = function() return "<hr />\n" end,
  link = function(lab,src,tit)
           local a = "<a href=\"" .. escape(src) .. "\""
           if string.len(tit) > 0 then a = a .. " title=\"" .. escape(tit) .. "\"" end
           a = a .. ">"
           return {a, lab.inlines, "</a>"}
         end,
  image = function(lab,src,tit)
           local a = "<img src=\"" .. escape(src) .. "\" alt=\"" .. escape(lab.raw) .. "\""
           if string.len(tit) > 0 then a = a .. " title=\"" .. escape(tit) .. "\"" end
           a = a .. " />"
           return a
         end,
  email_link = function(addr)
                 local obfuscated_addr = obfuscate(addr)
                 return("<a href=\"" .. obfuscate("mailto:") .. obfuscated_addr .. "\">" .. obfuscated_addr .. "</a>")
               end,
  reference = function(lab,src,tit)
                return {key = util.normalize_label(lab.raw), label = lab.inlines, source = src, title = tit}
              end
  }
end

