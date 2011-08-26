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

Format of option table:

{ "top line of usage message",
  "rest of usage message (if absent, this is automatically generated)",
  optname = <argspec>,
  optname = <argspec>,
  ...
}

argspec is a table with the following fields:
* shortform - a single letter abbreviation
* arg - type of argument ("number" for numerical, "boolean" for boolean,
  "string" or anything else for string)
* optarg - if true, the argument is optional
* validate - function that takes an argument and returns a boolean
* description - description of option

Example: See test below.
--]]

local function is_option(s)
  if s:sub(1,1) == "-"  then return true end
end

local function usage(opt_table,defaults)
  io.write(opt_table[1])
  io.write("\n")
  if opt_table[2] then -- opt_table[2] if present overrides the automatic usage message
    io.write(opt_table[2])
  else
    for k,v in pairs(opt_table) do
      if type(k) ~= "number" then
        defaultval = defaults and defaults[k]
        if type(defaultval) == "string" or type(defaultval) == "number" then
          default = "(" .. tostring(defaults[k]) .. "*)"
        else
          default = ""
        end
        local optname, argspec, descr = "","",""
        optname = "--" .. k
        if v.shortform then
          optname = optname .. ",-" .. v.shortform
        end
        if v.arg then
          local vnice = v.arg
          if vnice == "boolean" then
            if defaultval then
              vnice = "true*|false"
            else
              vnice = "true|false*"
            end
          end
          if v.optarg then
            argspec = "["..vnice.."]"
          else
            argspec = vnice
          end
        end
        if v.description then
          descr = v.description
        end
        io.write(string.format("  %-30s %s %s\n", optname.." "..argspec, descr, default))
      end
    end
    io.write(string.format("  %-30s %s\n", "--help", "This message"))
  end
end

local function err(s,exit_code)
  io.stderr:write(s.."\n")
  os.exit(exit_code or 1)
end

local function getargs(opt_table, defaults)
  local opts = {}
  local args = defaults or {}
  local parseopts = true
  for k,v in pairs(opt_table) do
    if type(k) ~= "number" then
      v.optname = k
      opts["--"..k] = v
      if v.shortform then
        local vs = v
        vs.optname = k
        if opts["-"..v.shortform] then
          error("-"..v.shortform.." is defined twice.")
        else
          opts["-"..v.shortform] = vs
        end
      end
      if opt_table[k].repeatable then
        args[k] = args[k] or {}
      end
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
    if is_option(this) then
      local opt = opts[this]
      local optname = opt and opt.optname
      if this == "--" then  -- '--' stops option parsing
        parseopts = false
        i = i + 1
      elseif not opt then
        if this == "--help" then
          usage(opt_table, defaults)
          os.exit(0)
        end
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
        elseif opt.optarg then
          args[optname] = true
          i = i + 1
        else
          err("Option " .. this .. " requires a numerical argument.")
        end
      elseif opt.arg == "boolean" then 
        local v = possarg:lower()
        local b = false
        if v == "true" or v == "yes" or v == "on" then
          add_value(optname, true)
          i = i + 2
        elseif v == "false" or v == "no" or v == "off" then
          add_value(optname, false)
          i = i + 2
        elseif opt.optarg then
          args[optname] = true
          i = i + 1
        else
          err("Option " .. this .. " requires a boolean argument.")
        end
      else
        add_value(optname, possarg)
        i = i + 2
      end
      if opt and opt.validate then
        local valid, helpmsg = opt.validate(args[optname])
        if not valid then
          if helpmsg then
            err("Option " .. this .. " " .. helpmsg .. ".")
          else
            err("Option " .. this .. " has invalid value " .. possarg .. ".")
          end
        end
      end
    else -- argument or --longopt=value
      table.insert(args,this)
      i = i + 1
    end
  end
  return args
end

local test = function()
  local opts = { "myprog [opts] file - does something",
                 angle = {shortform = true, arg = "number", optarg = false,
                           validate = function(x) return (x>=0 and x<=360) end,
                           description = "Angle in degrees"},
                 verbose = {shortform = true, description = "Verbose output"},
                 venue = {arg = "string", repeatable = true},
                 output = {shortform = true, arg = "string", optarg = true},
               }
  local args = getargs(opts, { angle = 45 })
  for k,v in pairs(args) do
    if type(v) == "table" then
      for w,z in ipairs(v) do print(k,w,z) end
    else
      print(k,v)
    end
  end
end

return { getargs = getargs  }
