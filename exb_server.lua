--- This is the server script that runs the websocket/http server
-- @author Russell Haley, Created with IntelliJ IDEA.
-- @copyright 2016
-- @license BSD 2 Clause. See License.txt

local nice_server = require "nice_server"
local websocket = require "http.websocket"
local dkjson = require "dkjson"
local serpent = require "serpent"

local configuration = require "configuration"

local conf = configuration.new([[exb_server.conf]])

function PrintTable(t)
    for k, v in pairs(t) do
        print(k, v)
    end
end


--local timeout = 2

--- Reply is where we process the request from the client.
-- The system upgrades to a websocket if the ws or wss protocols are used.
-- @param resp A table with response meta data retrieved from the request.
-- This would typically be used in an http response.
local function reply(resp)


    for k, v in pairs(resp.request_headers) do
        print(k, v)
    end

    local scheme = resp.request_headers:get(":scheme")
    local upgrade
    if resp.request_headers:get("upgrade") then
        upgrade = resp.request_headers:get("upgrade")
    else
        upgrade = "none"
    end
    local sws_version

    if resp.request_headers:get("sec-websocket-version") then
        sws_version = tonumber(resp.request_headers:get("sec-websocket-version"))
    else
        sws_version = 0
    end



    if scheme:upper() == "HTTP" then

        if upgrade:upper() == "WEBSOCKET" and sws_version >= 13 then
            local ws = websocket.new_from_stream(resp.stream, resp.request_headers)
            assert(ws:accept())
            assert(ws:send("Welcome To exb Server"))

            repeat
                local data = assert(ws:receive())
                if data ~= nil then
                    local json, pos, err = dkjson.decode(data, 1, nil)
                    if not err then
                        print(serpent.dump(json))

                        if json[1] == "ECHO" then
                            print "echo echo echoecho..."
                            ws:send("echo2")
                        elseif json[1] == "TO BAD SAM" then
                            print "Nice knownin ya bud"
                            ws:send("echo2")
                        elseif json[1] == "ECHO3" then
                            print "now this is just silly"
                            ws:send("echo2")
                        end
                    else
                        print(data)
                        print(err)
                        ws:send(data)
                    end
                else
                    print "NIL DATA"
                end

            until not data or data == "QUIT"
        else
            resp.body = "No can do bub"
        end
    else
        resp.body = "Not an http request"
    end

    --Not used right now.
    --local req_body = assert(resp.stream:get_body_as_string(timeout))
    --local req_body_type = resp.request_headers:get "content-type"

    --1) check the request type. If it's a ws connection, then upgrade it?

    --This would be used in standard http web server

    --    resp.headers:upsert(":status", "200")
    --    resp.headers:append("content-type", req_body_type or "text/plain")
    --    resp:set_body("I don't think so bub")
end

assert(nice_server.new {
    host = conf.host;
    port = conf.port;
    reply = reply;
}:loop())
