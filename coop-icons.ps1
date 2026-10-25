####### Generates the co-op mod's sidebar icons (mods/racoop/uibits/coop-icons*.png) #######
#
#   .\coop-icons.ps1
#
# Draws the icons as vector shapes, so the same design is rendered crisply at 1x, 2x and 3x.
# Each icon has a normal, disabled and active version, in the flat colors of RA's order-icons
# (white, #808080 and #FFC000), laid out left to right in this order:
#
#   sell, sell-disabled, sell-active, send-cash, send-cash-disabled, send-cash-active
#
# The regions are defined in mods/racoop/chrome.yaml (coop-order-icons); update them if the layout changes.
# Sell is redrawn here (rather than using RA's glyph) so its $ matches the one in send-cash.

param([string]$OutDir = (Join-Path $PSScriptRoot "mods\racoop\uibits"))

$ErrorActionPreference = "Stop"
Add-Type -AssemblyName System.Drawing

$Icons = @(
	@{ Name = "sell"; Arrow = $false },
	@{ Name = "send-cash"; Arrow = $true })

$StateColors = @(
	[System.Drawing.Color]::FromArgb(255, 255, 255, 255),
	[System.Drawing.Color]::FromArgb(255, 128, 128, 128),
	[System.Drawing.Color]::FromArgb(255, 255, 192, 0))

# Shapes are given in 1x units of a 16x16 icon, and scaled by $s.

# A bold $ filling the box starting at x = $left, 8.5 units wide and 15.5 high.
function DollarPath([float]$s, [float]$left)
{
	$glyph = New-Object System.Drawing.Drawing2D.GraphicsPath
	$font = New-Object System.Drawing.FontFamily "Arial"
	$glyph.AddString('$', $font, [int][System.Drawing.FontStyle]::Bold, 100, (New-Object System.Drawing.PointF 0, 0), [System.Drawing.StringFormat]::GenericTypographic)
	$b = $glyph.GetBounds()

	$m = New-Object System.Drawing.Drawing2D.Matrix
	$m.Translate($left * $s, 0.25 * $s)
	$m.Scale(8.5 * $s / $b.Width, 15.5 * $s / $b.Height)
	$m.Translate(-$b.X, -$b.Y)
	$glyph.Transform($m)
	return $glyph
}

function IconPath([hashtable]$icon, [float]$s)
{
	# Winding fill so overlapping shapes (the arrow shaft and head) don't cancel each other out
	$path = New-Object System.Drawing.Drawing2D.GraphicsPath ([System.Drawing.Drawing2D.FillMode]::Winding)

	if ($icon.Arrow)
	{
		# $ on the left, with an arrow pointing right.
		# The tip stops half a pixel short of the edge, so its anti-aliasing stays inside the icon.
		$path.AddPath((DollarPath $s 0), $false)
		$path.AddRectangle((New-Object System.Drawing.RectangleF (9.5 * $s), (6.5 * $s), (3 * $s), (3 * $s)))
		$path.AddPolygon([System.Drawing.PointF[]]@(
			(New-Object System.Drawing.PointF (11.5 * $s), (3 * $s)),
			(New-Object System.Drawing.PointF (15.5 * $s), (8 * $s)),
			(New-Object System.Drawing.PointF (11.5 * $s), (13 * $s))))
	}
	else
	{
		# $ on its own. It is 9 pixels wide at 1x, so it can't be exactly centered:
		# this leaves 3 pixels on the left and 4 on the right. It starts on a whole pixel,
		# so it renders identically to the $ in send-cash.
		$path.AddPath((DollarPath $s 3), $false)
	}

	return $path
}

# Textures must be power-of-two sized, so the sheet is padded with transparency (icons stay in the top-left).
function NextPowerOfTwo([int]$n)
{
	$p = 1
	while ($p -lt $n) { $p *= 2 }
	return $p
}

foreach ($scale in 1, 2, 3)
{
	$size = 16 * $scale
	$count = $Icons.Count * $StateColors.Count
	$bmp = New-Object System.Drawing.Bitmap (NextPowerOfTwo ($count * $size)), (NextPowerOfTwo $size), ([System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
	$g = [System.Drawing.Graphics]::FromImage($bmp)
	$g.SmoothingMode = "AntiAlias"
	$g.Clear([System.Drawing.Color]::Transparent)

	$index = 0
	foreach ($icon in $Icons)
	{
		foreach ($color in $StateColors)
		{
			$path = IconPath $icon $scale
			$offset = New-Object System.Drawing.Drawing2D.Matrix
			$offset.Translate($index * $size, 0)
			$path.Transform($offset)

			# Clip to the icon's own cell, so nothing can bleed into its neighbours in the sheet
			$g.SetClip((New-Object System.Drawing.Rectangle ($index * $size), 0, $size, $size))
			$g.FillPath((New-Object System.Drawing.SolidBrush $color), $path)
			$g.ResetClip()
			$index++
		}
	}

	$suffix = if ($scale -eq 1) { "" } else { "-${scale}x" }
	$file = Join-Path $OutDir "coop-icons$suffix.png"
	$bmp.Save($file, [System.Drawing.Imaging.ImageFormat]::Png)
	Write-Host "Wrote $file ($($bmp.Width)x$($bmp.Height))"

	$g.Dispose()
	$bmp.Dispose()
}
