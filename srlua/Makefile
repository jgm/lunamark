# makefile for srlua - modified for lunamark

UNAME := $(shell uname)

# these will probably work if Lua has been installed globally
LUA= /usr/local
LUAINC= $(LUA)/include
LUALIB= $(LUA)/lib
LUABIN= $(LUA)/bin

# probably no need to change anything below here
CC= gcc
CFLAGS= $(INCS) $(WARN) -O2 $G
WARN= -ansi -pedantic -Wall
INCS= -I$(LUAINC)
LIBS= -L$(LUALIB) -llua -lm -ldl
BYTECODE= lunamark.lub
LUNAMARK= ..

ifeq ($(UNAME), Darwin)
EXPORT=
else
EXPORT= -Wl,-E
endif

TARGET= lunamark
S= srlua
OBJS= srlua.o

all: $(TARGET)

$(BYTECODE): $(LUNAMARK)/bin/lunamark $(LUNAMARK)/lunamark/util.lua $(LUNAMARK)/lunamark/cmdopts.lua $(LUNAMARK)/lunamark/reader/markdown.lua $(LUNAMARK)/lunamark/writer/html.lua $(LUNAMARK)/lunamark/writer/html5.lua
	luac -o $(BYTECODE) $^

$(TARGET): $S glue $(BYTECODE)
	./glue $S $(BYTECODE) $(TARGET)
	chmod +x $(TARGET)

$S:	$(OBJS)
	$(CC) -o $@ $(EXPORT) $(OBJS) $(LIBS)

clean:
	rm -f $(OBJS) $(TARGET) $S core core.* a.out *.o glue $(BYTECODE)

