local myAddonName, ns = ...

local function isActive()
  return ns.AddonOptions.db.auras.active
end

local function isDebug()
  return ns.AddonOptions.db.auras.debug
end

local function debugPrint(message)
  if not isDebug() then return end

  print(message)
end

local f = CreateFrame("Frame")

function f:ADDON_LOADED(event, addOnName)
  if addOnName == myAddonName then
    print(format("Hello %s! Auras.lua loaded.", UnitName("player")))
  end
end

f.watchPlayers = function ()
  f:RegisterUnitEvent("UNIT_AURA", "player", "raid1")
  -- local aura = C_UnitAuras.GetAuraDataByAuraInstanceID(unit, auraInstanceID)
end

function f:OnEvent(event, ...)
  if not isActive() then return end

  self[event](self, event, ...)
end

local function makeBuff(track, name, channel, banner, itemID)
  return { track = track, name = name, channel = channel or "SAY", banner = banner or false, itemID = itemID }
end

local buffs = { --[383648] = makeBuff(false, "Erdschild"),
                [274834] = makeBuff(false, "phalanx", nil, true),
                [28418] = makeBuff(true, "General's Warcry 10 %", nil, true),
                [28419] = makeBuff(true, "General's Warcry 20 %", nil, true),
                [28420] = makeBuff(true, "General's Warcry 30 %", nil, true),
                [171250] = makeBuff(true, "scroll of speed", nil, false, 116410),
                [388035] = makeBuff(false, "Fortitude of the Bear"),
                [171249] = makeBuff(true, "prot", "INSTANCE_CHAT", false, 116411),
                [357650] = makeBuff(false, "mini BL"),
                [157504] = makeBuff(false, "cloudburst totem"),
                --[197916] = { false, "Lebenszyklus (Beleben)" },
                --[197919] = { false, "Lebenszyklus (Einhüllender Nebel)" },
                --[164273] = makeBuff(false, "Einsamer Wolf"),
                --[2645] = { false, "Geisterwolf" },
                [61295] = makeBuff(false, "Springflut", nil, false, 116411)
}
local function makeOnceExpiration(id, after, total)
  local expiration = { expires = expires, type = "once" }
  local function callback()
    local aura = C_UnitAuras.GetPlayerAuraBySpellID(id)
    if not aura then return end

    -- DevTools_Dump(aura)
    local collected = (aura.points[1] or 0) / 1000
    local message = format("%s in %d seconds! %d k healing", aura.name, total - after, collected)
    RaidNotice_AddMessage(RaidWarningFrame, message, ChatTypeInfo["RAID_WARNING"])
    PlaySound(8959)
    C_Timer.NewTicker(1, function (timer)
      local aura = C_UnitAuras.GetPlayerAuraBySpellID(id)
      if not aura then
        timer:Cancel()
        return
      end

      local collected = (aura.points[1] or 0) / 1000
      local message = format("%s! %d k healing", aura.name, collected)
      RaidNotice_AddMessage(RaidWarningFrame, message, ChatTypeInfo["RAID_WARNING"])
      print(message)
    end, total - after)
  end
  expiration.makeCallback = function ()
    C_Timer.After(after, callback)
  end

  return expiration
end

local function makeRepeatingExpiration(id, after, announce)
  local expiration = { expires = expires, type = "countdown" }
  local function callback()
    local aura = C_UnitAuras.GetPlayerAuraBySpellID(id)
    if not aura then return end

    local seconds = aura.expirationTime - GetTime()
    local message = format("%s for %d more seconds", GetSpellLink(id), seconds)
    if announce and UnitInBattleground("player") then
      SendChatMessage(message, "SAY")
    end
    debugPrint("LOCAL: "..message)
    expiration.makeCallback()
  end
  expiration.makeCallback = function ()
    C_Timer.After(after, callback)
  end

  return expiration
end

local function makeDecreasingStatusBar(id, name)
  local expiration = {}
  expiration.makeCallback = function (auraData)
    print("in makeDeacreasingStatusBar")
    local maxValue = auraData.expirationTime - GetTime()
    local name = name or auraData.name
    local statusBar = _G["DecreasingStatusBar"] or CreateFrame("StatusBar", "DecreasingStatusBar", UIParent)
    statusBar:SetPoint("CENTER", 0, -30)
    statusBar:SetReverseFill(true)
    statusBar:SetSize(100, 30)
    statusBar:SetMinMaxValues(0, maxValue)
    statusBar.texture = statusBar.texture or statusBar:CreateTexture()
    statusBar.texture:SetColorTexture(255 / 255, 215 / 255, 0, 0.75)
    statusBar:SetStatusBarTexture(statusBar.texture)
    statusBar:SetValue(maxValue)
    statusBar.fs = statusBar.fs or statusBar:CreateFontString(nil, "OVERLAY", "GameTooltipText")
    statusBar.fs:SetPoint("CENTER")
    statusBar.fs:SetText(format("%s: %d s left", name, maxValue))

    local function callback(timer)
      local aura = C_UnitAuras.GetPlayerAuraBySpellID(id)
      if not aura then
        statusBar:Hide()
        timer:Cancel()
        return
      end

      local remainingTime = math.floor(aura.expirationTime - GetTime())
      statusBar.fs:SetText(format("%s: %d s left", name, remainingTime))
      statusBar:SetValue(remainingTime)
    end

    local statusMin, statusMax = statusBar:GetMinMaxValues()
    print(format("statusMin = %d, statusMax = %d", statusMin, statusMax))
    statusBar:Show()
    C_Timer.NewTicker(1, callback)
  end

  return expiration
end

local CloudburstHealing = "CloudburstHealing"
local cbFormatString = "%d k heal"

local function makeStatusBar(id)
  local expiration = {}
  expiration.makeCallback = function (auraData)
    local statusBar = _G[CloudburstHealing] or CreateFrame("StatusBar", CloudburstHealing, UIParent)
    -- statusBar:SetBackdrop(BACKDROP_ACHIEVEMENTS_0_64) BackdropTemplate , "AnimatedStatusBarTemplate"
    statusBar:SetPoint("CENTER")
    statusBar:SetSize(100, 30)
    statusBar:SetMinMaxValues(0, 500)
    --statusBar:SetStatusBarTexture("Interface\\TARGETINGFRAME\\UI-StatusBar")
    local statusMin, statusMax = statusBar:GetMinMaxValues()
    print(format("statusMin = %d, statusMax = %d", statusMin, statusMax))
    statusBar.fs = statusBar.fs or statusBar:CreateFontString(nil, "OVERLAY", "GameTooltipText")
    statusBar.fs:SetPoint("CENTER")
    statusBar.fs:SetText(format(cbFormatString, 0))

    statusBar.texture = statusBar.texture or statusBar:CreateTexture()
    -- statusBar.texture:SetAllPoints()
    statusBar.texture:SetColorTexture(127 / 255, 255 / 255, 0, 0.75)
    statusBar:SetStatusBarTexture(statusBar.texture)
    statusBar:SetValue(0)

    local function callback(timer)
      local aura = C_UnitAuras.GetPlayerAuraBySpellID(id)
      if not aura then
        statusBar:Hide()
        timer:Cancel()
        return
      end
      statusBar:Show()
  
      local collected = math.floor((aura.points[1] or 0) / 1000)
      statusBar:SetValue(collected)
      statusBar.fs:SetText(format(cbFormatString, collected))
    end

    C_Timer.NewTicker(1, callback)
  end

  return expiration
end

local expirations = {
  -- cloudburst
  [157504] = { makeOnceExpiration(157504, 10, 15), makeStatusBar(157504) },
  -- Springflut
  [61295] = { makeDecreasingStatusBar(61295) },
  -- prot
  [171249] = { makeDecreasingStatusBar(171249, "prot") },
  -- speed
  [171250] = { makeRepeatingExpiration(171250, 5, not true) }
}
local aurasMeta = {
  __index = function (self, auraInstanceID)
    return self.store[auraInstanceID]
  end,
  __newindex = function (self, auraInstanceID, pair)
    self.store[auraInstanceID] = self.store[auraInstanceID] or {}
    table.insert(self.store[auraInstanceID], pair)
  end,
  __call = function (self, auraInstanceID)
    return table.remove(self.store[auraInstanceID], 1)
  end
}
local auras = setmetatable({ store = {}, debug = false }, aurasMeta)

-- /auaura
SLASH_AU_AURA1 = "/auau"

SlashCmdList["AU_AURA"] = function (message, _editBox)
  if message == "off" then
    AshranUtilitiesDB.auras.active = false
  elseif message == "on" then
    AshranUtilitiesDB.auras.active = true
  end
  print(format("Aura tracking active? %s", tostring(AshranUtilitiesDB.auras.active)))
end

local function debugAura(unitTarget, auraData)
  print(format("LOCAL: %s start, target = %s, source = %s, spellId = %s, auraInstanceID = %s", auraData.name, UnitName(unitTarget), auraData.sourceUnit, auraData.spellId, auraData.auraInstanceID))
end

function f:UNIT_AURA(event, unitTarget, updateInfo)
  if not updateInfo then return end
  if updateInfo.isFullUpdate then return end

  if updateInfo.addedAuras and next(updateInfo.addedAuras) then
    for _, auraData in ipairs(updateInfo.addedAuras) do
      if auras.debug then debugAura(unitTarget, auraData) end

      local buff = buffs[auraData.spellId]
      if buff then
        local source = UnitName(auraData.sourceUnit)
        if buff.banner then source = 'banner' end
        auras[auraData.auraInstanceID] = { source, buff }

        local message = format("%s used %s", source, buff.name)
        if buff.track and UnitInBattleground("player") then
          local message = format("{rt4} %s", message)
          if buff.itemID then
            message = format("%s (%s)", message, (select(2, GetItemInfo(buff.itemID))))
          end

          if unitTarget == "player" then
            SendChatMessage(message, buff.channel)
          else
            local message = format("%s on %s (%s)", message, UnitName(unitTarget), unitTarget)
            local name, server = UnitName(unitTarget)
            SendChatMessage(message, "SAY")
            debugPrint("LOCAL: "..message)
          end
        end

        debugPrint(format("LOCAL: %s, track? %s", message, tostring(buff.track)))
      end

      local list = expirations[auraData.spellId]
      if list then
        for _, expiration in ipairs(list) do
          expiration.makeCallback(auraData)
        end
      end
    end
  end
 
  if updateInfo.updatedAuraInstanceIDs and next(updateInfo.updatedAuraInstanceIDs) then
    for _, auraInstanceID in ipairs(updateInfo.updatedAuraInstanceIDs) do
    end
  end
 
  if updateInfo.removedAuraInstanceIDs and next(updateInfo.removedAuraInstanceIDs) then
    for _, auraInstanceID in ipairs(updateInfo.removedAuraInstanceIDs) do
      if auras[auraInstanceID] then
        -- using __call
        local source, buff = unpack(auras(auraInstanceID))
        if not source or not buff then return end

        if buff.track and not buff.banner and UnitInBattleground("player") then
          if unitTarget == "player" then
            SendChatMessage(format("{rt7} %s expired", buff.name), buff.channel)
          else
            local message = format("%s on %s (%s)", message, UnitName(unitTarget), unitTarget)
            local name, server = UnitName(unitTarget)
            SendChatMessage(message, "SAY")
            debugPrint("LOCAL: "..message)
          end
        end
        debugPrint(format("LOCAL: %s by %s expired", buff.name, source))
      end
    end
  end
end

function f:PLAYER_ENTERING_BATTLEGROUND()
  debugPrint(format("entering battleground %s", GetRealZoneText()))
  f.watchPlayers()
end

f:RegisterEvent("ADDON_LOADED")
--f:RegisterEvent("UNIT_AURA")
f:RegisterEvent("PLAYER_ENTERING_BATTLEGROUND")
f.watchPlayers()
f:SetScript("OnEvent", f.OnEvent)
