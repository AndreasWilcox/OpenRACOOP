--[[
   Co-op Test Range: a small, flat map for test scenarios that don't depend on a map's layout, run with
   `coop test -Map test-range`. There are no waves: the Enemy only owns what a scenario creates.
   The humans (Multi0, Multi1) start in the west; scenarios put their targets in the east (x 20-40).
   Player slots nobody joined are not created, so every human player may be nil.
]]

WorldLoaded = function()
	Enemy = Player.GetPlayer("Enemy")
	Humans = Player.GetPlayers(function(p)
		return p.InternalName == "Multi0" or p.InternalName == "Multi1"
	end)

	-- Marker checked by `coop smoke` to prove the script loaded and ran.
	print("coop: WorldLoaded with " .. #Humans .. " human player(s)")

	CoopTest.Run(Scenarios)
end
