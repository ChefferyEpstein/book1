# BOOK1 v1.8.0.1 — CONNECT 4 HOTFIX

**The degenerates discovered a mathematical loophole. The regime has sealed it.**

- Fixed a Connect 4 bug where the server could occasionally award a win with only **three connected pieces**.
- Root cause: SQL NULL comparison semantics meant an empty square before three connected pieces could be treated as a valid starting point for a four-piece run.
- Win detection is now NULL-safe.
- Added explicit regression checks:
  - three connected pieces = **not a win**
  - four connected pieces = **win**
- Database function version moved to **v28**.

**Connect 4 is once again Connect 4.**
