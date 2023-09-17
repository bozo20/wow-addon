local myAddonName, ns = ...

local f = CreateFrame("Frame")

function f:OnEvent(event, ...)
	self[event](self, event, ...)
end


local mountsMeta = {
  types = {
    [230] = {},
    [248] = {},
    [402] = {}
  },
  lookup = {
    [230] = "ground",
    ["ground"] = 230,
    [248] = "flying",
    ["flying"] = 248,
    [402] = "df",
    ["df"] = 402
  },
  factionMap = {
    ["Horde"] = 0,
    ["Alliance"] = 1
  },
  isMountUsable = function (self, isFactionSpecific, faction)
    if not isFactionSpecific then return true end
  
    local englishFaction, localizedFaction = UnitFactionGroup("player")

    return self[englishFaction] == faction
  end,
  __index = {
    debug = function (self)
      local meta = getmetatable(self)

      for mountTypeID, mounts in pairs(meta.types) do
        print(format("type %s: # = %d", meta.lookup[mountTypeID], #mounts))
      end
    end,
    isZoneForDragonriding = function (self)
      local mapID = C_Map.GetBestMapForUnit("player")
      local mapInfo = C_Map.GetMapInfo(mapID)
      while mapInfo.mapID ~= 1978 and mapInfo.parentMapID ~= 0 do
        mapInfo = C_Map.GetMapInfo(mapInfo.parentMapID)
        if mapInfo.mapID == 1978 then return true end
      end

      return false
    end,
    random = function (self, type)
      if IsIndoors() then return end

      local meta = getmetatable(self)
      local mountTypeID = meta.lookup[type]

      local mountID, name
      local max = #meta.types[mountTypeID]
      local canUse = false
      local randomIndex = math.random(max)
      for i = randomIndex, randomIndex + max do
        local index = i % max
        mountID, name = unpack(meta.types[mountTypeID][index])
        local name, spellID, icon, isActive, isUsable, sourceType, isFavorite, isFactionSpecific, faction, shouldHideOnChar, isCollected, mountID = C_MountJournal.GetMountInfoByID(mountID)
        canUse = isUsable and meta:isMountUsable(isFactionSpecific, faction)
        if canUse then break end
      end
      if not canUse then return end

      print(format("summoning %s (%s)", name, type))
      C_MountJournal.SummonByID(mountID)
    end
  },
  __call = function (self, mountTypeID, mountID, name)
    local meta = getmetatable(self)
    if not meta.types[mountTypeID] then return end
    if self[mountID] then return end

    self[mountID] = mountID
    table.insert(meta.types[mountTypeID], { mountID, name })
  end
}
local mounts = setmetatable({}, mountsMeta)

local function readMounts()
  if mounts.scanned then return end

  local any = false
  for _, mountID in ipairs(C_MountJournal.GetMountIDs()) do
    local name, spellID, icon, isActive, isUsable, sourceType, isFavorite, isFactionSpecific, faction, shouldHideOnChar, isCollected, mountID, isForDragonriding = C_MountJournal.GetMountInfoByID(mountID)
    if isCollected then
      local creatureDisplayInfoID, description, source, isSelfMount, mountTypeID, uiModelSceneID, animID, spellVisualKitID, disablePlayerMountPreview = C_MountJournal.GetMountInfoExtraByID(mountID)
      mounts(mountTypeID, mountID, name)
      any = true
    end
  end
  mounts.scanned = any
end

function f:ADDON_LOADED(event, addOnName)
  if addOnName == myAddonName then
    print(format("Hello %s! Mounts.lua loaded.", UnitName("player")))
    readMounts()
  end
end

function f:MOUNT_JOURNAL_USABILITY_CHANGED(event)
  readMounts()
end

SLASH_AU_MOUNT1 = "/aumount"

SlashCmdList["AU_MOUNT"] = function (message, editBox)
  readMounts()

  print(format("IsAltKeyDown() = %s, IsShiftKeyDown() = %s", tostring(IsAltKeyDown()), tostring(IsShiftKeyDown())))
  if message == "info" then
    mounts:debug()
  elseif IsAltKeyDown() then
    mounts:random("ground")
  elseif IsShiftKeyDown() then
    print("dismount!")
    Dismount()
  elseif mounts:isZoneForDragonriding() then
    mounts:random("df")
  else
    mounts:random("flying")
  end
end

f:RegisterEvent("ADDON_LOADED")
f:RegisterEvent("MOUNT_JOURNAL_USABILITY_CHANGED")
f:SetScript("OnEvent", f.OnEvent)
