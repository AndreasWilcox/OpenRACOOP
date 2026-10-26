--[[
   Automated test scenarios for twolane.lua, run with `coop test`.
   Each scenario must be listed in the `ScriptLobbyDropdown@test` values in rules.yaml.
]]

Scenarios = { }

-- True if the actor is alive and within `range` cells of the waypoint (in both directions).
local function Near(actor, waypoint, range)
	return not actor.IsDead
		and math.abs(actor.Location.X - waypoint.Location.X) <= range
		and math.abs(actor.Location.Y - waypoint.Location.Y) <= range
end

-- Every wave sends its units down both lanes, and they make it through the map to the western cliff gaps.
Scenarios["waves"] = function()
	local initial = Utils.Where(Enemy.GetActors(), function(a) return a.HasProperty("Health") end)
	CoopTest.AssertEqual(#initial, 0, "enemy units and buildings at the start")

	-- Just after the first wave has spawned in both lanes
	Trigger.AfterDelay(WaveInterval + DateTime.Seconds(3), function()
		CoopTest.AssertEqual(WaveNumber, 1, "waves sent")
		Utils.Do(Lanes, function(lane)
			CoopTest.AssertEqual(#lane.Actors, #WaveUnits, "units sent down the " .. lane.Name .. " lane")
		end)
	end)

	-- Wait for a unit to reach each lane's western gap, and take a screenshot there.
	-- Only one lane is handled per check, as the screenshot is taken after the camera has moved.
	local reached = { }
	local check
	check = function()
		for _, lane in ipairs(Lanes) do
			local arrived = Utils.Where(lane.Actors, function(a) return Near(a, lane.WestGap, 4) end)
			if not reached[lane.Name] and #arrived > 0 then
				reached[lane.Name] = true
				CoopTest.Log("ok - " .. lane.Name .. " lane reached its western gap in wave " .. WaveNumber)
				Camera.Position = arrived[1].CenterPosition
				CoopTest.Screenshot(lane.Name .. "-lane")
				break
			end
		end

		if reached["north"] and reached["south"] then
			Trigger.AfterDelay(DateTime.Seconds(1), CoopTest.Pass)
		else
			Trigger.AfterDelay(DateTime.Seconds(1), check)
		end
	end

	Trigger.AfterDelay(WaveInterval, check)
end
