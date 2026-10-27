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
using OpenRA.Scripting;
using OpenRA.Traits;

namespace OpenRA.Mods.Common.Scripting
{
	[ScriptPropertyGroup("Experience")]
	public class PromotesUnitsProperties : ScriptActorProperties, Requires<PromotesUnitsInfo>
	{
		readonly PromotesUnits promotes;

		public PromotesUnitsProperties(ScriptContext context, Actor self)
			: base(context, self)
		{
			promotes = self.Trait<PromotesUnits>();
		}

		[Desc("Promote one of the owner's units by one level, charging the owner for it, the same as when a player orders it.",
			"Returns false, without charging, if the unit can't be promoted or the owner can't afford it.")]
		public bool Promote(Actor unit)
		{
			return promotes.Promote(Self, unit);
		}

		[Desc("The cost of promoting the given unit by one level.")]
		public int PromotionCost(Actor unit)
		{
			return promotes.PromotionCost(unit);
		}
	}
}
