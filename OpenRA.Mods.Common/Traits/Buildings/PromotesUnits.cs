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
	[Desc("Lets the owner select this actor and then target one of their own units to promote it one veterancy level instantly, for a share of the unit's cost.",
		"The unit must have `" + nameof(GainsExperience) + "` and must not be a building.")]
	public sealed class PromotesUnitsInfo : ConditionalTraitInfo, Requires<IOccupySpaceInfo>
	{
		[Desc("Cost of each promotion, as a percentage of the unit's `" + nameof(Valued) + "` cost.")]
		public readonly int CostPercentage = 25;

		[CursorReference]
		[Desc("Cursor to display when hovering over a unit that can be promoted.")]
		public readonly string Cursor = "ability";

		[CursorReference]
		[Desc("Cursor to display when hovering over an own unit that is already at its highest level, or that the player can't afford to promote.")]
		public readonly string BlockedCursor = "generic-blocked";

		[NotificationReference("Speech")]
		[Desc("Speech notification to play when the player can't afford a promotion.")]
		public readonly string InsufficientFundsNotification = null;

		[FluentReference(optional: true)]
		[Desc("Text notification to display when the player can't afford a promotion.")]
		public readonly string InsufficientFundsTextNotification = null;

		public override object Create(ActorInitializer init) { return new PromotesUnits(this); }
	}

	public sealed class PromotesUnits : ConditionalTrait<PromotesUnitsInfo>, IIssueOrder, IResolveOrder
	{
		public const string OrderID = "PromoteUnit";

		public PromotesUnits(PromotesUnitsInfo info)
			: base(info) { }

		/// <summary>The cost of promoting the given unit by one level.</summary>
		public int PromotionCost(Actor unit)
		{
			var cost = unit.Info.TraitInfoOrDefault<ValuedInfo>()?.Cost ?? 0;
			return cost * Info.CostPercentage / 100;
		}

		/// <summary>Whether this can ever promote the given unit, ignoring its level and the owner's cash.</summary>
		public bool CanPromoteType(Actor self, Actor unit)
		{
			return !IsTraitDisabled && unit != null && !unit.IsDead && unit.IsInWorld && unit != self
				&& unit.Owner == self.Owner && !unit.Info.HasTraitInfo<BuildingInfo>()
				&& unit.TraitOrDefault<GainsExperience>() is GainsExperience exp && exp.MaxLevel > 0;
		}

		/// <summary>Whether the given unit can be promoted right now.</summary>
		public bool CanPromote(Actor self, Actor unit)
		{
			return CanPromoteType(self, unit) && unit.Trait<GainsExperience>().CanGainLevel
				&& self.Owner.PlayerActor.Trait<PlayerResources>().GetCashAndResources() >= PromotionCost(unit);
		}

		/// <summary>
		/// Promotes the given unit by one level and charges the owner for it.
		/// Returns false, without charging, if the unit can't be promoted or the owner can't afford it.
		/// </summary>
		public bool Promote(Actor self, Actor unit)
		{
			if (!CanPromoteType(self, unit))
				return false;

			var exp = unit.Trait<GainsExperience>();
			if (!exp.CanGainLevel)
				return false;

			if (!self.Owner.PlayerActor.Trait<PlayerResources>().TakeCash(PromotionCost(unit)))
			{
				Game.Sound.PlayNotification(self.World.Map.Rules, self.Owner, "Speech", Info.InsufficientFundsNotification, self.Owner.Faction.InternalName);
				TextNotificationsManager.AddTransientLine(self.Owner, Info.InsufficientFundsTextNotification);
				return false;
			}

			exp.GiveLevels(1);
			return true;
		}

		IEnumerable<IOrderTargeter> IIssueOrder.Orders
		{
			get
			{
				if (!IsTraitDisabled)
					yield return new PromoteOrderTargeter(this);
			}
		}

		Order IIssueOrder.IssueOrder(Actor self, IOrderTargeter order, in Target target, bool queued)
		{
			if (order.OrderID != OrderID)
				return null;

			return new Order(order.OrderID, self, target, false);
		}

		void IResolveOrder.ResolveOrder(Actor self, Order order)
		{
			if (order.OrderString != OrderID || order.Target.Type != TargetType.Actor)
				return;

			Promote(self, order.Target.Actor);
		}

		sealed class PromoteOrderTargeter : IOrderTargeter
		{
			readonly PromotesUnits trait;

			public PromoteOrderTargeter(PromotesUnits trait)
			{
				this.trait = trait;
			}

			public string OrderID => PromotesUnits.OrderID;
			public int OrderPriority => 5;
			public bool IsQueued => false;
			public bool TargetOverridesSelection(Actor self, in Target target, List<Actor> actorsAt, CPos xy, TargetModifiers modifiers) { return true; }

			public bool CanTarget(Actor self, in Target target, ref TargetModifiers modifiers, ref string cursor)
			{
				if (target.Type != TargetType.Actor || !trait.CanPromoteType(self, target.Actor))
					return false;

				// Units that can't be promoted right now still accept the order, so the player hears why it was refused
				cursor = trait.CanPromote(self, target.Actor) ? trait.Info.Cursor : trait.Info.BlockedCursor;
				return true;
			}
		}
	}
}
