WFCShamanFrame = CreateFrame("Frame", "WFCShamanFrame", UIParent)

local COMM_PREFIX = "WF_STATUS"
local COMM_PREFIX_CREDIT = "WF_CREDIT"
C_ChatInfo.RegisterAddonMessagePrefix(COMM_PREFIX)

local classIcon = {
    ["WARRIOR"] = "Interface\\Icons\\inv_sword_27",
    ["PALADIN"] = "Interface\\Icons\\ability_thunderbolt",
    -- ["HUNTER"] = "Interface\\Icons\\inv_weapon_bow_07",
    ["ROGUE"] = "Interface\\Icons\\inv_throwingknife_04",
}

-- https://wowwiki-archive.fandom.com/wiki/EnchantId/Enchant_IDs
local spellTable = { [2639] = 'WF5', [2638] = 'WF4', [564] = 'WF3', [563] = 'WF2', [1783] = 'WF1' }

local function GetPartySig()
    local sig = ""
    for index = 1, 4 do
        local pstring = "party" .. index
        local guid = UnitGUID(pstring)
        if guid then
            sig = sig..UnitGUID(pstring)
        end
    end
    return sig
end

function WFCShamanFrame:Init() -- initialize the frames on screen
    self.icons, self.guids, self.currentTimers, self.buttons = {}, {}, {}, {}
    self.ixs, self.party, self.class, self.partyIndex = {}, {}, {}, {}

    self:SetPoint("CENTER", UIParent, 0, -225)
    self:EnableMouse(true)
    self:SetMovable(true)
    self:RegisterForDrag("LeftButton")
    self:SetScript("OnDragStart", function(self)
        if not wfcdbc.locked then
            WFCShamanFrame:StartMoving()
        end
    end)
    self:SetScript("OnDragStop", self.StopMovingOrSizing)
    for i = 0, 3 do
        self.buttons[i] = CreateFrame("FRAME", nil, UIParent)
        self.buttons[i].bg = self.buttons[i]:CreateTexture(nil, "BACKGROUND")
        self.buttons[i].bg:SetColorTexture(1, 0, 0)
        self.buttons[i].bg:Hide()
        self.buttons[i].cd = CreateFrame("COOLDOWN", nil, self.buttons[i], "CooldownFrameTemplate")
        self.buttons[i].cd:SetDrawBling(false)
        self.buttons[i].cd:SetDrawEdge(false)
        self.buttons[i].name = self.buttons[i]:CreateFontString(nil, "ARTWORK")
        self.buttons[i].name:SetFont("Fonts\\FRIZQT__.ttf", 9, "OUTLINE")
        self.buttons[i].icon = self.buttons[i]:CreateTexture(nil, "ARTWORK")
        self.buttons[i].icon:SetTexture("Interface\\Icons\\Spell_nature_cyclone")
        self.buttons[i].icon:SetDesaturated(1)
        self.buttons[i].icon:SetAlpha(0.5)
        self.buttons[i]:Hide() -- hide buttons until group is joined
    end
    self:Hide() -- hide frame until group is joined
    self:ModLayout()
end

function WFCShamanFrame:ResetPos()
    wfc.out("Resetting position")
    self:ClearAllPoints()
    self:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 100, -100)
end

function WFCShamanFrame:ModLayout()
    local warnsize, size, space, xspace, yspace = wfcdb.warnsize or 4, wfcdb.size or 37, wfcdb.space or 4, wfcdb.xspace or 1, wfcdb.yspace or 0
    local xsize = size + (size + space) * xspace * 3
    local ysize = size + (size + space) * yspace * 3
    self:SetSize(xsize, ysize)
    for i = 0, 3 do
        local xpoint, ypoint =
        i * (size + space) * xspace, i * (size + space) * yspace
        self.buttons[i]:SetPoint("TOPLEFT", self, "TOPLEFT", xpoint, ypoint)
        self.buttons[i]:SetSize(size, size)
        self.buttons[i].name:SetPoint("CENTER", self.buttons[i], "TOP", 0, 5)
        self.buttons[i].bg:SetSize(size + warnsize * 2, size + warnsize * 2)
        self.buttons[i].bg:SetPoint("TOPLEFT", self, "TOPLEFT", xpoint - warnsize, -ypoint + warnsize)
        self.buttons[i].icon:SetSize(size, size)
        self.buttons[i].icon:SetPoint("TOPLEFT", self, "TOPLEFT", xpoint, -ypoint)
        if warnsize == 0 then
            self.buttons[i].bg:Hide()
        end
    end
end

function WFCShamanFrame:SetSpacing(x)
    wfcdb.space = tonumber(x)
    self:ModLayout()
end

function WFCShamanFrame:SetScale(x)
    wfcdb.size = tonumber(x)
    self:ModLayout()
end

function WFCShamanFrame:SetWarnSize(x)
    wfcdb.warnsize = tonumber(x)
    self:ModLayout()
end

function WFCShamanFrame:FlipLayout()
    if arg2 == "horizontal" then
        wfcdb.yspace = 0
        wfcdb.xspace = 1
        self:ModLayout()
    elseif arg2 == "vertical" then
        wfcdb.yspace = 1
        wfcdb.xspace = 0
        self:ModLayout()
    end
end

function WFCShamanFrame:CollectGroupInfo()
    self:Show() -- group joined, show frame
    wipe(self.ixs)
    wipe(self.partyIndex)
    wipe(wfc.partyVersion)
    local j = -1
    for index = 1, 4 do
        local pstring = "party" .. index
        local gclass = select(2, UnitClass(pstring))
        self.buttons[index - 1]:Show() -- group joined, show buttons
        if classIcon[gclass] then
            local name = wfc:GetFullName(pstring)
            local gGUID, color = UnitGUID(pstring), RAID_CLASS_COLORS[gclass]
            j = j + 1
            self.partyIndex[name] = index
            self.ixs[gGUID], self.party[gGUID], self.class[gGUID], self.guids[j] = j, pstring, gclass, gGUID
            self.buttons[j].name:SetText(strsub(name, 1, 5))
            self.buttons[j].name:SetTextColor(color.r, color.g, color.b)
            self.buttons[j].icon:SetTexture(classIcon[gclass])
            self.buttons[j].icon:SetDesaturated(1)
            self.buttons[j].icon:SetAlpha(0.5)
            self.buttons[j].bg:Hide()
        end
    end
    j = nil
end

function WFCShamanFrame:ResetGroup()
    for j = 0, 3 do
        self.buttons[j].name:SetText("")
        self.buttons[j].cd:SetCooldown(0, 0)
        self.buttons[j].icon:SetTexture("Interface\\ICONS\\Spell_nature_cyclone")
        self.buttons[j].icon:SetDesaturated(1)
        self.buttons[j].icon:SetAlpha(0.5)
        self.buttons[j].bg:Hide()
        self.buttons[j]:Hide() -- group reset, hide buttons
    end
    self:Hide() -- group reset, hide frame
end

function WFCShamanFrame:StartTimerButton(gGUID, remain)
    local icon = self.icons[gGUID]
    if remain > 0 and self.ixs[gGUID] then
        local j = self.ixs[gGUID]
        self.buttons[j].icon:SetDesaturated(nil)
        self.buttons[j].icon:SetAlpha(1)
        self.buttons[j].cd:SetCooldown(GetTime() - (10 - remain), 10)
        self.buttons[j].bg:Hide()
        self.icons[j] = icon
    end
end

function WFCShamanFrame:SetBlockerButton(gGUID, remain, spellID)
    local _, _, icon, _, _, _, _ = GetSpellInfo(spellID)

    if remain > 0 and self.ixs[gGUID] then
        local j = self.ixs[gGUID]
        self.buttons[j].icon:SetTexture(icon)
        self.buttons[j].icon:SetDesaturated(1)
        self.buttons[j].icon:SetAlpha(1)
        self.buttons[j].cd:SetCooldown(GetTime(), remain)
        self.icons[j] = icon
    end
end

function WFCShamanFrame:PartyPlayerDead(playerIndex)
    self.buttons[playerIndex].icon:SetAlpha(1)
    self.buttons[playerIndex].icon:SetDesaturated(1)
    self.buttons[playerIndex].cd:SetCooldown(0, 0)
    self.buttons[playerIndex].bg:SetAlpha(0)
end

function WFCShamanFrame:ShowWarning(playerIndex, combat)
    self.buttons[playerIndex].icon:SetAlpha(1)
    self.buttons[playerIndex].icon:SetDesaturated(1)
    self.buttons[playerIndex].cd:SetCooldown(0, 0)
    if combat == "0" then
        self.buttons[playerIndex].bg:SetAlpha(0.2)
        self.buttons[playerIndex].bg:SetColorTexture(1, 1, 0)
    else
        self.buttons[playerIndex].bg:SetAlpha(1)
        self.buttons[playerIndex].bg:SetColorTexture(1, 0, 0)
    end
    if wfcdb.warnsize then
        self.buttons[playerIndex].bg:Show()
    end
end

function WFCShamanFrame:UpdateCurrentTimers()
    wipe(self.currentTimers)
    for j = 0, 3 do
        if self.guids[j] then
            gGUID = self.guids[j]
            self.currentTimers[gGUID] = self.buttons[j].cd:GetCooldownDuration() / 1000
        end
    end
end

function WFCShamanFrame:RestartCurrentTimers()
    for gGUID, j in pairs(self.ixs) do
        if self.currentTimers[gGUID] then
            self:StartTimerButton(gGUID, self.currentTimers[gGUID], self.icons[gGUID])
        end
    end
    wipe(self.currentTimers)
end

function WFCShamanFrame:ShowUI()
    self:Show()
    for i = 0, 3 do
        self.buttons[i]:Show()
    end
end

function WFCShamanFrame:HideUI()
    self:Hide()
    for i = 0, 3 do
        self.buttons[i]:Hide()
    end
end

-- Message Handlers ------------------------------------------------------

function WFCShamanFrame:OnWfRefreshMessage(prefix, message, channel, sender)
    local gGUID, spellID, expiration, lag, combat, isdead, version = strsplit(":", message)
    local playerIndex = self.ixs[gGUID]
    if not playerIndex then
        return
    end
    spellID, expiration, lagHome = tonumber(spellID), tonumber(expiration), tonumber(lagHome)
    local spellName = spellTable[spellID]

    if wfcdb.debugStatus then
        wfc.debug('|c99ff9900'..channel..'|r', '|cffdddddd'..prefix..'|r', '|cff99ff00'..sender..'|r', spellName or spellID or '-', 't'..(expiration and expiration / 1000 or '-'), 'c'..tostring(combat or "-"), 'd'..tostring(isdead or "-"), 'v'..(version or "-"))
    end
    wfc.partyVersion[sender] = version or "-"

    if isdead == "1" then
        self:PartyPlayerDead(playerIndex)
    elseif spellName ~= nil then -- update buffs
        local _, _, lagHome, _ = GetNetStats()
        local remain = (expiration - (lag + lagHome)) / 1000
        self:StartTimerButton(gGUID, remain)
    else -- addon installed or buff expired
        self:ShowWarning(playerIndex, combat)
    end
end

function WFCShamanFrame:OnWfCreditMessage(prefix, message, channel, sender)
    if wfcdb.printCredit then
        local index = self.partyIndex[sender]
        if index and index > 0 then
            local combatTime, wfTime, shaman, strTime, agiTime, frTime, frrTime, gndTime = strsplit(":", message)
            combatTime, agiTime, frTime, frrTime, gndTime = tonumber(combatTime), tonumber(agiTime or '0'), tonumber(frTime or '0'), tonumber(frrTime or '0'), tonumber(gndTime or '0')
            local stats = "|cff00bbffWF|r:"..WFCMeleeFrame:UptimeTextSeconds(tonumber(wfTime), combatTime)
            stats = stats.." |cff00bbffSTR|r:"..WFCMeleeFrame:UptimeTextSeconds(tonumber(strTime), combatTime)
            if agiTime > 0 then
                stats = stats.." |cff00bbffAGI|r:"..WFCMeleeFrame:UptimeTextSeconds(agiTime, combatTime)
            end
            if frTime > 0 then
                stats = stats.." |cff00bbffFR|r:"..WFCMeleeFrame:UptimeTextSeconds(frTime, combatTime)
            end
            if frrTime > 0 then
                stats = stats.." |cff00bbffFrR|r:"..WFCMeleeFrame:UptimeTextSeconds(frrTime, combatTime)
            end
            if gndTime > 0 then
                stats = stats.." |cff00bbffGND|r:"..WFCMeleeFrame:UptimeTextSeconds(gndTime, combatTime)
            end
            local strippedName = select(1, strsplit("-", sender))
            local className = self.class[self.guids[index-1] or ''] or "WARRIOR"
            local colorName = "|c"..RAID_CLASS_COLORS[className].colorStr..strippedName.."|r"
            wfc.out(colorName, stats)
            --WFCMeleeFrame:UptimeReport(tonumber(combatTime), tonumber(wfTime), shaman, tonumber(strTime), tonumber(agiTime), tonumber(frTime), tonumber(frrTime), tonumber(gndTime), sender, "FINAL")
        end
    end
end

-- Event Handlers ------------------------------------------------------

function WFCShamanFrame:GROUP_ROSTER_UPDATE()
    if GetNumGroupMembers() == 0 then
        self:ResetGroup()
    else
        local partySig = GetPartySig()
        if partySig ~= self.partySig then
            self:UpdateCurrentTimers()
            self:ResetGroup()
            self:CollectGroupInfo()
            self:RestartCurrentTimers()
            self.partySig = partySig
        end
    end
end

function WFCShamanFrame:CHAT_MSG_ADDON(prefix, message, channel, sender)
    if prefix == COMM_PREFIX then
        self:OnWfRefreshMessage(prefix, message, channel, sender)
    elseif prefix == COMM_PREFIX_CREDIT then
        self:OnWfCreditMessage(prefix, message, channel, sender)
    end
end
