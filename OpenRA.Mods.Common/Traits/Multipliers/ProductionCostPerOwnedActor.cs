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
using System.Linq;
using OpenRA.Traits;

namespace OpenRA.Mods.Common.Traits
{
	[Desc("Raises the production cost of this actor by a percentage for each actor of the listed types its owner has",
		"or is producing (counted by CountedOwnedActor, even while disabled). Requires the OwnedActorCounter trait on the player.")]
	public class ProductionCostPerOwnedActorInfo : TraitInfo<ProductionCostPerOwnedActor>, IProductionCostModifierInfo
	{
		[FieldLoader.Require]
		[Desc("CountedOwnedActor types to count.")]
		public readonly ImmutableArray<string> Types = [];

		[Desc("Percentage points added for each counted actor.")]
		public readonly int Percent = 50;

		int IProductionCostModifierInfo.GetProductionCostModifier(TechTree techTree, string queue)
		{
			var player = techTree.Owner;
			var counter = player.PlayerActor.TraitOrDefault<OwnedActorCounter>();
			if (counter == null)
				return 100;

			var count = Types.Sum(counter.Owned);

			// Items already in production count as well, so queueing several at once doesn't avoid the price increase
			var actors = player.World.Map.Rules.Actors;

			// The player actor is in the world too, so this covers both player-wide and per-building queues
			var queues = player.World.ActorsWithTrait<ProductionQueue>().Where(q => q.Actor.Owner == player).Select(q => q.Trait);

			foreach (var q in queues)
			{
				foreach (var item in q.AllQueued())
				{
					var counted = actors[item.Item].TraitInfoOrDefault<CountedOwnedActorInfo>();
					if (counted != null && Types.Contains(counted.Type))
						count++;
				}
			}

			return 100 + Percent * count;
		}
	}

	public class ProductionCostPerOwnedActor { }
}
