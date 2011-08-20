lunamark.lub:bin/lunamark lunamark/util.lua lunamark/cmdopts.lua lunamark/reader/markdown.lua lunamark/writer/html.lua lunamark/writer/html5.lua
	luac -o $@ $^

.PHONY: clean
clean:
	-rm lunamark.lub

