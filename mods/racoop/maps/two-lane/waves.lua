--[[
   The enemy waves of Two Lanes, run by racoop|scripts/coopwaves.lua.

   Each wave:
     Delay   Countdown to this wave, from the start of the previous wave (for wave 1: from the start of the game).
             Players can call the next wave early, which restarts the countdown from then.
     Hint    Fluent key (in map.ftl) describing the wave, shown while counting down to it.
     Groups  The groups of units the wave sends:
       Units   Unit types, in the order they enter (repeat a type to send more of it).
       Lane    "north", "south", or "random" to pick one of them each time the group is sent.
       Delay   Optional delay after the wave starts before the group is sent (default 0).
       Rank    Optional starting veterancy: 0 (default) to 4 (elite).
       Repeat  Optional: send the group again, e.g. { Every = DateTime.Seconds(20), Times = 3 } sends it 3 times in total.

   Ships, engineers, spies, thieves, mine layers, APCs, Chinooks, supply trucks, harvesters and MCVs can't be used.
   Medics and mechanics escort their group. Demolition trucks and MAD tanks charge straight at the players.
   Every wave needs at least one unit that can shoot at aircraft: rifle infantry, rocket soldiers, Rangers,
   flak trucks, mammoth tanks or Longbows (CoopWaves.AntiAirUnits).

   Each wave sends its groups over 1-2 minutes, and the countdown to the next wave is longer than that.
]]

local S = DateTime.Seconds

WaveConfig =
{
	-- 1
	{
		Delay = S(120),
		Hint = "twolane-wave-1-hint",
		Groups =
		{
			{ Units = { "e1", "e1", "e1" }, Lane = "random", Repeat = { Every = S(20), Times = 3 } },
			{ Units = { "dog" }, Lane = "random", Delay = S(10), Repeat = { Every = S(30), Times = 2 } },
			{ Units = { "e1", "e3" }, Lane = "random", Delay = S(50) },
			{ Units = { "jeep" }, Lane = "random", Delay = S(70) }
		}
	},
	-- 2
	{
		Delay = S(120),
		Hint = "twolane-wave-2-hint",
		Groups =
		{
			{ Units = { "e1", "e1", "e3", "e3" }, Lane = "random", Repeat = { Every = S(25), Times = 2 } },
			{ Units = { "e2", "e2", "medi" }, Lane = "random", Delay = S(15) },
			{ Units = { "jeep", "jeep" }, Lane = "random", Delay = S(60) },
			{ Units = { "dog", "dog" }, Lane = "random", Delay = S(80) }
		}
	},
	-- 3
	{
		Delay = S(135),
		Hint = "twolane-wave-3-hint",
		Groups =
		{
			{ Units = { "1tnk" }, Lane = "random", Repeat = { Every = S(30), Times = 3 } },
			{ Units = { "e1", "e1", "e1", "e1" }, Lane = "random", Delay = S(10), Repeat = { Every = S(30), Times = 3 } },
			{ Units = { "e3", "e3" }, Lane = "random", Delay = S(45) }
		}
	},
	-- 4
	{
		Delay = S(135),
		Hint = "twolane-wave-4-hint",
		Groups =
		{
			{ Units = { "e1", "e1", "e1", "e2", "e2" }, Lane = "north", Repeat = { Every = S(20), Times = 3 } },
			{ Units = { "e1", "e1", "e1", "e3", "e3" }, Lane = "south", Delay = S(10), Repeat = { Every = S(20), Times = 3 } },
			{ Units = { "e4", "e4", "medi" }, Lane = "random", Delay = S(40) }
		}
	},
	-- 5
	{
		Delay = S(135),
		Hint = "twolane-wave-5-hint",
		Groups =
		{
			{ Units = { "jeep", "jeep" }, Lane = "random", Repeat = { Every = S(30), Times = 2 } },
			{ Units = { "e3", "e3", "e3" }, Lane = "random", Delay = S(15), Repeat = { Every = S(30), Times = 2 } },
			{ Units = { "yak" }, Lane = "random", Delay = S(20), Repeat = { Every = S(30), Times = 2 } }
		}
	},
	-- 6
	{
		Delay = S(135),
		Hint = "twolane-wave-6-hint",
		Groups =
		{
			{ Units = { "2tnk", "2tnk", "mech" }, Lane = "random", Repeat = { Every = S(40), Times = 2 } },
			{ Units = { "1tnk", "e3", "e3" }, Lane = "random", Delay = S(20), Repeat = { Every = S(40), Times = 2 } },
			{ Units = { "dog", "dog", "dog" }, Lane = "random", Delay = S(60) }
		}
	},
	-- 7
	{
		Delay = S(150),
		Hint = "twolane-wave-7-hint",
		Groups =
		{
			{ Units = { "3tnk" }, Lane = "north", Repeat = { Every = S(45), Times = 2 } },
			{ Units = { "hind" }, Lane = "north", Delay = S(10) },
			{ Units = { "3tnk" }, Lane = "south", Delay = S(20), Repeat = { Every = S(45), Times = 2 } },
			{ Units = { "hind" }, Lane = "south", Delay = S(40) },
			{ Units = { "e1", "e1", "e3", "e3", "medi" }, Lane = "random", Delay = S(30), Repeat = { Every = S(30), Times = 2 } }
		}
	},
	-- 8
	{
		Delay = S(150),
		Hint = "twolane-wave-8-hint",
		Groups =
		{
			{ Units = { "2tnk", "2tnk" }, Lane = "random", Repeat = { Every = S(40), Times = 2 } },
			{ Units = { "e3", "e3", "e3", "e3" }, Lane = "random", Delay = S(15), Rank = 1, Repeat = { Every = S(40), Times = 2 } },
			{ Units = { "arty", "arty" }, Lane = "random", Delay = S(30), Repeat = { Every = S(40), Times = 2 } }
		}
	},
	-- 9
	{
		Delay = S(150),
		Hint = "twolane-wave-9-hint",
		Groups =
		{
			{ Units = { "jeep", "jeep", "jeep" }, Lane = "random", Repeat = { Every = S(20), Times = 4 } },
			{ Units = { "ftrk", "ftrk" }, Lane = "random", Delay = S(30), Repeat = { Every = S(40), Times = 2 } },
			{ Units = { "dtrk" }, Lane = "random", Delay = S(75) }
		}
	},
	-- 10
	{
		Delay = S(165),
		Hint = "twolane-wave-10-hint",
		Groups =
		{
			{ Units = { "3tnk", "3tnk", "mech" }, Lane = "random", Rank = 1, Repeat = { Every = S(45), Times = 2 } },
			{ Units = { "e4", "e4", "e1", "e1", "medi" }, Lane = "random", Delay = S(15), Repeat = { Every = S(45), Times = 2 } },
			{ Units = { "yak", "yak" }, Lane = "random", Delay = S(30), Repeat = { Every = S(45), Times = 2 } }
		}
	},
	-- 11
	{
		Delay = S(150),
		Hint = "twolane-wave-11-hint",
		Groups =
		{
			{ Units = { "e1", "e1", "e1", "e1", "e1", "e1" }, Lane = "random", Repeat = { Every = S(15), Times = 6 } },
			{ Units = { "e3", "e3", "e2", "e2" }, Lane = "random", Delay = S(8), Repeat = { Every = S(20), Times = 4 } },
			{ Units = { "shok", "shok", "medi" }, Lane = "random", Delay = S(30), Repeat = { Every = S(30), Times = 2 } },
			{ Units = { "dog", "dog", "dog", "dog" }, Lane = "random", Delay = S(50) }
		}
	},
	-- 12
	{
		Delay = S(165),
		Hint = "twolane-wave-12-hint",
		Groups =
		{
			{ Units = { "hind", "hind" }, Lane = "random", Repeat = { Every = S(40), Times = 2 } },
			{ Units = { "jeep", "jeep" }, Lane = "random", Repeat = { Every = S(40), Times = 2 } },
			{ Units = { "yak" }, Lane = "random", Delay = S(20), Repeat = { Every = S(40), Times = 3 } },
			{ Units = { "ftrk" }, Lane = "random", Delay = S(40) },
			{ Units = { "mig" }, Lane = "random", Delay = S(90) }
		}
	},
	-- 13
	{
		Delay = S(150),
		Hint = "twolane-wave-13-hint",
		Groups =
		{
			{ Units = { "ttnk", "ttnk" }, Lane = "random", Repeat = { Every = S(45), Times = 2 } },
			{ Units = { "e1", "e1", "e3", "e3", "medi" }, Lane = "random", Delay = S(10), Repeat = { Every = S(30), Times = 3 } },
			{ Units = { "2tnk", "3tnk", "mech" }, Lane = "random", Delay = S(20), Repeat = { Every = S(45), Times = 2 } }
		}
	},
	-- 14
	{
		Delay = S(165),
		Hint = "twolane-wave-14-hint",
		Groups =
		{
			{ Units = { "3tnk", "3tnk" }, Lane = "random", Repeat = { Every = S(40), Times = 3 } },
			{ Units = { "e3", "e3", "e3", "medi" }, Lane = "random", Delay = S(10), Rank = 1, Repeat = { Every = S(40), Times = 3 } },
			{ Units = { "v2rl", "v2rl" }, Lane = "random", Delay = S(25), Repeat = { Every = S(40), Times = 3 } }
		}
	},
	-- 15
	{
		Delay = S(180),
		Hint = "twolane-wave-15-hint",
		Groups =
		{
			{ Units = { "4tnk" }, Lane = "north", Rank = 1, Repeat = { Every = S(50), Times = 2 } },
			{ Units = { "2tnk", "2tnk", "mech" }, Lane = "random", Delay = S(10), Repeat = { Every = S(40), Times = 2 } },
			{ Units = { "4tnk" }, Lane = "south", Delay = S(25), Rank = 1, Repeat = { Every = S(50), Times = 2 } },
			{ Units = { "hind" }, Lane = "random", Delay = S(60), Repeat = { Every = S(30), Times = 2 } }
		}
	},
	-- 16
	{
		Delay = S(165),
		Hint = "twolane-wave-16-hint",
		Groups =
		{
			{ Units = { "jeep", "jeep", "1tnk", "1tnk" }, Lane = "random", Repeat = { Every = S(30), Times = 3 } },
			{ Units = { "shok", "shok", "shok" }, Lane = "random", Delay = S(15), Repeat = { Every = S(30), Times = 3 } },
			{ Units = { "dtrk" }, Lane = "random", Delay = S(30), Repeat = { Every = S(40), Times = 2 } },
			{ Units = { "qtnk" }, Lane = "random", Delay = S(60) }
		}
	},
	-- 17
	{
		Delay = S(165),
		Hint = "twolane-wave-17-hint",
		Groups =
		{
			{ Units = { "ctnk", "ctnk" }, Lane = "random", Rank = 2, Repeat = { Every = S(40), Times = 2 } },
			{ Units = { "e3", "e3", "e4", "e4", "medi" }, Lane = "random", Rank = 1, Repeat = { Every = S(30), Times = 3 } },
			{ Units = { "3tnk", "3tnk", "mech" }, Lane = "random", Delay = S(20), Rank = 1, Repeat = { Every = S(40), Times = 2 } }
		}
	},
	-- 18
	{
		Delay = S(180),
		Hint = "twolane-wave-18-hint",
		Groups =
		{
			{ Units = { "hind", "hind" }, Lane = "random", Repeat = { Every = S(40), Times = 3 } },
			{ Units = { "3tnk", "3tnk" }, Lane = "random", Repeat = { Every = S(60), Times = 2 } },
			{ Units = { "ftrk", "ftrk" }, Lane = "random", Delay = S(10), Repeat = { Every = S(60), Times = 2 } },
			{ Units = { "mig" }, Lane = "random", Delay = S(20), Repeat = { Every = S(40), Times = 3 } },
			{ Units = { "yak", "yak" }, Lane = "random", Delay = S(30), Repeat = { Every = S(45), Times = 2 } },
			{ Units = { "heli" }, Lane = "random", Delay = S(50), Repeat = { Every = S(40), Times = 2 } }
		}
	},
	-- 19
	{
		Delay = S(180),
		Hint = "twolane-wave-19-hint",
		Groups =
		{
			{ Units = { "4tnk", "4tnk", "mech" }, Lane = "north", Rank = 2, Repeat = { Every = S(60), Times = 2 } },
			{ Units = { "e3", "e3", "e3", "e3", "medi" }, Lane = "random", Rank = 2, Repeat = { Every = S(30), Times = 3 } },
			{ Units = { "v2rl", "arty" }, Lane = "random", Delay = S(20), Repeat = { Every = S(40), Times = 3 } },
			{ Units = { "4tnk", "4tnk", "mech" }, Lane = "south", Delay = S(30), Rank = 2, Repeat = { Every = S(60), Times = 2 } }
		}
	},
	-- 20
	{
		Delay = S(180),
		Hint = "twolane-wave-20-hint",
		Groups =
		{
			{ Units = { "4tnk", "4tnk", "3tnk", "mech" }, Lane = "random", Rank = 3, Repeat = { Every = S(40), Times = 3 } },
			{ Units = { "e3", "e3", "e3", "e4", "e4", "shok", "shok", "medi" }, Lane = "random", Rank = 2, Repeat = { Every = S(30), Times = 4 } },
			{ Units = { "hind", "hind" }, Lane = "random", Delay = S(10), Repeat = { Every = S(40), Times = 3 } },
			{ Units = { "ttnk", "ctnk" }, Lane = "random", Delay = S(20), Rank = 2, Repeat = { Every = S(40), Times = 2 } },
			{ Units = { "mig", "mig" }, Lane = "random", Delay = S(30), Repeat = { Every = S(40), Times = 2 } },
			{ Units = { "qtnk" }, Lane = "north", Delay = S(60) },
			{ Units = { "dtrk" }, Lane = "south", Delay = S(90) }
		}
	}
}
