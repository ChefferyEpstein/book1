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
