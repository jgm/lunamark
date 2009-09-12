module(..., package.seeall)

function map(func, t)
  local new_t = {}
  for i,v in ipairs(t) do
    new_t[i] = func(v)
  end
  return new_t
end

function traverse_tree(f, t)
  for k,v in pairs(t) do
    if type(v) == "string" then
      f(v)
    else
      traverse_tree(f, v)
    end
  end
end

function to_string(t)
  local buffer = {}
  traverse_tree(function(x) table.insert(buffer,x) end, t)
  return table.concat(buffer)
end

function to_file(file, t)
  return traverse_tree(function(x) file:write(x) end, t)
end

function normalize_label(a)
  return string.upper(string.gsub(a, "[\n\r\t ]+", " "))
end

