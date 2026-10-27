--[[
   Automated test scenarios that don't depend on a map's layout, run with `coop test -Map test-range`.
   Each scenario must be listed in the `ScriptLobbyDropdown@test` values in rules.yaml.
   This file holds the force scenarios; the testrange-tests-<feature>.lua files add the rest.
]]

Scenarios = { }

-- What each force can build (see racoop|rules/forces.yaml), sorted by name.
-- Tech Center units are listed separately: they can only be built once there is a Tech Center.
local CommonBuildings = { "atek", "dome", "fix", "powr", "upgr" }
local Forces =
{
	infantry = { Buildings = { "barr" }, Units = { "e1", "e2", "e3", "medi" }, TechUnits = { "e4" } },
	tanks = { Buildings = { "weap" }, Units = { "1tnk", "3tnk", "jeep" }, TechUnits = { "4tnk" } },
	air = { Buildings = { "afld", "hpad", "weap.air" }, Units = { "ftrk", "heli", "hind", "yak" }, TechUnits = { "mig" } },
	support = { Buildings = { "weap" }, Units = { "arty", "mnly" }, TechUnits = { "dtrk", "v2rl" } }
}

local function Sorted(...)
	local all = { }
	for _, list in ipairs({ ... }) do
		for _, item in ipairs(list) do
			all[#all + 1] = item
		end
	end

	table.sort(all)
	return table.concat(all, ", ")
end

local function Buildable(player)
	return table.concat(Test.BuildableItems(player), ", ")
end

-- A force (set with the scenario name, see coop.ps1) sees the whole map, starts with an undeployable Construction Yard
-- and 4000 cash, and can build exactly its own buildings and units plus the common buildings.
for name, force in pairs(Forces) do
	Scenarios["force-" .. name] = function()
		local player = Humans[1]
		CoopTest.AssertEqual(player.Faction, name, "force")
		CoopTest.AssertEqual(player.Cash, 4000, "starting cash")

		-- The whole map is visible: check the far east edge
		CoopTest.Assert(Test.CellVisible(player, CPos.New(40, 16)), "the east edge of the map is visible")

		local yards = player.GetActorsByType("fact")
		CoopTest.AssertEqual(#yards, 1, "Construction Yards at the start")
		CoopTest.AssertEqual(#player.GetActorsByType("mcv"), 0, "MCVs at the start")

		yards[1].Deploy()
		Trigger.AfterDelay(DateTime.Seconds(3), function()
			CoopTest.Assert(not yards[1].IsDead and #player.GetActorsByType("mcv") == 0, "the Construction Yard can't be packed up")
			CoopTest.AssertEqual(Buildable(player), Sorted(CommonBuildings, force.Buildings), "buildable with only a Construction Yard")

			local x = 3
			for _, building in ipairs(force.Buildings) do
				Actor.Create(building, true, { Owner = player, Location = CPos.New(x, 13) })
				x = x + 5
			end
		end)

		Trigger.AfterDelay(DateTime.Seconds(5), function()
			CoopTest.AssertEqual(Buildable(player), Sorted(CommonBuildings, force.Buildings, force.Units), "buildable with the force's production buildings")
			Actor.Create("atek", true, { Owner = player, Location = CPos.New(3, 19) })
		end)

		Trigger.AfterDelay(DateTime.Seconds(7), function()
			CoopTest.AssertEqual(Buildable(player), Sorted(CommonBuildings, force.Buildings, force.Units, force.TechUnits), "buildable with a Tech Center")
			CoopTest.Screenshot("sidebar")
			Trigger.AfterDelay(DateTime.Seconds(1), CoopTest.Pass)
		end)
	end
end
