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
	[Desc("Use the price this actor was actually bought for as its sell, repair and bounty value, ",
		"instead of its listed cost. Actors not created by production use the cost or CustomSellValue.")]
	public class PurchasePriceSellValueInfo : TraitInfo
	{
		public override object Create(ActorInitializer init) { return new PurchasePriceSellValue(init); }
	}

	public class PurchasePriceSellValue
	{
		public readonly int Value;

		public PurchasePriceSellValue(ActorInitializer init)
		{
			Value = init.GetValue<PurchasePriceInit, int>(init.Self.Info.GetSellValue());
		}
	}

	[Desc("The price paid to produce this actor.")]
	public class PurchasePriceInit(int value) : ValueActorInit<int>(value), ISingleInstanceInit { }
}
