--[[
   Runs the enemy waves of a co-op map from a wave config, and decides when the players win or lose.

   A map opts in by:
     - loading this file (and racoop|fluent/lua.ftl in its FluentMessages),
     - defining its waves as `WaveConfig` (see maps/two-lane/waves.lua for the format),
     - placing waypoint actors for each lane: where the units enter, the gap they head for on the enemy's side,
       and the gap on the players' side they attack-move to before going after the players,
     - calling `CoopWaves.Start(WaveConfig, lanes, humans, enemy)` from WorldLoaded.

   The wave status display and the "Call next wave" button are driven through the `Waves` global
   (the WaveStatus and CallNextWave traits).
]]

CoopWaves = { }

-- Units that can't be sent in waves: ships (there's no route by water), and units that have nothing
-- to do without an enemy base or would only frustrate (engineers, spies, thieves, mine layers, transports, ...).
CoopWaves.ExcludedUnits =
{
	"e6", "spy", "thf", "mnly", "apc", "tran", "harv", "mcv", "truk",
	"ss", "msub", "dd", "ca", "pt", "lst"
}

-- Units that escort their group instead of fighting.
CoopWaves.EscortUnits = { "medi", "mech" }

-- What the enemy goes for once there are no player units left to fight.
CoopWaves.BaseTypes = { "fact" }

-- What the players must keep at least one of: losing them all loses the game.
CoopWaves.LifelineTypes = { "fact", "mcv" }

-- Units that can shoot at aircraft (rifles, rockets, machine guns, flak, mammoth tusks, Longbow missiles).
-- Every wave must have one, so a player relying on aircraft always meets some resistance.
CoopWaves.AntiAirUnits = { "e1", "e3", "jeep", "ftrk", "4tnk", "heli" }

-- Set to false (e.g. in a test) to allow waves without anti-air units.
CoopWaves.RequireAntiAir = true

-- A group with this lane is sent down a randomly picked lane, every time it is sent.
CoopWaves.RandomLane = "random"

local function Contains(list, value)
	return Utils.Any(list, function(v) return v == value end)
end

local function ConfigError(message)
	error("Wave config: " .. message)
end

-- Fail early (and loudly, in `coop smoke`) on mistakes in the config.
local function Validate(config, lanes)
	if #config == 0 then
		ConfigError("no waves defined")
	end

	for i, wave in ipairs(config) do
		local where = "wave " .. i
		if type(wave.Delay) ~= "number" or wave.Delay < 0 then
			ConfigError(where .. " needs a Delay")
		end

		if not wave.Groups or #wave.Groups == 0 then
			ConfigError(where .. " has no Groups")
		end

		local antiAir = false
		for j, group in ipairs(wave.Groups) do
			local groupWhere = where .. ", group " .. j
			if group.Lane ~= CoopWaves.RandomLane and not lanes[group.Lane] then
				ConfigError(groupWhere .. " has unknown lane '" .. tostring(group.Lane) .. "'")
			end

			if not group.Units or #group.Units == 0 then
				ConfigError(groupWhere .. " has no Units")
			end

			for _, unit in ipairs(group.Units) do
				-- Throws for unknown actor types
				Actor.Cost(unit)
				if Contains(CoopWaves.ExcludedUnits, unit) then
					ConfigError(groupWhere .. ": '" .. unit .. "' can't be used in waves")
				end

				antiAir = antiAir or Contains(CoopWaves.AntiAirUnits, unit)
			end

			if group.Rank and (group.Rank < 0 or group.Rank > 4) then
				ConfigError(groupWhere .. " has Rank " .. group.Rank .. ", which must be between 0 and 4")
			end

			if group.Repeat and (not group.Repeat.Every or group.Repeat.Every <= 0 or not group.Repeat.Times or group.Repeat.Times < 1) then
				ConfigError(groupWhere .. " needs Repeat = { Every = <ticks>, Times = <count> }")
			end
		end

		if CoopWaves.RequireAntiAir and not antiAir then
			ConfigError(where .. " has no unit that can shoot at aircraft (one of " .. table.concat(CoopWaves.AntiAirUnits, ", ") .. ")")
		end
	end
end

-- Actors of the human players that are still alive, matching the filter.
local function HumanActors(filter)
	local actors = { }
	Utils.Do(CoopWaves.Humans, function(player)
		Utils.Do(player.GetActors(), function(a)
			if not a.IsDead and a.IsInWorld and a.HasProperty("Health") and filter(a) then
				actors[#actors + 1] = a
			end
		end)
	end)

	return actors
end

local function Closest(actor, candidates)
	local best, bestDistance = nil, nil
	for _, candidate in ipairs(candidates) do
		local dx = candidate.Location.X - actor.Location.X
		local dy = candidate.Location.Y - actor.Location.Y
		local distance = dx * dx + dy * dy
		if not bestDistance or distance < bestDistance then
			best, bestDistance = candidate, distance
		end
	end

	return best
end

-- Whether the actor can attack the target. Actors without a weapon (MAD tanks) go for anything on the ground.
local function CanAttack(actor, target)
	if actor.HasProperty("CanTarget") then
		return actor.CanTarget(target)
	end

	return target.CenterPosition.Z == 0
end

-- The closest player unit the actor can attack. If there are none, the closest Construction Yard, then any building.
local function ChooseTarget(actor)
	local function Attackable(a) return CanAttack(actor, a) end

	local units = HumanActors(function(a) return a.HasProperty("Move") and Attackable(a) end)
	if #units > 0 then
		return Closest(actor, units)
	end

	local bases = HumanActors(function(a) return Contains(CoopWaves.BaseTypes, a.Type) and Attackable(a) end)
	if #bases > 0 then
		return Closest(actor, bases)
	end

	return Closest(actor, HumanActors(Attackable))
end

-- Whether any player unit can be attacked by the actor.
local function PlayerUnitsLeft(actor)
	return #HumanActors(function(a) return a.HasProperty("Move") and CanAttack(actor, a) end) > 0
end

-- While attacking a building, check every second for player units to go after instead.
-- Stopping makes the actor idle, so it picks a new target.
local function AttackBuilding(actor, target)
	actor.Attack(target)

	local check
	check = function()
		if actor.IsDead or target.IsDead or not actor.IsInWorld then
			return
		end

		if PlayerUnitsLeft(actor) then
			actor.Stop()
		else
			Trigger.AfterDelay(DateTime.Seconds(1), check)
		end
	end

	Trigger.AfterDelay(DateTime.Seconds(1), check)
end

-- Go after the players: attack-move towards the closest target, picking a new one whenever idle.
-- Attack-moving means anything that crosses the unit's path is fought on the way.
-- Attack-moving units only pick defenses among buildings, so other buildings are attacked directly.
local function Engage(actor)
	Trigger.OnIdle(actor, function()
		local target = ChooseTarget(actor)
		if not target then
			actor.Wait(DateTime.Seconds(1))
		elseif actor.Type == "dtrk" then
			actor.Attack(target)
		elseif actor.Type == "qtnk" then
			actor.Detonate(target)
		elseif not target.HasProperty("Move") then
			AttackBuilding(actor, target)
		else
			actor.AttackMove(target.Location, 2)
		end
	end)
end

-- Medics and mechanics follow a fighting member of their group, and look for another when it dies.
local function Escort(actor, group)
	Trigger.OnIdle(actor, function()
		local leader = Utils.Where(group, function(a)
			return not a.IsDead and not Contains(CoopWaves.EscortUnits, a.Type)
		end)[1]

		if leader then
			actor.Guard(leader)
		else
			actor.Wait(DateTime.Seconds(1))
		end
	end)
end

local function SpawnGroup(group)
	-- Utils.Random uses the shared random, so every player picks the same lane
	local laneName = group.Lane
	if laneName == CoopWaves.RandomLane then
		laneName = Utils.Random(CoopWaves.LaneNames)
	end

	local lane = CoopWaves.Lanes[laneName]
	local path = { lane.Spawn.Location, lane.EastGap.Location }
	local units

	-- Runs as each unit reaches the gap on the enemy's side of its lane
	local onArrival = function(a)
		if Contains(CoopWaves.EscortUnits, a.Type) then
			Escort(a, units)
		elseif a.Type == "dtrk" or a.Type == "qtnk" then
			-- Charge straight at the players
			Engage(a)
		else
			a.AttackMove(lane.WestGap.Location, 2)
			Engage(a)
		end
	end

	units = Reinforcements.Reinforce(CoopWaves.Enemy, group.Units, path, DateTime.Seconds(1), onArrival)
	Utils.Do(units, function(a)
		-- Gives aircraft unlimited ammo
		if a.HasProperty("GrantCondition") and a.AcceptsCondition("wave-unit") then
			a.GrantCondition("wave-unit")
		end

		if group.Rank and group.Rank > 0 and a.HasProperty("GiveLevels") then
			a.GiveLevels(group.Rank, true)
		end

		CoopWaves.Units[#CoopWaves.Units + 1] = a
	end)

	CoopWaves.OnGroupSpawned(group, units, laneName)
end

--- Called with every group as it spawns, for tests to hook into.
---@param group table
---@param units actor[]
---@param laneName string The lane it was sent down (picked when the group's Lane is "random")
CoopWaves.OnGroupSpawned = function(group, units, laneName) end

local function Hint(wave)
	local hint = CoopWaves.Config[wave] and CoopWaves.Config[wave].Hint
	return hint and UserInterface.GetFluentMessage(hint) or nil
end

-- Count down to the given wave. Starting another countdown (or a wave early) cancels this one.
local function CountDownTo(wave)
	CoopWaves.Countdown = CoopWaves.Countdown + 1
	local countdown = CoopWaves.Countdown
	local delay = CoopWaves.Config[wave].Delay

	Waves.SetStatus(wave - 1, #CoopWaves.Config, delay, Hint(wave))
	Trigger.AfterDelay(delay, function()
		if countdown == CoopWaves.Countdown then
			CoopWaves.StartWave(wave)
		end
	end)
end

---@param wave integer
CoopWaves.StartWave = function(wave)
	CoopWaves.Started = wave
	CoopWaves.Countdown = CoopWaves.Countdown + 1

	if wave < #CoopWaves.Config then
		CountDownTo(wave + 1)
	else
		Waves.SetStatus(wave, #CoopWaves.Config, -1)
	end

	Utils.Do(CoopWaves.Config[wave].Groups, function(group)
		local times = group.Repeat and group.Repeat.Times or 1
		for i = 0, times - 1 do
			-- Spawn undelayed groups right away: AfterDelay(0) would wait a tick, putting them out of step with the rest
			local delay = (group.Delay or 0) + i * (group.Repeat and group.Repeat.Every or 0)
			if delay == 0 then
				SpawnGroup(group)
			else
				CoopWaves.Pending = CoopWaves.Pending + 1
				Trigger.AfterDelay(delay, function()
					CoopWaves.Pending = CoopWaves.Pending - 1
					SpawnGroup(group)
				end)
			end
		end
	end)

	local message = UserInterface.GetFluentMessage("coop-wave-started", { ["wave"] = wave, ["total"] = #CoopWaves.Config })
	Utils.Do(CoopWaves.Humans, function(player)
		Media.PlaySpeechNotification(player, "EnemyUnitsApproaching")
	end)
	Media.DisplayMessage(message, UserInterface.GetFluentMessage("coop-waves-prefix"))
end

--- Start the next wave now, as when a player calls it early. Does nothing if no wave is counting down.
CoopWaves.CallNextWave = function()
	if CoopWaves.Started < #CoopWaves.Config and not CoopWaves.Finished then
		CoopWaves.StartWave(CoopWaves.Started + 1)
	end
end

local function Finish(won)
	CoopWaves.Finished = true
	CoopWaves.Countdown = CoopWaves.Countdown + 1
	Waves.SetStatus(CoopWaves.Started, #CoopWaves.Config, -1)

	Utils.Do(CoopWaves.Humans, function(player)
		if won then
			player.MarkCompletedObjective(CoopWaves.Objectives[player.InternalName])
		else
			player.MarkFailedObjective(CoopWaves.Objectives[player.InternalName])
		end
	end)
end

-- Once a second: handle calls for the next wave, and check whether the game is won or lost.
local function Check()
	if CoopWaves.Finished then
		return
	end

	if Waves.CallRequested then
		Waves.ClearCall()
		CoopWaves.CallNextWave()
	end

	CoopWaves.Units = Utils.Where(CoopWaves.Units, function(a) return not a.IsDead end)
	if CoopWaves.Started == #CoopWaves.Config and CoopWaves.Pending == 0 and #CoopWaves.Units == 0 then
		Finish(true)
		return
	end

	local lifelines = HumanActors(function(a) return Contains(CoopWaves.LifelineTypes, a.Type) end)
	if #lifelines == 0 then
		Finish(false)
		return
	end

	Trigger.AfterDelay(DateTime.Seconds(1), Check)
end

--- Start running the waves: the countdown to the first wave starts now.
---@param config table The waves, in order (see maps/two-lane/waves.lua)
---@param lanes table<string, { Spawn: actor, EastGap: actor, WestGap: actor }> Waypoints of each lane, by name
---@param humans player[] The players defending against the waves
---@param enemy player The player owning the waves
CoopWaves.Start = function(config, lanes, humans, enemy)
	Validate(config, lanes)

	CoopWaves.Config = config
	CoopWaves.Lanes = lanes

	-- Sorted, so random lanes are picked from the same list on every player's machine
	CoopWaves.LaneNames = { }
	for name in pairs(lanes) do
		CoopWaves.LaneNames[#CoopWaves.LaneNames + 1] = name
	end
	table.sort(CoopWaves.LaneNames)
	CoopWaves.Humans = humans
	CoopWaves.Enemy = enemy

	-- Number of waves started, spawns still to come, and the spawned units that may still be alive
	CoopWaves.Started = 0
	CoopWaves.Pending = 0
	CoopWaves.Units = { }
	CoopWaves.Countdown = 0
	CoopWaves.Finished = false

	CoopWaves.Objectives = { }
	Utils.Do(humans, function(player)
		CoopWaves.Objectives[player.InternalName] = player.AddPrimaryObjective(UserInterface.GetFluentMessage("coop-objective-survive"))
	end)

	CountDownTo(1)
	Trigger.AfterDelay(DateTime.Seconds(1), Check)
end
