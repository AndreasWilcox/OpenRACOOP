--[[
   Two Lanes: wave defense map for up to four players.
   The humans (Multi0-Multi3) build in the west, behind the western cliff line.
   The Enemy has no base: every wave enters at the east edge and is sent down both lanes,
   north and south of the lake. The lane waypoints are named actors in map.yaml, so they can be moved in the editor.
   Player slots nobody joined are not created, so every human player may be nil.
]]

WaveInterval = DateTime.Seconds(15)
WaveUnits = { "e1", "e1" }

-- Each lane: where its units enter, the gap in the eastern cliffs they walk to,
-- and the gap in the western cliffs they then attack-move to before hunting freely.
Lanes = { }

-- Number of waves sent so far, and every unit they contained (in total and per lane)
WaveNumber = 0
WaveActors = { }

SendWave = function()
	WaveNumber = WaveNumber + 1

	Utils.Do(Lanes, function(lane)
		-- The callback runs once each unit has walked the path, so the units are recorded from the returned list
		local path = { lane.Spawn.Location, lane.EastGap.Location }
		local units = Reinforcements.Reinforce(Enemy, WaveUnits, path, DateTime.Seconds(1), function(a)
			a.AttackMove(lane.WestGap.Location)
			IdleHunt(a)
		end)

		Utils.Do(units, function(a)
			WaveActors[#WaveActors + 1] = a
			lane.Actors[#lane.Actors + 1] = a
		end)
	end)

	Trigger.AfterDelay(WaveInterval, SendWave)
end

WorldLoaded = function()
	Enemy = Player.GetPlayer("Enemy")
	Humans = Player.GetPlayers(function(p)
		return p.InternalName == "Multi0" or p.InternalName == "Multi1"
			or p.InternalName == "Multi2" or p.InternalName == "Multi3"
	end)

	Lanes =
	{
		{ Name = "north", Spawn = NorthSpawn, EastGap = NorthEastGap, WestGap = NorthWestGap, Actors = { } },
		{ Name = "south", Spawn = SouthSpawn, EastGap = SouthEastGap, WestGap = SouthWestGap, Actors = { } }
	}

	Utils.Do(Humans, function(player)
		InitObjectives(player)
		Media.DisplayMessageToPlayer(player, UserInterface.GetFluentMessage("twolane-welcome"))
	end)

	Trigger.AfterDelay(WaveInterval, SendWave)

	-- Marker checked by `coop smoke` to prove the script loaded and ran.
	print("coop: WorldLoaded with " .. #Humans .. " human player(s)")

	CoopTest.Run(Scenarios)
end
