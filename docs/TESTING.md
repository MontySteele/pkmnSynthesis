# Testing Pokemon: Synthesis (Windows)

No dev tools needed. Total setup time: ~10 minutes.

## Step 1: Get Pokemon Infinite Fusion

1. Go to the [Pokemon Infinite Fusion Discord](https://discord.gg/infinitefusion)
   or download the game from [pokemoninfinitefusion.com](https://www.pokemoninfinitefusion.com/)
2. Download the latest version and extract it somewhere (e.g. `Desktop\Pokemon Infinite Fusion`)
3. Verify it works: double-click `Game.exe` and confirm the game launches

## Step 2: Get the mod files

**Option A — Download from GitHub (easiest):**

1. Go to the repo on GitHub
2. Click the green **Code** button → **Download ZIP**
3. Extract the ZIP somewhere (e.g. Desktop)
4. Open the `dist\` folder inside

**Option B — If you already have the repo cloned:**

Just open the `dist\` folder — the patched files are already there.

## Step 3: Install the mod

1. Open the `dist\` folder
2. Double-click **`install.bat`**
3. If it doesn't auto-detect your game, drag your game folder onto the window and press Enter
4. It will back up your original files and copy the patched ones in

## Step 4: Play

Launch `Game.exe` as normal. The modified dialogue should appear in Pallet Town.

## Uninstalling

Double-click **`uninstall.bat`** in the `dist\` folder. It restores the original files from backup.

## What's patched

Currently modified maps:
- **Map042** — Pallet Town (Blue NPC, Oak intro)
- **Map077** — Oak's Lab

## Troubleshooting

**"Windows protected your PC" SmartScreen warning:**
Click "More info" → "Run anyway". This is normal for unsigned .bat files.

**Game crashes on launch after patching:**
Run `uninstall.bat` to restore originals and report the issue.

**Dialogue looks the same:**
Make sure you installed to the right game folder. Check that `Data\.synthesis_backup\` exists
inside your game directory (this confirms the install ran).
