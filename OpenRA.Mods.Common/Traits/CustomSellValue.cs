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
	[Desc("Allow a non-standard sell/repair value to avoid buy-sell exploits.")]
	public class CustomSellValueInfo : TraitInfo<CustomSellValue>
	{
		[FieldLoader.Require]
		public readonly int Value = 0;
	}

	public class CustomSellValue { }

	public static class CustomSellValueExts
	{
		public static int GetSellValue(this Actor a)
		{
			if (a.Info.HasTraitInfo<PurchasePriceSellValueInfo>())
			{
				var purchasePrice = a.TraitOrDefault<PurchasePriceSellValue>();
				if (purchasePrice != null)
					return purchasePrice.Value;
			}

			return a.Info.GetSellValue();
		}

		public static int GetSellValue(this ActorInfo a)
		{
			var csv = a.TraitInfoOrDefault<CustomSellValueInfo>();
			if (csv != null) return csv.Value;

			var valued = a.TraitInfoOrDefault<ValuedInfo>();
			if (valued != null) return valued.Cost;

			return 0;
		}
	}
}
