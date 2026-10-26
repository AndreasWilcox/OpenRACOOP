
# Red Alert coop game mode design doc

The game mode is inspired by custom maps such as EnfosTD from Warcraft 3. In this new game mode players defend against continuous waves of enemy troops.

## Players
The current design is made for a minimum of 4 players but it's not a hard limit. Players can pick the same force if they want; the game won't block you from leaving forces unused. Preferably the enemy should scale with player count.

## Enemy

The enemy does not have a base building feature but instead waves are continuously spawned and sent in intervals (like in tower defence).
What units are sent and how strong they are change based on wave progression. There is a fixed number of waves and these waves should be definable in a config.

### Wave config
The waves are configured per map. Each wave has:
- A delay: the countdown to the wave, from when the previous wave started. Wave 1's delay doubles as the build-up time at the start of the game.
- A hint describing the wave, shown to the players while counting down to it.
- Groups of units. A wave can have several groups, and they don't have to contain the same units. Each group has:
  - The units to send.
  - The lane it's sent down (north or south).
  - An optional delay within the wave.
  - An optional starting veterancy, making the group more difficult.
  - An optional repeat: send the group again every X seconds, Y times.

Waves come on a fixed timer, so they can stack up if players fall behind. Players can call the next wave early, which restarts the countdown from then.

All Red Alert units can be used in waves; there is no distinction between Allied and Soviet units. These are excluded: ships, Engineers, Spies, Thieves, Mine Layers, APCs, Chinooks, Harvesters and MCVs. Scaling with player count is ignored for now.

### Enemy behaviour
- Enemies always prioritize units over buildings.
- Enemies don't gain veterancy while fighting across the map; groups may have veterancy from the start.
- Air units behave like ground units: they attack any unit that crosses their path. They have unlimited ammo and never leave the map; there is always a Construction Yard to attack until the players lose.
- Demo Trucks and M.A.D. Tanks charge in as a suicide attack.
- Medics and Mechanics escort their group, which makes them a target for players' aircraft and artillery to snipe out.

### Wave display
The players see the current wave count and a hint of what's in the next wave (specified in the wave config), along with a button to call the next wave early. A sound plays when a wave starts, timed with the text.

## Victory
The players win when the final enemy unit of the last wave dies. Every unit of every wave has to be dead.

## Defeat
The players lose when all player Construction Yards are destroyed.

## Forces
To create more teamwork between players each player has access to a set of units & powers they can use unique for that player. Lets call these forces; they replace factions so each player selects a force in the game start UI. Units no longer automatically gain veterancy, they get promoted by going to the upgrade bay (see Buildings).

Units, buildings and support powers work as they do in the original game unless specified. The original game's tech tree isn't used.

Handy lists of units in original game, only for reference.
[Allied units](http://ra.afraid.org/html/ra/a_units.html)
[Soviet units](http://ra.afraid.org/html/ra/s_units.html)

## Units
Only the units in a specific force can be bought by that force. All the units a force can buy should be under the same tab; ie Infantry units uses Infantry and requires Barracks, Tanks uses Vehicles and requires War Factory, Air uses Aircraft and requires Airfield/Helipad/War Factory and Support uses Vehicles and requires War Factory. In effect, each force would only build from Buildings and their unit tab. Units only requires their force's construction building, additionally some require the Tech Center. Air has multiple construction buildings so there it is specified. Anything not listed is unavailable.

### Infantry
- Rifle Infantry
- Rocket Soldier
- Grenadier
- Medic
- Flamethrower - Requires Tech Center

### Tanks
- Ranger
- Light Tank
- Heavy Tank
- Mammoth Tank - Requires Tech Center.

### Air
- Hind - Requires Helipad.
- Longbow - Requires Helipad.
- Yak - Requires Airfield.
- MiG - Requires Airfield.
- Mobile Flak - Requires War Factory, is visible in Aircraft tab.

### Support
- Artillery - Decrease damage by 40% compared to original game.
- Mine Layer
- V2 Rocket - Requires Tech Center. Decrease damage by 40% compared to original game.
- Demo Truck - Tech Center.

## Powers
NOTE: Need ideas for fitting powers so each team has at least one.
### Infantry
- Paratroopers
### Tanks
- Flash Freeze (*new*) - Makes units in a 5x5 area slow down to 60% speed for 20 seconds. Check if OpenRA has a way to do this already.
### Air
### Support
- Parabombs - Previously Ukraine's support power. Cooldown should be 4 minutes.
- Cruiser Shelling (*new*) - Fires in a barrage of 6 Cruiser shells from offscreen hitting an area of 4x4 squares. We don't see the cruisers themselves, just the shots coming in from the left side of the map. Can be placed anywhere. 3 minute cooldown.

## Buildings
Each player starts with a Construction Yard which they can't undeploy. Building generally works as before but we have a different set of buildings to build per force. Anything not listed is unavailable. A player isn't fully out even if their Construction Yard is destroyed, they can still build from their production building and move around remaining troops. Selling a building gives back half of the cost. Repairing buildings costs money just as before.

### Common buildings (all forces)
- Upgrade Bay (use Chonosphere visual) - Requires force's construction building. Selecting the building and then clicking a unit promotes that unit to the next level of veterancy. Each promotion level costs 25% of unit cost. Promotions follow the [OpenRA veterancy](https://openra-red-alert.fandom.com/wiki/Veterancy), ie three chevron ranks plus Elite. The promotion is instant. Can only build one and the building costs 600.
- Power Plant - now only increases all units/buildings damage by 10% for the player. Can build more than one, each one increases damage additively (ie, 3 buildings is 30% more damage). Initially costs 2000, price increases by 1000 for each building.
- Radar Dome - now only increases all units/buildings attack range by 1 cell for the player. Costs 2500. Can also build more than one and range is increased additively (ie, 3 buildings is 3 cells extra range).
- Tech Center - Unlocks support powers for the player (according to Powers heading). Initially costs 3000, price increases by 1500 for each building.
- Service Depot - Repairing a unit is free. Costs 1000.

### Infantry
- Barracks (use soviet visual style) - Builds all infantry. Costs 300.

### Tanks
- War Factory - Builds all tanks. Costs 1000.

### Air
- Airfield - Builds Yak & MiG. Landing on it will repair in addition to rearming the craft. Repair should be done at same speed as Service Depot. Costs 500.
- Helipad - Builds Hind & Longbow. Will repair as well as rearm, just as Airfield. Costs 600.
- War Factory - Only builds Mobile Flak. Costs 400.

### Support
- War Factory - Builds all support vehicles. Costs 1000.

## Resources
Players start out with 4000. Ore is not gathered anymore, players get money by killing enemies and completing side objectives. Whoever did the most total damage gets 30% of the unit's cost as income when it dies (use last hit if two players have the same damage). Enemies that start with veterancy pay out by the same percentage.
It's possible to send money between players as well. Power/energy is no longer used; it doesn't have to be removed but we can just set buildings to not use power.

## Map
The map is a long & small map, currently testing with 128x32. It's built on the idea of two lanes but with open areas between the 'lanes'. See the test map TwoLane that I've made for how I'm thinking.
Enemies spawn at either lane and move & attack until they reach the player's base.

## Side objectives
NOTE: Hold on with implementing this until the other stuff is done.
During the game while defending there should occur side objectives that will give players money for completing. These objectives gives incentives for players to be more adaptable and gives risk/reward choices.

### Destroy radar vehicle
A radar vehicle will spawn and move to one of a few defined points. Players need to destroy it within a timelimit before it leaves. Money logic is the same as with other enemy units. I think we can reuse the M.A.D. Tank for this but just disable its firing.

### Resupply drop
A money crate will spawn somewhere towards the enemy's side. The player that touches the crate gets the money.

## Other notes
Full map will always be visible to all players.