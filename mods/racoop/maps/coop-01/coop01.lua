--[[
   Co-op 01: wave defense test map.
   Two human players (Multi0, Multi1) share a team against the Enemy, which has no base:
   it only sends waves of units from the east edge at a fixed interval.
   Player slots nobody joined are not created, so every human player may be nil.
]]

WaveInterval = DateTime.Seconds(10)
WaveUnits = { "e1", "e1" }
WavePath = { CPos.New(109, 26), CPos.New(80, 26) }

-- Number of waves sent so far, and every unit they contained
WaveNumber = 0
WaveActors = { }

SendWave = function()
	WaveNumber = WaveNumber + 1

	local wave = Reinforcements.Reinforce(Enemy, WaveUnits, WavePath, DateTime.Seconds(1))
	Utils.Do(wave, function(a)
		IdleHunt(a)
		WaveActors[#WaveActors + 1] = a
	end)

	Trigger.AfterDelay(WaveInterval, SendWave)
	return wave
end

WorldLoaded = function()
	Enemy = Player.GetPlayer("Enemy")
	Humans = Player.GetPlayers(function(p)
		return p.InternalName == "Multi0" or p.InternalName == "Multi1"
	end)

	Utils.Do(Humans, function(player)
		InitObjectives(player)
		Media.DisplayMessageToPlayer(player, UserInterface.GetFluentMessage("coop01-welcome"))
	end)

	Trigger.AfterDelay(WaveInterval, SendWave)

	-- Marker checked by `coop smoke` to prove the script loaded and ran.
	print("coop: WorldLoaded with " .. #Humans .. " human player(s)")

	CoopTest.Run(Scenarios)
end
