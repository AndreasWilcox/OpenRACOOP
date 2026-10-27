--[[
   Automated test scenarios for Two Lanes and the wave runner (racoop|scripts/coopwaves.lua), run with `coop test`.
   Each scenario must be listed in the `ScriptLobbyDropdown@test` values in rules.yaml.
   Scenarios that don't depend on the map are on the test-range map instead.
   Scenarios run before the waves start, so they can replace WaveConfig with small test waves.
]]

Scenarios = { }

local LaneNames = { "north", "south" }

-- True if the actor is alive and within `range` cells of the waypoint (in both directions).
local function Near(actor, waypoint, range)
	return not actor.IsDead
		and math.abs(actor.Location.X - waypoint.Location.X) <= range
		and math.abs(actor.Location.Y - waypoint.Location.Y) <= range
end

-- Give the first human a Construction Yard, so the game isn't lost while the test's waves attack
local function KeepAlive()
	Actor.Create("fact", true, { Owner = Humans[1], Location = CPos.New(6, 16) })
end

-- Groups spawn after their delay, repeat, get their rank, and every lane's units reach the western gaps.
Scenarios["waves"] = function()
	WaveConfig =
	{
		{
			Delay = DateTime.Seconds(2),
			Hint = "twolane-wave-1-hint",
			Groups =
			{
				{ Units = { "e1", "e1" }, Lane = "north", Repeat = { Every = DateTime.Seconds(5), Times = 3 } },
				{ Units = { "e3" }, Lane = "south", Delay = DateTime.Seconds(4), Rank = 2 }
			}
		}
	}

	local spawns = { north = { }, south = { } }
	local laneUnits = { north = { }, south = { } }
	CoopWaves.OnGroupSpawned = function(group, units)
		local times = spawns[group.Lane]
		times[#times + 1] = DateTime.GameTime
		Utils.Do(units, function(a) laneUnits[group.Lane][#laneUnits[group.Lane] + 1] = a end)
	end

	local initial = Utils.Where(Enemy.GetActors(), function(a) return a.HasProperty("Health") end)
	CoopTest.AssertEqual(#initial, 0, "enemy units and buildings at the start")

	Trigger.AfterDelay(DateTime.Seconds(15), function()
		CoopTest.AssertEqual(CoopWaves.Started, 1, "waves started")
		CoopTest.AssertEqual(#spawns.north, 3, "times the repeating north group was sent")
		CoopTest.AssertEqual(spawns.north[2] - spawns.north[1], DateTime.Seconds(5), "ticks between repeats")
		CoopTest.AssertEqual(#spawns.south, 1, "times the south group was sent")
		CoopTest.AssertEqual(spawns.south[1] - spawns.north[1], DateTime.Seconds(4), "ticks the south group waited after the wave started")
		CoopTest.AssertEqual(#laneUnits.north, 6, "units sent down the north lane")
		CoopTest.AssertEqual(laneUnits.south[1].Level, 2, "rank of the south group")
		CoopTest.AssertEqual(laneUnits.north[1].Level, 0, "rank of the north group")
	end)

	-- Wait for a unit to reach each lane's western gap, and take a screenshot there.
	-- Only one lane is handled per check, as the screenshot is taken after the camera has moved.
	local reached = { }
	local check
	check = function()
		for _, name in ipairs(LaneNames) do
			local gap = Lanes[name].WestGap
			local arrived = Utils.Where(laneUnits[name], function(a) return Near(a, gap, 4) end)
			if not reached[name] and #arrived > 0 then
				reached[name] = true
				CoopTest.Log("ok - " .. name .. " lane reached its western gap")
				Camera.Position = arrived[1].CenterPosition
				CoopTest.Screenshot(name .. "-lane")
				break
			end
		end

		if reached.north and reached.south then
			Trigger.AfterDelay(DateTime.Seconds(1), CoopTest.Pass)
		else
			Trigger.AfterDelay(DateTime.Seconds(1), check)
		end
	end

	Trigger.AfterDelay(DateTime.Seconds(5), check)
end

-- Aircraft keep attacking well past their normal ammo, and never leave the map.
Scenarios["air"] = function()
	WaveConfig =
	{
		{
			Delay = DateTime.Seconds(1),
			Groups =
			{
				{ Units = { "yak" }, Lane = "north" },
				{ Units = { "hind" }, Lane = "south" }
			}
		}
	}

	-- Only aircraft, so they are the only ones attacking the tanks
	CoopWaves.RequireAntiAir = false
	KeepAlive()

	-- Sturdy targets for the aircraft, between the lanes. Heavy tanks can't shoot back at aircraft.
	local hits = { }
	for i = 0, 2 do
		local tank = Actor.Create("3tnk", true, { Owner = Humans[1], Location = CPos.New(40, 14 + 2 * i) })
		Trigger.OnDamaged(tank, function(_, attacker)
			if attacker then
				hits[attacker.Type] = (hits[attacker.Type] or 0) + 1
			end
		end)
	end

	local aircraft = { }
	CoopWaves.OnGroupSpawned = function(_, units)
		Utils.Do(units, function(a) aircraft[a.Type] = a end)
	end

	Trigger.AfterDelay(DateTime.Seconds(75), function()
		-- Normal ammo: 18 shots for the Yak, 24 for the Hind
		CoopTest.Assert((hits["yak"] or 0) > 18, "the Yak hit more than its 18 shots of ammo (" .. tostring(hits["yak"]) .. ")")
		CoopTest.Assert((hits["hind"] or 0) > 24, "the Hind hit more than its 24 shots of ammo (" .. tostring(hits["hind"]) .. ")")
		Utils.Do({ "yak", "hind" }, function(type)
			CoopTest.Assert(aircraft[type].IsInWorld and not aircraft[type].IsDead, type .. " is still over the map")
		end)

		Camera.Position = aircraft["hind"].CenterPosition
		CoopTest.Screenshot("aircraft")
		Trigger.AfterDelay(DateTime.Seconds(1), CoopTest.Pass)
	end)
end

-- The players win once the last wave has been sent and its last unit dies, and not before.
Scenarios["victory"] = function()
	WaveConfig =
	{
		{ Delay = DateTime.Seconds(2), Groups = { { Units = { "e1" }, Lane = "north" } } },
		{ Delay = DateTime.Seconds(5), Groups = { { Units = { "e1" }, Lane = "south", Delay = DateTime.Seconds(3) } } }
	}

	-- The game ends shortly after the win, so the scenario passes from here
	local wonAt = nil
	Trigger.OnPlayerWon(Humans[1], function()
		wonAt = DateTime.GameTime
		CoopTest.AssertEqual(CoopWaves.Started, 2, "waves started when won")
		CoopTest.AssertEqual(CoopWaves.Pending, 0, "groups still to be sent when won")
		CoopTest.AssertEqual(#Utils.Where(CoopWaves.Units, function(a) return not a.IsDead end), 0, "wave units alive when won")
		CoopTest.Pass()
	end)

	-- Kill every wave unit as soon as it has entered the map
	local killer
	killer = function()
		Utils.Do(CoopWaves.Units, function(a)
			if a.IsInWorld and not a.IsDead then
				a.Kill()
			end
		end)
		Trigger.AfterDelay(5, killer)
	end
	Trigger.AfterDelay(1, killer)

	-- Wave 2 starts at 7 seconds, and its group is sent 3 seconds later
	Trigger.AfterDelay(DateTime.Seconds(9), function()
		CoopTest.AssertEqual(CoopWaves.Started, 2, "waves started")
		CoopTest.AssertEqual(wonAt, nil, "won before the last group was sent")
	end)

	Trigger.AfterDelay(DateTime.Seconds(20), function()
		CoopTest.Assert(wonAt ~= nil, "won after every wave unit died")
	end)
end

-- Calling the next wave starts it at once, and restarts the countdown to the wave after it.
Scenarios["call-early"] = function()
	local wave = { Delay = DateTime.Seconds(30), Hint = "twolane-wave-1-hint", Groups = { { Units = { "e1" }, Lane = "north" } } }
	WaveConfig = { wave, wave, wave }

	-- The wave status display while counting down: the time left, the hint and the call button
	Trigger.AfterDelay(DateTime.Seconds(1), function()
		CoopTest.Screenshot("countdown")
	end)

	Trigger.AfterDelay(DateTime.Seconds(2), function()
		CoopTest.AssertEqual(CoopWaves.Started, 0, "waves started before calling one")
		CoopWaves.CallNextWave()
		CoopTest.AssertEqual(CoopWaves.Started, 1, "waves started right after calling one")
	end)

	-- The original countdown to wave 1 would have ended at 30 seconds: it must not start wave 2
	Trigger.AfterDelay(DateTime.Seconds(31), function()
		CoopTest.AssertEqual(CoopWaves.Started, 1, "waves started when the original countdown would have ended")
	end)

	-- The new countdown to wave 2 ends 30 seconds after the call
	Trigger.AfterDelay(DateTime.Seconds(33), function()
		CoopTest.AssertEqual(CoopWaves.Started, 2, "waves started after the restarted countdown")
		CoopTest.Pass()
	end)
end

-- With no player units left, ground units and aircraft attack the Construction Yard.
Scenarios["attack-base"] = function()
	WaveConfig =
	{
		{
			Delay = DateTime.Seconds(1),
			Groups =
			{
				{ Units = { "jeep" }, Lane = "north" },
				{ Units = { "yak" }, Lane = "north" },
				{ Units = { "hind" }, Lane = "south" }
			}
		}
	}

	local yard = Humans[1].GetActorsByType("fact")[1]
	local hits = { }
	Trigger.OnDamaged(yard, function(_, attacker)
		if attacker then
			hits[attacker.Type] = true
		end
	end)

	-- Don't let the yard die, which would lose the game
	local heal
	heal = function()
		if not yard.IsDead then
			yard.Health = yard.MaxHealth
			Trigger.AfterDelay(DateTime.Seconds(1), heal)
		end
	end
	heal()

	local check
	check = function()
		if hits["jeep"] and hits["yak"] and hits["hind"] then
			Camera.Position = yard.CenterPosition
			CoopTest.Screenshot("yard-attacked")
			Trigger.AfterDelay(DateTime.Seconds(1), CoopTest.Pass)
		else
			Trigger.AfterDelay(DateTime.Seconds(1), check)
		end
	end
	check()

	Trigger.AfterDelay(DateTime.Seconds(100), function()
		Utils.Do({ "jeep", "yak", "hind" }, function(type)
			CoopTest.Assert(hits[type], type .. " attacked the Construction Yard")
		end)
	end)
end

-- MAD tanks and Demolition Trucks charge the base and blow themselves up there.
-- The MAD tank has no weapon, so choosing its target mustn't rely on what it can attack.
Scenarios["suicide"] = function()
	WaveConfig =
	{
		{
			Delay = DateTime.Seconds(1),
			Groups =
			{
				{ Units = { "qtnk" }, Lane = "north" },
				{ Units = { "dtrk" }, Lane = "south" }
			}
		}
	}

	-- Only the two suicide units, so the scenario can wait for both to be dead
	CoopWaves.RequireAntiAir = false

	-- Keep the Construction Yards standing, so the game isn't lost
	KeepAlive()
	local heal
	heal = function()
		Utils.Do(Humans[1].GetActorsByType("fact"), function(yard) yard.Health = yard.MaxHealth end)
		Trigger.AfterDelay(5, heal)
	end
	heal()

	local units = { }
	CoopWaves.OnGroupSpawned = function(_, spawned)
		Utils.Do(spawned, function(a) units[#units + 1] = a end)
	end

	-- Pass once both are dead, or fail on the one still alive after 2 minutes
	local check
	check = function()
		if #units == 2 and Utils.All(units, function(a) return a.IsDead end) then
			CoopTest.Pass()
		elseif DateTime.GameTime > DateTime.Seconds(120) then
			Utils.Do(units, function(a)
				CoopTest.Assert(a.IsDead, a.Type .. " blew itself up")
			end)
		else
			Trigger.AfterDelay(DateTime.Seconds(1), check)
		end
	end
	Trigger.AfterDelay(DateTime.Seconds(2), check)
end

-- A group with Lane = "random" picks a lane each time it is sent, so a repeating group uses both lanes.
Scenarios["random-lane"] = function()
	WaveConfig =
	{
		{
			Delay = DateTime.Seconds(1),
			Groups = { { Units = { "e1" }, Lane = "random", Repeat = { Every = DateTime.Seconds(1), Times = 12 } } }
		}
	}

	KeepAlive()
	local sent = { north = 0, south = 0 }
	CoopWaves.OnGroupSpawned = function(_, _, laneName)
		sent[laneName] = sent[laneName] + 1
	end

	Trigger.AfterDelay(DateTime.Seconds(15), function()
		CoopTest.AssertEqual(sent.north + sent.south, 12, "groups sent")
		CoopTest.Assert(sent.north > 0 and sent.south > 0, "both lanes were used (north " .. sent.north .. ", south " .. sent.south .. ")")
		CoopTest.Pass()
	end)
end
