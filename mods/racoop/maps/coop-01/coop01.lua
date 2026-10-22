--[[
   Co-op 01: pipeline test map.
   Two human players (Multi0, Multi1) share a team against a scripted/AI Enemy.
   Player slots nobody joined are not created, so every human player may be nil.
]]

FirstWaveDelay = DateTime.Minutes(3)
FirstWaveUnits = { "3tnk", "3tnk", "e1", "e1", "e1", "e2", "e2" }
FirstWavePath = { CPos.New(109, 26), CPos.New(80, 26) }

SendFirstWave = function()
	Utils.Do(Humans, function(player)
		Media.DisplayMessageToPlayer(player, UserInterface.GetFluentMessage("coop01-wave-incoming"))
	end)

	local wave = Reinforcements.Reinforce(Enemy, FirstWaveUnits, FirstWavePath, DateTime.Seconds(1))
	Utils.Do(wave, IdleHunt)

	Trigger.OnAllKilled(wave, function()
		Utils.Do(Humans, function(player)
			player.MarkCompletedObjective(SurviveObjectives[player.InternalName])
		end)
	end)
end

WorldLoaded = function()
	Enemy = Player.GetPlayer("Enemy")
	Humans = Player.GetPlayers(function(p)
		return p.InternalName == "Multi0" or p.InternalName == "Multi1"
	end)

	SurviveObjectives = { }
	Utils.Do(Humans, function(player)
		InitObjectives(player)
		Media.DisplayMessageToPlayer(player, UserInterface.GetFluentMessage("coop01-welcome"))
		SurviveObjectives[player.InternalName] = AddSecondaryObjective(player, "coop01-survive-first-wave")
	end)

	Trigger.AfterDelay(FirstWaveDelay, SendFirstWave)

	-- Marker checked by `coop smoke` to prove the script loaded and ran.
	print("coop: WorldLoaded with " .. #Humans .. " human player(s)")
end
