# monday.com for the Omarchy bar

An open-work count in the bar, and a two-tab popup: the items assigned to you
bucketed by how late they are, and a status rollup for each watched board.

Requires Omarchy 4 (the Quickshell `omarchy-shell`) and `python3` — standard
library only, nothing to `pip install`.

## Install

```bash
omarchy plugin add https://github.com/lab81io/omarchy-monday.git
```

Plugins run as unsandboxed code inside your long-running shell process, so it
lands disabled for you to read first. Then:

```bash
omarchy plugin enable lab81io.monday
omarchy bar move lab81io.monday --section right
```

Later updates are a fast-forward with a diff to review first:

```bash
omarchy plugin update lab81io.monday
```

## Setup

1. **Get an API token** — in monday.com: avatar (bottom left) → *Developers* →
   *My access tokens* → copy the personal token.

2. **Store it**, readable only by you:

   ```bash
   install -m 600 /dev/null ~/.config/omarchy/monday/token
   $EDITOR ~/.config/omarchy/monday/token   # paste the token, nothing else
   ```

   `$MONDAY_API_TOKEN` in the environment is used instead when it is set.

3. **Pick it up** — left-click the widget and press `r`. No restart needed.

## Which boards it watches

By default: the 8 boards you touched most recently. To pin an explicit list,
put one board id per line in `~/.config/omarchy/monday/boards`:

```
1234567890   # Roadmap
9876543210   # Support queue
```

The id is the number in a board's URL: `.../boards/1234567890`.

## How it reads your boards

Board layouts differ, so nothing is hardcoded. On every fetch the helper reads
each board's columns and picks:

- **Person** — the `people` column, preferring one titled *Owner*.
- **Status** — the `status` column that declares done labels, preferring one
  titled *Status* (boards routinely also have *Priority* or *Health*).
- **Due date** — a `date` column titled *Due*/*Deadline*/*Target*, else the
  board's `timeline` end, else any date column.

"Done" is whatever that board marked as a done label in monday (`done_colors`),
not a guess at English label text, so renamed labels and non-English boards
still roll up correctly. Status dots and the per-board rule use the real label
colours from monday.

## Interaction

| Where | Action |
|---|---|
| Bar, left click | Open the popup |
| Bar, right click | Refresh now |
| Bar, middle click | Open monday.com |
| Popup, `←` / `→` | Switch tab (`1` my work, `2` boards) |
| Popup, `↑` / `↓` | Move the cursor |
| Popup, `⏎` or `o` | Open the item or board in the browser |
| Popup, `r` | Refresh |

The bar count is your open (not-done) assigned items, and turns urgent-coloured
with a trailing `!` when any of them are past their due date.

## Settings

`refreshIntervalSec` (default 300, min 60) in the widget's `shell.json` entry.

## Files

```
manifest.json        plugin declaration
Panel.qml            bar button + popup
Service.qml          polling loop and parsed state
Model.js             date bucketing and label formatting
MondayIcon.qml       drawn mark, so no Nerd Font glyph dependency
bin/monday-fetch     python3 helper — the only thing that talks to the API
```

The helper uses the Python standard library only; no `pip install` needed.
