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
using OpenRA.Mods.Common.Effects;
using OpenRA.Traits;

namespace OpenRA.Mods.Common.Traits
{
	[Desc("When killed by a player, this actor's bounty is split evenly between all players that can receive it,",
		"whether or not they damaged it. Only playable players that can receive cash and are not non-combatants are paid.",
		"What can't be split evenly is dropped.")]
	public class GivesSharedBountyInfo : ConditionalTraitInfo
	{
		[Desc("Percentage of the actor's value to be split between the players.")]
		public readonly int Percentage = 30;

		[Desc("Percentage of the Valued cost that is added to the actor's value per GainsExperience level.")]
		public readonly int PercentagePerLevel = 25;

		[Desc("Player relationships a player needs to have with this actor's owner to be paid.")]
		public readonly PlayerRelationship ValidRelationships = PlayerRelationship.Enemy;

		[Desc("Whether to show a floating text announcing the local player's share.")]
		public readonly bool ShowBounty = true;

		public override object Create(ActorInitializer init) { return new GivesSharedBounty(this); }
	}

	public class GivesSharedBounty : ConditionalTrait<GivesSharedBountyInfo>, INotifyKilled
	{
		GainsExperience gainsExperience;

		public GivesSharedBounty(GivesSharedBountyInfo info)
			: base(info) { }

		protected override void Created(Actor self)
		{
			gainsExperience = self.TraitOrDefault<GainsExperience>();
			base.Created(self);
		}

		/// <summary>The cash this actor pays out in total when killed right now, before it is split.</summary>
		public int BountyValue(Actor self)
		{
			var cost = self.Info.TraitInfoOrDefault<ValuedInfo>()?.Cost ?? 0;
			var level = gainsExperience?.Level ?? 0;
			var value = (long)cost * (100 + Info.PercentagePerLevel * level) / 100;
			return (int)(value * Info.Percentage / 100);
		}

		/// <summary>Each recipient's share of the total. The remainder is dropped.</summary>
		public static int Share(int total, int recipients)
		{
			return recipients > 0 ? total / recipients : 0;
		}

		bool CanReceive(Actor self, Player player)
		{
			if (player == null || !player.Playable || player.NonCombatant || player.Spectating || player.PlayerActor.Disposed)
				return false;

			if (!Info.ValidRelationships.HasRelationship(player.RelationshipWith(self.Owner)))
				return false;

			return player.PlayerActor.Info.HasTraitInfo<PlayerResourcesInfo>();
		}

		void INotifyKilled.Killed(Actor self, AttackInfo e)
		{
			if (IsTraitDisabled || e.Attacker == null || e.Attacker.Disposed || !CanReceive(self, e.Attacker.Owner))
				return;

			// World.Players is in the same order on every client.
			var recipients = new List<Player>();
			foreach (var p in self.World.Players)
				if (CanReceive(self, p))
					recipients.Add(p);

			var share = Share(BountyValue(self), recipients.Count);
			if (share <= 0)
				return;

			foreach (var p in recipients)
			{
				if (Info.ShowBounty && self.IsInWorld && p == self.World.RenderPlayer)
				{
					var pos = self.CenterPosition;
					var color = p.Color;
					self.World.AddFrameEndTask(w => w.Add(new FloatingText(pos, color, FloatingText.FormatCashTick(share), 30)));
				}

				p.PlayerActor.Trait<PlayerResources>().ChangeCash(share);
			}
		}
	}
}
