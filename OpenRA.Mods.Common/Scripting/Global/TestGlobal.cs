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

using System;
using System.Collections.Generic;
using System.Linq;
using Eluant;
using OpenRA.Mods.Common.Traits;
using OpenRA.Scripting;
using OpenRA.Traits;

namespace OpenRA.Mods.Common.Scripting
{
	[ScriptGlobal("Test")]
	public class TestGlobal : ScriptGlobal
	{
		public TestGlobal(ScriptContext context)
			: base(context) { }

		[Desc("Save a screenshot of the local player's view after the next rendered frame. " +
			"The file is written as <name>.png to the Screenshots folder in the support directory, " +
			"or to the directory in the OPENRA_SCREENSHOT_DIR environment variable if set.")]
		public void Screenshot(string name)
		{
			Game.TakeScreenshot(name);
		}

		[Desc("Whether the cell is currently visible to the player (not under shroud or fog).")]
		public bool CellVisible(Player player, CPos cell)
		{
			return player.Shroud.IsVisible(cell);
		}

		[Desc("The actor types the player can build right now in any of their production queues, sorted by name.")]
		public string[] BuildableItems(Player player)
		{
			return Queues(player)
				.SelectMany(q => q.BuildableItems())
				.Select(a => a.Name)
				.Distinct()
				.Order(StringComparer.Ordinal)
				.ToArray();
		}

		// The player actor is in the world too, so this covers both player-wide and per-building queues
		static IEnumerable<ProductionQueue> Queues(Player player)
		{
			return player.World.ActorsWithTrait<ProductionQueue>().Where(a => a.Actor.Owner == player).Select(a => a.Trait);
		}

		ActorInfo GetActorInfo(string actorType)
		{
			if (!Context.World.Map.Rules.Actors.TryGetValue(actorType, out var actorInfo))
				throw new LuaException($"Unknown actor type '{actorType}'");

			return actorInfo;
		}

		[Desc("The price the player would pay right now to start producing the actor type, " +
			"or -1 if none of the player's production queues can build it.")]
		public int ProductionCost(Player player, string actorType)
		{
			var actorInfo = GetActorInfo(actorType);
			var queue = Queues(player).FirstOrDefault(q => q.Enabled && q.CanBuild(actorInfo));
			return queue?.GetProductionCost(actorInfo) ?? -1;
		}

		[Desc("Place a building the player has finished producing at the cell (its top left corner), as when the player clicks on the map. " +
			"The building appears at the end of the tick. Returns false if no production queue has the building ready, " +
			"or if it can't be placed there.")]
		public bool PlaceBuilding(Player player, string actorType, CPos cell)
		{
			var actorInfo = GetActorInfo(actorType);
			var buildingInfo = actorInfo.TraitInfoOrDefault<BuildingInfo>();
			var queue = Queues(player).FirstOrDefault(q => q.AllQueued().Any(i => i.Done && i.Item == actorType));
			if (queue == null || buildingInfo == null
				|| !player.World.CanPlaceBuilding(cell, actorInfo, buildingInfo, null)
				|| !buildingInfo.IsCloseEnoughToBase(player.World, player, actorInfo, cell))
				return false;

			var order = new Order("PlaceBuilding", player.PlayerActor, Target.FromCell(player.World, cell), false)
			{
				TargetString = actorType,
				ExtraData = queue.Actor.ActorID,
				SuppressVisualFeedback = true
			};

			foreach (var r in player.PlayerActor.TraitsImplementing<PlaceBuilding>())
				((IResolveOrder)r).ResolveOrder(player.PlayerActor, order);

			return true;
		}

		[Desc("The actor's current damage modifier in percent, combining all its firepower modifiers.")]
		public int FirepowerModifier(Actor actor)
		{
			return Util.ApplyPercentageModifiers(100, actor.TraitsImplementing<IFirepowerModifier>().Select(m => m.GetFirepowerModifier()));
		}

		[Desc("The actor's current weapon range modifier in percent, combining all its range modifiers.")]
		public int RangeModifier(Actor actor)
		{
			return Util.ApplyPercentageModifiers(100, actor.TraitsImplementing<IRangeModifier>().Select(m => m.GetRangeModifier()));
		}

		[Desc("The amount the actor is worth when sold, before applying the refund percentage and its health.")]
		public int SellValue(Actor actor)
		{
			return actor.GetSellValue();
		}

		[Desc("The actor's speed as a percentage of its normal speed, from all its speed modifiers (such as veterancy).")]
		public int SpeedPercent(Actor actor)
		{
			return Util.ApplyPercentageModifiers(100, actor.TraitsImplementing<ISpeedModifier>().Select(m => m.GetSpeedModifier()));
		}

		[Desc("The order names of the support powers the player can use or is charging, sorted by name.")]
		public string[] SupportPowers(Player player)
		{
			return player.PlayerActor.Trait<SupportPowerManager>().Powers
				.Where(p => p.Value.Active)
				.Select(p => p.Key)
				.Order(StringComparer.Ordinal)
				.ToArray();
		}

		[Desc("Ticks left until the player's support power is charged, or -1 if the player doesn't have it.")]
		public int SupportPowerRemainingTicks(Player player, string power)
		{
			var powers = player.PlayerActor.Trait<SupportPowerManager>().Powers;
			return powers.TryGetValue(power, out var instance) ? instance.RemainingTicks : -1;
		}

		[Desc("Activate the player's support power at the target cell at once, even if it isn't charged yet. " +
			"Returns false if the player can't use the power.")]
		public bool ActivateSupportPower(Player player, string power, CPos target)
		{
			var manager = player.PlayerActor.Trait<SupportPowerManager>();
			if (!manager.Powers.TryGetValue(power, out var instance) || !instance.Active)
				return false;

			var source = instance.Instances.FirstOrDefault(i => !i.IsTraitDisabled && !i.IsTraitPaused);
			if (source == null)
				return false;

			var order = new Order(power, player.PlayerActor, Target.FromCell(player.World, target), false);
			source.Activate(source.Self, order, manager);
			return true;
		}

		[Desc("Deal damage to the target as if the attacker actor had hit it. Damage modifiers are ignored.")]
		public void Damage(Actor target, Actor attacker, int amount)
		{
			target.Trait<IHealth>().InflictDamage(target, attacker, new Damage(amount), true);
		}
	}
}
