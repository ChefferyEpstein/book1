# Book1 1.9.0 — Bokémongs & Social Expansion

## Shipped

### Career milestones
Persistent long-term challenges now track historical Book1 activity, including pool games played, balls potted, wins, minigames, Connect 4 wins, Chess wins and weekly challenge claims. Completed milestones pay chips and can unlock Bokémongs. Claims are validated server-side and cannot be claimed twice.

### Chess & Battleships intelligence
Both game pages now include long-term intelligence leaderboards with games played, W-L-D, win percentage, streaks, victims and nemeses.

### Social calendar
Book1 now has a shared Calendar section. Players can create fixed-date events or flexible date polls, RSVP, mark availability, and organisers can confirm the selected date or cancel the event.

The 1.9.0 UI is agenda/poll-first. A graphical month-grid calendar is reserved for a follow-on.

### 8-man payout correction
8-man tournaments now display the intended prize split:

- Winner — 75%
- Runner-up — 25%

The displayed values are calculated from the paid pot, and the completed tournament stores both winner and runner-up prize amounts.

### Bokémongs V1
The first Bokémongs system is live with 20 original Book1 creatures.

Players choose one of three starters and receive a three-creature starter team. The Bokedex tracks owned and undiscovered creatures, long-term milestones unlock additional Bokémongs, and activity XP feeds Bokémong bond level.

V1 battles are server-resolved 3v3 contests using team power, Book1 activity progression and a controlled random factor. Tactical turn-by-turn combat is a future expansion.

### Connect 4 live refresh
Active Connect 4 boards now listen to the existing lightweight Book pulse and fetch only the selected game's detail. Opponent moves should therefore appear near-realtime without restoring the previous full-state realtime egress pattern.

## Technical

- Client: Book1.9.0
- Database function version: 35
- Migration: `migrations/book1_9_0_update.sql`
- New player RPC: `book_19_action`
- Client JavaScript parse: PASS
- Supabase performance advisor: no findings
- GitHub Pages deployment: run 38734487065 SUCCESS

## Follow-ons

- graphical month calendar
- richer event metadata, reminders and event chat
- tactical turn-by-turn Bokémong combat
- Bokémong team editing, evolution chains, items and trading
- deeper Chess and Battleships telemetry where historical detail is available
