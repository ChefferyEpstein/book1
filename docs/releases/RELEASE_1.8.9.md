# BOOK1 v1.8.9 — GRANDMASTER DEGENERACY

**Somebody suggested Chess, so the office now has another way to discover that confidence and competence are unrelated.**

## ♟️ Chess is live

Challenge anyone directly, choose your clock, optionally put chips on it, and find out who actually knows what en passant means.

Time controls:
- **Bullet** — 1+0
- **Blitz** — 3+2
- **Rapid** — 10+0
- **Untimed** — for people who apparently have all week

Chess has its own **Elo rating**, completely separate from pool.

The server validates the board, turns and results. It handles check, checkmate, stalemate, castling, en passant, promotion, resignation, draws and timeouts.

No, moving your bishop like a rook because nobody is looking does not work.

## 📈 Levels stop being flat

The old 500 XP every level system has been sent to the gulag.

Level requirements now scale:
- Level 1: **100 XP**
- gradually harder as you climb
- Level 25: **1,500 XP**
- full prestige: **20,000 XP**

Your existing prestige count stays intact.

## 🏅 Prestige finally gives you something

Free Spin gets faster as your prestige climbs:

- P0 — 30 minutes
- P1 — 25 minutes
- P2 — 20 minutes
- P3+ — 15 minutes
- P5+ — 10 minutes
- P10+ — 5 minutes

This is the first prestige reward track. The system is now ready for future prestige-only games and perks without duct-taping them onto progression later.

## 🎰 THE WHEEL CAN NO LONGER SPOIL ITSELF

Previously the result text waited for the wheel, but your chip balance could update first and tell you exactly what you had won.

That was shite.

Now:
1. the wheel result is chosen
2. the prize waits pending
3. the wheel spins
4. it lands
5. **then** your chips are credited

If you reload halfway through, the unfinished spin waits for you instead of disappearing.

## 🧠 Chess feeds progression

Chess games earn XP and the weekly minigame rotation now includes:

**Checkmate** — win 1 Chess game → **5,000 chips + 500 XP**

## 🔧 Under the bonnet

- Book1 → **v1.8.9**
- Database → **v31**
- Chess state, move legality, clocks, Elo and settlement are server-authoritative
- Free Spin payout is now two-stage so realtime balance refresh cannot reveal it early
- Progression now uses a 25-level scaling XP curve
- Prestige gate is server-side at 20,000 XP


## 🧠 CONNECT 4 INTELLIGENCE REPORT

The Book now keeps enough evidence to stop arguments about who is actually good at Connect 4.

The Connect 4 page now shows:

- games played
- wins / losses / draws
- win percentage
- average moves to win / lose
- quick wins and humiliations (13 moves or fewer)
- inferred first-player and second-player win rates
- current and best streaks
- favourite victim
- nemesis
- full head-to-head dossier
- shortest recorded humiliation

And, because apparently normal statistics weren't sufficiently insulting:

**MONG INDEX**

80% weighted loss rate + 20% how often your losses happen in 13 moves or fewer.

Higher number = thicker.

Players under 5 completed games are marked provisional, because winning one game and retiring undefeated is cowardice, not statistical significance.

New Connect 4 games also record first player, move history and explicit forfeits, so future analysis can get even more forensic.
