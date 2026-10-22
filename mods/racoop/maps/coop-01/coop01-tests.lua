--[[
   Automated test scenarios for coop01.lua, run with `coop test`.
   Each scenario must be listed in the `ScriptLobbyDropdown@test` values in rules.yaml.
]]

Scenarios = { }

-- The first wave spawns as configured, and wiping it out completes everyone's survive objective.
Scenarios["first-wave"] = function()
	local wave = SendFirstWave()
	CoopTest.AssertEqual(#wave, #FirstWaveUnits, "first wave unit count")

	Trigger.AfterDelay(DateTime.Seconds(10), function()
		local alive = Utils.Where(wave, function(a) return not a.IsDead end)
		CoopTest.AssertEqual(#alive, #FirstWaveUnits, "wave units alive after arriving")

		Camera.Position = alive[1].CenterPosition
		CoopTest.Screenshot("wave-arrived")

		-- Screenshots are taken on the next rendered frame, so wait a moment before changing the scene
		Trigger.AfterDelay(DateTime.Seconds(1), function()
			Utils.Do(alive, function(a) a.Kill() end)
		end)
	end)

	Trigger.AfterDelay(DateTime.Seconds(13), function()
		Utils.Do(Humans, function(player)
			CoopTest.Assert(player.IsObjectiveCompleted(SurviveObjectives[player.InternalName]),
				player.InternalName .. " completed the survive objective")
		end)

		CoopTest.Pass()
	end)
end
