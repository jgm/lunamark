local testdir = tests
local lfs = require("lfs")
local diff = require("diff")
local cmdname = "lunamark"

local function do_matching_tests(path, patt, fun)
  local patt = patt or "."
  local result = {}
  for f in lfs.dir(path) do
    local fpath = path .. "/" .. f
    if f ~= "." and f ~= ".." and f:match(patt) and f:match("%.test$") then
      local fh = io.open(fpath, "r")
      local contents = fh:read("*all"):gsub("\r","")
      local cmd, inp, out = contents:match("^([^\n]*)\n<<<[ \t]*\n(.-\n)>>>[ \t]*\n(.*)$")
      assert(cmd ~= nil, "Command not found in " .. f)
      cmd = cmd:gsub("^(%S+)",cmdname)
      fun({ name = f:match("^(.*)%.test$"), path = fpath,
            command = cmd, input = inp or "", output = out or ""})
      fh:close()
    end
  end
end

local format = string.format

local function ansicolor(s)
  return string.char(27) .. '[' .. tostring(s) .. 'm'
end

local function show_diff(expected, actual)
  local difflines = diff.diff(expected, actual)
  for _,l in ipairs(difflines) do
    local text, status = l[1], l[2]
    if status == "in" then
      io.write(ansicolor(42) .. text .. ansicolor(0))
    elseif status == "out" then
      io.write(ansicolor(41) .. ansicolor(37) .. text .. ansicolor(0))
    else
      io.write(ansicolor(36) .. text .. ansicolor(0))
    end
  end
end

local function run_test(test)
  local tmp = os.tmpname()
  local tmph = io.open(tmp, "w")
  tmph:write(test.input)
  tmph:close()
  local cmd = test.command .. " " .. tmp
  local outh = io.popen(cmd, "r")
  local actual_out = outh:read("*all")
  outh:close()
  os.remove(tmp)
  io.write(test.name .. "...")
  if actual_out == test.output then
    io.write("PASS\n")
  else
    io.write("FAIL\n")
    io.write(cmd .. "\n")
    show_diff(test.output, actual_out)
  end
end

-- test:
do_matching_tests(arg[1], arg[2], run_test)
