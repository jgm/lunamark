#!/usr/bin/env lua

local lfs = require("lfs")
local diff = require("diff")
local alt_getopt = require("alt_getopt")
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
  local actual = outh:read("*all")
  local expected = test.output
  outh:close()
  os.remove(tmp)
  if actual == expected then
    tests_passed = tests_passed + 1
    io.write(passcolor("[OK]") .. "     " .. test.path .. "\n")
  else
    tests_failed = tests_failed + 1
    io.write(failcolor("[FAILED]") .. " " .. test.path .. "\n")
    local worddiff = false
    show_diff(expected, actual)
  end
end

-- main program

local version = [[
shtest.lua 0.1
Copyright (C) 2009-2011 John MacFarlane
]]

local usage = [[
Usage: shtest.lua [options] [pattern] - run shell tests

Options:
  --dir,-d PATH      Directory containing .test files (default tests)
  --normalize,-n     Normalize whitespace in output
  --version,-V       Version information
  --help,-h          This message
]]

local long_opts = {
  dir = "d",
  normalize = "n",
  version = "V",
  help = "h"
}

local short_opts = "d:nVh"
local optarg,optind = alt_getopt.get_opts(arg, short_opts, long_opts)

if optarg.h then
  io.write(usage)
  os.exit(0)
end

if optarg.V then
  io.write(version)
  os.exit(0)
end

local testdir = optarg.d or "tests"
local pattern = arg[optind]
local normalize = optarg.n

do_matching_tests(testdir, pattern, run_test)
io.write(string.format("Passed: %d\nFailed: %d\n", tests_passed, tests_failed))
os.exit(tests_failed)
