--[[
simple command line parser (c) 2011 John MacFarlane

Features:

* automatic --help/-h usage message
* options can be given a short form (--verbose/-v)
* option values can be optional, and can be typed string or number
* options can be made repeatable, in which case they return a table
* option values can be validated
* short options can be consolidated
* short option values can be given as -r 22 or -r22
* long option values can be given as --radius 22 or --radius=22
* options and arguments can be mixed, unless opts_before_args is true
* in any case, -- ends option parsing

Example: See test below.
--]]

local function is_option(s)
  if s:sub(1,1) == "-"  then return true end
end

local function usage(topmessage, opts)
  io.write(topmessage)
  io.write("\n")
  for k,v in pairs(opts) do
    local optname, argspec, descr = "","",""
    optname = "--" .. k
    if v.shortform then
      optname = optname .. ",-" .. k:sub(1,1)
    end
    if v.arg then
      if v.optarg then
        argspec = "["..v.arg.."]"
      else
        argspec = v.arg
      end
    end
    if v.description then
      descr = v.description
    end
    io.write(string.format("  %-30s %s\n", optname .. " " .. argspec, descr))
  end
end

local function err(s,exit_code)
  io.stderr:write(s.."\n")
  os.exit(exit_code or 1)
end

local function getargs(message, opt_table, opts_before_args)
  local opts = {}
  local args = {}
  local parseopts = true
  for k,v in pairs(opt_table) do
    v.optname = k
    opts["--"..k] = v
    if v.shortform then
      local vs = v
      local firstletter = k:sub(1,1)
      vs.optname = firstletter
      if opts["-"..firstletter] then
        error("-"..firstletter.." is defined twice.")
      else
        opts["-"..firstletter] = vs
      end
    end
    if opt_table[k].repeatable then
      args[k] = {}
    end
  end
  local function add_value(k,v)
    if type(args[k]) == "table" then
      table.insert(args[k],v)
    else
      args[k] = v
    end
  end
  local i = 1
  while i <= table.getn(arg) do
    local this, possarg = arg[i], arg[i+1]
    if this == "--help" or this == "-h" then
      usage(message,opt_table)
      os.exit(0)
    end
    if is_option(this) then
      local opt = opts[this]
      local optname = opt and opt.optname
      if this == "--" then  -- '--' stops option parsing
        parseopts = false
        i = i + 1
      elseif not opt then
        local longoptname, longoptval = this:match("(--%a+)=(.*)")
        if longoptval then   --opt=val
          table.remove(arg,i)
          table.insert(arg,i,longoptname)
          table.insert(arg,i+1,longoptval)
        elseif this:sub(1,2) ~= "--" and #this > 2 then  -- -cvrt33
          local x, y, rest = this:sub(2,2), this:sub(3,3), this:sub(4)
          table.remove(arg,i)
          table.insert(arg,i,"-" .. x)
          if opts["-"..x] and opts["-"..x].arg then
            table.insert(arg,i+1,y..rest)
          else
            table.insert(arg,i+1,"-" .. y .. rest)
          end
        else
          err("Unknown option " .. this .. ".")
        end
      elseif not opt.arg then
        args[optname] = true
        i = i + 1
      elseif not possarg or is_option(possarg) then  -- no argument
        if opt.optarg then
          args[optname] = true
          i = i + 1
        else
          err("Option " .. this .. " requires an argument.")
        end
      elseif opt.arg == "number" then
        local num = tonumber(possarg)
        if num then
          add_value(optname, num)
          i = i + 2
        else
          err("Option " .. this .. " requires a numerical argument.")
        end
      else
        add_value(optname, possarg)
        i = i + 2
      end
      if opt and opt.validate and not opt.validate(args[optname]) then
        err("Option " .. this .. " has illegal value. ")
      end
    else -- argument or --longopt=value
      table.insert(args,this)
      i = i + 1
      if opts_before_args then parseopts = false end
    end
  end
  return args
end

local test = function()
  local opts = { angle = {shortform = true, arg = "number", optarg = false,
                           validate = function(x) return (x>=0 and x<=360) end,
                           description = "Angle in degrees"},
                 verbose = {shortform = true, description = "Verbose output"},
                 venue = {arg = "string", repeatable = true},
                 output = {shortform = true, arg = "string", optarg = true},
               }
  local args = getargs("my function [opts] [file..]",opts)
  for k,v in pairs(args) do
    if type(v) == "table" then
      for w,z in ipairs(v) do print(k,w,z) end
    else
      print(k,v)
    end
  end
end

test()
