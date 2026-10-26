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

using OpenRA.Mods.Common.Traits;
using OpenRA.Primitives;
using OpenRA.Widgets;

namespace OpenRA.Mods.Common.Widgets.Logic
{
	public class WaveStatusLogic : ChromeLogic
	{
		[FluentReference("time")]
		const string FirstWave = "label-wave-status-first";

		[FluentReference("wave", "total", "time")]
		const string NextWave = "label-wave-status-next";

		[FluentReference("wave", "total")]
		const string FinalWave = "label-wave-status-final";

		[FluentReference("hint")]
		const string Hint = "label-wave-status-hint";

		[ObjectCreator.UseCtor]
		public WaveStatusLogic(Widget widget, World world)
		{
			var status = world.WorldActor.TraitOrDefault<WaveStatus>();
			widget.IsVisible = () => status != null && status.Total > 0;
			if (status == null)
				return;

			// Counting down in whole seconds, rounded up so the timer reaches 0:00 as the wave starts
			int SecondsLeft() => (status.TicksUntilNextWave * world.Timestep + 999) / 1000;

			var statusText = new CachedTransform<(int Wave, int Total, int Seconds, bool CountingDown), string>(s =>
			{
				if (!s.CountingDown)
					return FluentProvider.GetMessage(FinalWave, "wave", s.Wave, "total", s.Total);

				var time = WidgetUtils.FormatTimeSeconds(s.Seconds);
				return s.Wave == 0
					? FluentProvider.GetMessage(FirstWave, "time", time)
					: FluentProvider.GetMessage(NextWave, "wave", s.Wave, "total", s.Total, "time", time);
			});

			widget.Get<LabelWidget>("STATUS").GetText =
				() => statusText.Update((status.Wave, status.Total, SecondsLeft(), status.IsCountingDown));

			var hintText = new CachedTransform<string, string>(h => FluentProvider.GetMessage(Hint, "hint", h));
			var hint = widget.Get<LabelWidget>("HINT");
			hint.IsVisible = () => status.IsCountingDown && !string.IsNullOrEmpty(status.NextWaveHint);
			hint.GetText = () => hintText.Update(status.NextWaveHint);

			var call = widget.Get<ButtonWidget>("CALL_NEXT_WAVE");
			var player = world.LocalPlayer;
			call.IsVisible = () => player != null && status.IsCountingDown && player.WinState == WinState.Undefined;
			call.IsDisabled = () => player == null || !CallNextWave.CanCall(player, status);
			call.OnClick = () => world.IssueOrder(CallNextWave.CallOrder(player));
		}
	}
}
