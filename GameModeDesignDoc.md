
# Red Alert coop game mode design doc

The game mode is inspired by custom maps such as EnfosTD from Warcraft 3. In this new game mode players defend against continuous waves of enemy troops.

## Enemy

The enemy does not have a base building feature but instead waves are continuously spawned and sent in intervals (like in tower defence).
What units are sent and how strong they are change based on wave progression. There is a fixed number of waves and these waves should be definable in a config, after completing all the waves the players win. Players lose when the enemy waves destroy all players deployed MCVs.

## Players

### Units
To create more teamwork between players each player has access to a set of units they can use unique for that player. Lets call these forces, so each player selects a force in the game start UI (I'm thinking how you select a faction currently). Units no longer automatically gain veterancy, they get promoted by going to the upgrade bay (see Buildings).

Handy lists of units in original game, only for reference.
[Allied units](http://ra.afraid.org/html/ra/a_units.html)
[Soviet units](http://ra.afraid.org/html/ra/s_units.html)

### Forces
- Infantry
- Tanks
- Air/anti-air
- Artillery/support

### Buildings
Each player starts with a deployed MCV which they can't undeploy. They also start with a single construction building based on what force they've selected (see above about forces). Building generally works as before but we have new buildings to use.

Upgrade bay (previously repair bay): Promotes a unit to the next level of veterancy. Each promotion costs 25% of unit cost. Promotions follow the [OpenRA veterancy](https://openra-red-alert.fandom.com/wiki/Veterancy), ie 1, 2, 3 and Elite.

### Resources
Ore is not gathered anymore, players get money by killing enemies and completing side objectives. It should be possible to send money between players as well. Power/energy is no longer used; it doesn't have to be removed but we can just set buildings to not use power.

## Map


## Side objectives
NOTE: Hold on with implementing this until the other stuff is done.
During the game while defending there should occur side objectives that will give players money for completing. These objectives gives incentives for players to be more adaptable and gives risk/reward choices.

### Destroy radar vehicle
A radar vehicle will spawn and move to one of a few defined points. Players need to destroy it within a timelimit before it leaves. They player that last hits it gets the money.

### Resupply drop
A money crate will spawn somewhere towards the enemy's side. The player that touches the crate gets the money.