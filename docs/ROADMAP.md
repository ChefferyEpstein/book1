# Book1 Roadmap

## Planned — Events & Availability Calendar

Book1 needs a shared calendar/scheduler for organising things outside the normal pool game-week flow.

### Core use cases

- **Fixed-date event:** "Go-karting — 19th" and everyone marks whether they are in or out.
- **Flexible-date event:** "Poker night this weekend" with several candidate dates/times and players voting when they are available.
- **General social plans:** meals, nights out, tournaments, watch parties, trips, practice sessions, etc.

### Event model

Each event should support:

- title
- description / notes
- event type
- organiser
- location text
- one fixed date/time **or** multiple proposed date/time options
- RSVP deadline
- optional max capacity
- optional cost / estimated cost
- event status: planning / confirmed / cancelled / completed

### Availability states

For a fixed event, every player can answer:

- **In**
- **Maybe**
- **Out**

For date polling, each player can mark each proposed slot:

- **Free**
- **Maybe**
- **Unavailable**

The event should clearly show:

- total available per option
- who is free / maybe / unavailable
- the best date based on availability
- conflicts
- players who have not responded

### Calendar view

Add a Book1 calendar showing:

- pool game weeks
- league / knockout dates
- social events
- confirmed events
- events still being polled

Views:

- upcoming agenda
- month calendar
- individual event detail

### Confirmation flow

For flexible events:

1. Organiser creates the event and proposes dates/times.
2. Players submit availability.
3. Book1 ranks the options by attendance.
4. Organiser confirms the chosen slot.
5. The event becomes a normal confirmed calendar item.
6. Players can still update RSVP if plans change.

### Nice-to-have follow-ons

- recurring events
- reminders for people who have not voted
- "best evening this week" quick poll
- transport / lift coordination
- deposits / paid status for paid activities
- teams / seats for capacity-limited events
- event chat/comments
- calendar export (.ics)
- event history and attendance stats

### Design principle

This should feel like **Doodle + an events calendar built directly into Book1**, rather than a separate planning tool.

The scheduler should use the existing Book1 player identities and make it obvious, at a glance, **what is happening, when it is happening, and who is actually available**.

**Status:** Roadmap — not yet implemented.


---

## Planned — Bokémongs

A Book1-native collectible creature system: **Bokémongs**. The goal is to make progression, minigames and weekly activity feed into a persistent collection without turning Book1 into a full monster-battler project.

### Core concept

Players collect original Book1 creatures inspired by the office, pool league, casino, minigames, prestige system and existing Book1 lore.

Bokémongs should be earned primarily through actually using Book1:

- weekly challenges
- pool and minigame milestones
- prestige milestones
- event rewards
- eggs / mystery rewards
- limited seasonal drops

### Bokémong identity

Each Bokémong can have:

- name
- original artwork / sprite
- type or types
- rarity
- level
- XP
- base stats
- traits / passive ability
- 3–4 battle moves
- evolution path
- alternate / rare variant
- owner and acquisition history

Possible Book1-specific types include:

- Pool
- Office
- Pub
- Regime
- Finance
- Arcade
- Rave
- Food
- Goblin
- Abomination

### Activity-driven progression

Existing Book1 activity should contribute to Bokémong progression rather than creating a separate grind.

Examples:

- pool wins → combat / physical XP
- Chess → intelligence / strategy XP
- Connect 4 → strategy XP
- Battleships → tactics XP
- weekly challenges → general Bokémong XP
- prestige milestones → rare unlocks / evolutions
- special achievements → unusual evolution conditions

### Collection

Add a **Bokémongs collection / dex** showing:

- owned creatures
- undiscovered silhouettes
- rarity
- evolution chains
- variant status
- collection completion %
- individual creature stats and history

### Battles — first version

Keep V1 deliberately simple:

- 3 Bokémongs per team
- turn-based PvP
- clear type strengths / weaknesses
- 3–4 moves per creature
- health, attack, defence, speed and one specialist stat
- optional casual chip stakes with anti-farming protection
- battle record / leaderboard

Do **not** attempt a huge competitive battle simulator in the first release.

### Evolution

Bokémongs can evolve through Book1-specific conditions rather than only raw level.

Examples:

- reach a certain level
- win a number of pool games
- win Connect 4 in a low number of moves
- complete a prestige tier
- complete a particular weekly challenge
- own / use a specific item
- meet a deliberately stupid hidden condition

### Starter flow

When Bokémongs launches, each player chooses **one of three starters**.

The starters should be original Book1 creatures with distinct roles and deliberately inappropriate personalities. Starter choice is permanent unless an admin recovery is needed.

### Example creature direction

Working examples only, not final roster:

- Cue Goblin
- Spreadsheet Necromancer
- Finance Wyrm
- Prestige Pigeon
- Connectivore
- The Mong
- Clanker

Creature names, artwork, moves and flavour text should lean heavily into Book1's existing tone and player lore.

### V1 scope

Target an initial release with roughly:

- 20 original Bokémongs
- 3 starters
- collection / dex
- XP and levelling
- a small number of evolution chains
- activity-based unlocks
- simple 3v3 battles
- battle history / basic leaderboard
- rare variants

### Later expansions

Potential follow-ons:

- trading
- ranked weekly league
- seasonal Bokémongs
- eggs / incubation
- items
- breeding or fusion-style systems
- team synergies
- boss / raid encounters
- special event creatures
- player-created nicknames
- cosmetics
- deeper battle formats

Trading and any chip economy around Bokémongs must include duplication, farming and transfer-abuse protections before release.

### Design principle

Bokémongs should feel like **a ridiculous collectible ecosystem growing out of Book1**, not a separate game bolted onto it.

Every major Book1 activity should eventually have at least one creature, unlock, evolution, move or reward associated with it.

**Status:** Roadmap — future expansion, not yet implemented.
