-- (c) 2009-2011 John MacFarlane. Released under MIT license.
-- See the file LICENSE in the source for details.

--- Generic instructions here about how to create a new writer,
-- with examples.

local util = require("lunamark.util")
local M = {}
local W = {}

local meta = {}
meta.__index =
  function(_, key)
    io.stderr:write(string.format("WARNING: Undefined writer function '%s'\n",key))
    return (function(...) return table.concat(arg," ") end)
  end
setmetatable(W, meta)

--- Returns a table with functions defining a generic lunamark writer,
-- which outputs plain text with no formatting.  `options` is an optional
-- table with the following fields:
--
-- + `layout`:  `minimize` (no space between blocks), `compact` (no
--   extra blank lines between blocks), `default` (blank line between
--   blocks).
function M.new(options)

--- The table contains the following fields:

  options = options or {}
  local metadata = {}

  --- Set metadata field `key` to `val`.
  function W.set_metadata(key, val)
    metadata[key] = val
    return ""
  end

  --- Add `val` to an array in metadata field `key`.
  function W.add_metadata(key, val)
    local cur = metadata[key]
    if type(cur) == "table" then
      table.insert(cur,val)
    elseif cur then
      metadata[key] = {cur, val}
    else
      metadata[key] = {val}
    end
  end

  --- Return metadata table.
  function W.get_metadata()
    return metadata
  end

  --- A space (string).
  W.space = " "

  --- Setup tasks at beginning of document.
  function W.start_document()
    return ""
  end

  --- Finalization tasks at end of document.
  function W.stop_document()
    return ""
  end

  --- Plain text block (not formatted as a pragraph).
  function W.plain(s)
    return s
  end

  --- A line break (string).
  W.linebreak = "\n"

  --- Line breaks to use between block elements.
  W.interblocksep = "\n\n"

  --- Line breaks to use between a container (like a `<div>`
  -- tag) and the adjacent block element.
  W.containersep = "\n"

  if options.layout == "minimize" then
    W.interblocksep = ""
    W.containersep = ""
  elseif options.layout == "compact" then
    W.interblocksep = "\n"
    W.containersep = "\n"
  end

  --- Ellipsis (string).
  W.ellipsis = "…"

  --- Em dash (string).
  W.mdash = "—"

  --- En dash (string).
  W.ndash = "–"

  --- String in curly single quotes.
  function W.singlequoted(s)
    return string.format("‘%s’",s)
  end

  --- String in curly double quotes.
  function W.doublequoted(s)
    return string.format("“%s”",s)
  end

  --- String, escaped as needed for the output format.
  function W.string(s)
    return s
  end

  --- Inline (verbatim) code.
  function W.code(s)
    return s
  end

  --- A link with link text `label`, uri `uri`,
  -- and title `title`.
  function W.link(label, uri, title)
    return lab
  end

  --- An image link with alt text `label`,
  -- source `src`, and title `title`.
  function W.image(label, src, title)
    return lab
  end

  --- A paragraph.
  function W.paragraph(s)
    return s
  end

  --- A bullet list with contents `items` (an array).  If
  -- `tight` is true, returns a "tight" list (with
  -- minimal space between items).
  function W.bulletlist(items,tight)
    return items
  end

  --- An ordered list with contents `items` (an array). If
  -- `tight` is true, returns a "tight" list (with
  -- minimal space between items). If optional
  -- number `startnum` is present, use it as the
  -- number of the first list item.
  function W.orderedlist(items,tight,startnum)
    return items
  end

  --- Inline HTML.
  function W.inline_html(s)
    return ""
  end

  --- Display HTML (HTML block).
  function W.display_html(s)
    return ""
  end

  --- Emphasized text.
  function W.emphasis(s)
    return s
  end

  --- Strongly emphasized text.
  function W.strong(s)
    return s
  end

  --- Block quotation.
  function W.blockquote(s)
    return s
  end

  --- Verbatim block.
  function W.verbatim(s)
    return s
  end

  --- Section of level `level`, with `header` and optionally
  -- contents `contents`.
  function W.section(header, level, contents)
    if contents then
      return header .. W.interblocksep .. contents
    else
      return header
    end
  end

  --- Horizontal rule.
  W.hrule = ""

  --- A footnote or endnote.
  function W.note(contents)
    return contents
  end

  return util.table_copy(W)
end

return M
