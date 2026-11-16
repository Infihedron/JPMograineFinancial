# JP Mograine Financial

*Private banking for adventurers.*

JP Mograine Financial turns your gold into a plan. Open accounts for what you are saving toward, see when they will be full, and get a weekly review from your personal advisor, Morgrim Stanley.

Tracking addons tell you where your gold went. JP Mograine Financial tells you where it is going.

Built for **World of Warcraft: Forever**.

## Features

- **Accounts.** WoW gives you one pile of gold; JP Mograine Financial lets you split it. Open a Mount Fund, a Savings account, a training reserve or anything else, and see it all at a glance: *Net worth 50g. Mount Fund 30g. Savings 10g. Free 10g.* Accounts can have a target or none at all.
- **Deposits, withdrawals and standing orders.** Move gold between Free and any account yourself, or set an auto-deposit rule such as "20% of everything I earn goes to the Mount Fund". Rules stop when an account is full.
- **Overdraft protection, your way.** Spending always comes out of Free first. If you spend more than Free holds, you are shown as overdrawn until you withdraw from an account, or, if you prefer, the addon covers it from your lowest-priority accounts automatically.
- **Training reserve that pays your trainer.** The training account fills from what your next six levels of training will cost, and training bought at a trainer is paid from it.
- **Forecast.** Your projected gold level by level, based on what you actually earn per hour played. Training and account purchases (like your mount) step the line down at the level they happen.
- **Trainer scan.** Open your class trainer once and the addon records what your next levels will cost, at your real price after reputation discounts. Skills from talents you do not have are left out. Hunters: pet trainer skills are planned separately.
- **Ledger.** Every gold change, sorted into categories: quests, loot, vendor sales, the auction house, mail, trades, class, pet and profession training, flights, repairs, the stable, and vendor purchases split into ammo, food and drink, crafting materials and reagents. Gold mailed between your own characters is a transfer, not income or spending.
- **Earnings by zone.** See where your gold actually comes from, and what each zone pays per hour played.
- **Wishlist and price watch.** Add items you want with a target price. Prices are recorded whenever you open a vendor or browse the auction house, item tooltips show the last price seen, and you are alerted when an item drops below your target.
- **Weekly statement and planning session.** Morgrim Stanley walks you through last week's earnings and spending, your biggest expense, your goals and what is coming up, with one piece of advice.
- **Household.** Every character's gold in one place, updated when you log into each.

## Install

1. Download the zip.
2. Extract the `JPMograineFinancial` folder into `World of Warcraft/_<version>_/Interface/AddOns/`.
3. Restart the game or type `/reload`.

## Your first five minutes

1. Type `/jpm` or click the gold coin on your minimap.
2. Open **Accounts** and open **Riding at 40**. Use **Deposit** to set aside what you already have, and **Auto %** to keep it growing.
3. Visit your **class trainer**. Nothing to click: the addon reads upcoming costs on its own.
4. Play for half an hour. The forecast needs a little play time to learn your gold per hour.
5. Right-click the minimap coin for your first planning session.

## Commands

| Command | What it does |
| --- | --- |
| `/jpm` | Open or close the window |
| `/jpm plan` | Start a planning session with Morgrim |
| `/jpm watch <item> [target]` | Add an item to the wishlist (shift-click the item; target like `15g`) |
| `/jpm report` | Copyable diagnostic report for bug reports |
| `/jpm debug` | Turn the debug log on or off |
| `/jpm log` | Show the debug log (`/jpm log clear` empties it) |
| `/jpm morgrim target` | Cast Morgrim from your current target: pick any NPC you like the look of |
| `/jpm skip <skill>` | Leave a trainer skill out of planned training (`/jpm unskip <skill>` undoes it, `/jpm skip` lists them) |

## Your data

- Every transaction is kept for 14 days (you can choose 7 to 90). After that it folds into daily totals, kept for a year, and monthly totals, kept forever. Saved data stays small even with many characters.
- Each character's history is saved per character. Settings, the wishlist and the household summary are shared across your account.
- **Settings** shows how much is stored and can delete old records, reset a character's history, or remove an old character from the household.
- If your gold changed while the addon was not running, the difference is recorded as a labelled adjustment so your books stay accurate.

## Reporting a problem

Type `/jpm report`, copy the text, and include it with your report along with what you were doing. If asked, turn on `/jpm debug`, reproduce the problem, then send `/jpm log`.

## FAQ

**Why does the forecast say it needs more data?** It projects from your real gold per hour played. Give it about 30 minutes of play, or set an override on the Forecast tab.

**Why are some prices missing?** The addon only sees prices when you look: at a vendor's window or in auction house search results. It never searches the auction house by itself.

**Does it change my gold or buy anything?** No. It only reads and records. Accounts are bookkeeping: your gold stays in your bags, and the addon only shows how you have divided it.

**What is "Free"?** Your gold minus everything set aside in accounts. It is what you can spend without touching your savings.

**I upgraded from 1.0 and my goals became accounts.** Each one starts with the share of your gold it had before, so nothing moved.

## Notices

JP Mograine Financial™ is a product of **Infihedron**. © 2026 Infihedron.

The code is free software under the **GNU General Public License v3** (or any later version): you may use, study, change and share it, and anything you release built on it must stay under the GPL too. See `LICENSE`.

The names *JP Mograine Financial*, *Morgrim Stanley*, *Gadgetzan Sachs* and *Infihedron*, and their branding, are **not** covered by the GPL. If you release a modified version, please give it a different name. See `NOTICE.md`.

JP Mograine Financial, Morgrim Stanley and Gadgetzan Sachs are parody names. They are not affiliated with or endorsed by any real financial institution.

Not affiliated with or endorsed by Blizzard Entertainment. World of Warcraft is a trademark of Blizzard Entertainment, Inc.

Morgrim Stanley is not a licensed financial advisor, in Azeroth or anywhere else.

## Support the project

JP Mograine Financial is free and always will be. If it helps your gold, you can leave a tip on [Ko-fi](https://ko-fi.com/infihedron) or use the **Sponsor** button on [GitHub](https://github.com/Infihedron/JPMograineFinancial). There is never anything to buy in the game.

## Contributing

Bug reports and ideas are welcome as GitHub issues. Please include the output of `/jpm report`.

Developers: `tests/` holds a mock of the WoW API and test scripts. Run `python3 tests/run_all.py` (needs `pip install lupa`).
