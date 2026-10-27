--[[
   Automated test scenarios for the Tech Center support powers (racoop|rules/powers.yaml), run with `coop test`.
   Adds to the Scenarios table from twolane-tests.lua. Each scenario must be listed in the
   `ScriptLobbyDropdown@test` values in rules.yaml. Scenarios named powers-<faction> run as that faction (see coop.ps1).
]]

-- The support powers (order names) each force gets from a Tech Center, sorted by name
local ForcePowers =
{
	infantry = { "CoopParatroopers" },
	tanks = { "CoopFlashFreeze" },
	air = { },
	support = { "CoopCruiserShelling", "CoopParabombs" }
}

-- Charge time of each power, in ticks
local ChargeTicks =
{
	CoopParatroopers = 7500,
	CoopFlashFreeze = DateTime.Minutes(3),
	CoopParabombs = DateTime.Minutes(4),
	CoopCruiserShelling = DateTime.Minutes(3)
}

local function Powers(player)
	return table.concat(Test.SupportPowers(player), ", ")
end

-- A single wave far in the future, so no enemies interfere with the test
local function NoWaves()
	WaveConfig = { { Delay = DateTime.Minutes(30), Groups = { { Units = { "e1" }, Lane = "north" } } } }
end

-- An idle unit that won't shoot at anything
local function Dummy(type, owner, cell)
	local actor = Actor.Create(type, true, { Owner = owner, Location = cell })
	actor.Stance = "HoldFire"
	return actor
end

-- Flash Freeze slows every unit in its 5x5 area to 60% speed for 20 seconds: own and enemy, on the ground and in the air.
local function TestFlashFreeze(player, done)
	local target = CPos.New(41, 16)
	local frozen =
	{
		Dummy("3tnk", player, CPos.New(40, 15)),
		Dummy("3tnk", Enemy, CPos.New(42, 17)),
		Dummy("e1", Enemy, CPos.New(39, 18)),
		Dummy("1tnk", player, CPos.New(43, 14))
	}
	local outside = Dummy("3tnk", Enemy, CPos.New(46, 16))

	-- A helicopter hovering over the area
	local heli = Dummy("heli", player, CPos.New(41, 8))
	heli.Move(target)
	frozen[#frozen + 1] = heli

	Trigger.AfterDelay(DateTime.Seconds(6), function()
		CoopTest.Assert(heli.CenterPosition.Z > 0, "the helicopter is airborne over the area")
		Utils.Do(frozen, function(a)
			CoopTest.AssertEqual(Test.SpeedPercent(a), 100, a.Type .. " speed before Flash Freeze")
		end)

		CoopTest.Assert(Test.ActivateSupportPower(player, "CoopFlashFreeze", target), "Flash Freeze activated")
		Camera.Position = Map.CenterOfCell(target)
	end)

	Trigger.AfterDelay(DateTime.Seconds(7), function()
		Utils.Do(frozen, function(a)
			CoopTest.AssertEqual(Test.SpeedPercent(a), 60, a.Type .. " (" .. a.Owner.InternalName .. ") speed while frozen")
		end)
		CoopTest.AssertEqual(Test.SpeedPercent(outside), 100, "speed of a tank outside the area")
		CoopTest.Screenshot("flash-freeze")
	end)

	-- 20 seconds after activation it has worn off
	Trigger.AfterDelay(DateTime.Seconds(6) + DateTime.Seconds(19), function()
		CoopTest.AssertEqual(Test.SpeedPercent(frozen[1]), 60, "speed just before Flash Freeze wears off")
	end)

	Trigger.AfterDelay(DateTime.Seconds(6) + DateTime.Seconds(21), function()
		Utils.Do(frozen, function(a)
			CoopTest.AssertEqual(Test.SpeedPercent(a), 100, a.Type .. " speed after Flash Freeze wore off")
		end)
		done()
	end)
end

-- Cruiser Shelling lands 6 shells in the 4x4 area around the target, fired by the player.
-- Every cell of the area has a tank, so each shell damages at least one. The shells are 10 ticks apart,
-- so the number of distinct times tanks were damaged is the number of shells.
local function TestCruiserShelling(player, done)
	-- The area around (41, 15) is x 40-43, y 14-17
	local target = CPos.New(41, 15)
	local impacts = { }
	local impactCount = 0
	local wrongAttacker = false
	for x = 40, 43 do
		for y = 14, 17 do
			local tank = Dummy("3tnk", Enemy, CPos.New(x, y))
			Trigger.OnDamaged(tank, function(_, attacker)
				if not attacker or attacker.Owner ~= player then
					wrongAttacker = true
				end

				if not impacts[DateTime.GameTime] then
					impacts[DateTime.GameTime] = true
					impactCount = impactCount + 1
				end
			end)
		end
	end

	-- Tanks 3 cells outside the area on each side must not be hit
	local outsideHits = 0
	Utils.Do({ CPos.New(37, 15), CPos.New(46, 15), CPos.New(41, 11), CPos.New(41, 20) }, function(cell)
		Trigger.OnDamaged(Dummy("3tnk", Enemy, cell), function()
			outsideHits = outsideHits + 1
		end)
	end)

	Trigger.AfterDelay(DateTime.Seconds(2), function()
		CoopTest.Assert(Test.ActivateSupportPower(player, "CoopCruiserShelling", target), "Cruiser Shelling activated")
	end)

	-- The shells are on their way in from the west
	Trigger.AfterDelay(DateTime.Seconds(2) + 40, function()
		Camera.Position = Map.CenterOfCell(CPos.New(28, 15))
		CoopTest.Screenshot("cruiser-shells-incoming")
	end)

	Trigger.AfterDelay(DateTime.Seconds(15), function()
		CoopTest.AssertEqual(impactCount, 6, "shell impacts in the area")
		CoopTest.AssertEqual(outsideHits, 0, "hits on tanks outside the area")
		CoopTest.Assert(not wrongAttacker, "the shells were fired by the player")
		done()
	end)
end

-- Paratroopers drop five infantry (with one rank) for the player.
local function TestParatroopers(player, done)
	local before = #player.GetActorsByTypes({ "e1r1", "e3r1" })
	CoopTest.Assert(Test.ActivateSupportPower(player, "CoopParatroopers", CPos.New(40, 16)), "Paratroopers activated")
	Trigger.AfterDelay(DateTime.Seconds(40), function()
		CoopTest.AssertEqual(#player.GetActorsByTypes({ "e1r1", "e3r1" }) - before, 5, "paratroopers landed")
		done()
	end)
end

-- Parabombs damage a tank at the target.
local function TestParabombs(player, done)
	local hit = false
	local tank = Dummy("3tnk", Enemy, CPos.New(40, 22))
	Trigger.OnDamaged(tank, function() hit = true end)
	CoopTest.Assert(Test.ActivateSupportPower(player, "CoopParabombs", CPos.New(40, 22)), "Parabombs activated")
	Trigger.AfterDelay(DateTime.Seconds(40), function()
		CoopTest.Assert(hit, "the parabombs hit the tank at the target")
		done()
	end)
end

-- Extra checks per force, run after the powers have been checked
local ForceTests =
{
	infantry = { TestParatroopers },
	tanks = { TestFlashFreeze },
	air = { },
	support = { TestCruiserShelling, TestParabombs }
}

-- Run the tests one after the other, then pass
local function RunAll(player, tests, index)
	index = index or 1
	if index > #tests then
		Trigger.AfterDelay(DateTime.Seconds(1), CoopTest.Pass)
		return
	end

	tests[index](player, function() RunAll(player, tests, index + 1) end)
end

-- With a Tech Center, a force has exactly its own support powers, and they start charging.
for name, powers in pairs(ForcePowers) do
	Scenarios["powers-" .. name] = function()
		NoWaves()

		local player = Humans[1]
		CoopTest.AssertEqual(player.Faction, name, "force")

		Trigger.AfterDelay(DateTime.Seconds(1), function()
			CoopTest.AssertEqual(Powers(player), "", "support powers without a Tech Center")
			Actor.Create("atek", true, { Owner = player, Location = CPos.New(3, 19) })
		end)

		Trigger.AfterDelay(DateTime.Seconds(4), function()
			CoopTest.AssertEqual(Powers(player), table.concat(powers, ", "), "support powers with a Tech Center")
			Utils.Do(powers, function(power)
				local remaining = Test.SupportPowerRemainingTicks(player, power)
				CoopTest.Assert(remaining > 0 and remaining < ChargeTicks[power],
					power .. " is charging (" .. remaining .. " of " .. ChargeTicks[power] .. " ticks left)")
			end)

			CoopTest.Screenshot("sidebar")
			RunAll(player, ForceTests[name])
		end)
	end
end
