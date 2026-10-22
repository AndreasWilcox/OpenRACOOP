--[[
   Helpers for automated co-op test scenarios, run in a hidden window by `coop test`.

   A map opts in by:
     - adding a hidden `ScriptLobbyDropdown@test` (ID: test) listing its scenarios,
     - loading this file and a test file defining `Scenarios = { ["name"] = function() ... end }`,
     - calling `CoopTest.Run(Scenarios)` at the end of `WorldLoaded`.

   Everything is reported as `coop-test: ...` lines in lua.log, which `coop test` reads.
   In a normal game the scenario is "none" and nothing here runs.
]]

CoopTest = { }

CoopTest.Scenario = Map.LobbyOptionOrDefault("test", "none")
CoopTest.Finished = false

---@param message string
CoopTest.Log = function(message)
	print("coop-test: " .. message)
end

CoopTest.Pass = function()
	if CoopTest.Finished then
		return
	end

	CoopTest.Finished = true
	CoopTest.Log("PASS " .. CoopTest.Scenario)
end

---@param message string
CoopTest.Fail = function(message)
	if CoopTest.Finished then
		return
	end

	CoopTest.Finished = true
	CoopTest.Log("FAIL " .. CoopTest.Scenario .. ": " .. message)
end

---@param condition boolean
---@param message string
---@return boolean
CoopTest.Assert = function(condition, message)
	if condition then
		CoopTest.Log("ok - " .. message)
	else
		CoopTest.Fail(message)
	end

	return condition
end

---@param actual any
---@param expected any
---@param message string
---@return boolean
CoopTest.AssertEqual = function(actual, expected, message)
	return CoopTest.Assert(actual == expected,
		message .. " (expected " .. tostring(expected) .. ", got " .. tostring(actual) .. ")")
end

--- Save a screenshot of the local player's view, named after the scenario.
--- It is taken on the next rendered frame, so delay changes to the scene (e.g. with Trigger.AfterDelay).
---@param name string
CoopTest.Screenshot = function(name)
	local file = CoopTest.Scenario .. "-" .. name
	Test.Screenshot(file)
	CoopTest.Log("screenshot " .. file)
end

--- Run the scenario selected in the lobby, if any. Fails it if it hasn't finished after `timeout` ticks.
---@param scenarios table<string, function>
---@param timeout? integer
CoopTest.Run = function(scenarios, timeout)
	if CoopTest.Scenario == "none" then
		return
	end

	local scenario = scenarios[CoopTest.Scenario]
	if not scenario then
		CoopTest.Fail("unknown scenario")
		return
	end

	CoopTest.Log("START " .. CoopTest.Scenario)
	Trigger.AfterDelay(timeout or DateTime.Minutes(5), function()
		CoopTest.Fail("timed out")
	end)

	scenario()
end
