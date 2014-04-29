local wm = WINDOW_MANAGER
local em = EVENT_MANAGER
local playerPool, reticlePool, db, _
local pbc = wm:CreateTopLevelWindow("ZAM_BuffDisplayPlayerContainer")
local rbc = wm:CreateTopLevelWindow("ZAM_BuffDisplayReticleoverContainer")
local GetNumBuffs = GetNumBuffs
local GetUnitBuffInfo = GetUnitBuffInfo
local GetBuffColor = GetBuffColor
local GetControl = GetControl
local zo_ceil = zo_ceil
local LAM = LibStub("LibAddonMenu-1.0")
local LMP = LibStub("LibMediaProvider-1.0")

--add option later to display reticle buffs in combat only??  IsUnitInCombat("player")
local defaults = {
    isLocked = true,
    player = {
        anchor = {
            a = TOPLEFT,
            b = TOPLEFT,
            x = 5,
            y = 100,
        },
        growUp = false,
    },
    reticleover = {
        anchor = {
            a = TOPLEFT,
            b = TOP,
            x = 150,
            y = 85,
        },
        growUp = false,
    },
    displayBars = true, --add support for this option
    font = "Arial Narrow",
    barColor = {
        r = .35,
        g = .35,
        b = .35,
        a = 1
    },
}

local function HandleAnchors(buff, buffID, unit)
    buff:ClearAnchors()
    local bc = unit == "player" and pbc or rbc
    local pool = unit == "player" and playerPool or reticlePool
    local anchorBuff = buffID == 1 and bc or pool:AcquireObject(buffID - 1)
    if db[unit].growUp then
        buff:SetAnchor(BOTTOMLEFT, anchorBuff, anchorBuff == bc and BOTTOMLEFT or TOPLEFT)
        buff:SetAnchor(BOTTOMRIGHT, anchorBuff, anchorBuff == bc and BOTTOMRIGHT or TOPRIGHT)
    else
        buff:SetAnchor(TOPLEFT, anchorBuff, anchorBuff == bc and TOPLEFT or BOTTOMLEFT)
        buff:SetAnchor(TOPRIGHT, anchorBuff, anchorBuff == bc and TOPRIGHT or BOTTOMRIGHT)
    end
end

local function SetFonts(buff)
    buff.name:SetFont(LMP:Fetch("font", db.font) .. "|18|soft-shadow-thin")
    buff.time:SetFont(LMP:Fetch("font", db.font) .. "|18|soft-shadow-thin")
end

local function CreateBuff(pool)
    local forPlayer = pool == playerPool
    local buff = ZO_ObjectPool_CreateControl(forPlayer and "ZAM_BuffDisplay_Player" or "ZAM_BuffDisplay_Reticleover", pool, forPlayer and pbc or rbc)
    buff.icon = GetControl(buff, "Icon")
    buff.time = GetControl(buff, "Time")
    buff.name = GetControl(buff, "Name")
    --GetControl(myBuff, "Name"):SetWidth(170)
    buff.bar = GetControl(buff, "Statusbar")
    buff.bar:SetColor(db.barColor.r, db.barColor.g, db.barColor.b, db.barColor.a)
    buff.bar.gloss:SetHidden(true)
    buff.bar:SetHidden(not db.displayBars)
    local buffID = pool.m_NextControlId
    HandleAnchors(buff, buffID, forPlayer and "player" or "reticleover")
    SetFonts(buff)
    buff.timeLastRun = 0
    buff:SetHandler("OnUpdate", function(self, updateTime)
        if (updateTime - self.timeLastRun) >= .5 then
            self.timeLastRun = updateTime
            --if self.endTime == "\195\236" then
            if self.endTime == "--" then
                return
            else
                local timeLeft = (self.endTime - updateTime)
                if timeLeft < 60 then
                    self.time:SetText(zo_ceil(timeLeft) .. "s")
                else
                    self.time:SetText(zo_ceil(timeLeft / 60) .. "m")
                end
            end
        end
    end)
    buff.bar.timeLastRun = 0
    buff.bar:SetHandler("OnUpdate", function(self, updateTime)
        if (updateTime - self.timeLastRun) >= .01 then
            self.timeLastRun = updateTime
            if self.noDur then
                return
            else
                self:SetValue((buff.endTime - updateTime) + self.min)
            end
        end
    end)

    return buff
end

local function RemoveBuff(buffFrame)
    buffFrame:SetHidden(true)
end

local function UpdateBuffs(unit)
    unit = unit or "player"
    local pool = unit == "player" and playerPool or reticlePool
    local numBuffs = GetNumBuffs(unit)
    for i = 1, numBuffs do
        local buffName, timeStarted, timeEnding, buffSlot, stackCount, iconFilename, buffType, effectType, abilityType, statusEffectType = GetUnitBuffInfo(unit, i)
        --try this for duplicate "Mount Up" buffs
        --[[if timeEnding==timeStarted and not longTerm then
            return
        end]]
        local myBuff = pool:AcquireObject(i)
        myBuff.name:SetText(buffName)
        myBuff.name:SetColor(GetBuffColor(effectType):UnpackRGBA())
        --myBuff.bar:SetColor(GetBuffColor(effectType):UnpackRGBA())
        myBuff.icon:SetTexture(iconFilename)
        myBuff:SetHidden(false)
        local noDur = timeStarted == timeEnding
        myBuff.bar.noDur = noDur
        --myBuff.endTime = noDur and "\195\236" or timeEnding
        myBuff.endTime = noDur and "--" or timeEnding
        if noDur then
            myBuff.time:SetText(myBuff.endTime)
        end
        myBuff.bar.min = timeStarted
        myBuff.bar.max = timeEnding
        myBuff.bar:SetMinMax(myBuff.bar.min, myBuff.bar.max)
    end
    local activeBuffs = pool:GetActiveObjectCount()
    if activeBuffs > numBuffs then
        for i = numBuffs + 1, activeBuffs do
            pool:ReleaseObject(i)
        end
    end
end

local function SetUpContainer(unit)
    local bc = unit == "player" and pbc or rbc
    bc:SetDimensions(250, 30)
    local anchors = db[unit].anchor
    bc:SetAnchor(anchors.a, GuiRoot, anchors.b, anchors.x, anchors.y)
    bc:SetDrawLayer(DL_BACKGROUND)
    bc:SetMouseEnabled(true)
    bc:SetMovable(not db.isLocked)
    bc:SetClampedToScreen(true)
    bc:SetHandler("OnReceiveDrag", function(self)
        if not db.isLocked then
            self:StartMoving()
        end
    end)
    bc:SetHandler("OnMouseUp", function(self)
        self:StopMovingOrResizing()
        _, anchors.a, _, anchors.b, anchors.x, anchors.y = self:GetAnchor()
    end)

    bc.bg = wm:CreateControl("ZAM_BuffDisplay" .. unit .. "ContainerBG", bc, CT_TEXTURE)
    bc.bg:SetAnchor(TOPLEFT, bc, TOPLEFT, -3, -3)
    bc.bg:SetAnchor(BOTTOMRIGHT, bc, BOTTOMRIGHT, 3, 3)
    bc.bg:SetColor(1, 1, 1, .5)
    bc.bg:SetAlpha(db.isLocked and 0 or .5)
end

local function CreateOptions()
    local zamPanel = LAM:CreateControlPanel("ZAM_ADDON_OPTIONS", "ZAM Addons")
    LAM:AddHeader(zamPanel, "ZAM_BuffDisplay_Options_Header", "ZAM BuffDisplay")
    LAM:AddCheckbox(zamPanel, "ZAM_BuffDisplay_Options_Lock", "Lock Buff Displays", "Lock or unlock the buff anchors to move them.",
        function() return db.isLocked end, --getFunc
        function() --setFunc
            db.isLocked = not db.isLocked
            pbc:SetMovable(not db.isLocked)
            pbc.bg:SetAlpha(db.isLocked and 0 or 1)
            rbc:SetMovable(not db.isLocked)
            rbc.bg:SetAlpha(db.isLocked and 0 or 1)
        end)
    LAM:AddDropdown(zamPanel, "ZAM_BuffDisplay_Options_Font", "Font", "The font to use for the text.",
        LMP:List("font"), function() return db.font end,
        function(val)
            db.font = val
            for i = 1, playerPool:GetTotalObjectCount() do
                SetFonts(playerPool:AcquireObject(i))
            end
            for i = 1, reticlePool:GetTotalObjectCount() do
                SetFonts(reticlePool:AcquireObject(i))
            end
        end)
    LAM:AddCheckbox(zamPanel, "ZAM_BuffDisplay_Options_GrowUpPlayer", "Grow Player Buffs Upward",
        "When enabled, new buffs will be added above the anchor instead of below.",
        function() return db.player.growUp end, --getFunc
        function() --setFunc
            db.player.growUp = not db.player.growUp
            for i = 1, playerPool:GetTotalObjectCount() do
                HandleAnchors(playerPool:AcquireObject(i), i, "player")
            end
        end)
    LAM:AddCheckbox(zamPanel, "ZAM_BuffDisplay_Options_GrowUpReticle", "Grow Reticleover Buffs Upward",
        "When enabled, new buffs will be added above the anchor instead of below.",
        function() return db.reticleover.growUp end, --getFunc
        function() --setFunc
            db.reticleover.growUp = not db.reticleover.growUp
            for i = 1, reticlePool:GetTotalObjectCount() do
                HandleAnchors(reticlePool:AcquireObject(i), i, "reticleover")
            end
        end)
    LAM:AddCheckbox(zamPanel, "ZAM_BuffDisplay_Options_ShowBars", "Display Statusbar",
        "Display the statusbar counting down the duration of the buff.",
        function() return db.displayBars end, --getFunc
        function() --setFunc
            db.displayBars = not db.displayBars
            for i = 1, playerPool:GetTotalObjectCount() do
                (playerPool:AcquireObject(i)).bar:SetHidden(not db.displayBars)
            end
            for i = 1, reticlePool:GetTotalObjectCount() do
                (reticlePool:AcquireObject(i)).bar:SetHidden(not db.displayBars)
            end
        end)
    LAM:AddColorPicker(zamPanel, "ZAM_BuffDisplay_Options_BarColor", "Statusbar Color", "The color of the statusbar.",
        function() return db.barColor.r, db.barColor.g, db.barColor.b, db.barColor.a end,
        function(r, g, b, a)
            db.barColor.r = r
            db.barColor.g = g
            db.barColor.b = b
            db.barColor.a = a
            for i = 1, playerPool:GetTotalObjectCount() do
                (playerPool:AcquireObject(i)).bar:SetColor(r, g, b, a)
            end
            for i = 1, reticlePool:GetTotalObjectCount() do
                (reticlePool:AcquireObject(i)).bar:SetColor(r, g, b, a)
            end
        end)
end

local function Initialize()
    ZAM_BuffDisplayDB = ZAM_BuffDisplayDB or {}
    for k, v in pairs(defaults) do
        if type(ZAM_BuffDisplayDB[k]) == "nil" then
            ZAM_BuffDisplayDB[k] = v
        end
    end
    db = ZAM_BuffDisplayDB

    SetUpContainer("player")
    SetUpContainer("reticleover")
    CreateOptions()

    playerPool = ZO_ObjectPool:New(CreateBuff, RemoveBuff)
    reticlePool = ZO_ObjectPool:New(CreateBuff, RemoveBuff)
    UpdateBuffs("player")

    --em:UnregisterForEvent("ZAM_BuffDisplay", EVENT_PLAYER_ACTIVATED)
    em:RegisterForEvent("ZAM_BuffDisplay", EVENT_EFFECT_CHANGED, function(event, changeType, effectSlot, effectName, unitTag, beginTime, endTime, stackCount, iconName, buffType, effectType, abilityType, statusEffectType)
        if unitTag == "player" or unitTag == "reticleover" then
            UpdateBuffs(unitTag)
        end
        if effectType == 5 then print(effectName .. " = passive?") return end
    end)
    em:RegisterForEvent("ZAM_BuffDisplay", EVENT_PLAYER_ACTIVATED, function()
        UpdateBuffs("player")
    end)
end

--em:RegisterForEvent("ZAM_BuffDisplay", EVENT_PLAYER_ACTIVATED, function()
em:RegisterForEvent("ZAM_BuffDisplay", EVENT_ADD_ON_LOADED, function(event, addon)
    if addon == "ZAM_BuffDisplay" then
        Initialize()
        em:UnregisterForEvent("ZAM_BuffDisplay", EVENT_ADD_ON_LOADED)
    end
end)
em:RegisterForEvent("ZAM_BuffDisplay", EVENT_RETICLE_TARGET_CHANGED, function()
    UpdateBuffs("reticleover")
end)

--em:RegisterForEvent("ZAM_BuffDisplay", EVENT_EFFECTS_FULL_UPDATE, function() print("full update") endem