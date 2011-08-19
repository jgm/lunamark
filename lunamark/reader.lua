local G = {}

setmetatable(G,{ __index = function(t,name)
                             local mod = require("lunamark.reader." .. name)
                             rawset(t,name,mod)
                             return t[name]
                            end })

return G
