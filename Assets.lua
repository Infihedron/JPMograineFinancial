--[[ JP Mograine Financial - Copyright (C) 2026 Infihedron. Licensed under the GNU GPL v3 or later; see LICENSE.
     Assets: what your bags and bank would sell for. Shown on its own, never added
     into net worth, which stays the gold you actually have. ]]

local _, ns = ...

local BANK = BANK_CONTAINER or -1
local BAGS = NUM_BAG_SLOTS or 4
local BANK_BAGS = NUM_BANKBAGSLOTS or 6

local function NumSlots(bag)
  if C_Container and C_Container.GetContainerNumSlots then return C_Container.GetContainerNumSlots(bag) or 0 end
  if GetContainerNumSlots then return GetContainerNumSlots(bag) or 0 end
  return 0
end

-- link and stack size in a slot, from either the modern or the classic API
local function SlotItem(bag, slot)
  if C_Container and C_Container.GetContainerItemInfo then
    local info = C_Container.GetContainerItemInfo(bag, slot)
    if info then return info.hyperlink, info.stackCount or 1, info.itemID end
    return nil
  end
  if GetContainerItemInfo then
    local _, count, _, _, _, _, link, _, _, id = GetContainerItemInfo(bag, slot)
    return link, count or 1, id
  end
end

local function SellPrice(link)
  local get = (C_Item and C_Item.GetItemInfo) or GetItemInfo
  if not get then return nil end
  local ok, name, _, _, _, _, _, _, _, _, _, price = pcall(get, link)
  if ok and name then return price or 0 end
  return nil   -- not cached yet; the game will send it and we scan again
end

-- Vendor value of a range of containers, plus auction value of priced wishlist items.
local function Scan(bags)
  local vendor, ah, items, missing = 0, 0, 0, 0
  for _, bag in ipairs(bags) do
    for slot = 1, NumSlots(bag) do
      local link, count, id = SlotItem(bag, slot)
      if link then
        items = items + count
        local price = SellPrice(link)
        if price then vendor = vendor + price * count else missing = missing + 1 end
        local w = id and ns.acct.wishlist[id]
        if w and w.last then ah = ah + w.last * count end
      end
    end
  end
  return vendor, ah, items, missing
end

local function BagList()
  local t = {}
  for b = 0, BAGS do t[#t + 1] = b end
  return t
end

local function BankList()
  local t = { BANK }
  for b = BAGS + 1, BAGS + BANK_BAGS do t[#t + 1] = b end
  return t
end

local bankOpen = false

function ns.ScanAssets()
  if not ns.char then return end
  local a = ns.char.assets
  a.bags, a.bagsAH, a.bagItems, a.missing = Scan(BagList())
  if bankOpen then
    a.bank, a.bankAH, a.bankItems = Scan(BankList())
    a.bankAt = time()
  end
  a.at = time()
  ns.Fire("JPMF_ASSETS_CHANGED")
end

-- Total vendor value (bags + last seen bank), auction value of priced wishlist items, and when the bank was seen.
function ns.Assets()
  local a = ns.char and ns.char.assets or {}
  return (a.bags or 0) + (a.bank or 0), (a.bagsAH or 0) + (a.bankAH or 0), a.bankAt
end

local pending = false
local function Soon(delay)
  if pending then return end
  pending = true
  local run = function() pending = false; ns.Safe(ns.ScanAssets) end
  if C_Timer then C_Timer.After(delay or 1, run) else run() end
end

ns.On("PLAYER_LOGIN", function() Soon(3) end)
ns.On("BAG_UPDATE_DELAYED", function() Soon(1) end)
ns.On("GET_ITEM_INFO_RECEIVED", function()
  if ns.char and (ns.char.assets.missing or 0) > 0 then Soon(2) end
end)
ns.On("BANKFRAME_OPENED", function() bankOpen = true; Soon(0.5) end)
ns.On("BANKFRAME_CLOSED", function() bankOpen = false end)
ns.On("PLAYERBANKSLOTS_CHANGED", function() if bankOpen then Soon(0.5) end end)
ns.On("PLAYERBANKBAGSLOTS_CHANGED", function() if bankOpen then Soon(0.5) end end)
ns.On("JPMF_WISHLIST_CHANGED", function() Soon(1) end)

-- One line for screens: "Assets 12g 30s in items (bank seen 2d ago)"
function ns.AssetsLine()
  local vendor, ah, bankAt = ns.Assets()
  local bank = bankAt and (" \194\183 bank " .. ns.Ago(bankAt)) or " \194\183 visit a bank to include it"
  local extra = ah > 0 and (" (wishlist items %s at auction)"):format(ns.Money(ah)) or ""
  return ("Assets %s in items%s%s"):format(ns.Money(vendor), extra, bank)
end
