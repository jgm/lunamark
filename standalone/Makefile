OBJS=lpeg.o slnunico.o
COPT= -O2 -DNDEBUG
CWARNS= -Wall -Wextra -pedantic
CC=gcc $(COPT) $(CWARNS) -I$(LUADIR) -L$(LUADIR)
LUADIR=lua
PROG ?= ./lunamark
TESTOPTS ?= --tidy
NUM ?= 25
benchtext=benchtext.txt
testfile=tmptest.txt

.PHONY : all test
all : lunamark lunamark.1

lunamark: lunamark.c main.squished.lua.embed $(OBJS) $(LUADIR)/liblua.a
	$(CC) -o $@ $< $(OBJS) -llua -lm -ldl

$(LUADIR)/liblua.a : $(wildcard $(LUADIR)/*.h) $(wildcard $(LUADIR)/*.c) $(LUADIR)/Makefile
	make liblua.a -C $(LUADIR) MYCFLAGS=-DLUA_USE_LINUX
	# note: LUA_USE_LINUX is recommended for linux, osx, freebsd

main.squished.lua : src/main.lua $(wildcard src/*.lua) $(wildcard src/*/*.lua) $(wildcard src/*/*/*.lua)
	(cd src && lua ../squish.lua)

lpeg.o : lpeg.c lpeg.h $(LUADIR)/liblua.a

slnunico.o : slnunico.c slnudata.c

%.embed : %
	xxd -i $< > $@

lunamark.1 : src/main.lua lunamark
	sed '1,/^@startman/d;/^@stopman/,$$d' $< | ./lunamark -Xdefinition_lists,notes,-smart -t man -s -d section=1,title=$(subst bin/,,$<),left_footer="${version}",date="${date}" -o $@

test:
	LUNAMARK_EXTENSIONS="" scripts/shtest ${TESTOPTS} -p ${PROG} ${OPTS}

${benchtext}:
	for i in tests/Markdown_1.0.3/*.test; do sed -e '1,/<<</d;/>>>/,$$d' "$$i" >> $@; echo >> $@.txt; done

${testfile}: ${benchtext}
	cat < /dev/null > ${testfile} ; \
	x=${NUM}; \
	while [ $$x -gt 0 ]; do \
		cat $< >> $@; \
		x=$$(($$x-1)); \
	done

bench: ${testfile}
	time -p ${PROG} < ${testfile} > /dev/null

clean:
	make -C $(LUADIR) clean
	rm $(lunamarkS) $(OBJS) lunamark main.squished.lua.embed lunamark.1
	rm ${benchtext} ${testfile}
