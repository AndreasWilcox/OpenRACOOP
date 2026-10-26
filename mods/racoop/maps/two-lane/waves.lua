--[[
   The enemy waves of Two Lanes, run by racoop|scripts/coopwaves.lua.

   Each wave:
     Delay   Countdown to this wave, from the start of the previous wave (for wave 1: from the start of the game).
             Players can call the next wave early, which restarts the countdown from then.
     Hint    Fluent key (in map.ftl) describing the wave, shown while counting down to it.
     Groups  The groups of units the wave sends:
       Units   Unit types, in the order they enter (repeat a type to send more of it).
       Lane    "north" or "south".
       Delay   Optional delay after the wave starts before the group is sent (default 0).
       Rank    Optional starting veterancy: 0 (default) to 4 (elite).
       Repeat  Optional: send the group again, e.g. { Every = DateTime.Seconds(20), Times = 3 } sends it 3 times in total.

   Ships, engineers, spies, thieves, mine layers, APCs, Chinooks, supply trucks, harvesters and MCVs can't be used.
   Medics and mechanics escort their group. Demolition trucks and MAD tanks charge straight at the players.
]]

WaveConfig =
{
	{
		Delay = DateTime.Seconds(120),
		Hint = "twolane-wave-1-hint",
		Groups =
		{
			{ Units = { "e1", "e1", "e1", "e1" }, Lane = "north" },
			{ Units = { "e1", "e1", "e1", "e1" }, Lane = "south", Delay = DateTime.Seconds(10) }
		}
	},
	{
		Delay = DateTime.Seconds(75),
		Hint = "twolane-wave-2-hint",
		Groups =
		{
			{ Units = { "e1", "e1", "e3", "e3" }, Lane = "north" },
			{ Units = { "e1", "e1", "e2", "e2" }, Lane = "south", Delay = DateTime.Seconds(10) }
		}
	},
	{
		Delay = DateTime.Seconds(75),
		Hint = "twolane-wave-3-hint",
		Groups =
		{
			{ Units = { "jeep", "jeep" }, Lane = "north" },
			{ Units = { "e1", "e1", "e1", "e3", "medi" }, Lane = "south" }
		}
	},
	{
		Delay = DateTime.Seconds(75),
		Hint = "twolane-wave-4-hint",
		Groups =
		{
			{ Units = { "1tnk", "1tnk" }, Lane = "north" },
			{ Units = { "1tnk", "1tnk" }, Lane = "south", Delay = DateTime.Seconds(15) }
		}
	},
	{
		Delay = DateTime.Seconds(75),
		Hint = "twolane-wave-5-hint",
		Groups =
		{
			{ Units = { "e1", "e1", "e1", "e3", "e3" }, Lane = "north", Repeat = { Every = DateTime.Seconds(20), Times = 2 } },
			{ Units = { "yak" }, Lane = "south", Delay = DateTime.Seconds(20) }
		}
	},
	{
		Delay = DateTime.Seconds(75),
		Hint = "twolane-wave-6-hint",
		Groups =
		{
			{ Units = { "2tnk", "2tnk", "mech" }, Lane = "north" },
			{ Units = { "e4", "e4", "e4", "e2", "e2" }, Lane = "south", Delay = DateTime.Seconds(10) }
		}
	},
	{
		Delay = DateTime.Seconds(75),
		Hint = "twolane-wave-7-hint",
		Groups =
		{
			{ Units = { "hind", "hind" }, Lane = "north" },
			{ Units = { "3tnk", "3tnk" }, Lane = "south" }
		}
	},
	{
		Delay = DateTime.Seconds(75),
		Hint = "twolane-wave-8-hint",
		Groups =
		{
			{ Units = { "2tnk", "2tnk", "arty", "arty" }, Lane = "south" },
			{ Units = { "e3", "e3", "e3", "e3" }, Lane = "north", Rank = 1 }
		}
	},
	{
		Delay = DateTime.Seconds(75),
		Hint = "twolane-wave-9-hint",
		Groups =
		{
			{ Units = { "3tnk", "3tnk", "3tnk" }, Lane = "south", Rank = 1 },
			{ Units = { "yak", "yak" }, Lane = "north", Repeat = { Every = DateTime.Seconds(30), Times = 2 } },
			{ Units = { "dtrk" }, Lane = "north", Delay = DateTime.Seconds(30) }
		}
	},
	{
		Delay = DateTime.Seconds(90),
		Hint = "twolane-wave-10-hint",
		Groups =
		{
			{ Units = { "4tnk", "4tnk" }, Lane = "north", Rank = 2 },
			{ Units = { "4tnk", "4tnk" }, Lane = "south", Rank = 2 },
			{ Units = { "mig", "mig" }, Lane = "north", Delay = DateTime.Seconds(20) },
			{ Units = { "qtnk" }, Lane = "south", Delay = DateTime.Seconds(30) }
		}
	}
}
