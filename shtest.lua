#!/usr/bin/env lua

local testdir = tests
local lfs = require("lfs")
local diff = require("diff")
local cmdname = "lunamark"
local tests_failed = 0
local tests_passed = 0

local function is_directory(path)
  return lfs.attributes(path, "mode") == "directory"
end

local function do_matching_tests(path, patt, fun)
  local patt = patt or "."
  local result = {}
  for f in lfs.dir(path) do
    local fpath = path .. "/" .. f
    if f ~= "." and f ~= ".." then
      if is_directory(fpath) then
        do_matching_tests(fpath, patt, fun)
      elseif fpath:match(patt) and fpath:match("%.test$") then
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
end

local format = string.format

local function ansicolor(s)
  return string.char(27) .. '[' .. tostring(s) .. 'm'
end

local function expectedcolor(s)
  return ansicolor(41) .. ansicolor(37) .. s .. ansicolor(0)
end

local function actualcolor(s)
  return ansicolor(42) .. s .. ansicolor(0)
end

local function bothcolor(s)
  return ansicolor(36) .. s .. ansicolor(0)
end

local function passcolor(s)
  return ansicolor(33) .. s .. ansicolor(0)
end

local function failcolor(s)
  return ansicolor(31) .. s .. ansicolor(0)
end

local function show_diff(expected, actual)
  io.write(expectedcolor("expected") .. actualcolor("actual") .. "\n")
  local tokenpattern = "[%s]"
  local difftoks = diff.diff(expected, actual, tokenpattern)
  for _,l in ipairs(difftoks) do
    local text, status = l[1], l[2]
    if status == "in" then
      io.write(actualcolor(text))
    elseif status == "out" then
      io.write(expectedcolor(text))
    else
      io.write(bothcolor(text))
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
  if actual_out == test.output then
    tests_passed = tests_passed + 1
    io.write(passcolor("[OK]") .. "     " .. test.path .. "\n")
  else
    tests_failed = tests_failed + 1
    io.write(failcolor("[FAILED]") .. " " .. test.path .. "\n")
    local worddiff = false
    show_diff(test.output, actual_out)
  end
end

-- test:
do_matching_tests(arg[1], arg[2], run_test)
io.write(string.format("Passed: %d\nFailed: %d\n", tests_passed, tests_failed))
os.exit(tests_failed)

