/*
* srlua.c
* Lua interpreter for self-running programs
* Luiz Henrique de Figueiredo <lhf@tecgraf.puc-rio.br>
* 20 Mar 2009 21:05:59
* This code is hereby placed in the public domain.
*/

#ifdef _WIN32
#include <windows.h>
#endif

#include <errno.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "glue.h"
#include "lua.h"
#include "lualib.h"
#include "lauxlib.h"

/*
** $Id: linit.c,v 1.14.1.1 2007/12/27 13:02:25 roberto Exp $
** Initialization of libraries for lua.c
** See Copyright Notice in lua.h
*/


#define linit_c
#define LUA_LIB

#include "lua.h"
#include "lpeg.h"
#include "lpeg.c"
#include "lualib.h"
#include "lauxlib.h"


static const luaL_Reg lualibs[] = {
  {"", luaopen_base},
  {LUA_LOADLIBNAME, luaopen_package},
  {LUA_TABLIBNAME, luaopen_table},
  {LUA_IOLIBNAME, luaopen_io},
  {LUA_OSLIBNAME, luaopen_os},
  {LUA_STRLIBNAME, luaopen_string},
  {LUA_MATHLIBNAME, luaopen_math},
  {LUA_DBLIBNAME, luaopen_debug},
  {"lpeg",luaopen_lpeg},
  {NULL, NULL}
};


LUALIB_API void luaL_openlibs (lua_State *L) {
  const luaL_Reg *lib = lualibs;
  for (; lib->func; lib++) {
    lua_pushcfunction(L, lib->func);
    lua_pushstring(L, lib->name);
    lua_call(L, 1, 0);
  }
}

typedef struct
{
 FILE *f;
 long size;
 char buff[512];
} State;

static const char *myget(lua_State *L, void *data, size_t *size)
{
 State* s=data;
 size_t n;
 if (s->size<=0) return NULL;
 n=(sizeof(s->buff)<=s->size)? sizeof(s->buff) : s->size;
 n=fread(s->buff,1,n,s->f);
 if (n==-1) return NULL;
 s->size-=n;
 *size=n;
 return s->buff;
}

#define cannot(x) luaL_error(L,"cannot %s %s: %s",x,name,strerror(errno))

static void load(lua_State *L, const char *name)
{
 Glue t;
 State S;
 FILE *f=fopen(name,"rb");
 if (f==NULL) cannot("open");
 if (fseek(f,-sizeof(t),SEEK_END)!=0) cannot("seek");
 if (fread(&t,sizeof(t),1,f)!=1) cannot("read");
 if (memcmp(t.sig,GLUESIG,GLUELEN)!=0) luaL_error(L,"no Lua program found in %s",name);
 if (fseek(f,t.size1,SEEK_SET)!=0) cannot("seek");
 S.f=f; S.size=t.size2;
 if (lua_load(L,myget,&S,"=")!=0) lua_error(L);
 fclose(f);
}

static int pmain(lua_State *L)
{
 char **argv=lua_touserdata(L,1);
 int i;
 lua_gc(L,LUA_GCSTOP,0);
 luaL_openlibs(L);
 lua_gc(L,LUA_GCRESTART,0);
 load(L,argv[0]);
 for (i=1; argv[i]; i++) ; /* count */
 lua_createtable(L,i-1,1);
 for (i=0; argv[i]; i++)
 {
  lua_pushstring(L,argv[i]);
  lua_rawseti(L,-2,i);
 }
 lua_setglobal(L,"arg");
 luaL_checkstack(L,i-1,"too many arguments to script");
 for (i=1; argv[i]; i++)
 {
  lua_pushstring(L,argv[i]);
 }
 lua_call(L,i-1,0);
 return 0;
}

static void fatal(const char* progname, const char* message)
{
#ifdef _WIN32
 MessageBox(NULL,message,progname,MB_ICONERROR | MB_OK);
#else
 fprintf(stderr,"%s: %s\n",progname,message);
#endif
 exit(EXIT_FAILURE);
}

int main(int argc, char *argv[])
{
 lua_State *L;
#ifdef _WIN32
 char name[MAX_PATH];
 argv[0]= GetModuleFileName(NULL,name,sizeof(name)) ? name : NULL;
#endif
 if (argv[0]==NULL) fatal("srlua","cannot locate this executable");
 L=lua_open();
 if (L==NULL) fatal(argv[0],"not enough memory for state");
 if (lua_cpcall(L,pmain,argv)) fatal(argv[0],lua_tostring(L,-1));
 lua_close(L);
 return EXIT_SUCCESS;
}
