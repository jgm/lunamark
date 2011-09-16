version=$(bin/lunamark --version)
date=$(date "%Y-%m-%d")
luas=lunamark.lua lunamark/*.lua lunamark/*/*.lua
testfile=tmptest.txt
benchtext=benchtext.txt
PROG ?= bin/lunamark
NUM ?= 25

all:
	@echo Targets: test bench docs run-code-examples install clean

.PHONY: test bench docs clean run-code-examples install
test:
	-lua shtest.lua -p "${PROG}" $@

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
	time --format "real %es  user %Us  sys %Ss" ${PROG} < ${testfile} > /dev/null

%.1: bin/%
	sed '1,/^@startman/d;/^@stopman/,$$d' $< | bin/lunamark -Xdefinition_lists,notes,-smart -t man -s -d section=1,title=$$prog,center_header="${version}",date="${date}" -o $(subst .1,,$@).1

docs: doc lunamark.1 lunadoc.1

doc: ${luas} run-code-examples
	mkdir -p doc
	bin/lunadoc ${luas}

run-code-examples: lunamark.lua
	@echo Running code examples... ;\
	grep -e '^--     ' $< | sed -e 's/^--     //' | lua

install: ${luas}
	luarocks make

clean:
	-rm -rf doc ${testfile} lunamark.1 lunadoc.1
