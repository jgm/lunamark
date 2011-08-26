local htmlparser = require("lunamark.htmlparser")

local function handle_nodes(writer, nodes)
  local output = {}
  for i,node in ipairs(nodes) do
    if type(node) == "string" then -- text node
      local contents = writer.string(node)
      table.insert(output, contents)
    elseif node.tag and node.child then -- tag with contents
      -- for now
      local contents = handle_nodes(writer, node.child)
      table.insert(output, contents)
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

