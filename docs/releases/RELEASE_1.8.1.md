# BOOK1 v1.8.1 — CONNECT 4 HOTFIX

**Huh. Strange. I am genuinely shocked you lot could count that high. I built this at the very edge of your collective cognitive ceiling, yet somehow you still found the arithmetic fault. Bravo, degenerates. Good spot.**

- Fixed the bug where Connect 4 could occasionally declare a winner with only **three connected pieces**.
- The issue was in the server-side win checker, not the board UI.
- PostgreSQL NULL comparison behaviour meant an empty square before three matching pieces could slip through as a valid four-piece run.
- Win detection is now NULL-safe.
- Added explicit regression checks:
  - **3 connected pieces = not a win**
  - **4 connected pieces = win**
- Database function version is now **v28**.

**Connect 4 has now been upgraded from Connect 3 back to the advertised number.**
