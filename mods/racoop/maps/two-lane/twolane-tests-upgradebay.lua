--[[
   Test scenarios for the Upgrade Bay (racoop|rules/upgradebay.yaml), added to the Scenarios table from twolane-tests.lua.
   They promote through the bay's Promote script property, which runs the same code as a player's promote order.
]]

-- Wait for the bay's build animation: it can't promote until it has finished.
local BayReady = DateTime.Seconds(3)

-- An Upgrade Bay and a known amount of cash for the first human. Waves are pushed back so they don't interfere.
local function SetUp(cash)
	WaveConfig = { { Delay = DateTime.Minutes(10), Groups = { { Units = { "e1" }, Lane = "north" } } } }

	local player = Humans[1]
	player.Resources = 0
	player.Cash = cash
	local bay = Actor.Create("upgr", true, { Owner = player, Location = CPos.New(3, 13) })
	return player, bay
end

-- Each promotion raises the unit one level, from anywhere on the map, and costs 25% of the unit's cost.
-- Promoting stops at Elite, without charging for the refused promotion. Aircraft can be promoted too.
Scenarios["upgrade-promote"] = function()
	local player, bay = SetUp(10000)
	local tank = Actor.Create("1tnk", true, { Owner = player, Location = CPos.New(60, 16) })
	local heli = Actor.Create("heli", true, { Owner = player, Location = CPos.New(20, 16) })

	Trigger.AfterDelay(BayReady, function()
		CoopTest.AssertEqual(bay.PromotionCost(tank), 175, "cost of promoting a Light Tank (25% of 700)")
		CoopTest.AssertEqual(tank.Level, 0, "Light Tank level at the start")

		CoopTest.Assert(bay.Promote(tank), "the Light Tank was promoted")
		CoopTest.AssertEqual(tank.Level, 1, "Light Tank level after one promotion")
		CoopTest.AssertEqual(player.Cash, 10000 - 175, "cash after one promotion")

		CoopTest.Assert(bay.Promote(heli), "the Longbow was promoted")
		CoopTest.AssertEqual(heli.Level, 1, "Longbow level after one promotion")
		CoopTest.AssertEqual(player.Cash, 10000 - 175 - 500, "cash after promoting the Longbow (25% of 2000)")

		for _ = 2, tank.MaxLevel do
			CoopTest.Assert(bay.Promote(tank), "the Light Tank was promoted again")
		end

		CoopTest.AssertEqual(tank.MaxLevel, 4, "Light Tank highest level")
		CoopTest.AssertEqual(tank.Level, 4, "Light Tank level after promoting to Elite")
		local cash = 10000 - 500 - 4 * 175
		CoopTest.AssertEqual(player.Cash, cash, "cash after promoting the Light Tank to Elite")

		CoopTest.Assert(not bay.Promote(tank), "an Elite unit can't be promoted")
		CoopTest.AssertEqual(tank.Level, 4, "Light Tank level after the refused promotion")
		CoopTest.AssertEqual(player.Cash, cash, "cash after the refused promotion")

		Camera.Position = tank.CenterPosition
	end)

	Trigger.AfterDelay(BayReady + DateTime.Seconds(1), function()
		CoopTest.Screenshot("elite")
		Trigger.AfterDelay(DateTime.Seconds(1), CoopTest.Pass)
	end)
end

-- Promotions the player can't afford, and units that can't be promoted, are refused without charging.
Scenarios["upgrade-refused"] = function()
	local player, bay = SetUp(100)
	local tank = Actor.Create("1tnk", true, { Owner = player, Location = CPos.New(10, 20) })
	local truck = Actor.Create("truk", true, { Owner = player, Location = CPos.New(12, 20) })
	local enemy = Actor.Create("e1", true, { Owner = Enemy, Location = CPos.New(60, 16) })

	Trigger.AfterDelay(BayReady, function()
		CoopTest.Assert(not bay.Promote(tank), "a promotion costing more than the player's cash is refused")
		CoopTest.AssertEqual(tank.Level, 0, "Light Tank level after the unaffordable promotion")
		CoopTest.AssertEqual(player.Cash, 100, "cash after the unaffordable promotion")

		player.Cash = 175
		CoopTest.Assert(bay.Promote(tank), "a promotion costing exactly the player's cash is allowed")
		CoopTest.AssertEqual(tank.Level, 1, "Light Tank level after the affordable promotion")
		CoopTest.AssertEqual(player.Cash, 0, "cash after the affordable promotion")

		player.Cash = 1000
		CoopTest.Assert(not bay.Promote(enemy), "an enemy unit can't be promoted")
		CoopTest.AssertEqual(enemy.Level, 0, "enemy unit level")

		CoopTest.Assert(not truck.HasProperty("Level"), "the Supply Truck has no veterancy")
		CoopTest.Assert(not bay.Promote(truck), "a unit without veterancy can't be promoted")
		CoopTest.Assert(not bay.Promote(bay), "the Upgrade Bay can't promote itself")

		local yard = Actor.Create("fact", true, { Owner = player, Location = CPos.New(6, 16) })
		CoopTest.Assert(not bay.Promote(yard), "a building can't be promoted")

		CoopTest.AssertEqual(player.Cash, 1000, "cash after the refused promotions")
		CoopTest.Pass()
	end)
end
