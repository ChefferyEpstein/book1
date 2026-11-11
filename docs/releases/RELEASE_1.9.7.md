# Book1 1.9.7 — Patch Notes

## Pinball
- Improved server-side score validation and scoring to make submitted scores more reliable.
- Fixed repeated contact scoring and refined flipper collision handling.
- Rebound multiplier now increases by **2% per rebound**; when a ball drains, it is **halved instead of reset**, and never drops below **1x**.
- Pinball XP is now **0.5% of the final score**, rounded down.
- Updated weekly Pinball score challenges to **15,000, 40,000, 60,000 and 90,000**.
- Reset the Pinball leaderboard while preserving XP already earned.
- Moved the Pinball XP explanation from the Casino page to the Pinball page.

## Fantasy
- Updated win points: **Elite 10**, **Challenger 15**, **Mong 20**.
- Removed draw points; ball-difference scoring remains.

## Weekly challenges
- Updated prediction targets to **9 and 15 correct predictions** per gameweek.
- Updated Casino wheel targets to **20 and 50 spins** per gameweek.
- Fixed Bokémong battle tracking and improved server-side weekly challenge validation and claiming.

## Results and betting
- Clearing an entered gameweek score is now handled safely.
- Clearing a fixture result reopens the related bets.

## Prestige
- Added a distinct emblem for every Prestige rank.
- Prestige 4 now has its own coloured diamond emblem.
- Added a separate **Prestige Master** emblem — a golden pool ball with a red crown — distinct from Prestige 10.
- Prestige Master is the final rank; no further prestiges are available after it.
- Added the Prestige Master unlock popup and persistent cosmetic/theme settings, with the existing layout and white typography retained.

## General
- Moved the Battleships leaderboard to just above Recent Games.
- Removed Chat and Bounties from the app navigation and removed their page routes.
- Improved the performance of shared bet settlement.

