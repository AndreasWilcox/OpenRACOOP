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
	[TraitLocation(SystemActors.Player)]
	[Desc("Attach this to the player actor to allow calling the next enemy wave early. Requires `WaveStatus` on the world actor.")]
	public sealed class CallNextWaveInfo : TraitInfo
	{
		[FluentReference("player")]
		[Desc("Text notification shown to everyone when a player calls the next wave.")]
		public readonly string CalledTextNotification = "notification-wave-called";

		public override object Create(ActorInitializer init) { return new CallNextWave(this); }
	}

	public sealed class CallNextWave : IResolveOrder
	{
		public const string OrderID = "CallNextWave";

		readonly CallNextWaveInfo info;

		public CallNextWave(CallNextWaveInfo info)
		{
			this.info = info;
		}

		/// <summary>Whether the given player can call the next wave right now.</summary>
		public static bool CanCall(Player player, WaveStatus status)
		{
			return status != null && status.IsCountingDown && !status.CallRequested
				&& player.WinState == WinState.Undefined && player.PlayerActor.Info.HasTraitInfo<CallNextWaveInfo>();
		}

		public static Order CallOrder(Player player)
		{
			return new Order(OrderID, player.PlayerActor, false);
		}

		void IResolveOrder.ResolveOrder(Actor self, Order order)
		{
			if (order.OrderString != OrderID)
				return;

			var status = self.World.WorldActor.TraitOrDefault<WaveStatus>();
			if (!CanCall(self.Owner, status) || !status.RequestCall())
				return;

			TextNotificationsManager.AddSystemLine(info.CalledTextNotification, "player", self.Owner.ResolvedPlayerName);
		}
	}
}
