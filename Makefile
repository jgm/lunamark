VERSION=0.3.3
REVISION=1
ROCKSPEC=lunamark-$(VERSION)-$(REVISION).rockspec
date=$(shell date +%x)
luas=lunamark.lua lunamark/*.lua lunamark/*/*.lua
testfile=tmptest.txt
benchtext=benchtext.txt
web=website
templatesdir=templates
NUM ?= 25
PROG ?= bin/lunamark
TESTOPTS ?= --tidy


all: build

build: $(ROCKSPEC)
	luarocks make $(ROCKSPEC)

.PHONY: build test testall check rock bench docs clean run-code-examples install website standalone

rock: $(ROCKSPEC)
	luarocks --local make $(ROCKSPEC)

check:
	luacheck bin/lunamark lunamark/*.lua lunamark/*/*.lua

test:
	LUAPATH="?.lua;lunamark/?.lua;lunamark/?/?.lua;$$LUAPATH"
	LUNAMARK_EXTENSIONS="" bin/shtest ${TESTOPTS} -d tests/Markdown_1.0.3 -p ${PROG} ${OPTS}
	LUNAMARK_EXTENSIONS="" bin/shtest ${TESTOPTS} -d tests/lunamark -p ${PROG} ${OPTS}

testall: test
	LUAPATH="?.lua;lunamark/?.lua;lunamark/?/?.lua;$$LUAPATH"
	LUNAMARK_EXTENSIONS="" bin/shtest ${TESTOPTS} -d tests/PHP_Markdown -p ${PROG} ${OPTS}

$(ROCKSPEC): rockspec.in
	sed -e "s/_VERSION/$(VERSION)/g; s/_REVISION/$(REVISION)/g" $< > $@

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

prof:
	lua -luatrace.profile ${PROG} ${benchtext} >/dev/null

coverage:
	-rm luacov.stats.out ; \
	LUNAMARK_EXTENSIONS="" bin/shtest ${TESTOPTS} -p "lua -lluacov ${PROG}" ${OPTS} ; \
	luacov

%.1: bin/%
	sed '1,/^@startman/d;/^@stopman/,$$d' $< | bin/lunamark -Xdefinition_lists,-smart -t man -s -d section=1,title=$(subst bin/,,$<),left_footer="${version}",date="${date}" -o $@

%.1.html: bin/% ${templatesdir}/man.html
	sed '1,/^@startman/d;/^@stopman/,$$d' $< | bin/lunamark -Xdefinition_lists,-smart -t html5 --template ${templatesdir}/man.html -s -d section=1,title=$(subst bin/,,$<),left_footer="${version}",date="${date}" -o $@

docs: doc lunamark.1 lunadoc.1 lunamark.1.html lunadoc.1.html

doc: ${luas} run-code-examples
	mkdir -p doc
	bin/lunadoc ${luas}

run-code-examples: lunamark.lua
	@echo Running code examples... ;\
	grep -e '^--     ' $< | sed -e 's/^--     //' | lua

install: ${luas}
	luarocks make

website: docs ${web}/index.html
	rm -r ${web}/doc ${web}/*.1.html
	cp -r doc lunamark.1.html lunadoc.1.html ${web}/

${web}/index.html: README.markdown ${templatesdir}/web.html
	bin/lunamark -Xdefinition_lists,smart --template ${templatesdir}/web.html -o $@ $<

standalone: ${luas}
	make -C standalone

clean:
	-rm -rf doc ${testfile} ${benchtext} lunamark.1 lunadoc.1
	make -C standalone clean
