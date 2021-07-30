local Timer = {}
local RunService = game:GetService("RunService")

local UpdateEvent = RunService.Heartbeat
local UpdateEventConnection = nil
local Tasks = {}

local RandomGenerator = Random.new()

-- DEBUGGER
local DEBUG = true -- RunService:IsStudio()
local DebugStats = nil
local DebugPrecision = 4
local Seperator = string.rep("-", 30)

-- Returns void, Update the stats.
local function UpdateStats(elapsedTime, expectedDuration)
	local margin = elapsedTime - expectedDuration

	if margin > DebugStats.Max then
		DebugStats.Max = margin
	end

	if margin < DebugStats.Min then
		DebugStats.Min = margin
	end

	if DebugStats.Avg then
		DebugStats.Avg = (DebugStats.Avg + margin)/2
	else
		DebugStats.Avg = elapsedTime
	end

	DebugStats.Rng = DebugStats.Max - DebugStats.Min
end

-- Returns void. Update the queued tasks, calling and deleting them if they're expired.
local function UpdateTasks()
	local now = os.clock()

	for index = #Tasks, 1, -1 do
		local task = Tasks[index]
		if task.Timeout <= now then
			local elapsedTime = now - task.StartTime
			table.remove(Tasks, index).Callback(elapsedTime, table.unpack(task.Params))
			if DEBUG then
				local expectedDuration = task.Timeout - task.StartTime
				UpdateStats(elapsedTime, expectedDuration)
			end
		end
	end
end

-- Returns the 'id' of the newly created task,
-- Call the function 'callback' after the specified 'duration' passing the extra parameters '...'.
function Timer.Delay(callback, duration, ...)
	local startTime = os.clock()
	duration = duration or 0
	local typeOfCallback = typeof(callback)

	if typeOfCallback ~= "function" then
		error("Callback is expected to be a function, got '"..typeOfCallback.."'")
	end

	local id = #Tasks + 1

	table.insert(Tasks, id, {
		StartTime = startTime,
		Timeout = startTime + duration,
		Callback = callback,
		Params = {...}
	})

	return id
end

function Timer.SetUpdateEvent(event)
	if not (typeof(event) == "RBXScriptSignal") then
		error("the returned event should be a roblox event signal.")
	end

	if UpdateEventConnection then
		UpdateEventConnection:Disconnect()
	end

	UpdateEventConnection = event:Connect(UpdateTasks)
end

-- Returns the internal tasks table.
function Timer.GetTasks()
	return Tasks
end

-- Returns a task through the specified 'id',
-- beware, it might return another task or nil if the specified task have expired.
function Timer.GetTask(id)
	return Tasks[id]
end

-- Returns the 'number' rounded to the nearest multiplier of 'factor',
-- Returns the 'number' itself if the 'factor' is zero.
function Timer.Round(number, factor)
	if factor == 0 then
		return number
	end

	return math.round(number/factor)*factor
end

-- Returns the 'number' with the specified 'precision' (decimal places) or less.
function Timer.Decimals(number, precision)
	precision = precision or DebugPrecision
	return Timer.Round(number, math.pow(10, -precision))
end

-- Returns a random number between 'min' and 'max', with the specified 'precision'.
function Timer.Random(min, max, precision)
	local factor = math.pow(10, precision)
	return RandomGenerator:NextInteger(min*factor, max*factor)/factor
end

-- Returns a table containing the stats of the timer measured through previous calls,
-- Beware, this will return an empty table if DEBUG is false and not being enabled before.
function Timer.GetStats()
	return DebugStats
end

-- Returns void, Print the stats returned by "Timer.GetStats" in a suitable format.
function Timer.PrintStats()
	local stats = Timer.GetStats()
	print(Seperator)
	print("TIMER STATS:")
	for stat, value in pairs(stats) do
		print("\t"..stat..": "..Timer.Decimals(value))
	end
	print(Seperator)
end

-- Returns void, Resets the "DebugStats" for a fresh debug start.
function Timer.ResetStats()
	DebugStats = {
		Min = math.huge, -- Minumum
		Max = 0, -- Max
		Avg = nil, -- Average
		Rng = math.huge, -- Range
	}
end

-- Returns DebugStats, Enable debugging stats and reset them.
function Timer.EnableDebug()
	if not DEBUG then
		Timer.ResetStats()
		DEBUG = true
	end
	return DebugStats
end

-- Returns DebugStats, Disable debugging stats,
-- The returned table won't change itself unless if enabled debugging again or done manually.
function Timer.DisableDebug()
	DEBUG = false
	return DebugStats
end

-- Returns Timer, Initialize the module.
local function Initialize()
	Timer.ResetStats()
	Timer.SetUpdateEvent(UpdateEvent)
	return Timer
end

function Timer.Debounce(event, callback, cooldown, ...)
	local params = {}
	local lastTime = 0

	event:Connect(function(...)
		local now = os.clock()
		local elapsedTime = now - lastTime
		
		if elapsedTime >= cooldown then
			lastTime = now
			callback(..., elapsedTime, table.unpack(params))
		end
	end)
end

return Initialize()
