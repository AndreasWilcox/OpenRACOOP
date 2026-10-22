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

using OpenRA.Scripting;

namespace OpenRA.Mods.Common.Scripting
{
	[ScriptGlobal("Test")]
	public class TestGlobal : ScriptGlobal
	{
		public TestGlobal(ScriptContext context)
			: base(context) { }

		[Desc("Save a screenshot of the local player's view after the next rendered frame. " +
			"The file is written as <name>.png to the Screenshots folder in the support directory, " +
			"or to the directory in the OPENRA_SCREENSHOT_DIR environment variable if set.")]
		public void Screenshot(string name)
		{
			Game.TakeScreenshot(name);
		}
	}
}
