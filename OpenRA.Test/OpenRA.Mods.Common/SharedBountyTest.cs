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

using NUnit.Framework;
using OpenRA.Mods.Common.Traits;

namespace OpenRA.Test
{
	[TestFixture]
	sealed class SharedBountyTest
	{
		[TestCase(30, 1, 30, TestName = "SharedBounty gives one player the whole bounty")]
		[TestCase(30, 2, 15, TestName = "SharedBounty splits the bounty evenly between two players")]
		[TestCase(30, 3, 10, TestName = "SharedBounty splits the bounty evenly between three players")]
		[TestCase(30, 4, 7, TestName = "SharedBounty drops the remainder that can't be split evenly")]
		[TestCase(517, 4, 129, TestName = "SharedBounty splits a ranked unit's bounty between four players")]
		[TestCase(3, 4, 0, TestName = "SharedBounty gives nothing when the bounty is smaller than the player count")]
		[TestCase(30, 0, 0, TestName = "SharedBounty gives nothing without players")]
		public void Share(int total, int recipients, int expected)
		{
			Assert.That(GivesSharedBounty.Share(total, recipients), Is.EqualTo(expected));
		}
	}
}
