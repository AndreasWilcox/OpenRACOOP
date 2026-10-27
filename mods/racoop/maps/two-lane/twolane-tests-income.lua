--[[
   Test scenarios for kill income (GivesDamageShareBounty in racoop|rules/income.yaml), added to the Scenarios table
   from twolane-tests.lua. Damage is dealt with Test.Damage, so the results don't depend on combat.
   With only one human in a test game, the rules for several damaging players (most damage wins, ties go to the
   last hitter) are covered by the DamageShareLedger unit tests in OpenRA.Test instead.
]]

-- An actor of the first human to deal damage with. Any actor counts for its owner, even a building.
local function HumanAttacker()
	return Humans[1].GetActorsByType("fact")[1]
end

-- An enemy unit standing between the lanes, far from the players, with no orders.
local function SpawnEnemy(type, y)
	return Actor.Create(type, true, { Owner = Enemy, Location = CPos.New(40, y) })
end

-- Killing an enemy unit pays 30% of its cost to the player that damaged it, and RA's kill bounty doesn't pay as well.
Scenarios["income-kill"] = function()
	local player = Humans[1]
	CoopTest.Assert(not player.HasPrerequisites({ "global-bounty" }), "RA's kill bounty option is off")

	local rifle = SpawnEnemy("e1", 14)
	Camera.Position = rifle.CenterPosition
	local cash = player.Cash
	Test.Damage(rifle, HumanAttacker(), 2000)
	CoopTest.AssertEqual(player.Cash, cash, "cash after damaging without killing")
	Test.Damage(rifle, HumanAttacker(), rifle.MaxHealth)
	CoopTest.Assert(rifle.IsDead, "the rifle infantry is dead")
	CoopTest.AssertEqual(player.Cash - cash, 30, "cash for killing a rifle infantry costing 100")

	-- The floating "+$30" is shown over where the unit died
	Trigger.AfterDelay(2, function()
		CoopTest.Screenshot("bounty")
		Trigger.AfterDelay(DateTime.Seconds(1), CoopTest.Pass)
	end)
end

-- A ranked enemy is worth 25% more of its cost per rank.
Scenarios["income-ranked"] = function()
	local player = Humans[1]
	local tank = SpawnEnemy("3tnk", 16)
	tank.GiveLevels(2, true)
	CoopTest.AssertEqual(tank.Level, 2, "rank of the heavy tank")

	local cash = player.Cash
	Test.Damage(tank, HumanAttacker(), tank.MaxHealth)
	CoopTest.Assert(tank.IsDead, "the heavy tank is dead")

	-- 1150 * 150% = 1725, and 30% of that is 517 (rounded down)
	CoopTest.AssertEqual(player.Cash - cash, 517, "cash for killing a heavy tank costing 1150 at rank 2")
	CoopTest.Pass()
end

-- Only the damage the unit still had HP for counts, and healing doesn't take damage away.
Scenarios["income-overkill"] = function()
	local player = Humans[1]
	local tank = SpawnEnemy("2tnk", 18)
	local hp = tank.MaxHealth

	Test.Damage(tank, HumanAttacker(), 1000)
	CoopTest.AssertEqual(Test.DamageDealt(tank, player), 1000, "damage counted for a normal hit")

	-- Healing (negative damage) raises the HP but doesn't count against the damage dealt
	Test.Damage(tank, HumanAttacker(), -500)
	CoopTest.AssertEqual(tank.Health, hp - 500, "health after healing")
	CoopTest.AssertEqual(Test.DamageDealt(tank, player), 1000, "damage counted after healing")

	-- A hit far larger than the HP left only counts the HP that was left
	local cash = player.Cash
	Test.Damage(tank, HumanAttacker(), hp * 10)
	CoopTest.Assert(tank.IsDead, "the medium tank is dead")
	CoopTest.AssertEqual(Test.DamageDealt(tank, player), 1000 + (hp - 500), "damage counted after an overkill hit")

	-- 30% of 850
	CoopTest.AssertEqual(player.Cash - cash, 255, "cash for killing a medium tank costing 850")
	CoopTest.Pass()
end

-- Nobody is paid for units that no player damaged, and the enemy isn't paid for killing player units.
Scenarios["income-no-damage"] = function()
	local player = Humans[1]
	local cash = player.Cash
	local enemyCash = Enemy.Cash

	-- Killed by the script
	local rifle = SpawnEnemy("e1", 20)
	rifle.Kill()
	CoopTest.Assert(rifle.IsDead, "the rifle infantry killed by the script is dead")

	-- Damaged and killed by another enemy unit
	local tank = SpawnEnemy("2tnk", 22)
	local other = SpawnEnemy("e1", 24)
	Test.Damage(tank, other, 1000)
	Test.Damage(tank, other, tank.MaxHealth)
	CoopTest.Assert(tank.IsDead, "the medium tank killed by an enemy unit is dead")
	CoopTest.AssertEqual(Test.DamageDealt(tank, Enemy), 0, "damage counted for the enemy")
	CoopTest.AssertEqual(player.Cash, cash, "player cash after kills without player damage")

	-- A player unit killed by an enemy unit: the non-combatant enemy can't be paid
	local own = Actor.Create("e1", true, { Owner = player, Location = CPos.New(42, 24) })
	Test.Damage(own, other, own.MaxHealth)
	CoopTest.Assert(own.IsDead, "the player's rifle infantry is dead")
	CoopTest.AssertEqual(Enemy.Cash, enemyCash, "enemy cash after killing a player unit")
	CoopTest.Pass()
end
