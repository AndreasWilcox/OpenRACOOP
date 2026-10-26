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

using OpenRA.Mods.Cnc.Traits;
using OpenRA.Scripting;
using OpenRA.Traits;

namespace OpenRA.Mods.Cnc.Scripting
{
	[ScriptPropertyGroup("Ability")]
	public class MadTankProperties : ScriptActorProperties, Requires<MadTankInfo>
	{
		readonly IResolveOrder madTank;

		public MadTankProperties(ScriptContext context, Actor self)
			: base(context, self)
		{
			madTank = Self.Trait<MadTank>();
		}

		[Desc("Detonate. If a target is given, drive next to it first.")]
		public void Detonate(Actor target = null)
		{
			var order = target != null
				? new Order("DetonateAttack", Self, Target.FromActor(target), false)
				: new Order("Detonate", Self, false);

			madTank.ResolveOrder(Self, order);
		}
	}
}
