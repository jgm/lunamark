--[[
With minor bug fixes by John MacFarlane 2011.

	Copyright (c) 2009 Christopher E. Moore ( christopher.e.moore@gmail.com / http://christopheremoore.net )

	Permission is hereby granted, free of charge, to any person obtaining a copy
	of this software and associated documentation files (the "Software"), to deal
	in the Software without restriction, including without limitation the rights
	to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
	copies of the Software, and to permit persons to whom the Software is
	furnished to do so, subject to the following conditions:

	The above copyright notice and this permission notice shall be included in
	all copies or substantial portions of the Software.

	THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
	IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
	FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
	AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
	LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
	OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
	THE SOFTWARE.
--]]

--[[
format of htmlparser.parse(s):

returns an indexed array of nodes representing the root nodes of a html tree

these nodes can be of either type objects:

	string:
		strings represent text leaf nodes within the tree

	table:
		tables are composed of the following properties:

			type: the type of the node.  could be one of the following:
				'tag'
				'cdata'
				'comment'

			str: if type is 'cdata', 'comment', or 'string' then this will hold the comment/cdata contents

			tag: if type is 'tag' then this holds the tag name.
			NOTE: tags with name 'script' or 'style' will only hold one child: a single string set to the script content

			attrs: if type is 'tag' then this holds an indexed array of objects with properties 'name' and 'value' defined
				if a html node has not attributes then this will be nil
			
			child: if type is 'tag' then this holds an indexed array of the child nodes of this node
				if a html node has not child then this will be nil

--]]

module('lunamark.htmlparser', package.seeall)

Parser = {}
Parser.__index = Parser

function new(page)
	local p = {
		lasttoken = '';
		thistoken = '';
		thiscol = 1;
		thisrow = 1;
		page = page;
		nodestack = {};
	}

	p.readtoken = coroutine.wrap(function()
		for i=1,#page do
			coroutine.yield(page:sub(i,i))
		end
	end)

	setmetatable(p, Parser)
	return p
end

function Parser:nexttoken()
	self.lasttoken = self.thistoken
	self.thistoken = self:readtoken()
	if self.thistoken == '\n' then
		if self.lasttoken ~= '\r' then
			self.thisrow = self.thisrow + 1
			self.thiscol = 0
		end
	elseif self.thistoken == '\r' then
		self.thisrow = self.thisrow + 1
		self.thiscol = 0
	else
		self.thiscol = self.thiscol + 1
	end
end

function Parser:parseerror(msg)
	error(self.thisrow..':'..self.thiscol..':'..(msg or ''))
end

function Parser:parseassert(test, msg)
	if not test then
		self:parseerror(msg)
	end
end

function Parser:parseassertmatch(a,b,msg)
	if not string.match(a,b) then
		self:parseerror((msg or '') .. ': '..tostring(a)..' does not match '..tostring(b))
	end
end

function Parser:canbe(pattern)
	if not self.thistoken then return false end
	if string.match(self.thistoken, pattern) then
		self:nexttoken()
		return true
	end
end

function Parser:mustbe(...)
	for _,pattern in ipairs{...} do
		self:parseassertmatch(self.thistoken, pattern)
		self:nexttoken()
	end
end

function Parser:spaces()
	while self:canbe('%s') do end
end

Parser.namepattern = '[%w_:%-]'
function Parser:name()
	self:mustbe(self.namepattern)
	local n = self.lasttoken
	while self:canbe(self.namepattern) do
		n = n .. self.lasttoken
	end
	return n
end

-- TODO - this goes slow
function Parser:strtil(capfinish, nodetype)
	local s = ''
	local capture = '^(.*)' .. capfinish .. '$'
	while self.thistoken do
		s = s .. self.thistoken
		self:nexttoken()
		local str = s:match(capture)
		if str then
			return {
				type=nodetype;
				str=str;
			}
		end
	end
	self:parseerror("found a non-terminating strtil deal "..nodetype)
end

-- already got <!
function Parser:comment()
	if self:canbe('%[') then
		if self:canbe('C') then
			self:mustbe('D','A','T','A','%%','%[')
			return self:strtil('%]%]>', 'cdata')
		else
			return self:strtil('%]>', 'preprocessor')
		end
	elseif self:canbe('%-') then
		self:mustbe('%-')
		return self:strtil('%-%->', 'comment')
	elseif self:canbe('D') then
		self:mustbe('O','C','T','Y','P','E')	-- there's probably a better way to optionally read a name...
		self:spaces()
		return self:strtil('>', 'doctype')
	end
end

-- already got <?
function Parser:xmlheader()
	return self:strtil('%?>', 'xmlheader')
end

function Parser:short(s)
	if #s < 10 then return s end
	return s:sub(1,10):gsub('[\r\n]','.')..'...('..#s..')'
end

-- already got </
function Parser:tagend()
	self:spaces()
	local n = self:name()
	self:spaces()
	self:mustbe('>')
	--print('reading closing tag '..self:short(n))
	return {
		type='closing';
		tag=n;
	}
end

function Parser:attrvalue()
	local quotetoken
	local s = {}
	do
		local lasttoken = self.thistoken
		if self:canbe("['\"]") then
			quotetoken = lasttoken
		else
			table.insert(s, lasttoken)
		end
	end
	while true do
		if quotetoken then
			if self:canbe(quotetoken) then
				return table.concat(s)
			end
		else
			-- don't use 'canbe' because we don't want to call nexttoken
			if self.thistoken and self.thistoken:match('[ >]') then
				return table.concat(s)
			end
		end
		table.insert(s, self.thistoken)
		self:nexttoken()
	end
end

Parser.htmlnonclosing = {
	br = true;
	img = true;
	meta = true;
	frame = true;
	area = true;
	hr = true;
	base = true;
	col = true;
	link = true;
	input = true;
	option = true;
	param = true;
}

-- already got <
function Parser:tagstart()
	-- closing tag...
	if self:canbe('/') then
		return self:tagend()
	end
	-- comment
	if self:canbe('!') then
		return self:comment()
	end
	-- xml header?
	if self:canbe('%?') then
		return self:xmlheader()
	end
	
	local t = {
		type='tag';
		child=true;	-- true means we should parse children (and replace with a table) 
	}

	self:spaces()
	t.tag = self:name()

	while true do
		self:spaces()
		if self:canbe('/') then
			self:mustbe('>')
			t.child = nil	-- turn off our 'parse children' flag
			return t
		end
		if self:canbe('>') then
			-- if it is an automatically closing tag then don't look for children
			if self.htmlnonclosing[t.tag:lower()] then
				t.child = nil
			end
			return t
		end
		local attr = {
			name = self:name();
		}
		if not attr.name then
			break
		end
		--print('  reading attr name '..attr.name)
		self:spaces()
		self:mustbe('=')
		self:spaces()
		-- this is fickle
		-- it is either a non-quoted chars-til-whitespace (or >)
		-- or a single-quoted or a double-quoted string
		attr.value = self:attrvalue()
		--print('  reading attr value '..attr.value)
		if not t.attrs then t.attrs = {} end
		table.insert(t.attrs, attr)
	end
	
	self:parseerror("shouldn't get this far")
end

-- tagname must be escaped
function Parser:tagofsinglestring(tagname)
	local s = ''
	local foundname = ''
	local closingindex
	local states = {
		-- states are arrays of pattern/nextstate
		openbrace = {};
		slash = {};
		openspace = {};
		tag = {};
		closespace = {};
	}
	states.openbrace.edges = {
		{reg='<', new=states.slash};
	}
	states.slash.enter = function()
		closingindex = #s-1
	end
	states.slash.edges = {
		{reg='/', new=states.openspace};
		{reg='<', new=states.slash};
		{new=states.openbrace};
	}
	states.openspace.edges = {
		{reg='[%w%-]', new=function() 
			foundname = self.thistoken
			return states.tag
		end};
		{reg='<', new=states.slash};
		{reg='[^%s]', new=states.openbrace};
	}
	states.tag.edges = {
		{reg='[%w%-]', new=function()
			foundname = foundname .. self.thistoken
			return states.tag
		end};
		{reg='<', new=states.slash};
		{reg='>', new=function()
			if foundname == tagname then
				return nil, s:sub(1,closingindex)
			end
			return states.openbrace
		end};
		{reg='%s', new=states.closespace};
		{new=states.openbrace};
	}
	states.closespace.edges = {
		{reg='>', new=function()
			if foundname == tagname then
				return nil, s:sub(1,closingindex)
			end
			return states.openbrace
		end};
		{reg='<', new=states.slash};
		{reg='[^%s]', new=states.openbrace};
	}
	local state = states.openbrace
	while self.thistoken do
		s = s .. self.thistoken
		for _,v in ipairs(state.edges) do
			if not v.reg or self.thistoken:match(v.reg) then
				local newstate = state
				if type(v.new) == 'table' then
					newstate = v.new
				elseif type(v.new) == 'function' then
					-- first argument is the new state
					-- second argument, if it exists, is the return node
					local nn
					newstate, nn = v.new()
					if nn then
						self:nexttoken()
						return nn
					end
				end
				if newstate ~= state then
					if state.exit then state.exit() end
					state = newstate
					if state.enter then state.enter() end
				end
				break
			end
		end
		self:nexttoken()
	end
end

function Parser:tag()
	local t = self:tagstart()
	if t.tag and (t.tag:lower() == 'script' or t.tag:lower() == 'style') then
		local tagcontent = self:tagofsinglestring(t.tag)
		if #tagcontent > 0 then
			t.child = {tagcontent}
		else 
			t.child = nil
		end
		return t
	end
	if not t.child then return t end
	local array, closer = self:tagarray(t)
	t.child = array	-- run until you find a closing tag of type t.tag
	if #t.child == 0 then t.child = nil end
	return t, closer
end

-- assumes we already have a [^<]
function Parser:leafstring()
	local s = ''
	while self:canbe('[^<]') do
		s = s .. self.lasttoken
	end
	return s
end

function Parser:tagarray(parent)
	local parenttag
	if parent then parenttag = parent.tag end
	if parent then table.insert(self.nodestack, parent) end
	--print('... entering child set of type '..tostring(parenttag))
	local array = {}
	while self.thistoken do
		-- self:spaces() -- JGM removed, as it collapses '<b>x</b> y'
		if self:canbe('<') then
			local ch, closer = self:tag()
			-- if closer then print('closing off multiple elements down to '..closer) end
			assert(ch.type ~= 'closing' or not closer, "we shouldn't have a closing tag and a closer returned")
			if ch.type == 'closing' or closer then
				closer = closer or ch.tag
				local closingindex
				for i=#self.nodestack,1,-1 do
					if self.nodestack[i].tag:lower() == closer:lower() then
						-- then close off all tags down to that one
						-- and longjump into it in the stack (i.e. the flatten-stack operation)
						-- this will be tricky...
						closingindex = i
						break
					end
				end

				--print('closing off down to '..closer..' and found index to be '..tostring(closingindex)..' of '..#nodestack)
				--io.write('nodestack:')
				--for _,v in ipairs(nodestack) do io.write('  '..v.tag) end
				--io.write('\n')
				
				if closingindex then
					-- if we did find the closing tag in the list then
					-- if it was on top of the stack then return our children
					if closingindex == #self.nodestack then
						if parent then table.remove(self.nodestack) end
						return array
					end
					-- otherwise return what we're closing off at the end
					-- to be dealt with by the parent
					if parent then table.remove(self.nodestack) end
					return array, ch.tag
				end
				-- if we didn't find the closing tag in our list then don't return the array
				-- because it didn't close anything off
			else
				table.insert(array, ch)
			end
		else
			table.insert(array, self:leafstring())
		end
	end
	return array
end

function Parser:base()
	return self:tagarray()
end

-- usage: Parser.new(_page):parse()
function Parser:parse()
	-- populate 'thistoken'
	self:nexttoken()
	-- and parse
	return self:base()
end

-- TODO - turn this into an instance method of the nodes' meta table
-- pretty printer while I'm here
function prettyprint(tree, tab, write)
	write = write or io.write
	tab = tab or 0
	local tabstr = string.rep('\t',tab)
	for i,n in ipairs(tree) do
		if type(n) == 'string' then
			write(tabstr..n..'\n')
		elseif type(n) == 'table' then
			if n.type == 'tag' then
				write(tabstr..'<' .. n.tag)
				if n.attrs then
					for _,a in ipairs(n.attrs) do
						write(' '..a.name..'="'..a.value..'"')
					end
				end
				if (not n.child or #n.child == 0) and n.tag:lower() ~= 'script' and n.tag:lower() ~= 'style' then
					write('/>\n')
				else
					write('>\n')
					if n.child then
						prettyprint(n.child, tab+1, write)
					end
					write(tabstr..'</'..n.tag..'>\n')
				end
			elseif n.type == 'cdata' then
				write(tabstr..'<![CDATA[' .. n.str .. ']]>\n')
			elseif n.type == 'comment' then
				write(tabstr..'<!--' .. n.str .. '-->\n')
			elseif n.type == 'doctype' then
				write(tabstr..'<!DOCTYPE '..n.str..'>\n')
			elseif n.type == 'preprocessor' then
				write(tabstr..'<!['..n.str..']>\n')
			elseif n.type == 'xmlheader' then
				write(tabstr..'<?'..n.str..'?>\n')
			else
				error("found child index "..i.." unknown node type: "..tostring(n.type))
			end
		else
			error("found child index "..i.." unknown lua type: "..tostring(type(n)))
		end
	end
end

function debugprintnode(k, n, tab)
	print(string.rep('\t',tab),k,'=>',n)
	if type(n) == 'table' then
		debugprint(n, tab+1)
	end
end

function debugprint(tree, tab)
	tab = tab or 0
	for k,n in pairs(tree) do
		-- technically this'll miss any numbers that are set beyond the largest contiguous 1-based index...
		if k ~= 'child' then
			debugprintnode(k,n,tab)
		end
	end
	if tree.child then
		debugprintnode('child', tree.child, tab)
	end
end

