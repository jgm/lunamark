module(..., package.seeall)

function to_string(t)
  local result = ""
  for k, v in pairs(t) do
    if type(v) == "string" then
      result = result .. v
    else
      result = result .. to_string(v)
    end
  end
  return result
end

function to_file(f, t)
  for k,v in pairs(t) do
    if type(v) == "string" then
      f:write(v)
    else
      to_file(f, v)
    end
  end
end

function map(func, t)
  local new_t = {}
  for i,v in ipairs(t) do
    new_t[i] = func(v)
  end
  return new_t
end

function normalize_label(a)
  return string.upper(string.gsub(a, "[\n\r\t ]+", " "))
end

