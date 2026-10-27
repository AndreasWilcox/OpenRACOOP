--[[
   Test scenarios for the Power Plant and Radar Dome bonuses (racoop|rules/buffs.yaml), run with `coop test -Map test-range`.
   Adds to the Scenarios table from testrange-tests.lua. Each scenario must be listed in the
   `ScriptLobbyDropdown@test` values in rules.yaml.
]]

-- Try to place the building the player has finished producing on a free spot near their Construction Yard.
-- Returns false if it isn't ready yet or there is no room.
local function TryPlaceNearYard(player, type)
	local yard = player.GetActorsByType("fact")[1]
	for radius = 3, 10 do
		for dy = -radius, radius do
			for dx = -radius, radius do
				if Test.PlaceBuilding(player, type, yard.Location + CVec.New(dx, dy)) then
					return true
				end
			end
		end
	end

	return false
end

-- Produce a building through the player's Building queue and place it as a player would,
-- then call `onPlaced(actor)` once it is in the world.
local function BuildAndPlace(player, type, onPlaced)
	if not CoopTest.Assert(player.Build({ type }), "started producing " .. type) then
		return
	end

	-- Keyed by name: Lua gets a new wrapper object for the same actor each time, so actors can't be table keys
	local before = { }
	Utils.Do(player.GetActorsByType(type), function(a) before[tostring(a)] = true end)

	local tries = 0
	local poll
	poll = function()
		if not TryPlaceNearYard(player, type) then
			tries = tries + 1
			if tries > 180 then
				CoopTest.Fail("the produced " .. type .. " could not be placed")
			else
				Trigger.AfterDelay(DateTime.Seconds(1), poll)
			end

			return
		end

		-- The building is created at the end of the tick
		Trigger.AfterDelay(1, function()
			local new = Utils.Where(player.GetActorsByType(type), function(a) return not before[tostring(a)] end)
			if CoopTest.AssertEqual(#new, 1, "new " .. type .. " buildings after placing one") then
				onPlaced(new[1])
			end
		end)
	end

	Trigger.AfterDelay(DateTime.Seconds(1), poll)
end

local function Place(player, type, x, y)
	return Actor.Create(type, true, { Owner = player, Location = CPos.New(x, y) })
end

-- The listed price of Power Plants and Radar Domes starts at 2000 and rises by 1000 for each one of the
-- same type the player owns or is producing, and drops again when one is gone.
Scenarios["buffs-price"] = function()
	local player = Humans[1]
	player.Cash = 50000

	CoopTest.AssertEqual(Test.ProductionCost(player, "powr"), 2000, "Power Plant price with none")
	CoopTest.AssertEqual(Test.ProductionCost(player, "dome"), 2000, "Radar Dome price with none")

	-- Actors created from Lua join the world at the end of the tick, so each check waits a tick
	local plants = { Place(player, "powr", 20, 3), Place(player, "powr", 24, 3) }
	Trigger.AfterDelay(1, function()
		CoopTest.AssertEqual(Test.ProductionCost(player, "powr"), 4000, "Power Plant price with 2 (still being built)")
		CoopTest.AssertEqual(Test.ProductionCost(player, "dome"), 2000, "Radar Dome price with 2 Power Plants")
		Place(player, "dome", 28, 3)
	end)

	Trigger.AfterDelay(2, function()
		CoopTest.AssertEqual(Test.ProductionCost(player, "dome"), 3000, "Radar Dome price with 1")

		-- Another player's buildings don't count
		Place(Enemy, "powr", 36, 25)
	end)

	Trigger.AfterDelay(3, function()
		CoopTest.AssertEqual(Test.ProductionCost(player, "powr"), 4000, "Power Plant price after the enemy got one")
		plants[1].Destroy()
	end)

	Trigger.AfterDelay(DateTime.Seconds(1), function()
		CoopTest.AssertEqual(Test.ProductionCost(player, "powr"), 3000, "Power Plant price after one was removed")

		-- One in production counts too, so several can't be queued at the old price
		CoopTest.Assert(player.Build({ "powr" }), "started producing a Power Plant")
		CoopTest.AssertEqual(Test.ProductionCost(player, "powr"), 4000, "Power Plant price while one is in production")
		CoopTest.Pass()
	end)
end

-- Each completed Power Plant adds 10% damage and each completed Radar Dome 10% weapon range
-- to the owner's units and buildings. The player's buildings don't affect enemy units.
Scenarios["buffs-modifiers"] = function()
	local player = Humans[1]
	local tank = Place(player, "1tnk", 24, 10)
	local turret = Place(player, "gun", 24, 12)

	-- Far enough from the turret that they don't fight
	local enemyTank = Place(Enemy, "1tnk", 38, 26)

	local function Check(firepower, range, when)
		Utils.Do({ tank, turret }, function(a)
			CoopTest.AssertEqual(Test.FirepowerModifier(a), firepower, a.Type .. " damage modifier " .. when)
			CoopTest.AssertEqual(Test.RangeModifier(a), range, a.Type .. " range modifier " .. when)
		end)

		CoopTest.AssertEqual(Test.FirepowerModifier(enemyTank), 100, "enemy damage modifier " .. when)
		CoopTest.AssertEqual(Test.RangeModifier(enemyTank), 100, "enemy range modifier " .. when)
	end

	Check(100, 100, "with no Power Plants or Radar Domes")

	local plants = { Place(player, "powr", 20, 3), Place(player, "powr", 24, 3) }
	Place(player, "dome", 28, 3)

	-- Actors created from Lua join the world at the end of the tick
	Trigger.AfterDelay(1, function()
		Check(100, 100, "while the buildings are still being built")
	end)

	Trigger.AfterDelay(DateTime.Seconds(5), function()
		Check(120, 110, "with 2 Power Plants and 1 Radar Dome")
		plants[1].Destroy()
		Place(player, "dome", 32, 3)
	end)

	Trigger.AfterDelay(DateTime.Seconds(10), function()
		Check(110, 120, "with 1 Power Plant and 2 Radar Domes")
		CoopTest.Pass()
	end)
end

-- Built through production and placed, a Power Plant remembers what it cost, and selling it refunds half of that.
-- Uses powr.test (rules.yaml), a Power Plant that builds almost instantly, so the test doesn't wait for production.
Scenarios["buffs-refund"] = function()
	local player = Humans[1]
	player.Cash = 50000
	player.GrantCondition("test-buildings")

	-- Not produced: worth its base cost
	local placed = Place(player, "powr", 20, 3)
	CoopTest.AssertEqual(Test.SellValue(placed), 2000, "sell value of a Power Plant that wasn't produced")
	placed.Destroy()

	Trigger.AfterDelay(DateTime.Seconds(1), function()
		BuildAndPlace(player, "powr.test", function(first)
			CoopTest.AssertEqual(Test.SellValue(first), 2000, "sell value of the first Power Plant")
			CoopTest.AssertEqual(Test.ProductionCost(player, "powr"), 3000, "Power Plant price with 1")

			BuildAndPlace(player, "powr.test", function(second)
				CoopTest.AssertEqual(Test.SellValue(second), 3000, "sell value of the second Power Plant")
				CoopTest.AssertEqual(Test.ProductionCost(player, "powr"), 4000, "Power Plant price with 2")

				-- Wait for it to finish building before selling it
				Trigger.AfterDelay(DateTime.Seconds(5), function()
					local cash = player.Cash
					second.Sell()
					Trigger.AfterDelay(DateTime.Seconds(5), function()
						CoopTest.Assert(second.IsDead or not second.IsInWorld, "the second Power Plant was sold")
						CoopTest.AssertEqual(player.Cash - cash, 1500, "refund for the Power Plant bought for 3000")
						CoopTest.AssertEqual(Test.ProductionCost(player, "powr"), 3000, "Power Plant price after selling one")
						CoopTest.Pass()
					end)
				end)
			end)
		end)
	end)
end
