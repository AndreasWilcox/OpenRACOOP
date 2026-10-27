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
	[Desc("Counts this actor for its owner's OwnedActorCounter, which the *PerOwnedActor traits use.",
		"Disabling this trait (e.g. while the building is still being built) keeps it counted for ProductionCostPerOwnedActor,",
		"but not for FirepowerMultiplierPerOwnedActor and RangeMultiplierPerOwnedActor.")]
	public class CountedOwnedActorInfo : ConditionalTraitInfo
	{
		[FieldLoader.Require]
		[Desc("Type to count this actor as.")]
		public readonly string Type = null;

		public override object Create(ActorInitializer init) { return new CountedOwnedActor(this); }
	}

	public class CountedOwnedActor : ConditionalTrait<CountedOwnedActorInfo>, INotifyAddedToWorld, INotifyRemovedFromWorld, INotifyOwnerChanged
	{
		OwnedActorCounter counter;

		public CountedOwnedActor(CountedOwnedActorInfo info)
			: base(info) { }

		void INotifyAddedToWorld.AddedToWorld(Actor self)
		{
			counter = self.Owner.PlayerActor.Trait<OwnedActorCounter>();
			counter.Add(Info.Type, !IsTraitDisabled);
		}

		void INotifyRemovedFromWorld.RemovedFromWorld(Actor self)
		{
			counter?.Remove(Info.Type, !IsTraitDisabled);
			counter = null;
		}

		void INotifyOwnerChanged.OnOwnerChanged(Actor self, Player oldOwner, Player newOwner)
		{
			if (counter == null)
				return;

			counter.Remove(Info.Type, !IsTraitDisabled);
			counter = newOwner.PlayerActor.Trait<OwnedActorCounter>();
			counter.Add(Info.Type, !IsTraitDisabled);
		}

		protected override void TraitEnabled(Actor self)
		{
			counter?.SetActive(Info.Type, true);
		}

		protected override void TraitDisabled(Actor self)
		{
			counter?.SetActive(Info.Type, false);
		}
	}
}
