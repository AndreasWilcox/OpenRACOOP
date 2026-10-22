####### Dev loop for the Red Alert co-op mod (mods/racoop) #######
#
#   .\coop [play]   Build and jump straight into the co-op map (single client).
#   .\coop duo      Build, start a local dedicated server and two clients to test co-op on one PC.
#   .\coop check    Build, lint the mod/maps, then run the smoke test.
#   .\coop smoke    Launch the map, wait for the Lua script to start, and fail on Lua errors or crashes.
#   .\coop lint     Lint the mod/maps only.
#
# Options: -Map <folder name>  (default coop-01), -NoBuild, -Fullscreen, -Port <n> (duo, default 1234),
#          -Timeout <seconds> (smoke, default 90)

param(
	[Parameter(Position = 0)]
	[ValidateSet("play", "duo", "check", "smoke", "lint")]
	[string]$Command = "play",
	[string]$Map = "coop-01",
	[switch]$NoBuild,
	[switch]$Fullscreen,
	[int]$Port = 1234,
	[int]$Timeout = 90
)

$ErrorActionPreference = "Stop"
$Mod = "racoop"
$Root = $PSScriptRoot
Set-Location $Root

$dotnet = "dotnet"
if (-not (Get-Command dotnet -ErrorAction SilentlyContinue) -and (Test-Path "C:\Program Files\dotnet\dotnet.exe"))
{
	$dotnet = "C:\Program Files\dotnet\dotnet.exe"
}

function Build
{
	if ($NoBuild) { return }
	Write-Host "Building..." -ForegroundColor Cyan
	$rid = if ($env:PROCESSOR_ARCHITECTURE -eq "ARM64") { "win-arm64" } else { "win-x64" }
	& $dotnet build -c Release --nologo -v q -p:TargetPlatform=$rid
	if ($LASTEXITCODE -ne 0)
	{
		Write-Host "Build failed." -ForegroundColor Red
		exit 1
	}
}

function GameArgs([string[]]$extra)
{
	$display = if ($Fullscreen) { @() } else { @("Graphics.Mode=Windowed", "Graphics.WindowedSize=1280,800") }
	return @("bin\OpenRA.dll", "--", "Engine.EngineDir=..", "Engine.LaunchPath=$Root\launch-game.cmd", "Game.Mod=$Mod") + $display + $extra
}

function StartGame([string[]]$extra)
{
	return Start-Process $dotnet -ArgumentList (GameArgs $extra) -PassThru
}

# Same lookup order as launch-game.cmd's crash dialog.
function LogDir
{
	if (Test-Path "$Root\Support\Logs") { return "$Root\Support\Logs" }
	if (Test-Path "$env:USERPROFILE\Documents\OpenRA\Logs") { return "$env:USERPROFILE\Documents\OpenRA\Logs" }
	return "$env:APPDATA\OpenRA\Logs"
}

# Reads the log files matching $pattern that were written after $since, otherwise returns "".
# Crashes are written to timestamped exception-*.log files, so this accepts wildcards.
function ReadFreshLog([string]$pattern, [datetime]$since)
{
	$text = ""
	Get-ChildItem -Path (LogDir) -Filter $pattern -ErrorAction SilentlyContinue |
		Where-Object { $_.LastWriteTime -ge $since } |
		ForEach-Object { $text += (Get-Content $_.FullName -Raw -ErrorAction SilentlyContinue) + "" }

	return $text
}

function Lint
{
	Write-Host "Linting $Mod..." -ForegroundColor Cyan
	$env:ENGINE_DIR = ".."
	& "bin\OpenRA.Utility.exe" $Mod --check-yaml
	if ($LASTEXITCODE -ne 0)
	{
		Write-Host "Lint failed." -ForegroundColor Red
		exit 1
	}
}

function Smoke
{
	Write-Host "Smoke testing map '$Map' (timeout ${Timeout}s)..." -ForegroundColor Cyan
	$since = (Get-Date).AddSeconds(-1)
	$game = StartGame @("Launch.Map=$Map", "Sound.Mute=True")
	$deadline = (Get-Date).AddSeconds($Timeout)
	$markerSeenAt = $null
	$result = $null

	while ($null -eq $result)
	{
		Start-Sleep -Milliseconds 500
		$lua = ReadFreshLog "lua.log" $since
		$exception = ReadFreshLog "exception*.log" $since

		if ($exception) { $result = "FAIL: engine exception`n$exception" }
		elseif ($lua -match "Fatal Lua Error") { $result = "FAIL: Lua error`n$lua" }
		elseif ($game.HasExited) { $result = "FAIL: game exited early (code $($game.ExitCode))" }
		elseif ($lua -match "coop: WorldLoaded")
		{
			# Let the game tick for a while after the script started, to catch early runtime errors.
			if ($null -eq $markerSeenAt) { $markerSeenAt = Get-Date }
			elseif ((Get-Date) -ge $markerSeenAt.AddSeconds(10)) { $result = "PASS" }
		}
		elseif ((Get-Date) -ge $deadline) { $result = "FAIL: timed out waiting for 'coop: WorldLoaded' in lua.log" }
	}

	if (-not $game.HasExited) { Stop-Process -Id $game.Id -Force }

	if ($result -eq "PASS")
	{
		Write-Host "Smoke test passed." -ForegroundColor Green
		(ReadFreshLog "lua.log" $since) -split "`n" | Where-Object { $_ -match "coop:" } | ForEach-Object { Write-Host "  $_" }
	}
	else
	{
		Write-Host "Smoke test $result" -ForegroundColor Red
		Write-Host "Logs: $(LogDir)"
		exit 1
	}
}

function Duo
{
	$env:ENGINE_DIR = ".."
	$uid = (& "bin\OpenRA.Utility.exe" $Mod --map-hash "mods\$Mod\maps\$Map" | Select-Object -Last 1).Trim()
	if (-not $uid)
	{
		Write-Host "Could not compute the map UID for '$Map'." -ForegroundColor Red
		exit 1
	}

	Write-Host "Starting dedicated server on port $Port with map '$Map' ($uid)..." -ForegroundColor Cyan
	$server = Start-Process "bin\OpenRA.Server.exe" -PassThru -ArgumentList @(
		"Engine.EngineDir=..", "Game.Mod=$Mod", "Server.Name=CoopDev", "Server.Map=$uid", "Server.ListenPort=$Port",
		"Server.AdvertiseOnline=False", "Server.AdvertiseOnLocalNetwork=False", "Server.EnableGeoIP=False",
		"Server.EnableSingleplayer=True")
	Start-Sleep -Seconds 3

	$clients = @(
		(StartGame @("Launch.Connect=127.0.0.1:$Port", "Player.Name=P1")),
		(StartGame @("Launch.Connect=127.0.0.1:$Port", "Player.Name=P2")))

	Write-Host "Two clients launched. Click Ready in both lobby windows to start. Close both clients to stop the server." -ForegroundColor Yellow
	$clients | Wait-Process
	if (-not $server.HasExited) { Stop-Process -Id $server.Id -Force }
	Write-Host "Server stopped."
}

switch ($Command)
{
	"play"
	{
		Build
		StartGame @("Launch.Map=$Map") | Out-Null
	}
	"duo" { Build; Duo }
	"lint" { Lint }
	"smoke" { Build; Smoke }
	"check" { Build; Lint; Smoke }
}
