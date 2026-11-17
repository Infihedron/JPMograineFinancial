--[[ JP Mograine Financial - Copyright (C) 2026 Infihedron. Licensed under the GNU GPL v3 or later; see LICENSE.
     Broker: a small readout for status-bar addons (Titan Panel, ChocolateBar, Bazooka and
     others). It uses LibDataBroker when one of those has loaded it; nothing is bundled. ]]

local _, ns = ...
local obj

local function Text()
  if not ns.char then return "" end
  local _, _, free = ns.Balances()
  local parts = { ns.Money(GetMoney(), true) }
  parts[#parts + 1] = free < 0 and ("|cfff08b80overdrawn %s|r"):format(ns.Money(-free))
    or ("free " .. ns.Money(free, true))
  local fNet = ns.acct.settings.pace ~= "hour" and ns.PerLevelPace()
  if fNet then parts[#parts + 1] = ns.Money(fNet(UnitLevel("player"))) .. "/lvl" end
  return table.concat(parts, " \194\183 ")
end

local function Update()
  if obj then obj.text = Text() end
end

ns.On("PLAYER_LOGIN", function()
  local stub = _G.LibStub
  local ldb = stub and stub("LibDataBroker-1.1", true)
  if not ldb then return end
  obj = ldb:NewDataObject("JP Mograine Financial", {
    type = "data source",
    label = "JP Mograine",
    icon = "Interface\\Icons\\INV_Misc_Coin_02",
    text = "",
    OnClick = function(_, button)
      if button == "RightButton" then
        if ns.OpenPlanning then ns.OpenPlanning(true) end
      elseif ns.ToggleMain then
        ns.ToggleMain()
      end
    end,
    OnTooltipShow = function(tt)
      if ns.FillTooltip then ns.FillTooltip(tt) else tt:AddLine("JP Mograine Financial") end
    end,
  })
  Update()
end)

for _, ev in ipairs({ "JPMF_LEDGER_CHANGED", "JPMF_GOALS_CHANGED", "JPMF_ASSETS_CHANGED", "PLAYER_MONEY" }) do
  ns.On(ev, function() ns.Safe(Update) end)
end
