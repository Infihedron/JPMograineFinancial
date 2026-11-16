local G = 10000
local ns = {}
for _, f in ipairs({"Core","Ledger","Planner","Market","UI","Pages","Morgrim"}) do assert(loadfile(DIR .. f .. ".lua"))("JPMograineFinancial", ns) end
local function FIRE(ev, ...) ns.Fire(ev, ...) end
local function money(d) MONEY = MONEY + d; FIRE("PLAYER_MONEY") end
local function last() return JPMF_CharDB.raw[#JPMF_CharDB.raw].c end
FIRE("ADDON_LOADED", "JPMograineFinancial"); FIRE("PLAYER_LOGIN"); FIRE("PLAYER_ENTERING_WORLD", true)
JPMF_DB.household["Lankhmar-Forever"] = { name = "Lankhmar" }
-- purchases
MERCH = { {"|Hitem:2515::|h[Sharp Arrow]|h", 10, 200}, {"|Hitem:4599::|h[Cured Ham Steak]|h", 400, 5}, {"|Hitem:2321::|h[Fine Thread]|h", 100, 1}, {"|Hitem:9999::|h[Shirt]|h", 500, 1} }
ITEMCLASS = { [2515] = {6, 2}, [4599] = {0, 5}, [2321] = {7, 0}, [9999] = {4, 0} }
ADV(5); FIRE("MERCHANT_SHOW")
for i = 1, 4 do BuyMerchantItem(i, 1); money(-MERCH[i][2]); print("bought", MERCH[i][1]:match("%[(.-)%]"), "->", last()) end
FIRE("MERCHANT_CLOSED")
-- transfers
ADV(5); FIRE("MAIL_SHOW"); MAIL = { {sender = "Lankhmar", money = 5 * G}, {sender = "Stranger", money = 1 * G} }
TakeInboxMoney(1); money(5 * G); print("mail from alt ->", last())
ADV(5); TakeInboxMoney(2); money(1 * G); print("mail from stranger ->", last())
ADV(5); SENDMONEY = 2 * G; SendMail("Lankhmar", "s", "b"); money(-2 * G - 30); print("sent to alt ->", last())
FIRE("MAIL_CLOSED")
-- zones
for i = 1, 30 do ADV(30); for _, t in ipairs(TICKERS) do t() end end   -- 15 minutes in STV
ADV(5); FIRE("CHAT_MSG_MONEY"); money(3 * G)
ZONE = "Arathi Highlands"
for i = 1, 30 do ADV(30); for _, t in ipairs(TICKERS) do t() end end
ADV(5); FIRE("CHAT_MSG_MONEY"); money(1 * G)
for _, z in ipairs(ns.ZoneReport(7)) do print("zone", z.zone, ns.Money(z.net), z.perHour and ns.Money(z.perHour) .. "/h" or "-", math.floor(z.secs / 60) .. "m") end
local st = ns.Statement(7)
print("statement transfers", ns.Money(st.transfers), "income", ns.Money(st.income))
print("gph excludes transfers", ns.Money(ns.GoldPerHour() or 0))
ns.ToggleMain()
for _, p in ipairs(ns.UI.pageOrder) do ns.ShowPage(p.name) end
ns.ShowPage("Ledger"); ns.UI.pages = ns.UI.pages
print(ns.StatementText():match("WHERE YOU EARNED.-\n\n"))
print("presets", ns.PRESETS[1].name, ns.Money(ns.PRESETS[1].target), ns.PRESETS[2].name, ns.PRESETS[3].name)
print("errors", #JPMF_DB.errors); for _, e in ipairs(JPMF_DB.errors) do print(e.msg) end
do
  do
    local pg = ns.UI.pages.Ledger
    pg.view = "zone"; for _, per in ipairs({ -1, 0, 7, nil }) do pg.period = per; pg:Refresh() end
    print("ledger zone view ok", pg.view)
  end
end
print("errors after zone view", #JPMF_DB.errors); for _, e in ipairs(JPMF_DB.errors) do print(e.msg) end
