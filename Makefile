version=$(shell bin/lunamark --version | head -1)
date=$(shell date +%x)
luas=lunamark.lua lunamark/*.lua lunamark/*/*.lua
testfile=tmptest.txt
benchtext=benchtext.txt
web=website
templatesdir=templates
PROG ?= bin/lunamark
NUM ?= 25

all:
	@echo Targets: test bench docs run-code-examples install clean

.PHONY: test bench docs clean run-code-examples install website
test:
	LUNAMARK_EXTENSIONS="" lua shtest.lua -p ${PROG} ${OPTS}

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

%.1: bin/%
	sed '1,/^@startman/d;/^@stopman/,$$d' $< | bin/lunamark -Xdefinition_lists,notes,-smart -t man -s -d section=1,title=$(subst bin/,,$<),left_footer="${version}",date="${date}" -o $@

%.1.html: bin/% ${templatesdir}/man.html
	sed '1,/^@startman/d;/^@stopman/,$$d' $< | bin/lunamark -Xdefinition_lists,notes,-smart -t html5 --template ${templatesdir}/man.html -s -d section=1,title=$(subst bin/,,$<),left_footer="${version}",date="${date}" -o $@

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

${web}/index.html: README.markdown ${templatesdir}/web.html
	bin/lunamark -Xdefinition_lists,notes,smart --template ${templatesdir}/web.html -o $@ $<

clean:
	-rm -rf doc ${testfile} ${benchtext} lunamark.1 lunadoc.1
