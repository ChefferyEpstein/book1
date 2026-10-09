# BOOK1 v1.8.8 — THE BOOKMAKER HAS DEVELOPED OBJECT PERMANENCE

**The bookmaker has finally learned that Ross v Miles is not the same event as Lorcan v Ajay, and the degenerates are no longer permitted to wait until somebody is 7–1 up before discovering a sudden interest in gambling.**

## 🎯 Correct score has grown a brain

Correct Score is now part of **Match Betting**.

The old fixed prices are gone.

Book1 now starts with the same player record + recent-form model used for normal match odds, then calculates the probability of every possible race-to-8 score from that matchup.

So:
- a favourite winning 8–3 is shorter
- the underdog winning 8–3 is much bigger
- close matches naturally make 8–6 and 8–7 more plausible
- the normal winner market and correct-score market now agree about who is actually good at pool

The price is calculated and locked by the server when the bet is placed.

Correct-score bets remain **singles only**.

## 🔴 START MATCH — BETTING CLOSED

There is now an actual pre-match betting lock.

Before you break, one of the two players presses:

**START MATCH**

That instantly records who started it and when, and shuts the market server-side.

Once a match is live:
- no new match-winner bets
- no new correct-score bets
- no adding it to an accumulator
- no new bounties
- no cancelling a bounty because your chosen horse has started getting battered
- no accumulator cash-out if one of its unresolved matches has already started

You also **cannot submit the result until the match has been started**.

So yes, pressing Start Match is now part of playing your fucking game.

If somebody starts the wrong fixture by accident, only the regime can reopen it, and only before anybody has submitted a score.

Knockout and 8-man matches use the same lock.

## 🏅 Prestige now follows you around

Levels and prestige are now visible next to player names throughout Book1.

Prestige also gets its own evolving badge:

- **P1** — bronze
- **P2** — silver
- **P3+** — gold
- **P5+** — red prestige
- **P10+** — mythic

So when somebody with a ridiculous prestige level says they “barely use Book1”, the evidence is now attached directly to their name.

## 📈 Weekly challenges now give XP

Weekly challenges now award **XP as well as chips**.

There is also a rotating challenge pool rather than the same three chores forever.

Pool challenges include:
- **Hat-trick** — win 3 pool games → **10,000 chips + 750 XP**
- **Clock In** — complete 4 pool games → **5,000 chips + 400 XP**
- **Run It Up** — finish at +10 ball difference → **7,500 chips + 750 XP**

Minigame challenges include:
- **Four in a Row** — win 2 Connect 4 games → **5,000 chips + 500 XP**
- **Naval Warfare** — win a Battleships game → **5,000 chips + 500 XP**
- **Hog Supremacy** — win a Hog duel → **3,000 chips + 300 XP**

Each game week serves **three challenges: two pool objectives and one minigame objective**.

Challenge XP counts towards your level and prestige.

Buying/spending chips still does not generate XP because we are not creating a pay-to-win office caste system. Yet.

## 🔧 Under the bonnet

- Book1 → **v1.8.8**
- Database → **v30**
- Exact-score pricing now uses the same underlying strength model as match odds
- Race-to-8 score probabilities are calculated rather than hard-coded
- Correct-score prices are server-authoritative
- Match-start betting locks are server-authoritative
- Weekly challenge validation and XP rewards are server-authoritative
- Accumulator cash-out now respects live matches

**The bookmaker now understands both probability and the passage of time.**

**As always: play your fucking games.**
