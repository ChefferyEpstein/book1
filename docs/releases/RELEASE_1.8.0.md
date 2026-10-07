# BOOK1 v1.8.0 — CONNECT 4

**The degenerates demanded more ways to lose imaginary money. The regime has complied.**

## New: Connect 4

- Challenge another active player directly from Book1.
- Play for **free or for chips**.
- Both players stake the same amount.
- The challenger's chips are escrowed immediately.
- The opponent's chips are escrowed when they accept.
- Declined or cancelled challenges refund the challenger.
- First player is chosen at random when the challenge is accepted.
- Turns are server-authoritative: no playing twice, no playing for someone else.
- Pieces automatically fall to the lowest available space in a column.
- Horizontal, vertical and diagonal four-in-a-row are detected automatically.
- Winner takes the full pot.
- Full-board draws refund both players.
- Forfeiting hands the pot to your opponent.
- Incoming challenges and **your turn** appear as a navigation notification.
- Recent Connect 4 games can be opened and viewed afterwards.

## Under the bonnet

- Database functions move to **v27**.
- Connect 4 state is stored in the shared Book1 data.
- Cloud and local development modes use the same game rules.
- New shared milestone: `M02 / 1.8.0 PvP`.

**As always: play your fucking games.**
