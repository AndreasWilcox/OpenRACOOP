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
using System.Linq;
using OpenRA.Traits;

namespace OpenRA.Mods.Common.Traits
{
	[TraitLocation(SystemActors.Player)]
	[Desc("Attach this to the player actor to allow sending cash to allied players.")]
	public sealed class CashTransferInfo : TraitInfo, Requires<PlayerResourcesInfo>
	{
		[FluentReference("player", "amount")]
		[Desc("Text notification shown to the player receiving cash.")]
		public readonly string ReceivedTextNotification = "notification-cash-received";

		[FluentReference("player", "amount")]
		[Desc("Text notification shown to the player sending cash.")]
		public readonly string SentTextNotification = "notification-cash-sent";

		public override object Create(ActorInitializer init) { return new CashTransfer(this); }
	}

	public sealed class CashTransfer : IResolveOrder
	{
		public const string OrderID = "SendCash";

		readonly CashTransferInfo info;

		public CashTransfer(CashTransferInfo info)
		{
			this.info = info;
		}

		/// <summary>The players that the given player can send cash to.</summary>
		public static IEnumerable<Player> ValidRecipients(Player sender)
		{
			return sender.World.Players.Where(p => p != sender && p.Playable && !p.NonCombatant && !p.IsBot
				&& p.WinState == WinState.Undefined && sender.IsAlliedWith(p)
				&& p.PlayerActor.Info.HasTraitInfo<PlayerResourcesInfo>());
		}

		public static Order SendCashOrder(Player sender, Player recipient, int amount)
		{
			return new Order(OrderID, sender.PlayerActor, false)
			{
				TargetString = recipient.InternalName,
				ExtraData = (uint)amount
			};
		}

		void IResolveOrder.ResolveOrder(Actor self, Order order)
		{
			if (order.OrderString != OrderID || order.ExtraData == 0 || order.ExtraData > int.MaxValue)
				return;

			var sender = self.Owner;
			var recipient = ValidRecipients(sender).FirstOrDefault(p => p.InternalName == order.TargetString);
			if (recipient == null || sender.WinState != WinState.Undefined)
				return;

			var amount = (int)order.ExtraData;
			if (!self.Trait<PlayerResources>().TakeCash(amount))
				return;

			recipient.PlayerActor.Trait<PlayerResources>().GiveCash(amount);

			var localPlayer = self.World.LocalPlayer;
			if (localPlayer == recipient)
				TextNotificationsManager.AddSystemLine(info.ReceivedTextNotification, "player", sender.ResolvedPlayerName, "amount", amount);
			else if (localPlayer == sender)
				TextNotificationsManager.AddSystemLine(info.SentTextNotification, "player", recipient.ResolvedPlayerName, "amount", amount);
		}
	}
}
