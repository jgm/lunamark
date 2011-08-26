local htmlparser = require("lunamark.htmlparser")
local entities = require("lunamark.entities")

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
  for i,node in ipairs(nodes) do
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
              preserve_space or tag == "pre")
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
      elseif tag == "em" or tag == "i" then
        table.insert(output, writer.emphasis(contents))
      elseif tag == "strong" or tag == "b" then
        table.insert(output, writer.strong(contents))
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
      else
        -- skip
      end
    else -- comment or xmlheader
      -- skip
    end
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

