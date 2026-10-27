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

using System.Collections.Immutable;
using OpenRA.Traits;

namespace OpenRA.Mods.Common.Traits
{
	[Desc("Modifies the damage of this actor's weapons by a percentage for each actor of the listed types its owner has",
		"(counted by CountedOwnedActor while enabled). Requires the OwnedActorCounter trait on the player.")]
	public class FirepowerMultiplierPerOwnedActorInfo : TraitInfo
	{
		[FieldLoader.Require]
		[Desc("CountedOwnedActor types to count.")]
		public readonly ImmutableArray<string> Types = [];

		[Desc("Percentage points added for each counted actor.")]
		public readonly int Percent = 10;

		public override object Create(ActorInitializer init) { return new FirepowerMultiplierPerOwnedActor(init.Self, this); }
	}

	public class FirepowerMultiplierPerOwnedActor : IFirepowerModifier
	{
		readonly Actor self;
		readonly FirepowerMultiplierPerOwnedActorInfo info;
		Player cachedOwner;
		OwnedActorCounter counter;

		public FirepowerMultiplierPerOwnedActor(Actor self, FirepowerMultiplierPerOwnedActorInfo info)
		{
			this.self = self;
			this.info = info;
		}

		int IFirepowerModifier.GetFirepowerModifier()
		{
			if (self.Owner != cachedOwner)
			{
				cachedOwner = self.Owner;
				counter = cachedOwner.PlayerActor.TraitOrDefault<OwnedActorCounter>();
			}

			return counter == null ? 100 : 100 + info.Percent * counter.Active(info.Types);
		}
	}
}
