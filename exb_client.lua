--- Opens a websocket connection with
-- the server_url option specified in the client conf file.
-- @author Russell Haley, Created with IntelliJ IDEA.
-- @copyright 2016
-- @license BSD 2 Clause. See License.txt

--- The cqueue library
local cqueues = require "cqueues"
--- lua-http websockets
local websocket = require "http.websocket"
--- json parser for converting tables to json
local json = require "dkjson"
--- a base message. I'm not very good at
-- Prototyping in Lua yet
local message1 = require "message_base"
--- See: instrumentation.lua
local instrumentation = require "instrumentation"
--- See: configuration.lua
local configuration = require "configuration"
--- A little library for file manipulation,
-- familiar patterns for a C# developer.
local file = require "file"

--Lua only serializer package.
--local serialize = require "ser"
--Used to generate Cyclicle Redundancy Checksum
--local CRC = require 'crc32lua'

local i = instrumentation.new("exb_client.conf")
local upd = i.UpdateInstrumentation

--local conf = configuration.new("/etc/rc.conf",true)
local conf = configuration.new("exb_client.conf", false, false)
i.debug_file_path = conf.base_path .. "/" .. conf.debug_file_name
local debug_file;

local cq;

local ws;

--- Shutdown flag. Set to True to end all processes
local Shutdown = false
--- Debug flag. Enables Debugging output from the client.
DEBUG = arg[1] or false

local function Log(level, fmt, ...)
    local msg = os.date("%Y-%m-%d_%H%M%S") .. " - " .. level .. ": "
    for _, v in ipairs { ... } do
        msg = msg .. " " .. string.format(fmt, v);
    end
    msg = msg .. "\n"
    if DEBUG then
        print(msg)
    end
    return debug_file:write(msg)
end

--- Writes errors to a file.
-- This needs serious work, or you should
-- just get a proper logger.
-- param: errno The error number provided by the exit call
-- param: err The error message provided by the exit call
-- param: debugOut true outputs the info to stdio
local function LogError(err, errno, ...)
    if not errno then errno = "" end
    if not err then err = "" end
    Log("Error", "%s", err, errno, ...)
end

--- Writes a line to the log. Appends Linefeed.
-- param: message - string for logging
local function LogInfo(message)
    Log("Info", "%s", message)
end



--- Get a UUID from the OS
-- return: Returns a system generated UUID
-- such as "4f1c1fbe-87a7-11e6-b146-0c54a518c15b"
-- usage: 4f1c1fbe-87a7-11e6-b146-0c54a518c15b
local function GetUUID()
    local handle = io.popen("uuidgen")
    local val, lines
    if handle then
        val, lines = handle:read("*a")
        --Don't remembe what this does, I think
        -- it strips whitespace?
        val = val:gsub("^%s*(.-)%s*$", "%1")
    else
        WriteError(0, "Failed to generate UUID");
    end
    return val
end

--- InitReceive. Starts the CQ wrap that listens on the websocket
-- param: cq - The cqueue to which we will add the routine
-- param: ws - The websocket reference
local function Receive()
    repeat
        LogInfo("open receive")
        --need to check the websocket first and connect it if it's down.
        local response, err, errno = ws:receive() -- does this return an error message if it fails?
        if not response then
            LogError(err, errno, "Recieve Failed. ", debug.traceback())
        else
            print("response: " .. response .. " sizeof: " .. #response)
        end
        LogInfo("looping...")
        cqueues.sleep(3)
    until Shutdown == true
end

--- InitStatusUpdate. Starts the cqueue wrap for sending
-- status updates to the server.
-- param: cq - The cqueue to which we will add the routine
-- param: ws - The websocket reference
-- param: sleepPeriod - The periodicity of the status update
local function StatusUpdate(sleepPeriod)
    repeat
        print(ws.readyState)
        if ws.readyState == 1 then --This doesn't seem to fail when the server goes away?
        --Check if our websocket is still working first.
        --if not, go back to sleep
        local msg = message1.new()
        msg.uuid = GetUUID()
        local items = i.ReadInstrumentation()
        for k, v in pairs(items) do
            msg.body[k] = v
        end

        str = json.encode(msg)
        local ok, err, errno = ws:send(str)
        if not ok then
            LogInfo("send failed.")
            LogError(err, errno, "Send Failed. ", debug.traceback())
        end
        else
            LogInfo("Skipped sending, ws not ready")
        end
        --This value should come from the config file.
        cqueues.sleep(sleepPeriod)
    until Shutdown == true
end



--- InitDebugInput. Creates sample data for testing.
-- param: cq - The cqueue to which we will add the routine
local function DebugInput()
    repeat
        local bt = "board_temperature"
        local nv = "new_value_2"

        local bt_val
        local nv_val

        --        local i
        --        i = 6

        bt_val = 152
        nv_val = 999

        if i[bt] ~= nil then
            bt_val = i[bt] + 152
        end
        upd(bt, bt_val)

        if i[nv] ~= nil then
            nv_val = i[nv] + 3
        end

        upd(nv, nv_val)

        if DEBUG then
            print(nv, nv_val)
            print(bt, bt_val)
            print(Shutdown)
        end
        cqueues.sleep(10)
    until Shutdown == true
end

local function StopServices()
    Shutdown = true
    ws:close()
    LogInfo("System shutdown initiated.")
end


--- InitStdioInput. A cq wrap for input from stdio. It's
-- purpose is for manual inupt and debugging.
-- param: cq - The cqueue to which we will add the routine
local function StdioInput()
    repeat
        io.stdout:write("Input> ")
        cqueues.poll({ pollfd = 0; events = "r" }) -- wait until data ready to read on stdin
        local data = io.stdin:read "*l" -- blockingly read a line. shouldn't block if tty is in line buffered mode.
        print(data)
        if data:upper() == "SHUTDOWN" then StopServices() end;
    until Shutdown == true
end


local function Run()

    debug_file = io.open(i.debug_file_path, 'a')

    LogInfo("Starting client service on " .. os.date("%b %d, %Y %X"))

    cq = cqueues.new()
    ws = websocket.new_from_uri("ws://" .. conf.server_url .. ":" .. conf.server_port)

    cq:wrap(Receive)
    cq:wrap(StdioInput)
    cq:wrap(DebugInput)
    cq:wrap(StatusUpdate, conf.status_period)

    repeat
        local ws_ok, err, errno = ws:connect()
        if ws_ok then
            LogInfo("Connected to ..how do I get the address back?")
            cq:loop()
            --If this falls out, check for errors before looping again
        else
            LogError(err, errno)
            LogInfo("Failed to connect. Sleeping for " .. conf.connect_sleep)
            cqueues.sleep(conf.connect_sleep)
        end

    until Shutdown == true

    --[[repeat
        local cq_ok, msg, errno = cq:step()
        if cq_ok then
            LogInfo("Step")
        else

            LogInfo("The main cqueue failed to step.")
            LogError(errno, msg)
        end
    until Shutdown == true or cq:empty()
    ws:close()]]

    --[[To get the error from step() --
    -- local cq_ok, msg, errno, thd = cq:step(); if not cq_ok then print(debug.traceback(thd, msg)) end
    -- ]]
end


Run()


--local http_request = require "http.request"
--local headers, stream = assert(http_request.new_from_uri("http://example.com"):go())
--local body = assert(stream:get_body_as_string())
--if headers:get ":status" ~= "200" then
--    error(body)
--end
--print(body)


