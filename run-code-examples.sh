#!/bin/sh
# runs the code examples in lunamark.lua
grep -e '^--     ' lunamark.lua | sed -e 's/^--     //' > tmp.lua
lua tmp.lua
