--[[ JP Mograine Financial - Copyright (C) 2026 Infihedron. Licensed under the GNU GPL v3 or later; see LICENSE.
     Market (the Gadgetzan Sachs desk): the wishlist, prices seen at vendors and the
     auction house, and price lines on item tooltips. ]]

local _, ns = ...
local MAX_POINTS = 60

local function ItemIDFromLink(link)
  return link and tonumber(link:match("item:(%d+)"))
end
ns.ItemIDFromLink = ItemIDFromLink

function ns.Watch(link, target, source)
  local id = ItemIDFromLink(link)
  if not id then return nil end
  local w = ns.acct.wishlist[id] or { points = {} }
  w.link = link
  w.name = link:match("%[(.-)%]") or w.name or ("item " .. id)
  if target then w.target = target end
  if source and source ~= "" then w.source = source end
  w.added = w.added or time()
  ns.acct.wishlist[id] = w
  ns.Fire("JPMF_WISHLIST_CHANGED")
  return w
end

function ns.Unwatch(id)
  ns.acct.wishlist[id] = nil
  ns.Fire("JPMF_WISHLIST_CHANGED")
end

function ns.WatchFromSlash(rest)
  local link = rest:match("(|c.-|h|r)") or rest:match("(|Hitem:.-|h.-|h)")
  if not link then ns.Say("usage: /jpm watch <shift-click an item> [target, e.g. 15g]"); return end
  local after = rest:sub((rest:find(link, 1, true) or 0) + #link)
  local w = ns.Watch(link, ns.ParseMoney(after))
  if w then ns.Say("watching " .. w.link .. (w.target and (" with a target of " .. ns.Money(w.target)) or "")) end
end

-- Record one price; points older than the last 60 are thinned to one per week.
local function AddPoint(w, price, src)
  local pts = w.points
  local last = pts[#pts]
  local now = time()
  w.last, w.lastSrc, w.lastAt = price, src, now
  if last and last.p == price and last.s == src and now - last.t < 3600 then
    last.t = now
    return
  end
  pts[#pts + 1] = { t = now, p = price, s = src }
  if #pts > MAX_POINTS then
    -- keep the newest half as-is; thin the older half to one point per week
    local keep, lastWeek, half = {}, nil, #pts - MAX_POINTS / 2
    for i, p in ipairs(pts) do
      local wk = math.floor(p.t / 604800)
      if i > half or wk ~= lastWeek then keep[#keep + 1] = p end
      lastWeek = wk
    end
    while #keep > MAX_POINTS do table.remove(keep, 1) end
    w.points = keep
  end
  if w.target and price <= w.target and now - (w.alertAt or 0) > 3600 then
    w.alertAt = now
    ns.Say(("Gadgetzan Sachs: %s is at %s (%s), at or below your target of %s."):format(
      w.link or w.name, ns.Money(price, true), src, ns.Money(w.target, true)))
  end
end

---------------------------------------------------------------------------
-- Vendors
---------------------------------------------------------------------------
ns.On("MERCHANT_SHOW", function()
  if not GetMerchantNumItems then return end
  for i = 1, GetMerchantNumItems() do
    local id = ItemIDFromLink(GetMerchantItemLink(i))
    local w = id and ns.acct.wishlist[id]
    if w then
      local _, _, price, quantity = GetMerchantItemInfo(i)
      if price and price > 0 then AddPoint(w, math.floor(price / math.max(quantity or 1, 1)), "vendor") end
    end
  end
  ns.Fire("JPMF_WISHLIST_CHANGED")
end)

---------------------------------------------------------------------------
-- Auction house (classic-style results). The lowest buyout per item is kept.
---------------------------------------------------------------------------
local ahPending = false
local function ReadAuctionList()
  ahPending = false
  if not GetNumAuctionItems or not GetAuctionItemInfo then return end
  local best = {}
  for i = 1, GetNumAuctionItems("list") do
    local _, _, count, _, _, _, _, _, _, buyout, _, _, _, _, _, _, itemId = GetAuctionItemInfo("list", i)
    if itemId and ns.acct.wishlist[itemId] and buyout and buyout > 0 then
      local per = math.floor(buyout / math.max(count or 1, 1))
      if not best[itemId] or per < best[itemId] then best[itemId] = per end
    end
  end
  for id, price in pairs(best) do AddPoint(ns.acct.wishlist[id], price, "AH") end
  if next(best) then ns.Fire("JPMF_WISHLIST_CHANGED") end
end

if GetAuctionItemInfo then
  ns.On("AUCTION_ITEM_LIST_UPDATE", function()
    if ahPending then return end
    ahPending = true
    if C_Timer then C_Timer.After(0.5, function() ns.Safe(ReadAuctionList) end) else ReadAuctionList() end
  end)
end

---------------------------------------------------------------------------
-- Auction house (modern C_AuctionHouse, which WoW: Forever uses).
-- Prices are read from browse results and from the item/commodity detail lists,
-- only for items on the wishlist.
---------------------------------------------------------------------------
local function Offer(best, id, price)
  if id and ns.acct.wishlist[id] and price and price > 0 then
    if not best[id] or price < best[id] then best[id] = price end
  end
end

local function Commit(best)
  for id, price in pairs(best) do AddPoint(ns.acct.wishlist[id], price, "AH") end
  if next(best) then ns.Fire("JPMF_WISHLIST_CHANGED") end
end

local function ReadBrowse()
  local AH = C_AuctionHouse
  if not (AH and AH.GetBrowseResults) then return end
  local best = {}
  for _, r in ipairs(AH.GetBrowseResults() or {}) do
    Offer(best, r.itemKey and r.itemKey.itemID, r.minPrice)
  end
  Commit(best)
end

local function ReadItemResults(itemKey)
  local AH = C_AuctionHouse
  if not (AH and itemKey and AH.GetNumItemSearchResults and AH.GetItemSearchResultInfo) then return end
  local best = {}
  for i = 1, AH.GetNumItemSearchResults(itemKey) or 0 do
    local r = AH.GetItemSearchResultInfo(itemKey, i)
    if r then Offer(best, itemKey.itemID, r.buyoutAmount) end
  end
  Commit(best)
end

local function ReadCommodityResults(itemID)
  local AH = C_AuctionHouse
  if not (AH and itemID and AH.GetNumCommoditySearchResults and AH.GetCommoditySearchResultInfo) then return end
  local best = {}
  for i = 1, AH.GetNumCommoditySearchResults(itemID) or 0 do
    local r = AH.GetCommoditySearchResultInfo(itemID, i)
    if r then Offer(best, itemID, r.unitPrice) end
  end
  Commit(best)
end

if C_AuctionHouse then
  local browsePending = false
  local function Browse()
    if browsePending then return end
    browsePending = true
    local run = function() browsePending = false; ns.Safe(ReadBrowse) end
    if C_Timer then C_Timer.After(0.5, run) else run() end
  end
  ns.On("AUCTION_HOUSE_BROWSE_RESULTS_UPDATED", Browse)
  ns.On("AUCTION_HOUSE_BROWSE_RESULTS_ADDED", Browse)
  ns.On("ITEM_SEARCH_RESULTS_UPDATED", function(_, itemKey) ns.Safe(ReadItemResults, itemKey) end)
  ns.On("COMMODITY_SEARCH_RESULTS_UPDATED", function(_, itemID) ns.Safe(ReadCommodityResults, itemID) end)
end

---------------------------------------------------------------------------
-- Tooltips: "JP Mograine: last seen 14g at the AH, 2d ago (target 15g)"
---------------------------------------------------------------------------
local function AddTooltipLine(tooltip, link)
  local id = ItemIDFromLink(link)
  local w = id and ns.acct and ns.acct.wishlist[id]
  if not w then return end
  local text
  if w.last then
    text = ("Last seen %s at the %s, %s"):format(ns.Money(w.last, true), w.lastSrc == "AH" and "AH" or "vendor", ns.Ago(w.lastAt))
  else
    text = "On your wishlist, no price seen yet"
  end
  if w.target then text = text .. (" (target %s)"):format(ns.Money(w.target, true)) end
  tooltip:AddLine("|cff" .. ns.GOLD_HEX .. "JP Mograine:|r " .. text, 1, 1, 1)
end

if TooltipDataProcessor and Enum and Enum.TooltipDataType then
  TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, function(tooltip)
    if tooltip.GetItem then
      local _, link = tooltip:GetItem()
      ns.Safe(AddTooltipLine, tooltip, link)
    end
  end)
else
  GameTooltip:HookScript("OnTooltipSetItem", function(tooltip)
    local _, link = tooltip:GetItem()
    ns.Safe(AddTooltipLine, tooltip, link)
  end)
end
