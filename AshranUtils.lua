local f = CreateFrame("Frame")

function f:OnEvent(event, ...)
	self[event](self, event, ...)
end

function f:ADDON_LOADED(event, addOnName)
  if addOnName == "AshranUtils" then
    print(format("Hello %s! %s loaded.", UnitName("player"), addOnName))
  end
end

-- name of item as it would appear in CHAT_MSG_LOOT = internal identifier
local items = { ["Rolle des Schutzes"] = "prot",
                ["Zauberstab der arkanen Gefangenschaft"] = "prison",
                ["Frostwyrmei"] = "egg",
                ["Nesingwarys verlorenes Horn"] = "horn",
                ["Beschwörungsschriftrolle für Yu'lon, die Jadeschlange"] = "yulon" }
-- debug
items["Wolliger Bergpelz"] = "Bergpelz"
items["gespaltener Huf"] = "Huf"
items["Bestienauge"] = "Bestienauge"

local ids = (function ()
  local t = {}
  for _k, v in pairs(items) do
    t[v] = true
  end

  return t
end)()

local playerLootMeta = {
  __call = function (self, text, playerName)
    for name, id in pairs(items) do
      if string.find(text, name) then
        local m = text:match("x(%d)") or 1
        local amount = tonumber(m, 10)
        self[playerName] = { id, amount }
      end
    end
  end,
  __newindex = function (self, playerName, args)
    local id, amount = unpack(args)
    local data = self.store[playerName] or {}
    data[id] = (data[id] or 0) + amount
    self.store[playerName] = data
  end
}
local playerLoot = setmetatable({ track = true, store = {}, debug = not true }, playerLootMeta)

function f:CHAT_MSG_LOOT(event, text, playerName, languageName, channelName, playerName2, specialFlags, zoneChannelID, channelIndex, channelBaseName, languageID, lineID, guid, bnSenderID, isMobile, isSubtitle, hideSenderInLetterbox, supressRaidIcons)
  if not playerLoot.track then return end

  playerLoot(text, playerName)
end

-- /auloot = show whole store
-- /auloot on = 
-- /auloot off = off
-- /auloot ids = show all tracked ids
-- /auloot $id = show who looted $id
SLASH_AU_LOOT1 = "/auloot"

SlashCmdList["AU_LOOT"] = function (message, _editBox)
  if message == "" then
    print(format("dump loot, track? %s", tostring(playerLoot.track)))
    DevTools_Dump(playerLoot.store)
  elseif message == "on" then
    playerLoot.track = true
    print(format("turned on: %s", tostring(playerLoot.track)))
  elseif message == "off" then
    playerLoot.track = false
    print(format("turned off: %s", tostring(playerLoot.track)))
  elseif message == "ids" then
    print("dump ids")
    DevTools_Dump(ids)
  elseif not ids[message] then
    print(format("unknown item id %s", message))
  else
    local total = 0
    for playerName, data in pairs(playerLoot.store) do
      local amount = data[message]
      if amount > 0 then
        print(format("%s had looted %d of %s", playerName, amount, message))
        if UnitInBattleground("player") then
          SendChatMessage(format("%s %d %s", playerName, amount, message), "SAY")
        end
        total = total + amount
      end
    end
    print(format("total for %s = %d", message, amount))
  end
end


-- /dump GetSpellInfo("Erdschild")
-- /dump GetSpellInfo(171249)
-- Rolle des Schutzes: 171249
-- Einsamer Wolf: 164273
-- Geisterwolf: 2645 (regular) , 260881 (dmg red)
-- Erdschild: 974
-- Lebenszyklus (Beleben): 197916
-- Lebenszyklus (Einhüllender Nebel): 197919
-- /say {rt5} xxx
-- Springflut: 61295
-- [357650] = "Urtümliche Wut"
-- /dump IsOutdoors()


-- /dump GetInstanceInfo()
-- /dump C_Map.GetBestMapForUnit("player")

-- areaPoiIDs = C_AreaPoiInfo.GetAreaPOIForMap(1478)
-- /dump C_AreaPoiInfo.GetAreaPOIForMap(1478)
-- secondsLeft = C_AreaPoiInfo.GetAreaPOISecondsLeft(6493)
-- /dump C_AreaPoiInfo.GetAreaPOISecondsLeft(6493)
-- Ashran Battleground 1191
-- /dump C_Map.GetMapInfo(4445)
-- /dump C_Map.GetMapInfo(603)
-- /dump C_Map.GetMapInfo(1191)


local function makeTowerInfo(pattern)
  return { pattern = pattern, duration = 0, faction = nil }
end

-- %s wird angegriffen! die %s ihn erobern
-- %s wird angegriffen! ihn zerstören
-- Eisblutturm
-- Turmstellung
-- der östlicher Frostwolfturm
-- der westliche Frostwolfturm
-- Nordbunker von Dun Baldar
-- Südbunder von Dun Baldar
-- Eisschwingenbunker
-- Steinbruchbunker

-- erobert
-- zerstört
local towersMeta = {
  __index = function (self, id)
    for _k, v in pairs(self.store) do
      for towerId, towerInfo in pairs(v) do
        if towerId == id then return towerInfo end
      end
    end
    return nil
  end,
  __call = function (self, text, playerName)
    if playerName ~= "Herold" then return end

    print(format("who: %s, what: %s", playerName, text))
    if text:find("Horde") then
      for id, towerInfo in pairs(self.store) do
        if text:find(towerInfo.pattern) then
          towerInfo.faction = "Horde"
          if text:find("erobert") then
            print(format("%s erobert!", towerInfo.pattern))
            -- reset
            towerInfo.duration = 0
          elseif text:find("erobern") then
            print(format("%s tapped!", towerInfo.pattern))
            -- started capturing
            towerInfo.duration = GetServerTime()
          else
            print(format("%s reset!", towerInfo.pattern))
            -- reset
            towerInfo.duration = 0
          end
        end
      end
    elseif text:find("Allianz") then
      for id, towerInfo in pairs(self.store) do
        if text:find(towerInfo.pattern) then
          towerInfo.faction = "Allianz"
          if text:find("zerstört") then
            print(format("%s erobert!", towerInfo.pattern))
            -- destroyed
            towerInfo.duration = -1
          elseif text:find("zerstören") then
            print(format("%s tapped!", towerInfo.pattern))
            -- started capturing
            towerInfo.duration = GetServerTime()
          else
            print(format("%s reset!", towerInfo.pattern))
            -- reset
            towerInfo.duration = 0
          end
        end
      end
    end
  end
}
local towers = setmetatable({ 
  reset = function (self)
    for _id, towerInfo in pairs(self.store) do
      towerInfo.duration = 0
    end
  end,
  store = {
    ["SH"] = makeTowerInfo("Steinbruchbunker"),
    ["IW"] = makeTowerInfo("Eisschwingenbunker"),
    ["south"] = makeTowerInfo("Südbunder von Dun Baldar"),
    ["north"] = makeTowerInfo("Nordbunker von Dun Baldar"),
    ["IB"] = makeTowerInfo("Eisblutturm"),
    ["TP"] = makeTowerInfo("Turmstellung"),
    ["east"] = makeTowerInfo("östlicher? Frostwolfturm"),
    ["west"] = makeTowerInfo("westlicher? Frostwolfturm")
  }
}, towersMeta)
local towerIds = (function (towers)
  local tmp = {}
  for id, towerInfo in pairs(towers.store) do
    tmp[id] = true
  end
  return tmp
end)(towers)

local function isTowerArg(message)
  return towerIds[message]
end

local function formatSeconds(diff)
  local m = 60
  local minutes = math.modf(diff / m)
  local seconds = math.floor(math.fmod (diff, m))

  return format("%d:%d", minutes, seconds)
end

local function debugTower(towerInfo)
  if towerInfo.duration < 0 then
    print(format("%s destroyed tower %s", towerInfo.faction, towerInfo.pattern))
  elseif towerInfo.duration == 0 then
    print(format("(%a) tower %s not attacked", towerInfo.faction, towerInfo.pattern))
  else
    local diff = GetServerTime() - towerInfo.duration
    print(format("%s rttower %s: %s", towerInfo.faction, towerInfo.pattern, formatSeconds(diff)))
  end
end

SLASH_AU_TOWERS1 = "/autowers"
SlashCmdList["AU_TOWERS"] = function (message, _editBox)
  if message == "" then
    for faction, v in pairs(towers.store) do
      for id, towerInfo in pairs(v) do
        debugTower(towerInfo)
      end
    end
  elseif message == "reset" then
    towers:reset()
  elseif isTowerArg(message) then
    for _k, v in pairs(towers.store) do
      for k, towerInfo in pairs(v) do
        if k == message then
          debugTower(towerInfo)
        end
      end
    end
  else
    print("AU_TOWERS: unknown command")
  end
end

function f:CHAT_MSG_MONSTER_YELL(event, text, playerName, languageName, channelName, playerName2, specialFlags, zoneChannelID, channelIndex, channelBaseName, languageID, lineID, guid, bnSenderID, isMobile, isSubtitle, hideSenderInLetterbox, supressRaidIcons)
  if GetRealZoneText() ~= "Alteractal" then return end

  towers(text, playerName)
end

SLASH_AU_POI1 = "/aupoi"

SlashCmdList["AU_POI"] = function (message, _editBox)
  local uiMapID = C_Map.GetBestMapForUnit("player")
  for _, areaPoiID in ipairs(C_AreaPoiInfo.GetAreaPOIForMap(uiMapID)) do
    local areaPOIInfo = C_AreaPoiInfo.GetAreaPOIInfo(uiMapID, areaPoiID)
    print(format("poi: %s", areaPOIInfo.name))
    if C_AreaPoiInfo.IsAreaPOITimed(areaPoiID) then
      print(format("time left: %d seconds", C_AreaPoiInfo.GetAreaPOISecondsLeft(areaPoiID)))
    else
      print("not timed")
      print(format("time left: %d seconds", C_AreaPoiInfo.GetAreaPOISecondsLeft(areaPoiID)))
    end
  end
end

f:RegisterEvent("ADDON_LOADED")
f:RegisterEvent("CHAT_MSG_MONSTER_YELL")
f:RegisterEvent("CHAT_MSG_LOOT")
f:SetScript("OnEvent", f.OnEvent)
