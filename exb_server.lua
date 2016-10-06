--[[
A simple HTTP server
If a request is not a HEAD method, then reply with "Hello world!"
Usage: lua examples/server_hello.lua [<port>]
]]

local port = arg[1] or 0 -- 0 means pick one at random

local http_server = require "http.server"
local http_headers = require "http.headers"
local dkjson = require "dkjson"
local serpent = require "serpent"

local function reply(myserver, stream) -- luacheck: ignore 212
	-- Read in headers
	local req_headers = assert(stream:get_headers())
	local req_method = req_headers:get ":method"

	-- Log request to stdout
	assert(io.stdout:write(string.format('[%s] "%s %s HTTP/%g"  "%s" "%s"\n',
		os.date("%d/%b/%Y:%H:%M:%S %z"),
		req_headers:get(":method") or "",
		req_headers:get(":path") or "",
		stream.connection.version,
		req_headers:get("referer") or "-",
		req_headers:get("user-agent") or "-"
	)))
local ws = websocket.new_from_stream(resp.stream, resp.request_headers)
if ws then
    assert(ws:accept())
    assert(ws:send("Welcome To exb Server."))

    repeat
        local data = ws:receive()
        if data ~= nul then
            local json, pos,err = dkjson.decode(data,1,nil)
            if json then
                print(serpent.dump(json))
            end
        end
    until not data
else

	-- Build response headers
	local res_headers = http_headers.new()
	res_headers:append(":status", "200")
	res_headers:append("content-type", "text/plain")
	-- Send headers to client; end the stream immediately if this was a HEAD request
	assert(stream:write_headers(res_headers, req_method == "HEAD"))
	if req_method ~= "HEAD" then
		-- Send body, ending the stream
		assert(stream:write_chunk("Hello world!\n", true))
	end
end
end

local myserver = http_server.listen {
	host = "localhost";
	port = port;
	onstream = reply;
}
-- Manually call :listen() so that we are bound before calling :localname()
assert(myserver:listen())
do
	local bound_port = select(3, myserver:localname())
	assert(io.stderr:write(string.format("Now listening on port %d\n", bound_port)))
end
-- Start the main server loop
assert(myserver:loop())
