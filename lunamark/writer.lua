-- (c) 2009-2011 John MacFarlane.  Released under MIT license.
-- See the file LICENSE in the source for details.

local G = {}

setmetatable(G,{ __index = function(t,name)
                             local mod = require("lunamark.writer." .. name)
                             rawset(t,name,mod)
                             return t[name]
                            end })

return G
