package = "lunamark"
version = "0.1-1"
source = {
   url = ""
}
description = {
   summary = "General markup format converter using lpeg.",
   detailed = [[
      Here we would put a detailed, typically
      paragraph-long description.
   ]],
   homepage = "",
   license = "GPL",
}
dependencies = {
   "lua >= 5.1",
   "lpeg >= 0.9"
}
build = {
   type = "builtin",
   modules = {
      lunamark = "lunamark.lua",
      ["lunamark.util"] = "lunamark/util.lua",
      ["lunamark.html_writer"] = "lunamark/html_writer.lua",
      ["lunamark.latex_writer"] = "lunamark/latex_writer.lua",
      ["lunamark.markdown_parser"] = "lunamark/markdown_parser.lua"
   }
}

