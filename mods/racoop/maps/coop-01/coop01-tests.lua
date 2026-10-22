--[[
   Automated test scenarios for coop01.lua, run with `coop test`.
   Each scenario must be listed in the `ScriptLobbyDropdown@test` values in rules.yaml.
]]

Scenarios = { }

-- The enemy starts with nothing, and sends a wave of 2 rifle infantry every 10 seconds.
Scenarios["waves"] = function()
	-- GetActors also includes the player's own (invisible) player actor, so only count actors with health
	local initial = Utils.Where(Enemy.GetActors(), function(a) return a.HasProperty("Health") end)
	CoopTest.AssertEqual(#initial, 0, "enemy units and buildings at the start")

	-- Just after the third wave has spawned
	Trigger.AfterDelay(3 * WaveInterval + DateTime.Seconds(3), function()
		CoopTest.AssertEqual(WaveNumber, 3, "waves sent after 30 seconds")
		CoopTest.AssertEqual(#WaveActors, 3 * #WaveUnits, "units sent in total")

		local types = Utils.Where(WaveActors, function(a) return a.Type ~= "e1" end)
		CoopTest.AssertEqual(#types, 0, "wave units that are not e1")

		-- Everything the enemy owns must come from the waves: no buildings or harvesters
		local others = Utils.Where(Enemy.GetActors(), function(a)
			return a.HasProperty("Health") and a.Type ~= "e1"
		end)
		CoopTest.AssertEqual(#others, 0, "enemy actors other than wave infantry")

		local alive = Utils.Where(WaveActors, function(a) return not a.IsDead end)
		Camera.Position = alive[1].CenterPosition
		CoopTest.Screenshot("third-wave")

		Trigger.AfterDelay(DateTime.Seconds(1), CoopTest.Pass)
	end)
end
