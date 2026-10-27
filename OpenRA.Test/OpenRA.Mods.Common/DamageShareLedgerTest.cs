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
	sealed class DamageShareLedgerTest
	{
		const string A = "a";
		const string B = "b";
		const string C = "c";

		[TestCase(TestName = "DamageShareLedger has no winner without damage")]
		public void NoDamage()
		{
			var ledger = new DamageShareLedger<string>();
			Assert.That(ledger.Winner(), Is.Null);

			ledger.Record(A, 0);
			ledger.Record(A, -50);
			Assert.That(ledger.Winner(), Is.Null);
			Assert.That(ledger.DamageBy(A), Is.Zero);
		}

		[TestCase(TestName = "DamageShareLedger picks the key with the most total damage")]
		public void MostDamage()
		{
			var ledger = new DamageShareLedger<string>();
			ledger.Record(A, 300);
			ledger.Record(B, 200);
			ledger.Record(B, 200);
			ledger.Record(A, 50);
			ledger.Record(C, 100);

			Assert.That(ledger.DamageBy(A), Is.EqualTo(350));
			Assert.That(ledger.DamageBy(B), Is.EqualTo(400));
			Assert.That(ledger.TotalDamage, Is.EqualTo(850));
			Assert.That(ledger.Winner(), Is.EqualTo(B));
		}

		[TestCase(TestName = "DamageShareLedger gives a tie to the last hitter")]
		public void TieLastHitter()
		{
			var ledger = new DamageShareLedger<string>();
			ledger.Record(A, 100);
			ledger.Record(B, 100);
			Assert.That(ledger.Winner(), Is.EqualTo(B));

			ledger.Record(B, 50);
			ledger.Record(A, 50);
			Assert.That(ledger.Winner(), Is.EqualTo(A));
		}

		[TestCase(TestName = "DamageShareLedger gives a tie the last hitter isn't in to the key that reached the total first")]
		public void TieWithoutLastHitter()
		{
			var ledger = new DamageShareLedger<string>();
			ledger.Record(B, 60);
			ledger.Record(A, 100);
			ledger.Record(B, 40);
			ledger.Record(C, 10);

			// A reached 100 before B did, and C landed the last hit with less damage.
			Assert.That(ledger.Winner(), Is.EqualTo(A));
		}
	}
}
