local f = CreateFrame("Frame")

function f:OnEvent(event, ...)
	self[event](self, event, ...)
end

function f:ADDON_LOADED(event, addOnName)
  if addOnName == "AshranUtils" then
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

local function makeText(text)
  RaidNotice_AddMessage(RaidWarningFrame, text, ChatTypeInfo["RAID_WARNING"])
end

local function announceInferno()
  if UnitInBattleground("player") and GetBattlefieldInstanceExpiration() == 0 then
    makeText("ancient inferno spawned")
    -- INSTANCE_CHAT, RAID, PARTY, SAY (but then no icons)
    -- (id: 6493, event: AREA_POIS_UPDATED, skull on map)
    --SendChatMessage("{rt8} ancient inferno spawned", "INSTANCE_CHAT")
    SendChatMessage("{rt8} ancient inferno spawned", "INSTANCE_CHAT")
  end
end

local ashran = { inferno = false }

function f:ZONE_CHANGED_NEW_AREA()
  -- print(format("entered zone %s", GetRealZoneText()))

  if GetRealZoneText() == "Ashran" then
    print(format("inferno spawned? %s", tostring(isInfernoSpawned())))
  else
    ashran.inferno = false
  end
end

function f:AREA_POIS_UPDATED()
  if GetRealZoneText() ~= "Ashran" then return end

  local b = isInfernoSpawned()
  -- you can see the moment of inferno death, will be true (is up) flip to false (dead)
  print(format("AREA_POIS_UPDATED, inferno? %s", tostring(b)))
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
  local b = isInfernoSpawned()
  print(format("inferno? %s", tostring(b)))
end

f:RegisterEvent("ADDON_LOADED")
f:RegisterEvent("AREA_POIS_UPDATED")
f:RegisterEvent("PVP_MATCH_COMPLETE")
f:RegisterEvent("ZONE_CHANGED_NEW_AREA")
f:SetScript("OnEvent", f.OnEvent)
