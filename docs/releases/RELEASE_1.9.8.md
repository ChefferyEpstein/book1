
# Book1 1.9.8

## Progression and XP integrity
- Replaced history-reconstructed Progress totals with a durable server-maintained XP balance.
- XP is credited automatically when server-side reward records are added, including weekly challenges, Brain Gym, case openings, Pinball, Tower Defense, predictions, fantasy settlement and completed games.
- Prestige now resets the balance while retaining a raw-history checkpoint, so old rewards are not subtracted repeatedly and new rewards continue to count.
- Removing or trimming old game/reward history no longer removes XP already earned.
- Aligned the server XP calculation for Tower Defense with the live 0.5% XP reward rate.
- Reconciled existing balances without carrying forward the overlapping manual XP offset patch; restored the two verified post-prestige common case rewards for Lorcan.

## Technical
- Added SQL migration v77 with an XP-balance synchronisation trigger on the shared Book record.
- Updated the client to display the authoritative `progression.*.xpBalance` value.
- Updated the app SQL version to 77.
