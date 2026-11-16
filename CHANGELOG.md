# Changelog

## 1.1.1 (2026-11-16)

- Settings: the options are in two columns, so they no longer run into the Your data panel.
- Statement: the statement scrolls inside its panel instead of running over the buttons.
- Accounts: the preset buttons are in two rows, so every preset fits.
- Zones with no gold earned or spent are left out of the statement and the zone view.

## 1.1.0 (2026-11-16)

**Accounts**
- Goals are now accounts: named shares of your gold with a balance and an optional target. The Dashboard shows your net worth split by account, with what is free to spend.
- Deposit and withdraw between Free and any account.
- Auto-deposit rules: a percent of everything you earn goes to an account until it is full. All rules together stay at or under 100%.
- Overdraft: spending comes out of Free first. When Free goes below zero you are shown as overdrawn. A setting covers it from your lowest-priority accounts instead.
- Training bought at a trainer is paid from the training reserve.
- Upgrading: 1.0 goals become accounts holding the share of gold they had, so nothing moves.
- Morgrim reports your accounts, overdrafts and standing orders.

**Ledger**
- Vendor purchases are split into Ammo, Food & drink, Crafting materials and Reagents.
- Gold mailed between your own characters is recorded as Transfers, and left out of income, spending and gold per hour.
- Earnings by zone, with gold per hour in each zone: on the Ledger tab (By zone), in the weekly statement and from Morgrim.

**Presets**
- Updated to WoW: Forever launch prices: Riding at 40 is 100g (first mount included), Riding at 60 is 1,000g, and a new Dual spec at 40 preset at 50g.

**License**
- JP Mograine Financial is now free software under the GNU GPL v3. The names and branding stay with Infihedron; see NOTICE.md.

## 1.0.7 (2026-11-16)

- Pet trainers are recognized as their own kind of trainer. Their skills (Great Stamina, Natural Armor, resistances, Growl) are planned separately, and spending there is recorded as Pet training.
- New setting: include pet trainer skills in the forecast (on by default).
- Earlier versions filed pet trainer prices as class training. Planned class training is cleared once so your next class trainer visit rebuilds it correctly.
- The trainer is scanned again whenever its list changes, so a first look that comes back empty fills in on its own.

## 1.0.6 (2026-11-16)

- Talent-locked skills are only left out when every sign agrees: no Rank 1 at the trainer, not in your spellbook, and the game says you lack the rank before. This stops real skills (like Aimed Shot) being dropped when the game misreports a requirement.
- Each kind of trainer (class, profession, and trainers that list nothing, like pet trainers) keeps its own record in /jpm report, so one visit no longer hides another.
- A trainer that lists nothing changes nothing.
- /jpm report no longer garbles lines: the game read the separator character as a formatting code.

## 1.0.5 (2026-11-16)

- Trainer scan reads skill status correctly on WoW: Forever, which returns an icon where Classic returns the status.
- Skills that need a talent you do not have (Counterattack, Trueshot Aura and the like) are left out of planned training, along with all their later ranks.
- `/jpm skip <skill>` and `/jpm unskip <skill>` leave a trainer skill out of planned costs by hand. `/jpm skip` alone lists them.
- /jpm report shows the raw trainer data, requirement info and skipped skills.

## 1.0.4 (2026-11-16)

- Auction house prices now work on WoW: Forever, which uses the modern auction house. Prices are read from search results and item detail lists for wishlist items.
- Coins looted with auto-loot are now counted as Loot instead of Other.
- The trainer scan counts every service you have not learned yet, runs a second time in case the list loads late, and never erases earlier prices with an empty result.
- /jpm report shows exactly what the last trainer listed, to diagnose scans that find nothing.
- Wishlist buy alerts appear at most once an hour per item.

## 1.0.3 (2026-11-16)

- The forecast no longer drops below zero. A shortfall is shown in words ("Short by about 45g at level 40"), and Morgrim warns about it.
- Goal lines on the chart show each goal's own amount instead of the running total.
- The "now" marker is a drawn dot instead of a character the game font lacks.
- The training reserve says "Visit your class trainer" until it has prices.
- Class and profession trainer scans are tracked separately, and both appear in /jpm report.

## 1.0.2 (2026-11-16)

- Fixed: goal and wishlist rows hid their names, notes, progress bars and prices behind the row background.
- The selected tab is now solid gold so the current page stands out.

## 1.0.1 (2026-11-16)

- `/jpm morgrim target` sets Morgrim's portrait from any NPC you are targeting.

## 1.0.0 (2026-11-16)

First release.

- Ledger with automatic categories, login reconciliation and tiered data retention.
- Goals with presets, priority order and protected gold.
- Trainer scan that turns upcoming class training into planned costs.
- Forecast by level with planned costs, goal lines and arrival estimates.
- Wishlist with vendor and auction house price capture, tooltip lines and buy alerts.
- Weekly statement and planning session with Morgrim Stanley.
- Household view across characters.
- Settings for data retention, deletion and reset; diagnostic report and debug log.
