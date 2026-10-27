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

using System.Collections.Generic;
using OpenRA.Traits;

namespace OpenRA.Mods.Common.Traits
{
	[TraitLocation(SystemActors.Player)]
	[Desc("Counts the player's actors that have the CountedOwnedActor trait, by type.",
		"Used by the *PerOwnedActor traits.")]
	public class OwnedActorCounterInfo : TraitInfo<OwnedActorCounter> { }

	public class OwnedActorCounter : ISync
	{
		readonly Dictionary<string, int> owned = [];
		readonly Dictionary<string, int> active = [];

		[VerifySync]
		public int TotalActive { get; private set; }

		// Number of owned actors of this type, including ones where CountedOwnedActor is disabled.
		public int Owned(string type) { return owned.GetValueOrDefault(type); }

		// Number of owned actors of this type where CountedOwnedActor is enabled.
		public int Active(string type) { return active.GetValueOrDefault(type); }

		public int Active(IEnumerable<string> types)
		{
			var count = 0;
			foreach (var type in types)
				count += Active(type);

			return count;
		}

		internal void Add(string type, bool isActive)
		{
			owned[type] = Owned(type) + 1;
			if (isActive)
				SetActive(type, true);
		}

		internal void Remove(string type, bool isActive)
		{
			owned[type] = Owned(type) - 1;
			if (isActive)
				SetActive(type, false);
		}

		internal void SetActive(string type, bool isActive)
		{
			var delta = isActive ? 1 : -1;
			active[type] = Active(type) + delta;
			TotalActive += delta;
		}
	}
}
