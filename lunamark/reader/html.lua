local htmlparser = require("lunamark.htmlparser")
local entities = require("lunamark.entities")

local function convert_entities(s)
  return s:gsub("&#[Xx](%x+);", entities.hex_entity):gsub("&#(%d+);", entities.dec_entity):gsub("&(%a+);", entities.char_entity)
end

local function handle_nodes(writer, nodes)
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
      local contents = writer.string(convert_entities(node))
      table.insert(output, contents)
    elseif node.tag and node.child then -- tag with contents
      local tag = node.tag
      local contents = handle_nodes(writer, node.child)
      if tag == "p" then
        preblockspace()
        table.insert(output, writer.paragraph(contents))
      else  --skip unknown tag
        table.insert(output, contents)
      end
    elseif node.tag then  -- self-closing tag
      -- skip
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

