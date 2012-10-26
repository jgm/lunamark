#include <stdlib.h>
#include <stdio.h>

/* Include the Lua API header files. */
#include <lua.h>
#include <lauxlib.h>
#include <lualib.h>

#include "lpeg.h"
#include "main.squished.lua.embed"

int luaopen_lpeg (lua_State *L);
int luaopen_unicode (lua_State *L);

int main( int argc, char *argv[] )
{
    lua_State *L = lua_open();

    /* command line args */
    lua_newtable(L);
    if (argc > 0) {
      int i;
      for (i = 1; i < argc; i++) {
        lua_pushnumber(L, i);
        lua_pushstring(L, argv[i]);
        lua_rawset(L, -3);
      }
    }
    lua_setglobal(L, "arg");

    /* load the libs */
    luaL_openlibs(L);
    luaopen_lpeg(L);
    luaopen_unicode(L);

    luaL_loadbuffer(L, main_squished_lua, main_squished_lua_len, "main_squished_lua");

    if (lua_pcall(L, 0, LUA_MULTRET, 0) != 0) {
      lua_error(L);
    }

    lua_close(L);

    return 0;
}
