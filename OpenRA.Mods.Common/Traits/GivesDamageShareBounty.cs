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
using OpenRA.Mods.Common.Effects;
using OpenRA.Traits;

namespace OpenRA.Mods.Common.Traits
{
	[Desc("When killed, this actor gives money to the player that dealt it the most damage.",
		"Only damage from players that can receive cash and are not non-combatants is counted.",
		"If several players dealt the same damage, the one that landed the last hit wins. If the last hitter is not",
		"among them, the one that reached that total first wins.")]
	public class GivesDamageShareBountyInfo : ConditionalTraitInfo, Requires<IHealthInfo>
	{
		[Desc("Percentage of the actor's value to be given.")]
		public readonly int Percentage = 30;

		[Desc("Percentage of the Valued cost that is added to the actor's value per GainsExperience level.")]
		public readonly int PercentagePerLevel = 25;

		[Desc("Player relationships the damaging player needs to have with this actor's owner for the damage to count.")]
		public readonly PlayerRelationship ValidRelationships = PlayerRelationship.Enemy;

		[Desc("Whether to show a floating text announcing the won bounty.")]
		public readonly bool ShowBounty = true;

		public override object Create(ActorInitializer init) { return new GivesDamageShareBounty(this); }
	}

	public class GivesDamageShareBounty : ConditionalTrait<GivesDamageShareBountyInfo>, INotifyDamage, INotifyKilled, ISync
	{
		readonly DamageShareLedger<Player> ledger = new();
		IHealth health;
		GainsExperience gainsExperience;

		// HP before the current damage event, used to cap the recorded damage at the HP that was left.
		int lastHP;

		[VerifySync]
		public int TotalRecordedDamage => ledger.TotalDamage;

		public GivesDamageShareBounty(GivesDamageShareBountyInfo info)
			: base(info) { }

		protected override void Created(Actor self)
		{
			health = self.Trait<IHealth>();
			gainsExperience = self.TraitOrDefault<GainsExperience>();
			lastHP = health.HP;
			base.Created(self);
		}

		/// <summary>Damage recorded for the given player so far.</summary>
		public int DamageDealtBy(Player player)
		{
			return ledger.DamageBy(player);
		}

		/// <summary>The cash this actor pays out when killed right now.</summary>
		public int BountyValue(Actor self)
		{
			var cost = self.Info.TraitInfoOrDefault<ValuedInfo>()?.Cost ?? 0;
			var level = gainsExperience?.Level ?? 0;
			var value = (long)cost * (100 + Info.PercentagePerLevel * level) / 100;
			return (int)(value * Info.Percentage / 100);
		}

		bool CanReceive(Actor self, Player player)
		{
			if (player == null || player.NonCombatant || player.Spectating || player.PlayerActor.Disposed)
				return false;

			if (!Info.ValidRelationships.HasRelationship(player.RelationshipWith(self.Owner)))
				return false;

			return player.PlayerActor.Info.HasTraitInfo<PlayerResourcesInfo>();
		}

		void INotifyDamage.Damaged(Actor self, AttackInfo e)
		{
			// Damage.Value is the damage after modifiers and can be larger than the HP that was left.
			var applied = e.Damage.Value < lastHP ? e.Damage.Value : lastHP;
			lastHP = health.HP;

			// Healing (negative damage) is ignored.
			if (IsTraitDisabled || applied <= 0 || e.Attacker == null)
				return;

			var player = e.Attacker.Owner;
			if (CanReceive(self, player))
				ledger.Record(player, applied);
		}

		void INotifyKilled.Killed(Actor self, AttackInfo e)
		{
			if (IsTraitDisabled)
				return;

			var recipient = ledger.Winner();
			if (recipient == null || recipient.PlayerActor.Disposed)
				return;

			var bounty = BountyValue(self);
			if (bounty <= 0)
				return;

			if (Info.ShowBounty && self.IsInWorld && recipient.IsAlliedWith(self.World.RenderPlayer))
			{
				var pos = self.CenterPosition;
				var color = recipient.Color;
				self.World.AddFrameEndTask(w => w.Add(new FloatingText(pos, color, FloatingText.FormatCashTick(bounty), 30)));
			}

			recipient.PlayerActor.Trait<PlayerResources>().ChangeCash(bounty);
		}
	}

	/// <summary>
	/// Tracks how much damage each key dealt and picks the one that dealt the most.
	/// The result does not depend on hash or dictionary iteration order.
	/// </summary>
	public class DamageShareLedger<T> where T : class
	{
		sealed class Entry
		{
			public readonly T Key;
			public int Damage;

			// Sequence number of the hit that brought Damage to its current value.
			public int ReachedAt;

			public Entry(T key) { Key = key; }
		}

		// Kept in order of first hit and searched linearly: there are only a handful of players.
		readonly List<Entry> entries = [];
		int sequence;
		T lastHitter;

		public int TotalDamage { get; private set; }

		/// <summary>Record damage dealt by key. Non-positive amounts are ignored.</summary>
		public void Record(T key, int amount)
		{
			if (amount <= 0)
				return;

			var entry = Find(key);
			if (entry == null)
			{
				entry = new Entry(key);
				entries.Add(entry);
			}

			entry.Damage = (int)Math.Min((long)entry.Damage + amount, int.MaxValue);
			entry.ReachedAt = ++sequence;
			TotalDamage = (int)Math.Min((long)TotalDamage + amount, int.MaxValue);
			lastHitter = key;
		}

		public int DamageBy(T key)
		{
			return Find(key)?.Damage ?? 0;
		}

		/// <summary>
		/// The key with the most damage, or null if nothing was recorded.
		/// Ties go to the last hitter if it is among the tied keys, otherwise to the one that reached the total first.
		/// </summary>
		public T Winner()
		{
			Entry best = null;
			foreach (var e in entries)
			{
				if (best == null || e.Damage > best.Damage)
					best = e;
				else if (e.Damage == best.Damage)
				{
					if (e.Key == lastHitter)
						best = e;
					else if (best.Key != lastHitter && e.ReachedAt < best.ReachedAt)
						best = e;
				}
			}

			return best?.Key;
		}

		Entry Find(T key)
		{
			foreach (var e in entries)
				if (e.Key == key)
					return e;

			return null;
		}
	}
}
