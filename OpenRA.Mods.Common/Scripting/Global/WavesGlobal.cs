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

using Eluant;
using OpenRA.Mods.Common.Traits;
using OpenRA.Scripting;

namespace OpenRA.Mods.Common.Scripting
{
	[ScriptGlobal("Waves")]
	public class WavesGlobal : ScriptGlobal
	{
		readonly WaveStatus status;

		public WavesGlobal(ScriptContext context)
			: base(context)
		{
			status = context.World.WorldActor.TraitOrDefault<WaveStatus>();
		}

		WaveStatus Status => status ?? throw new LuaException("The Waves global requires the WaveStatus trait on the world actor.");

		[Desc("Update the wave status display: the number of waves started so far, the total number of waves, " +
			"the ticks until the next wave starts (-1 if none is counting down, which also stops it being called early), " +
			"and an optional description of the next wave.")]
		public void SetStatus(int wave, int total, int ticksUntilNextWave = -1, string hint = null)
		{
			Status.SetStatus(wave, total, ticksUntilNextWave, hint);
		}

		[Desc("True when a player has called the next wave early. Call ClearCall() once it has been handled.")]
		public bool CallRequested => Status.CallRequested;

		[Desc("Mark a call for the next wave as handled.")]
		public void ClearCall()
		{
			Status.ClearCall();
		}
	}
}
