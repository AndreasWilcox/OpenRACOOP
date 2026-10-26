--[[
   Two Lanes: wave defense map for up to four players.
   The humans (Multi0-Multi3) build in the west, behind the western cliff line.
   The Enemy has no base: its waves (waves.lua) enter at the east edge and come down the lanes
   north and south of the lake, run by racoop|scripts/coopwaves.lua.
   The lane waypoints are named actors in map.yaml, so they can be moved in the editor.
   Player slots nobody joined are not created, so every human player may be nil.
]]

WorldLoaded = function()
	Enemy = Player.GetPlayer("Enemy")
	Humans = Player.GetPlayers(function(p)
		return p.InternalName == "Multi0" or p.InternalName == "Multi1"
			or p.InternalName == "Multi2" or p.InternalName == "Multi3"
	end)

	-- Where each lane's units enter, the gap in the eastern cliffs they head for,
	-- and the gap in the western cliffs they attack-move to before going after the players.
	Lanes =
	{
		north = { Spawn = NorthSpawn, EastGap = NorthEastGap, WestGap = NorthWestGap },
		south = { Spawn = SouthSpawn, EastGap = SouthEastGap, WestGap = SouthWestGap }
	}

	Utils.Do(Humans, function(player)
		InitObjectives(player)
		Media.DisplayMessageToPlayer(player, UserInterface.GetFluentMessage("twolane-welcome"))
	end)

	-- Marker checked by `coop smoke` to prove the script loaded and ran.
	print("coop: WorldLoaded with " .. #Humans .. " human player(s)")

	-- Test scenarios run first, so they can replace WaveConfig with their own waves.
	CoopTest.Run(Scenarios)
	CoopWaves.Start(WaveConfig, Lanes, Humans, Enemy)
end
