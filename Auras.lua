local myAddonName, ns = ...

local function isActive()
  return ns.AddonOptions.db.auras.active
end

local function isDebug()
  return ns.AddonOptions.db.auras.debug
end

local function isExpirationsActive()
  return ns.AddonOptions.db.auras.expirations
end

local function debugPrint(message, ...)
  if not isDebug() then return end

  ns.print("Auras.Debug: "..message, ...)
end

local f = CreateFrame("Frame")

function f:ADDON_LOADED(event, addOnName)
  if addOnName == myAddonName then
    ns.print("Auras.lua loaded.")
  end
end

f.watchPlayers = function ()
  f:RegisterUnitEvent("UNIT_AURA", "player")
  -- local aura = C_UnitAuras.GetAuraDataByAuraInstanceID(unit, auraInstanceID)
end

function f:OnEvent(event, ...)
  if not isActive() then return end

  ns.wrap(self[event], self, event, ...)
end

local function makeBuff(track, name, channel, itemID)
  return { track = track, name = name, channel = channel or "SAY", itemID = itemID }
end

local buffs = { --[383648] = makeBuff(false, "Erdschild"),
                [274834] = makeBuff(false, "phalanx"),
                [28418] = makeBuff(true, "General's Warcry 10 %"),
                [28419] = makeBuff(true, "General's Warcry 20 %"),
                [28420] = makeBuff(true, "General's Warcry 30 %"),
                [171250] = makeBuff(true, "scroll of speed", nil, 116410),
                [388035] = makeBuff(false, "Fortitude of the Bear"),
                [171249] = makeBuff(true, "prot", "INSTANCE_CHAT", 116411),
                [357650] = makeBuff(false, "mini BL"),
                [157504] = makeBuff(false, "cloudburst totem"),
                [197916] = makeBuff(false, "Lebenszyklus (Beleben)"),
                [197919] = makeBuff(false, "Lebenszyklus (Einhüllender Nebel)"),
                [193534] = makeBuff(false, "Beständiger Fokus"),
                [260242] = makeBuff(false, "Präzise Schüsse"),
                --[164273] = makeBuff(false, "Einsamer Wolf"),
                --[2645] = { false, "Geisterwolf" },
                [61295] = makeBuff(false, "Springflut", nil)
}

function ns.rgb(r, g, b, a)
  return r / 255, g / 255, b / 255, a or 1.0
end

local function makeOnceExpiration(id, after, total)
  local expiration = {}
  local function callback()
    local aura = C_UnitAuras.GetPlayerAuraBySpellID(id)
    if not aura then return end

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
    end, total - after)
  end
  expiration.makeCallback = function ()
    C_Timer.After(after, callback)
  end

  return expiration
end

local function makeRepeatingExpiration(id, after, announce)
  local expiration = {}
  local function callback()
    local aura = C_UnitAuras.GetPlayerAuraBySpellID(id)
    if not aura then return end

    local seconds = aura.expirationTime - GetTime()
    local message = format("%s for %d more seconds", GetSpellLink(id), seconds)
    if announce and UnitInBattleground("player") then
      SendChatMessage(message, "SAY")
    end
    expiration.makeCallback()
  end
  expiration.makeCallback = function ()
    C_Timer.After(after, callback)
  end

  return expiration
end

local function makeDecreasingStatusBar(id, name, offset)
  local expiration = {}
  local formatString = "%s: %.1f s left"
  local alpha = 1.0
  local offset = offset or 0

  expiration.makeCallback = function (auraData, index)
    local remainingTime = auraData.expirationTime - GetTime()
    local maxValue = remainingTime * 10
    local name = name or auraData.name

    local frameId = "DecreasingStatusBar"..id
    local statusBar = _G[frameId] or CreateFrame("StatusBar", frameId, UIParent)
    statusBar:SetPoint("CENTER", 0, -30 + offset)
    -- statusBar:SetReverseFill(not true)
    statusBar:SetSize(100, 30)
    statusBar:SetMinMaxValues(0, maxValue)

    statusBar.texture = statusBar.texture or statusBar:CreateTexture()
    statusBar.texture:SetColorTexture(ns.rgb(0, 217, 255, alpha))
    statusBar:SetStatusBarTexture(statusBar.texture)

    statusBar:SetValue(maxValue)

    statusBar.fs = statusBar.fs or statusBar:CreateFontString(nil, "OVERLAY", "GameTooltipText")
    statusBar.fs:SetPoint("CENTER")
    statusBar.fs:SetText(format(formatString, name, remainingTime))

    local icon = select(8, GetSpellInfo(id))
    statusBar.icon = statusBar.icon or statusBar:CreateTexture()
    statusBar.icon:SetTexture(icon)
    statusBar.icon:SetPoint("LEFT", -30, 0)
    statusBar.icon:SetSize(30, 30)
    statusBar.icon:SetAlpha(alpha)

    local function callback(timer)
      local aura = C_UnitAuras.GetPlayerAuraBySpellID(id)
      if not aura then
        statusBar:Hide()
        timer:Cancel()
        return
      end
      statusBar:Show()

      local remainingTime = aura.expirationTime - GetTime()
      statusBar.fs:SetText(format(formatString, name, remainingTime))
      statusBar:SetValue(remainingTime * 10)
    end

    statusBar:Show()
    C_Timer.NewTicker(0.05, callback)
  end

  return expiration
end

local function makeStatusBar(id)
  local expiration = {}
  local formatString = "%d k heal"
  local alpha = 1.0
  expiration.makeCallback = function (auraData, index)
    local statusBar = _G["CloudburstHealing"] or CreateFrame("StatusBar", "CloudburstHealing", UIParent)
    -- statusBar:SetBackdrop(BACKDROP_ACHIEVEMENTS_0_64) BackdropTemplate , "AnimatedStatusBarTemplate"
    statusBar:SetPoint("CENTER")
    statusBar:SetSize(100, 30)
    statusBar:SetMinMaxValues(0, 500)

    statusBar.fs = statusBar.fs or statusBar:CreateFontString(nil, "OVERLAY", "GameTooltipText")
    statusBar.fs:SetPoint("CENTER")
    statusBar.fs:SetText(format(formatString, 0))

    statusBar.texture = statusBar.texture or statusBar:CreateTexture()
    statusBar.texture:SetColorTexture(ns.rgb(127, 255, 0, alpha))
    statusBar:SetStatusBarTexture(statusBar.texture)
    statusBar:SetValue(0)

    local icon = select(8, GetSpellInfo(id))
    statusBar.icon = statusBar.icon or statusBar:CreateTexture()
    statusBar.icon:SetTexture(icon)
    statusBar.icon:SetPoint("LEFT", -30, 0)
    statusBar.icon:SetSize(30, 30)
    statusBar.icon:SetAlpha(alpha)

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
      statusBar.fs:SetText(format(formatString, collected))
    end

    statusBar:Show()
    C_Timer.NewTicker(0.5, callback)
  end

  return expiration
end

local function makeMistBar(id, colourAsTable)
  local expiration = {}
  local function extractName(name)
    local name = string.match(name, "%((.+)%)")
    return name
  end
  local formatString = "%s currently!"

  expiration.makeCallback = function (auraData, index)
    local frameId = "MistFrame"..id
    local statusBar = _G[frameId] or CreateFrame("Frame", frameId, UIParent)
    statusBar:SetPoint("CENTER", 0, -60)
    statusBar:SetSize(200, 30)
    statusBar.fs = statusBar.fs or statusBar:CreateFontString(nil, "OVERLAY", "GameTooltipText")
    statusBar.fs:SetPoint("CENTER")
    statusBar.fs:SetText(format(formatString, extractName(auraData.name)))

    statusBar.texture = statusBar.texture or statusBar:CreateTexture()
    statusBar.texture:SetColorTexture(unpack(colourAsTable))
    statusBar.texture:SetAllPoints()

    local function callback(timer)
      local aura = C_UnitAuras.GetPlayerAuraBySpellID(id)
      if not aura then
        statusBar:Hide()
        timer:Cancel()
        return
      end
      statusBar:Show()

      statusBar.fs:SetText(format(formatString, extractName(auraData.name)))
    end

    statusBar:Show()
    C_Timer.NewTicker(1, callback)
  end

  return expiration
end

local expirations = {
  -- Präzise Schüsse
  [260242] = { makeDecreasingStatusBar(260242, "", -60) },
  -- Beständiger Fokus
  [193534] = { makeDecreasingStatusBar(193534, nil, -30) },
  -- cloudburst
  [157504] = { makeOnceExpiration(157504, 10, 15), makeStatusBar(157504) },
  -- Springflut
  -- [61295] = { makeDecreasingStatusBar(61295, nil, -30) },
  -- prot
  [171249] = { makeDecreasingStatusBar(171249, "prot") },
  -- speed
  [171250] = { makeDecreasingStatusBar(171250, "speed") },
  -- Einhüllender Nebel
  [197916] = { makeMistBar(197916, { ns.rgb(0, 255, 94, 0.75) }) },
  -- Beleben
  [197919] = { makeMistBar(197919, { ns.rgb(255, 215, 0, 0.75) }) },
  -- Manatee
  [197908] = { makeDecreasingStatusBar(197908, nil, -30) }
}


local auras = { store = {} }
do
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
  setmetatable(auras, aurasMeta)
end

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
  debugPrint(format("%s start, target = %s, source = %s, spellId = %s, auraInstanceID = %s", auraData.name, UnitName(unitTarget), tostring(auraData.sourceUnit), auraData.spellId, auraData.auraInstanceID))
end

local aurasColour = "eb7cd9"

function f:UNIT_AURA(event, unitTarget, updateInfo)
  if not updateInfo then return end
  if updateInfo.isFullUpdate then return end

  if updateInfo.addedAuras and next(updateInfo.addedAuras) then
    for _, auraData in ipairs(updateInfo.addedAuras) do
      if auras.debug then debugAura(unitTarget, auraData) end

      local buff = buffs[auraData.spellId]
      if buff then
        local source = auraData.sourceUnit and UnitName(auraData.sourceUnit) or format("fail: %s", auraData.name)
        auras[auraData.auraInstanceID] = { source, buff }

        local message = format("%s used %s", source, buff.name)
        -- ns.log("")
        if buff.track and UnitInBattleground("player") then
          local message = format("{rt4} %s", message)
          if buff.itemID then
            message = format("%s (%s)", message, (select(2, GetItemInfo(buff.itemID))))
          end

          if unitTarget == "player" then
            SendChatMessage(message, buff.channel)
          else
            local message = format("%s on %s (%s)", message, UnitName(unitTarget), unitTarget)
            SendChatMessage(message, "SAY")
            debugPrint(message)
          end
        end

        debugPrint(format("%s, track? %s", message, tostring(buff.track)), ns.hex2rgb(aurasColour))
      end

      if isExpirationsActive() then
        local list = expirations[auraData.spellId]
        if list and unitTarget == "player" then
          for index, expiration in ipairs(list) do
            expiration.makeCallback(auraData, index)
          end
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
        local source, buff = unpack(auras(auraInstanceID) or {})
        if not source or not buff then return end

        if buff.track and UnitInBattleground("player") then
          local message = format("{rt7} %s expired", buff.name)
          if unitTarget == "player" then
            SendChatMessage(message, buff.channel)
          else
            message = format("%s on %s (%s)", message, UnitName(unitTarget), unitTarget)
            -- SendChatMessage(message, "SAY")
            debugPrint(message, ns.hex2rgb(aurasColour))
          end
        end

        debugPrint(format("%s by %s expired", buff.name, source), ns.hex2rgb(aurasColour))
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
