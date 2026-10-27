# Co-op mode: open checks and follow-ups

## Test by hand (`.\coop duo -Map two-lane`)
These were built and pass the automated tests (`.\coop test -Map two-lane`) but haven't been tried by a player yet.

- [ ] **Upgrade Bay:** with the bay selected, clicking your own unit promotes it, for 25% of its cost. The cursor shows whether it's allowed. Check this with the default and the classic mouse styles.
- [ ] **Tech Center powers over the network,** with one client per force:
  - [ ] Infantry: Paratroopers
  - [ ] Tanks: Flash Freeze (also slows your own units)
  - [ ] Support: Parabombs and Cruiser Shelling. Cruiser Shelling may be too weak for a 3-minute cooldown.
- [ ] **Kill income with two players:** the player who did the most damage gets 30% of the unit's value, and the "+$" shows for them. Automated tests only cover this with one player.
- [ ] **Power Plants and Radar Domes:** the price rises by 1000 per one owned or queued, selling refunds half of what was paid, and the bonuses apply.
- [ ] **Airfield and Helipad repairs** are free. Also check that players' Artillery and V2s do 40% less damage.

## Decisions to make
- [ ] Repair cost and kill bounty of Power Plants and Radar Domes are based on the price each was bought for, so later ones cost more to repair. Is that OK?
- [ ] Tech Center powers come from the force, which the Construction Yard provides. Losing it removes the powers until it's rebuilt. Is that OK?
- [ ] Flash Freeze cooldown: set to 3 minutes, since the doc doesn't give one.
- [ ] A power for the Air force.

## Later
- [ ] Side objectives (on hold in the design doc).
- [ ] Enemy scaling with player count.
