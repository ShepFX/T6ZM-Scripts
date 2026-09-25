# CUKServers Black Ops 2 (T6) zombie scripts

The GSC the CUKServers Black Ops 2 (T6) servers actually run. Every file here was taken
from a live server, so what is in this repo is what is running.

Scripts install into `runtime/plutonium/storage/t6/scripts/zm/` unless a folder's README says
otherwise; Plutonium runs them at map load.

## What is deployed where

Several files are named differently on the servers than in this repo. The
deployed name is the one that matters — that is the filename to copy to.

| In this repo | Deployed as | Running on |
| --- | --- | --- |
| `Achievements/T6Achievements.gsc` | `T6Achievements.gsc` | 4 MP servers, in `scripts/mp/` |
| `AFK/_zm_AFK.gsc` | `_zm_afk.gsc` | 11 zombie servers |
| `AntiExploit/_zm_anti_exploit_t6.gsc` | `_zm_anti_exploit_clean.gsc` | 12 zombie servers |
| `First-Room-Challenge/FirstRoomChallenge.gsc` | `T6FirstRoomChallenge.gsc` | t6zm-first |
| `GameStats/T6GameStats.gsc` | `T6GameStats.gsc` | 11 zombie servers |
| `LiveRound/T6LiveRound.gsc` | `T6LiveRound.gsc` | 12 zombie servers |
| `RoundSaver/CUKRoundSaver.gsc` | `T6RoundSaverNew.gsc` | 12 zombie servers |
| `Speedrun/T6Speedrun.gsc` | `T6Speedrun.gsc` | 12 zombie servers |
| `T6PostRoundLockExploit/T6PostRoundLockExploit.gsc` | `T6PostRoundLockVote.gsc` | 12 zombie servers |
| `Zombie-Counter/CounterHUD.gsc` | `CounterHUD.gsc` | 12 zombie servers |

Last verified against the live servers on 2026-09-25.
