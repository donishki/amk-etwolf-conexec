-- Conditional commands execution.

-- Global variables are exposed to configuration file.
PLAYERS = 0
SPECTATORS = 0
MAPNAME = "none"
MAPTIME = 0
TIMELIMIT = 0
GAMESTATE = -1

local rules = {}
local config = "conexec.cfg"
local startup = true
local futures = {}
local baseLevelTime = nil

-- MAPTIME, TIMELIMIT and GAMESTATE update frequency in milliseconds,
-- set to zero to turn it off completely.
local timefreq = 10000

-- Time of delay before first execution in milliseconds.
local delay = 10000

function et_InitGame(levelTime, randomSeed, restart)

	et.RegisterModname("conexec.lua " .. et.FindSelf());
	configure()

	MAPNAME = et.trap_Cvar_Get("mapname")

end

-- Delays execution, updates MAPTIME and TIMELIMIT.
function et_RunFrame(levelTime)

	if baseLevelTime == nil then
		baseLevelTime = levelTime
	end

	levelTime = levelTime - baseLevelTime

	if timefreq ~= 0 and levelTime > 0 and math.mod(levelTime, timefreq) == 0 then

		local seconds = levelTime / 1000

		if seconds ~= MAPTIME then
			MAPTIME = seconds
			TIMELIMIT = tonumber(et.trap_Cvar_Get("timelimit")) * 60
			GAMESTATE = tonumber(et.trap_Cvar_Get("gamestate"))
			futures.execute = function() execute() end
		end

	end

	if startup and levelTime > delay then
		startup = false
		futures.execute = function() execute() end
	end

	if next(futures) ~= nil then
		table.foreach(futures, function(_, future) future() end)
		futures = {}
	end

end

function et_ClientConnect(clientNum, firstTime, isBot)
	futures.clients = function() clients() end
end

function et_ClientDisconnect(clientNum)
	futures.clients = function() clients() end
end

function et_ClientBegin(clientNum)
	futures.clients = function() clients() end
end

function et_ClientUserinfoChanged(clientNum)
	futures.clients = function() clients() end
end

-- Updates PLAYERS and SPECTATORS.
function clients()

	local p = 0
	local s = 0

	for i = 0, tonumber(et.trap_Cvar_Get("sv_maxclients")) - 1 do

		local team = tonumber(et.gentity_get(i, "sess.sessionTeam"))

		if team == 1 or team == 2 then
			p = p + 1
		elseif team == 3 then
			s = s + 1
		end

	end

	if p ~= PLAYERS or s ~= SPECTATORS then
		PLAYERS = p
		SPECTATORS = s
		execute()
	end

end

-- Runs conditions of all rules and execute those
-- with changed result and evaluting to TRUE.
function execute()

	if startup then
		return
	end

	table.foreach(rules, function(_, rule)

		local result = false

		-- Enforces the expression being casted to boolean.
		if rule.condition() then
			result = true
		end

		if result and not rule.result then

			rule.result = true

			table.foreach(rule.commands, function(_, command)
				et.trap_SendConsoleCommand(et.EXEC_APPEND, command .. "\n")
			end)

		end

		if not result then
			rule.result = false
		end

	end)

end

-- Reads ruleset from configuration.
-- When there's an error, current rules are unchanged.
function configure()

	local fd, len = et.trap_FS_FOpenFile(config, et.FS_READ)

	if len > -1 then

		local content = et.trap_FS_Read(fd, len)
		local success = true
		local r = {}

		for condition, commands in string.gfind(content, "([^\r\n]+)%s+\{([^}]+)\}") do

			local rule = {
				condition = loadstring("return " .. condition),
				commands = lines(commands),
			}

			if not rule.condition then
				et.G_LogPrint("conexec.lua: loadstring(" .. condition .. ") failure\n")
				success = false
			end

			if table.getn(rule.commands) > 0 and rule.condition then
				table.insert(r, rule)
			end

		end

		if success then
			rules = r
		end

	end

	et.trap_FS_FCloseFile(fd)

end

-- Splits given string to individual trimmed lines.
-- Empty lines are omitted.
function lines(text)

	local lines = {}

	for line in string.gfind(text, "([^\r\n]+)") do
		line = string.gsub(line, "^%s", "")
		if line ~= "" then
			table.insert(lines, line)
		end
	end

	return lines

end
