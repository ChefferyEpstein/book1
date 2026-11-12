# Book1 1.9.8

## Tower Defense
- Added a new Tower Defense game inspired by classic Desktop Tower Defense.
- Added a 20×20 open build grid with route-finding: towers can shape the maze, but cannot block the creep route.
- Added Pellet, Dart, Swarm, Frost, Bash, Ink, Squirt and Missile tower choices, with cash costs, firing rates, range and damage differences.
- Added normal, fast, armoured and boss creeps, escalating waves, lives, cash from kills, tower upgrades and a separate Tower Defense leaderboard.
- Added a 100-chip server-side entry fee.
- Added server-side session validation and score recording. Tower Defense XP is 0.5% of the final score, rounded down.
- Added weekly challenges: complete 3 Tower Defense games, and reach wave 15 in a single game.

## Technical
- Added SQL migrations v64–66 with server-side game start/finish functions, weekly-challenge validation and server-only session tokens.
- Updated the app SQL version to 66.
