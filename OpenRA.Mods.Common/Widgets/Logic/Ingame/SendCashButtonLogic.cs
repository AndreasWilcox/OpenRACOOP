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

using System.Linq;
using OpenRA.Mods.Common.Traits;
using OpenRA.Widgets;

namespace OpenRA.Mods.Common.Widgets.Logic
{
	public class SendCashButtonLogic : ChromeLogic
	{
		readonly Widget playerRoot;
		Widget panel;

		[ObjectCreator.UseCtor]
		public SendCashButtonLogic(Widget widget, World world)
		{
			playerRoot = Ui.Root.Get("PLAYER_ROOT");

			var button = (ButtonWidget)widget;
			var player = world.LocalPlayer;
			var enabled = player != null && player.PlayerActor.Info.HasTraitInfo<CashTransferInfo>();
			button.IsVisible = () => enabled;
			if (!enabled)
				return;

			button.IsDisabled = () => panel == null && !CashTransfer.ValidRecipients(player).Any();
			button.IsHighlighted = () => panel != null;
			button.Get<ImageWidget>("ICON").GetImageName =
				() => button.IsDisabled() ? "send-cash-disabled" : panel != null ? "send-cash-active" : "send-cash";
			button.OnClick = () =>
			{
				if (panel != null)
					ClosePanel();
				else
					panel = Game.LoadWidget(world, "SEND_CASH_PANEL", playerRoot, new WidgetArgs { { "onExit", ClosePanel } });
			};
		}

		void ClosePanel()
		{
			if (panel == null)
				return;

			playerRoot.RemoveChild(panel);
			panel = null;
		}
	}
}
