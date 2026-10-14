# BOOK1 v1.8.11 — PRESTIGE ISN'T A PARTICIPATION TROPHY

Prestige was getting too easy.

Previously every Prestige reset needed the same **20,000 XP**.

That meant somebody could eventually reach the higher Prestige tiers simply by continuing to exist near the Book for long enough.

That has been corrected.

## 📈 Prestige XP now scales

The next Prestige now costs:

- **P0 → P1:** 20,000 XP
- **P1 → P2:** 25,000 XP
- **P2 → P3:** 30,000 XP
- **P3 → P4:** 35,000 XP
- **P4 → P5:** 40,000 XP
- **P5 → P6:** 50,000 XP
- **P6 → P7:** 60,000 XP
- **P7 → P8:** 75,000 XP
- **P8 → P9:** 90,000 XP
- **P9 → P10:** 110,000 XP

Reaching **P10 now takes 535,000 cumulative XP**, versus 200,000 under the old system.

After P10, the requirement continues increasing by **20,000 XP per Prestige**.

## 🪜 Levels scale with Prestige too

The 25 levels inside each Prestige now stretch to match that Prestige's total XP requirement.

So you no longer hit Level 25 at 20k and then sit in a dead zone waiting for another 90,000 XP.

The whole level curve gets harder as your Prestige rises.

## 🏅 Existing Prestige is safe

Nobody loses an existing Prestige.

Existing XP offsets are preserved.

The harder requirement applies to the **next** Prestige you are working towards.

## 🔧 Under the bonnet

- Book1 → **v1.8.11**
- Database → **v34**
- Prestige threshold is enforced server-side
- Client progression bar uses the same dynamic curve
- P10 cumulative requirement: **535,000 XP**
