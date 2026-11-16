local ns = {}
for _, f in ipairs({"Core","Ledger","Planner","Market","UI","Pages","Morgrim"}) do assert(loadfile(DIR .. f .. ".lua"))("JPMograineFinancial", ns) end
ns.Fire("ADDON_LOADED", "JPMograineFinancial"); ns.Fire("PLAYER_LOGIN"); ns.Fire("PLAYER_ENTERING_WORLD", true)
ns.ToggleMain()
for _, p in ipairs(ns.UI.pageOrder) do ns.ShowPage(p.name) end
ns.OpenPlanning(true)
SlashCmdList.JPMOGRAINE("")
SlashCmdList.JPMOGRAINE("log")
SlashCmdList.JPMOGRAINE("help")
print("fresh errors", #JPMF_DB.errors)
for _, e in ipairs(JPMF_DB.errors) do print(e.msg) end
for _, l in ipairs(ns.MorgrimLines()) do print(l) end
