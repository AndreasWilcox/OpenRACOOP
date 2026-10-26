#region Copyright & License Information
/*
 * Copyright (c) The OpenRA Developers and Contributors
 * This file is part of OpenRA, which is free software. It is made
 * available to you under the terms of the GNU General Public License
 * as published by the Free Software Foundation, either version 3 of
 * the License, or (at your option) any later version. For more
 * information, see COPYING.
 */
#endregion

using OpenRA.Traits;

namespace OpenRA.Mods.Common.Traits
{
	[TraitLocation(SystemActors.World)]
	[Desc("Tracks the progress of enemy waves sent by the map script, for the wave status display",
		"and for players calling the next wave early. The script updates it through the `Waves` Lua global.")]
	public sealed class WaveStatusInfo : TraitInfo
	{
		public override object Create(ActorInitializer init) { return new WaveStatus(init.World); }
	}

	public sealed class WaveStatus : ISync
	{
		readonly World world;

		[VerifySync]
		public int Wave { get; private set; }

		[VerifySync]
		public int Total { get; private set; }

		/// <summary>World tick at which the next wave starts, or -1 if no wave is counting down.</summary>
		[VerifySync]
		public int NextWaveTick { get; private set; } = -1;

		/// <summary>Set when a player has called the next wave early, until the script handles it.</summary>
		[VerifySync]
		public bool CallRequested { get; private set; }

		/// <summary>Description of the next wave, shown while it is counting down. Display only.</summary>
		public string NextWaveHint { get; private set; }

		public WaveStatus(World world)
		{
			this.world = world;
		}

		public bool IsCountingDown => NextWaveTick >= 0;
		public int TicksUntilNextWave => IsCountingDown ? NextWaveTick - world.WorldTick : 0;

		public void SetStatus(int wave, int total, int ticksUntilNextWave, string hint)
		{
			Wave = wave;
			Total = total;
			NextWaveTick = ticksUntilNextWave >= 0 ? world.WorldTick + ticksUntilNextWave : -1;
			NextWaveHint = hint;
		}

		public bool RequestCall()
		{
			if (!IsCountingDown || CallRequested)
				return false;

			CallRequested = true;
			return true;
		}

		public void ClearCall()
		{
			CallRequested = false;
		}
	}
}
