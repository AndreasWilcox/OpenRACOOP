####### Dev loop for the Red Alert co-op mod (mods/racoop) #######
#
#   .\coop [play]   Build and jump straight into the co-op map in a visible window, for playtesting.
#   .\coop duo      Build, start a local dedicated server and two visible clients to test co-op on one PC.
#   .\coop check    Build, lint the mod/maps, then run the smoke test and all test scenarios.
#   .\coop smoke    Launch the map, wait for the Lua script to start, and fail on Lua errors or crashes.
#   .\coop test     Run the map's automated test scenarios (see mods/racoop/scripts/cooptest.lua).
#   .\coop lint     Lint the mod/maps only.
#
# smoke, test and check run the game in a hidden window (no window or console pops up); play and duo never do.
#
# Options: -Map <folder name>  (default coop-01), -NoBuild, -Fullscreen, -Port <n> (duo, default 1234),
#          -Timeout <seconds> (smoke/test, per run, default 90),
#          -Scenario <name> (test: run only this scenario; default runs all of the map's scenarios),
#          -Show (smoke/test: show the game window instead of hiding it, for debugging),
#          -Fog (play with normal shroud and fog of war; by default the whole map is revealed for debugging)

param(
	[Parameter(Position = 0)]
	[ValidateSet("play", "duo", "check", "smoke", "test", "lint")]
	[string]$Command = "play",
	[string]$Map = "coop-01",
	[switch]$NoBuild,
	[switch]$Fullscreen,
	[int]$Port = 1234,
	[int]$Timeout = 90,
	[string]$Scenario,
	[switch]$Show,
	[switch]$Fog
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

# Lobby options applied by the host: reveal the whole map unless -Fog is given.
function LobbyOptions([string[]]$extra = @())
{
	$options = @($extra)
	if (-not $Fog) { $options += @("explored=True", "fog=False") }
	if ($options.Count -eq 0) { return @() }
	return @("Launch.LobbyOptions=" + ($options -join ","))
}

# Starts a visible game, for the user to play.
function StartGame([string[]]$extra)
{
	return Start-Process $dotnet -ArgumentList (GameArgs $extra) -PassThru
}

# Starts a game for automated runs: hidden window and console unless -Show is given.
function StartAutomatedGame([string[]]$extra)
{
	$gameArgs = GameArgs (@("Sound.Mute=True") + $extra)

	# Environment variables are inherited by the game process and read by the engine.
	$env:OPENRA_SCREENSHOT_DIR = ResultsDir
	if (-not $Show) { $env:OPENRA_HIDDEN_WINDOW = "1" }
	try
	{
		if ($Show) { return Start-Process $dotnet -ArgumentList $gameArgs -PassThru }
		return Start-Process $dotnet -ArgumentList $gameArgs -PassThru -WindowStyle Hidden
	}
	finally
	{
		Remove-Item Env:\OPENRA_SCREENSHOT_DIR, Env:\OPENRA_HIDDEN_WINDOW -ErrorAction SilentlyContinue
	}
}

# Same lookup order as launch-game.cmd's crash dialog.
function LogDir
{
	if (Test-Path "$Root\Support\Logs") { return "$Root\Support\Logs" }
	if (Test-Path "$env:USERPROFILE\Documents\OpenRA\Logs") { return "$env:USERPROFILE\Documents\OpenRA\Logs" }
	return "$env:APPDATA\OpenRA\Logs"
}

# Screenshots taken by automated runs are saved here (gitignored) instead of the user's Screenshots folder.
function ResultsDir
{
	return Join-Path $Root "test-results\$Map"
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

# Polls the logs of a running game until $evaluate (given the lua.log text) returns "PASS" or a failure
# message, the game crashes or exits, or the timeout expires. Always stops the game. Returns the result.
function WatchGame($game, [datetime]$since, [scriptblock]$evaluate, [string]$waitingFor)
{
	$deadline = (Get-Date).AddSeconds($Timeout)
	$result = $null
	while ($null -eq $result)
	{
		Start-Sleep -Milliseconds 500
		$lua = ReadFreshLog "lua.log" $since
		$exception = ReadFreshLog "exception*.log" $since

		if ($exception) { $result = "FAIL: engine exception`n$exception" }
		elseif ($lua -match "Fatal Lua Error") { $result = "FAIL: Lua error`n$lua" }
		elseif ($game.HasExited) { $result = "FAIL: game exited early (code $($game.ExitCode))" }
		else
		{
			$result = & $evaluate $lua
			if ($null -eq $result -and (Get-Date) -ge $deadline) { $result = "FAIL: timed out after ${Timeout}s waiting for $waitingFor" }
		}
	}

	# Give a pending screenshot a moment to be written before stopping the game.
	if ($result -eq "PASS") { Start-Sleep -Seconds 1 }
	if (-not $game.HasExited) { Stop-Process -Id $game.Id -Force }
	return $result
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
	$game = StartAutomatedGame (@("Launch.Map=$Map") + (LobbyOptions))

	# Let the game tick for a while after the script started, to catch early runtime errors.
	$script:markerSeenAt = $null
	$result = WatchGame $game $since {
		param($lua)
		if ($lua -notmatch "coop: WorldLoaded") { return $null }
		if ($null -eq $script:markerSeenAt) { $script:markerSeenAt = Get-Date }
		if ((Get-Date) -ge $script:markerSeenAt.AddSeconds(10)) { return "PASS" }
		return $null
	} "'coop: WorldLoaded' in lua.log"

	if ($result -eq "PASS")
	{
		Write-Host "Smoke test passed." -ForegroundColor Green
		(ReadFreshLog "lua.log" $since) -split "`n" | Where-Object { $_ -match "coop:" } | ForEach-Object { Write-Host "  $($_.Trim())" }
	}
	else
	{
		Write-Host "Smoke test $result" -ForegroundColor Red
		Write-Host "Logs: $(LogDir)"
		exit 1
	}
}

# Reads the scenario ids from the map's hidden `ScriptLobbyDropdown@test` values (excluding "none").
function MapScenarios
{
	$scenarios = @()
	$inDropdown = $false
	$inValues = $false
	foreach ($line in Get-Content "mods\$Mod\maps\$Map\rules.yaml" -ErrorAction SilentlyContinue)
	{
		if ($line -match "^\tScriptLobbyDropdown@test:") { $inDropdown = $true; continue }
		if (-not $inDropdown) { continue }
		if ($line -notmatch "^\t\t") { break }
		if ($line -match "^\t\tValues:") { $inValues = $true; continue }
		if ($inValues -and $line -match "^\t\t\t([^:\s]+):") { if ($Matches[1] -ne "none") { $scenarios += $Matches[1] } }
		elseif ($line -match "^\t\t\S") { $inValues = $false }
	}

	return $scenarios
}

function RunScenario([string]$name)
{
	Write-Host "Test '$Map/$name'..." -ForegroundColor Cyan
	$since = (Get-Date).AddSeconds(-1)
	$started = Get-Date
	$game = StartAutomatedGame (@("Launch.Map=$Map") + (LobbyOptions @("test=$name", "gamespeed=test")))

	$result = WatchGame $game $since {
		param($lua)
		if ($lua -match "coop-test: FAIL (.*)") { return "FAIL: $($Matches[1].Trim())" }
		if ($lua -match "coop-test: PASS") { return "PASS" }
		return $null
	} "'coop-test: PASS' or 'FAIL' in lua.log"

	(ReadFreshLog "lua.log" $since) -split "`n" | Where-Object { $_ -match "coop-test:" } | ForEach-Object { Write-Host "  $($_.Trim())" }
	Get-ChildItem (ResultsDir) -Filter "$name-*.png" -ErrorAction SilentlyContinue |
		Where-Object { $_.LastWriteTime -ge $since } | ForEach-Object { Write-Host "  screenshot: $($_.FullName)" }

	$elapsed = [int]((Get-Date) - $started).TotalSeconds
	if ($result -eq "PASS")
	{
		Write-Host "  PASS ($elapsed s)" -ForegroundColor Green
		return $true
	}

	Write-Host "  $result" -ForegroundColor Red
	return $false
}

function Test
{
	$scenarios = if ($Scenario) { @($Scenario) } else { @(MapScenarios) }
	if ($scenarios.Count -eq 0)
	{
		Write-Host "No test scenarios found for map '$Map'." -ForegroundColor Yellow
		return
	}

	$failed = @($scenarios | Where-Object { -not (RunScenario $_) })
	if ($failed.Count -gt 0)
	{
		Write-Host "$($failed.Count) of $($scenarios.Count) scenario(s) failed: $($failed -join ', '). Logs: $(LogDir)" -ForegroundColor Red
		exit 1
	}

	Write-Host "All $($scenarios.Count) scenario(s) passed." -ForegroundColor Green
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
		# P1 joins first and becomes the lobby admin, so only it needs to set the lobby options.
		(StartGame (@("Launch.Connect=127.0.0.1:$Port", "Player.Name=P1") + (LobbyOptions))),
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
		StartGame (@("Launch.Map=$Map") + (LobbyOptions)) | Out-Null
	}
	"duo" { Build; Duo }
	"lint" { Lint }
	"smoke" { Build; Smoke }
	"test" { Build; Test }
	"check" { Build; Lint; Smoke; Test }
}
