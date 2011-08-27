local htmlparser = require("lunamark.htmlparser")
local entities = require("lunamark.entities")

local function lookup_attr(node, name)
  if node.attr then
    for _,x in ipairs(t) do
      if x.name == name then
        return convert_entities(x.value)
      end
    end
  end
end

local function convert_entities(s)
  return s:gsub("&#[Xx](%x+);", entities.hex_entity):gsub("&#(%d+);", entities.dec_entity):gsub("&(%a+);", entities.char_entity)
end

local function handle_nodes(writer, nodes, preserve_space)
  local output = {}
  local firstblock = true
  local function preblockspace()
    if firstblock then
      firstblock = false
    else
      table.insert(output, writer.interblocksep)
    end
  end
  local i = 1
  while nodes[i] do
    local node = nodes[i]
    if type(node) == "string" then -- text node
      local contents
      if preserve_space then
        contents = writer.string(convert_entities(node))
      else
        local s = convert_entities(node)
        contents = s:gsub("%s+", writer.space)
      end
      table.insert(output, contents)
    elseif node.tag and node.child then -- tag with contents
      local tag = node.tag
      local contents = handle_nodes(writer, node.child,
              preserve_space or tag == "pre" or tag == "code")
      if tag == "p" then
        preblockspace()
        table.insert(output, writer.paragraph(contents))
      elseif tag == "blockquote" then
        preblockspace()
        table.insert(output, writer.blockquote(contents))
      elseif tag == "li" then
        table.insert(output, writer.listitem(contents))
      elseif tag == "ul" then
        preblockspace()
        table.insert(output, writer.bulletlist(contents))
      elseif tag == "ol" then
        preblockspace()
        table.insert(output, writer.orderedlist(contents))
      elseif tag == "pre" then
        preblockspace()
        table.insert(output, writer.verbatim(contents))
      elseif tag:match("^h[123456]$") then
        local lev = tonumber(tag:sub(2,2))
        preblockspace()
        local bodynodes = {}
        while nodes[i+1] do
          local nd = nodes[i+1]
          if nd.tag and nd.tag:match("^h[123456]$") and
             tonumber(nd.tag:sub(2,2)) <= lev then
             break
          else
            table.insert(bodynodes,nd)
          end
          i = i + 1
        end
        local body = handle_nodes(writer, bodynodes, preserve_space)
        table.insert(output, writer.section(contents, lev, body))
      elseif tag == "a" then
        local src = lookup_attr(node, "href") or ""
        local tit = lookup_attr(node, "title")
        table.insert(output, writer.link(contents,src,tit))
      elseif tag == "em" or tag == "i" then
        table.insert(output, writer.emphasis(contents))
      elseif tag == "strong" or tag == "b" then
        table.insert(output, writer.strong(contents))
      elseif tag == "code" then
        table.insert(output, writer.code(contents))
      else  --skip unknown tag
        table.insert(output, contents)
      end
    elseif node.tag then  -- self-closing tag
      local tag = node.tag
      if tag == "hr" then
        preblockspace()
        table.insert(output, writer.hrule)
      elseif tag == "br" then
        preblockspace()
        table.insert(output, writer.linebreak)
      elseif tag == "img" then
        local alt = lookup_attr(node, "alt") or ""
        local src = lookup_attr(node, "src") or ""
        local tit = lookup_attr(node, "title")
        table.insert(output, writer.image(alt,src,tit))
      else
        -- skip
      end
    else -- comment or xmlheader
      -- skip
    end
    i = i + 1
  end
  return table.concat(output)
end

local function html(writer, options)

  local function convert(inp)
    local parser = htmlparser.new(inp)
    local parsed = parser:parse()
    return handle_nodes(writer, parsed)
  end

  return convert
end
return html

