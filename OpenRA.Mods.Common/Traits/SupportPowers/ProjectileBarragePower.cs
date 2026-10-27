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

using System.Collections.Generic;
using System.Linq;
using System.Numerics;
using OpenRA.Effects;
using OpenRA.GameRules;
using OpenRA.Graphics;
using OpenRA.Traits;

namespace OpenRA.Mods.Common.Traits
{
	[Desc("Fires a barrage of projectiles from beyond the west edge of the map at random cells in an area around the target.")]
	public class ProjectileBarragePowerInfo : SupportPowerInfo
	{
		[WeaponReference]
		[FieldLoader.Require]
		[Desc("Weapon whose projectile is fired. Its warheads deal the damage, owned by the player.")]
		public readonly string Weapon = null;

		[Desc("Number of projectiles fired.")]
		public readonly int Count = 6;

		[Desc("Size of the area the projectiles land in, in cells, around the target cell.")]
		public readonly CVec Dimensions = new(4, 4);

		[Desc("Delay in ticks between two projectiles.")]
		public readonly int Interval = 10;

		[Desc("How far beyond the west edge of the map the projectiles are fired from.")]
		public readonly WDist SourceOffset = new(3072);

		[Desc("Height above the ground the projectiles are fired from.")]
		public readonly WDist SourceAltitude = WDist.Zero;

		[Desc("Sound to play at the target when the power is activated.")]
		public readonly string OnFireSound = null;

		[Desc("Image of the sprite marking the affected cells while targeting.")]
		public readonly string FootprintImage = "overlay";

		[SequenceReference(nameof(FootprintImage))]
		[Desc("Sequence of the sprite marking the affected cells while targeting.")]
		public readonly string FootprintSequence = "target-select";

		public WeaponInfo WeaponInfo { get; private set; }

		public override object Create(ActorInitializer init) { return new ProjectileBarragePower(init.Self, this); }

		public override void RulesetLoaded(Ruleset rules, ActorInfo ai)
		{
			var weaponToLower = Weapon.ToLowerInvariant();
			if (!rules.Weapons.TryGetValue(weaponToLower, out var weapon))
				throw new YamlException($"Weapons Ruleset does not contain an entry '{weaponToLower}'");

			if (weapon.Projectile == null)
				throw new YamlException($"Weapon '{weaponToLower}' used by {nameof(ProjectileBarragePower)} must have a projectile.");

			if (Count < 1 || Dimensions.X < 1 || Dimensions.Y < 1)
				throw new YamlException($"{nameof(ProjectileBarragePower)} needs a positive {nameof(Count)} and {nameof(Dimensions)}.");

			WeaponInfo = weapon;
			base.RulesetLoaded(rules, ai);
		}
	}

	public class ProjectileBarragePower : SupportPower
	{
		readonly ProjectileBarragePowerInfo info;

		public ProjectileBarragePower(Actor self, ProjectileBarragePowerInfo info)
			: base(self, info)
		{
			this.info = info;
		}

		public override void SelectTarget(Actor self, string order, SupportPowerManager manager)
		{
			self.World.OrderGenerator = new SelectBarrageTarget(order, manager, this);
		}

		public override void Activate(Actor self, Order order, SupportPowerManager manager)
		{
			base.Activate(self, order, manager);
			PlayLaunchSounds();
			Game.Sound.Play(SoundType.World, info.OnFireSound, order.Target.CenterPosition);

			var world = self.World;
			var targetCell = world.Map.CellContaining(order.Target.CenterPosition);
			var cells = Area(targetCell).Where(world.Map.Contains).ToList();
			if (cells.Count == 0)
				cells.Add(targetCell);

			// The player actor fires the projectiles, so they still land if the actor with the power is destroyed.
			var firedBy = self.Owner.PlayerActor;
			for (var i = 0; i < info.Count; i++)
			{
				var target = world.Map.CenterOfCell(cells[world.SharedRandom.Next(cells.Count)]);
				var source = new WPos(world.Map.ProjectedTopLeft.X - info.SourceOffset.Length, target.Y, info.SourceAltitude.Length);
				var delay = i * info.Interval;
				if (delay == 0)
					world.AddFrameEndTask(_ => Fire(firedBy, source, target));
				else
					world.AddFrameEndTask(w => w.Add(new DelayedAction(delay, () => Fire(firedBy, source, target))));
			}
		}

		void Fire(Actor firedBy, WPos source, WPos target)
		{
			if (firedBy.Disposed)
				return;

			var args = new ProjectileArgs
			{
				Weapon = info.WeaponInfo,
				Facing = (target - source).Yaw,
				CurrentMuzzleFacing = () => (target - source).Yaw,
				DamageModifiers = [],
				InaccuracyModifiers = [],
				RangeModifiers = [],
				Source = source,
				CurrentSource = () => source,
				SourceActor = firedBy,
				PassiveTarget = target,
				GuidedTarget = Target.FromPos(target)
			};

			var projectile = info.WeaponInfo.Projectile.Create(args);
			if (projectile != null)
				firedBy.World.Add(projectile);
		}

		/// <summary>The cells the projectiles can land in when targeting the given cell.</summary>
		public IEnumerable<CPos> Area(CPos target)
		{
			var x = target.X - (info.Dimensions.X - 1) / 2;
			var y = target.Y - (info.Dimensions.Y - 1) / 2;
			for (var j = 0; j < info.Dimensions.Y; j++)
				for (var i = 0; i < info.Dimensions.X; i++)
					yield return new CPos(x + i, y + j);
		}

		sealed class SelectBarrageTarget : SelectGenericPowerTarget
		{
			readonly ProjectileBarragePower power;
			readonly Sprite tile;
			readonly float alpha;

			public SelectBarrageTarget(string order, SupportPowerManager manager, ProjectileBarragePower power)
				: base(order, manager, power.info)
			{
				this.power = power;
				var sequence = manager.Self.World.Map.Sequences.GetSequence(power.info.FootprintImage, power.info.FootprintSequence);
				tile = sequence.GetSprite(0);
				alpha = sequence.GetAlpha(0);
			}

			protected override IEnumerable<IRenderable> Render(WorldRenderer wr, World world)
			{
				var xy = wr.Viewport.ViewToWorld(Viewport.LastMousePos);
				if (!world.Map.Contains(xy))
					yield break;

				var palette = wr.Palette(TileSet.TerrainPaletteInternalName);
				foreach (var cell in power.Area(xy))
					yield return new SpriteRenderable(tile, world.Map.CenterOfCell(cell), WVec.Zero, -511, palette,
						1f, alpha, Vector3.One, TintModifiers.IgnoreWorldTint, true);
			}
		}
	}
}
