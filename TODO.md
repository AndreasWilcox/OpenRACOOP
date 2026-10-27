# Co-op mode: open checks and follow-ups

## Test by hand (`.\coop duo -Map two-lane`)
These were built and pass the automated tests (`.\coop test -Map test-range`) but haven't been tried by a player yet.

- [X] **Upgrade Bay:** with the bay selected, clicking your own unit promotes it, for 25% of its cost. The cursor shows whether it's allowed. Check this with the default and the classic mouse styles.
- [ ] **Tech Center powers over the network,** with one client per force:
  - [ ] Infantry: Paratroopers
  - [ ] Tanks: Flash Freeze (also slows your own units)
  - [ ] Support: Parabombs and Cruiser Shelling. Cruiser Shelling may be too weak for a 3-minute cooldown.
- [X] **Kill income with two players:** when either player kills a unit, both get a share of its value (with 30% split two ways, a rifle infantry gave +15 each; it is now 80%, so +40), and each sees their own amount. Automated tests only cover this with one player.
- [ ] **Power Plants and Radar Domes:** the price rises by 1000 per one owned or queued, selling refunds half of what was paid, and the bonuses apply.
- [ ] **Airfield and Helipad repairs** are free. Also check that players' Artillery and V2s do 40% less damage.
- [ ] **Building descriptions** in the build menu match what the co-op buildings do (Power Plant, Radar Dome, Tech Center, Service Depot, Airfield, Helipad, Air War Factory).
- [ ] **Enemy aircraft attack a Construction Yard** once there are no player units left, and switch to units when some show up.
- [ ] **The 20 waves over a full game:** difficulty, income from kills, and the time between waves. The unit counts and timings in `two-lane/waves.lua` are a first guess. Use "Call next wave" to reach the later waves quickly.

## Decisions to make
- [ ] Repair cost and kill bounty of Power Plants and Radar Domes are based on the price each was bought for, so later ones cost more to repair. Is that OK?
- [ ] Tech Center powers come from the force, which the Construction Yard provides. Losing it removes the powers until it's rebuilt. Is that OK?
- [ ] Flash Freeze cooldown: set to 3 minutes, since the doc doesn't give one.
- [ ] A power for the Air force.

## Later
- [ ] Side objectives (on hold in the design doc).
- [ ] Enemy scaling with player count.
