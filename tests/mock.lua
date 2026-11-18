unpack = unpack or table.unpack
math.atan2 = math.atan2 or math.atan
local NOW_T = 1794700000
local NOW_G = 1000.0
function time() return NOW_T end
function SET_TIME(t) NOW_T = t end
function ADV(sec) NOW_T = NOW_T + sec; NOW_G = NOW_G + sec end
function GetTime() return NOW_G end
local _date = os.date
function date(f, t) return _date(f, t or NOW_T) end
MONEY = 371240
function GetMoney() return MONEY end
function UnitName() return "Valindra" end
LEVEL = 32
function UnitLevel() return LEVEL end
function UnitClass() return "Hunter", "HUNTER" end
function GetRealmName() return "Forever" end
function GetRealZoneText() return "Stranglethorn Vale" end
function GetBuildInfo() return "1.60.1", "70291", "Nov 2026", 16001 end
function debugstack() return "stack" end
function wipe(t) for k in pairs(t) do t[k] = nil end return t end
tinsert = table.insert
STANDARD_TEXT_FONT = "Fonts\\FRIZQT__.TTF"
UISpecialFrames = {}
SlashCmdList = {}
StaticPopupDialogs = {}
PRINTS = {}
print = function(...) local t = {} for i=1,select('#',...) do t[#t+1]=tostring(select(i,...)) end PRINTS[#PRINTS+1]=table.concat(t," ") end

-- generic widget stub
FRAMES = {}
local mt = {}
mt.__index = function(t, k)
  local f
  if k == "GetText" then f = function(self) return rawget(self, "_text") or "" end
  elseif k == "SetText" then f = function(self, v) rawset(self, "_text", v) end
  elseif k == "SetScript" then f = function(self, n, fn) local s = rawget(self, "_scripts") or {}; s[n] = fn; rawset(self, "_scripts", s) end
  elseif k == "HookScript" then f = function(self, n, fn) local s = rawget(self, "_scripts") or {}; s[n] = fn; rawset(self, "_scripts", s) end
  elseif k == "GetScript" then f = function(self, n) return (rawget(self, "_scripts") or {})[n] end
  elseif k == "RegisterEvent" then f = function(self, e) EVENTS[e] = true end
  elseif k == "Show" then f = function(self) rawset(self, "_shown", true); local s = (rawget(self,"_scripts") or {}).OnShow; if s then s(self) end end
  elseif k == "Hide" then f = function(self) rawset(self, "_shown", false) end
  elseif k == "SetShown" then f = function(self, v) if v then self:Show() else self:Hide() end end
  elseif k == "IsShown" then f = function(self) return rawget(self, "_shown") ~= false end
  elseif k == "GetWidth" or k == "GetHeight" then f = function() return 140 end
  elseif k == "GetCenter" then f = function() return 100, 100 end
  elseif k == "GetEffectiveScale" then f = function() return 1 end
  elseif k == "GetFrameLevel" then f = function() return 1 end
  elseif k == "HasFocus" then f = function(self) return rawget(self, "_focus") or false end
  elseif k == "GetChecked" then f = function() return true end
  elseif k == "GetItem" then f = function() return "x", "|cff0070dd|Hitem:10567::::::::|h[Quillshooter]|h|r" end
  elseif k:match("^Get") then f = function() return 0 end
  elseif k:match("^Is") or k:match("^Has") then f = function() return false end
  elseif k:match("^Create") then f = function(self) return NewStub() end
  else f = function(self) return self end end
  return f
end
function NewStub() local s = setmetatable({}, mt); FRAMES[#FRAMES+1] = s; return s end
EVENTS = {}
function CreateFrame(kind, name) local f = NewStub(); if name then _G[name] = f end; return f end
UIParent = NewStub(); Minimap = NewStub(); GameTooltip = NewStub(); ChatFontNormal = NewStub()
function hooksecurefunc(a, b, c)
  if type(a) == "string" then local orig = _G[a]; _G[a] = function(...) local r = {orig(...)}; b(...); return unpack(r) end
  else local orig = a[b]; a[b] = function(...) local r = {orig(...)}; c(...); return unpack(r) end end
end
TICKERS = {}
C_Timer = { After = function(d, fn) fn() end, NewTicker = function(d, fn) TICKERS[#TICKERS+1] = fn end }
function StaticPopup_Show() return NewStub() end
function GetCursorPosition() return 0, 0 end

-- game systems
function RepairAllItems() end
function TakeTaxiNode() end
function TakeInboxMoney() end
function AutoLootMailItem() end
function GetInboxInvoiceInfo(i) return i == 1 and "seller" or nil end
function InRepairMode() return false end
TRAINER = {}
function GetNumTrainerServices() return #TRAINER end
function GetTrainerServiceInfo(i) return TRAINER[i][1], TRAINER[i][6] or "Rank 1", 132336, TRAINER[i][2] end
SPELLBOOK = { "Raptor", "Auto Shot", "Arcane Shot", "Serpent Sting", "Aimed Shot", "Hunter's Mark" }
function GetSpellBookItemName(i) return SPELLBOOK[i] end
function GetTrainerServiceNumAbilityReq(i) return #(TRAINER[i][5] or {}) end
function GetTrainerServiceAbilityReq(i, r) local q = TRAINER[i][5][r]; return q[1], q[2] end
function GetTrainerServiceCost(i) return TRAINER[i][3] end
function GetTrainerServiceLevelReq(i) return TRAINER[i][4] end
UNAVAIL = 0
function GetTrainerServiceTypeFilter(k) return UNAVAIL end
function SetTrainerServiceTypeFilter(k, v) UNAVAIL = v end
function IsTradeskillTrainer() return false end
MERCH = {}
function GetMerchantNumItems() return #MERCH end
function GetMerchantItemLink(i) return MERCH[i][1] end
function GetMerchantItemInfo(i) return "n", "tex", MERCH[i][2], MERCH[i][3] end
AH = {}
function GetNumAuctionItems() return #AH end
function GetAuctionItemInfo(_, i) local a = AH[i]; return "n","t",a.count,1,true,1,"",1,1,a.buyout,0,false,nil,"o","o",0,a.id,true end
function GetItemIcon() return 1 end
MAH_BROWSE = {}
MAH_ITEM = {}
MAH_COMM = {}
C_AuctionHouse = {
  GetBrowseResults = function() return MAH_BROWSE end,
  GetNumItemSearchResults = function(k) return #MAH_ITEM end,
  GetItemSearchResultInfo = function(k, i) return MAH_ITEM[i] end,
  GetNumCommoditySearchResults = function(id) return #MAH_COMM end,
  GetCommoditySearchResultInfo = function(id, i) return MAH_COMM[i] end,
}
ZONE = "Stranglethorn Vale"
function GetRealZoneText() return ZONE end
function BuyMerchantItem(i, q) end
ITEMCLASS = {}
function GetItemInfoInstant(link) local id = tonumber(link:match("item:(%d+)")); local c = ITEMCLASS[id] or {}; return id, "t", "s", "", 0, c[1], c[2] end
MAIL = {}
function GetInboxHeaderInfo(i) local m = MAIL[i] or {}; return nil, nil, m.sender, "subj", m.money or 0 end
SENDMONEY = 0
function GetSendMailMoney() return SENDMONEY end
function SendMail(to, subj, body) end
-- bags, bank and item prices
CONTAINERS = {}     -- [bag] = { {link, count, id}, ... }
SELLPRICE = {}      -- [itemID] = copper
C_Container = {
  GetContainerNumSlots = function(bag) return CONTAINERS[bag] and #CONTAINERS[bag] or 0 end,
  GetContainerItemInfo = function(bag, slot)
    local s = CONTAINERS[bag] and CONTAINERS[bag][slot]
    if not s then return nil end
    return { hyperlink = s[1], stackCount = s[2], itemID = s[3] }
  end,
}
function GetItemInfo(link)
  local id = tonumber(tostring(link):match("item:(%d+)"))
  if not id or SELLPRICE[id] == nil then return nil end
  return "Item" .. id, link, 1, 1, 1, "t", "s", 20, "", 0, SELLPRICE[id]
end
function ConfirmTalentWipe() end
function StaticPopup_Show(which) end
