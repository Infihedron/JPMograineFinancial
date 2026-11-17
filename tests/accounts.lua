-- Accounts: migration, deposits, rules, training payments, overdraft modes
local G = 10000
MONEY = 50 * G
-- a 1.0 character with three goals and no balances
JPMF_CharDB = { schema = 2, nextGoalId = 4, debits = { class = { [34] = 3 * G, [36] = 7 * G }, prof = {}, pet = {} },
  goals = {
    { id = 1, kind = "training", name = "Training reserve", target = 0 },
    { id = 2, kind = "riding40", name = "Riding at 40", target = 90 * G, level = 40, spend = true },
    { id = 3, kind = "custom", name = "Savings", target = 0 },
  } }
JPMF_DB = { schema = 2 }
local ns = {}
for _, f in ipairs({"Core","Ledger","Planner","Market","Assets","UI","Pages","Morgrim","Broker"}) do assert(loadfile(DIR .. f .. ".lua"))("JPMograineFinancial", ns) end
local function FIRE(ev, ...) ns.Fire(ev, ...) end
local function money(d) MONEY = MONEY + d; FIRE("PLAYER_MONEY") end
local function show(tag)
  local saved, held, free = ns.Balances()
  local parts = {}
  for _, g in ipairs(JPMF_CharDB.goals) do parts[#parts + 1] = g.name .. "=" .. ns.Money(saved[g.id]) end
  print(tag, table.concat(parts, ", "), "| held " .. ns.Money(held), "| free " .. ns.Money(free))
end
FIRE("ADDON_LOADED", "JPMograineFinancial"); FIRE("PLAYER_LOGIN"); FIRE("PLAYER_ENTERING_WORLD", true)
show("seeded (expect training 10g, riding 40g, savings 0)")
ns.Withdraw(2, 15 * G); show("withdraw 15g riding")
ns.Deposit(3, 100 * G); show("deposit 'too much' to savings (expect 15g)")
ns.Withdraw(3, 5 * G)
print("rule set to", ns.SetRule(2, 20), "and savings asks 90 ->", ns.SetRule(3, 90))
ADV(5); FIRE("CHAT_MSG_MONEY"); money(10 * G); show("loot 10g (riding +2g, savings +8g)")
FIRE("PLAYER_LOGOUT"); ns.Record(5 * G, "Unreconciled", "test"); MONEY = MONEY + 5 * G; JPMF_CharDB.gold = MONEY
show("unreconciled +5g, no rule deposits")
FIRE("TRAINER_SHOW"); money(-3 * G); FIRE("TRAINER_CLOSED"); show("paid 3g class training from training reserve")
ADV(5); FIRE("MERCHANT_SHOW"); money(-20 * G); FIRE("MERCHANT_CLOSED"); show("spent 20g at a vendor (hold mode)")
ns.acct.settings.overdraft = "pull"; ADV(5); FIRE("MERCHANT_SHOW"); money(-1); FIRE("MERCHANT_CLOSED"); show("pull mode covers it")
print("auto deposits week", ns.Money((ns.AutoDeposits(7))))
for _, l in ipairs(ns.MorgrimLines()) do print("M:", l) end
ns.ToggleMain()
for _, p in ipairs(ns.UI.pageOrder) do ns.ShowPage(p.name) end
print(ns.StatementText():match("ACCOUNTS.-\n\n"))
print("errors", #JPMF_DB.errors)
for _, e in ipairs(JPMF_DB.errors) do print(e.msg) end
