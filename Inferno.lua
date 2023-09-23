local myAddonName, ns = ...

local function isActive()
  return ns.AddonOptions.db.inferno.active
end

local function isDebug()
  return ns.AddonOptions.db.inferno.debug
end

local function debugPrint(message)
  if not isDebug() then return end

  print(message)
end

local f = CreateFrame("Frame")

function f:OnEvent(event, ...)
  if not isActive() then return end

  ns.wrap(self[event], self, event, ...)
end

function f:ADDON_LOADED(event, addOnName)
  if addOnName == myAddonName then
    print(format("Hello %s! Inferno.lua loaded.", UnitName("player")))
  end
end

local function isInfernoSpawned()
  if GetRealZoneText() ~= "Ashran" then return false end

  local mapID = C_Map.GetBestMapForUnit("player")
  for _, areaPoiID in ipairs(C_AreaPoiInfo.GetAreaPOIForMap(mapID)) do
    if areaPoiID == 6493 then return true end
  end

  return false
end

-- /dump C_AreaPoiInfo.GetAreaPOIInfo(1478, 6493)


-- just make text appear mid-screen, like a raid warning
-- no sound, no icons
local function makeLocalRaidwarning(text)
  RaidNotice_AddMessage(RaidWarningFrame, text, ChatTypeInfo["RAID_WARNING"])
end

local function announceInferno()
  if UnitInBattleground("player") and GetBattlefieldInstanceExpiration() == 0 then
    makeLocalRaidwarning("ancient inferno spawned")
    SendChatMessage("{rt8} ancient inferno spawned", "INSTANCE_CHAT")
  end
end

local ashran = { inferno = false }

function f:ZONE_CHANGED_NEW_AREA()
  if GetRealZoneText() == "Ashran" then
    debugPrint(format("inferno spawned? %s", tostring(isInfernoSpawned())))
  else
    ashran.inferno = false
  end
end

function f:AREA_POIS_UPDATED()
  if GetRealZoneText() ~= "Ashran" then return end

  local b = isInfernoSpawned()
  -- you can see the moment of inferno death, will be true (is up) flip to false (dead)
  debugPrint(format("AREA_POIS_UPDATED, inferno? %s", tostring(b)))
  if b and not ashran.inferno then
    announceInferno()
    ashran.inferno = true
  elseif not b and ashran.inferno then
    ashran.inferno = false
  end
end

function f:PVP_MATCH_COMPLETE(event, _winner, _duration)
  ashran.inferno = false
end

SLASH_AU_AA1 = "/auaa"

SlashCmdList["AU_AA"] = function (message, _editBox)
  ns.wrap(function ()
    local b = isInfernoSpawned()
    print(format("inferno spawned? %s ashran.inferno = %s", tostring(b), tostring(ashran.inferno)))
  end)
end

f:RegisterEvent("ADDON_LOADED")
f:RegisterEvent("AREA_POIS_UPDATED")
f:RegisterEvent("PVP_MATCH_COMPLETE")
f:RegisterEvent("ZONE_CHANGED_NEW_AREA")
f:SetScript("OnEvent", f.OnEvent)
