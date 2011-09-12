local testdir = tests
local lfs = require("lfs")
local diff = require("diff")

local function do_matching_tests(path, patt, fun)
  local patt = patt or "."
  local result = {}
  for f in lfs.dir(path) do
    local fpath = path .. "/" .. f
    if f ~= "." and f ~= ".." and f:match(patt) and f:match("%.test$") then
      local fh = io.open(fpath, "r")
      local contents = fh:read("*all"):gsub("\r","")
      local cmd, inp, out = contents:match("^([^\n]*)\n<<<[ \t]*\n(.-\n)>>>[ \t]*\n(.*)")
      fun({ name = f:match("^(.*)%.test$"), path = fpath,
            command = cmd, input = inp, output = out })
    end
  end
end

-- test:
do_matching_tests(arg[1], arg[2], function(t) print(t.name, t.command) end)
