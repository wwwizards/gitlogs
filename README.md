# gitlogs — Git Commit Time Miner

Mine your `git log` for billable hours, weekly summaries, and daily activity reports.

[![MIT License](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
![PowerShell](https://img.shields.io/badge/PowerShell-5.1%2B%20%7C%20pwsh-blue)

---

## Origin

This tool started as a Perl script (~2003) written to generate billable-hour breakdowns
from commit history for freelance clients. It was ported to bash (~2015) for a Wall Street
engagement where the client wanted time reports derived from source control rather than
manual timesheets. The current PowerShell version was written in 2023.

```
gitperl (~2003)  →  git-timeline.sh (bash, ~2015)  →  Report-TimeLogs.ps1 (PowerShell, 2023)
```

The legacy bash version is preserved in [`legacy/git-timeline.sh`](legacy/git-timeline.sh).

---

## How It Works

Runs `git log` against the current repo, groups commits by day, and estimates hours worked
using a simple heuristic:

- **1 commit in a day** → assumes minimum 1 hour
- **Multiple commits in a day** → `lastCommit - firstCommit` (rounded to 1 decimal)

Aggregates daily hours into weekly and monthly buckets. Outputs a formatted report to stdout.

---

## Prerequisites

- PowerShell 5.1+ (Windows) or [`pwsh`](https://github.com/PowerShell/PowerShell) (macOS/Linux)
- Must be run from inside a git-managed directory

```bash
# macOS install
brew install powershell
```

---

## Usage

```powershell
# Last 2 weeks (default)
.\Report-TimeLogs.ps1

# Last 30 days — summary only
.\Report-TimeLogs.ps1 -lookback 1m -summary

# Last week — full daily detail
.\Report-TimeLogs.ps1 -lookback 1w -full

# Specific date forward
.\Report-TimeLogs.ps1 -lookback '11/01/2023'

# Date range
.\Report-TimeLogs.ps1 -lookback '10/01/2023 to 10/31/2023'

# Save to file
.\Report-TimeLogs.ps1 -lookback 1m -summary > $(Get-Date -f 'yyyy-MM-dd')-timesheet.txt
```

### Lookback formats

| Format | Example | Meaning |
|---|---|---|
| Relative | `14d`, `2w`, `1m`, `1y` | N days/weeks/months/years ago |
| Date | `11/01/2023` | From that date to now |
| Range | `10/01/2023 to 10/31/2023` | Explicit start and end |

### Output modes

| Flag | Output |
|---|---|
| *(none)* | Daily detail + weekly + monthly summaries |
| `-summary` | Weekly and monthly summaries only |
| `-full` | Full detail including all commit messages |
| `-quick` | Monthly totals only |

---

## Sample Output

```
--------------------------------------------------------------------------------
         ###   GIT-CODE CHECK-IN MONTHLY HOURS SUMMARY REPORT   ###
--------------------------------------------------------------------------------
   2023-11    |  Date Range: November              |  Hours Logged: 117.0
--------------------------------------------------------------------------------

--------------------------------------------------------------------------------
         ###   GIT-CODE CHECK-IN WEEKLY HOURS SUMMARY REPORT   ###
--------------------------------------------------------------------------------
 2023-Week45  |  Date Range: 10/30/2023 to 11/5/2023   |  Hours Logged: 25.2
 2023-Week46  |  Date Range: 11/6/2023 to 11/12/2023   |  Hours Logged: 43.8
 2023-Week47  |  Date Range: 11/13/2023 to 11/19/2023  |  Hours Logged: 48.0
--------------------------------------------------------------------------------
```

See [`sample-output/`](sample-output/) for full report examples.

---

## Roadmap

- [ ] Pester test suite (`Report-TimeLogs.Tests.ps1`)
- [ ] Package as a PowerShell module (`.psm1`)
- [ ] Multi-repo walker — aggregate hours across all git repos under a root directory
- [ ] Python port (`gitlogs.py`) for cross-platform use without pwsh dependency
- [ ] Session detection — treat gaps > N minutes as separate work sessions

---

## Technical Reference

See [REFERENCE.md](REFERENCE.md) for full function-level API documentation
(auto-generated from inline comment headers).

---

## License

[MIT](LICENSE) © 2003–2026 [wwwizards](https://github.com/wwwizards)
