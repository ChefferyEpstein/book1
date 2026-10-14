# BOOK1 v1.8.10 — USE YOUR BRAIN FOR ONCE

**The Book has acquired educational content. Management accepts no liability for sudden cognitive improvement.**

## ♟️ Chess pieces are actually distinguishable now

White and black pieces now use strongly contrasting fills/outlines instead of both armies visually collapsing into the same dark Unicode soup.

Selected squares, legal moves and board coordinates still work exactly as before.

## 🏆 One leaderboard for all minigames

Progression now includes an **All-minigame leaderboard** combining:

- Connect 4
- Chess
- Battleships
- Hog Trumps

It shows **games played, wins, losses, draws, win rate**, plus each player's per-game record.

Ranking is primarily by **total wins**, then win rate and games played.

The individual Chess Elo and Connect 4 Intelligence Report remain separate.

## 🏅 Prestige rewards expanded

Prestige now improves more than Free Spin.

- **P1** — Free Spin 25m
- **P2** — Free Spin 20m + 10% cheaper cases
- **P3** — Free Spin 15m + 10% weekly challenge chip bonus
- **P4** — +10 percentage points on duplicate-card refunds
- **P5** — Free Spin 10m + 20% cheaper cases + 15% weekly bonus
- **P7** — 25% cheaper cases + 20% weekly bonus + 20pp duplicate refunds
- **P10** — Free Spin 5m + 30% cheaper cases + 25% weekly bonus + 25pp duplicate refunds

The bonuses are calculated server-side so changing the browser does not create magical cheap cases.

## 🧠 BRAIN GYM

A new daily section has been added for activities that may actually benefit a human brain.

### Sudoku
Daily 9×9 Sudoku.

**Reward: 300 XP**

### Mini Crossword
Daily four-word square with clue solving.

**Reward: 250 XP**

### Brain Teaser
A rotating daily logic/riddle question.

**Reward: 150 XP**

Complete all three on the same London calendar day:

**+200 XP full-clear bonus**

That's **900 XP maximum per day** from Brain Gym.

Rewards can only be claimed once per puzzle per day and answers are validated server-side.

Brain Gym gives **XP only** — no chips — because we are trying to introduce one feature that does not immediately become a gambling exploit.

A daily full-clear streak is also shown.

## 🔧 Under the bonnet

- Book1 → **v1.8.10**
- Database → **v33**
- New dedicated `book_brain_claim` RPC
- Brain Gym XP included in canonical progression calculations
- Prestige case discounts enforced by `book_open_case`
- Prestige weekly challenge bonuses enforced by `book_player_action`
- Duplicate-card prestige refund bonuses enforced server-side
- Combined minigame standings are derived from existing completed game records
