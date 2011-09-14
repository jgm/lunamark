version=$(bin/lunamark --version)
date=$(date "%Y-%m-%d")
luas=lunamark.lua lunamark/*.lua lunamark/*/*.lua

all:
	@echo Targets: test docs install clean

.PHONY: test docs clean install
test:
	-lua shtest.lua -p `pwd`/bin/lunamark $@

%.1: bin/%.lua
	prog=$(echo $< | sed -e 's/^bin\///' -e 's/\.lua$//') \
	sed '1,/^@startman/d;/^@stopman/,$d' $< | bin/lunamark -Xdefinition_lists,notes,-smart -t man -s -d section=1,title=$$prog,center_header="${version}",date="${date}" -o $$prog.1

docs: doc lunamark.1 lunadoc.1

doc: ${luas}
	mkdir -p doc
	bin/lunadoc ${luas}

install: ${luas}
	luarocks make

clean:
	-rm -rf doc
