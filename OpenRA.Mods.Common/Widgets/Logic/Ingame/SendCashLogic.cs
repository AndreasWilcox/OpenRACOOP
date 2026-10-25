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
using System.Globalization;
using System.Linq;
using OpenRA.Mods.Common.Traits;
using OpenRA.Primitives;
using OpenRA.Widgets;

namespace OpenRA.Mods.Common.Widgets.Logic
{
	public class SendCashLogic : ChromeLogic
	{
		[FluentReference("amount")]
		const string Total = "label-send-cash-total";

		readonly Player player;
		readonly PlayerResources resources;

		// The amount to send to each recipient. Nothing is sent until the Send button is pressed.
		readonly Dictionary<Player, int> amounts = [];

		[ObjectCreator.UseCtor]
		public SendCashLogic(Widget widget, World world, Action onExit)
		{
			player = world.LocalPlayer;
			resources = player.PlayerActor.Trait<PlayerResources>();

			var list = widget.Get<ScrollPanelWidget>("PLAYER_LIST");
			var template = list.Get("PLAYER_TEMPLATE");
			list.RemoveChildren();

			foreach (var recipient in CashTransfer.ValidRecipients(player).ToList())
			{
				amounts[recipient] = 0;
				var item = template.Clone();

				var nameLabel = item.Get<LabelWidget>("NAME");
				var name = WidgetUtils.TruncateText(recipient.ResolvedPlayerName, nameLabel.Bounds.Width, Game.Renderer.Fonts[nameLabel.Font]);
				nameLabel.GetText = () => name;
				nameLabel.GetColor = () => CanReceive(recipient) ? recipient.Color : Color.Gray;

				var amountText = new CachedTransform<int, string>(a => "$" + a.ToString(NumberFormatInfo.CurrentInfo));
				item.Get<LabelWidget>("AMOUNT").GetText = () => amountText.Update(amounts[recipient]);

				SetupStepButton(item, "MINUS_1000", recipient, -1000);
				SetupStepButton(item, "MINUS_100", recipient, -100);
				SetupStepButton(item, "PLUS_100", recipient, 100);
				SetupStepButton(item, "PLUS_1000", recipient, 1000);

				list.AddChild(item);
			}

			var totalLabel = widget.Get<LabelWidget>("TOTAL");
			var totalText = new CachedTransform<int, string>(t => FluentProvider.GetMessage(Total, "amount", t));
			totalLabel.GetText = () => totalText.Update(TotalAmount());
			totalLabel.GetColor = () => TotalAmount() > Cash() ? Color.Red : totalLabel.TextColor;

			var sendButton = widget.Get<ButtonWidget>("SEND_BUTTON");
			sendButton.IsDisabled = () => TotalAmount() == 0 || TotalAmount() > Cash();
			sendButton.OnClick = () =>
			{
				foreach (var (recipient, amount) in amounts)
					if (amount > 0 && CanReceive(recipient))
						world.IssueOrder(CashTransfer.SendCashOrder(player, recipient, amount));

				onExit();
			};

			widget.Get<ButtonWidget>("CLOSE_BUTTON").OnClick = onExit;
		}

		void SetupStepButton(Widget item, string id, Player recipient, int step)
		{
			var button = item.Get<ButtonWidget>(id);
			if (step > 0)
				button.IsDisabled = () => !CanReceive(recipient) || TotalAmount() >= Cash();
			else
				button.IsDisabled = () => !CanReceive(recipient) || amounts[recipient] == 0;

			button.OnClick = () =>
			{
				// The total over all recipients can't be more than the player's cash.
				var max = amounts[recipient] + Math.Max(0, Cash() - TotalAmount());
				amounts[recipient] = Math.Clamp(amounts[recipient] + step, 0, max);
			};
		}

		bool CanReceive(Player recipient) => CashTransfer.ValidRecipients(player).Contains(recipient);

		int Cash() => resources.GetCashAndResources();

		int TotalAmount() => amounts.Where(kv => CanReceive(kv.Key)).Sum(kv => kv.Value);
	}
}
