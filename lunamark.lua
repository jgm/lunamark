-- (c) 2009-2011 John MacFarlane.  Released under MIT license.
-- See the file LICENSE in the source for details.

--[[|
Usage:

    lunamark = require("lunamark")

and then all the lunamark modules will be available.
So, for example, one can refer to `lunamark.reader.markdown`.
Modules are not loaded until they are actually needed, so
it is safe to `require("lunamark")` even if you only intend to
use one reader and one writer.
]]--

local G = {}

setmetatable(G,{ __index = function(t,name)
                             local mod = require("lunamark." .. name)
                             rawset(t,name,mod)
                             return t[name]
                            end })

return G
