--[[
Bot v0.2

Skills:
Twin Breath:

Twin Fangs:

Fie And Ice:

toDO:

Laning
Pushing
Reset Bools if timeout
Items
Retreat
--]]
local _G = getfenv(0)
local object = _G.object

object.myName = object:GetName()

object.bRunLogic        = true
object.bRunBehaviors    = true
object.bUpdates         = true
object.bUseShop         = true

object.bRunCommands     = true 
object.bMoveCommands    = true
object.bAttackCommands  = true
object.bAbilityCommands = true
object.bOtherCommands   = true

object.bReportBehavior = false
object.bDebugUtility = false
object.bDebugExecute = false

object.logger = {}
object.logger.bWriteLog = false
object.logger.bVerboseLog = false

object.core         = {}
object.eventsLib    = {}
object.metadata     = {}
object.behaviorLib  = {}
object.skills       = {}

runfile "bots/core.lua"
runfile "bots/botbraincore.lua"
runfile "bots/eventsLib.lua"
runfile "bots/metadata.lua"
runfile "bots/behaviorLib.lua"

local core, eventsLib, behaviorLib, metadata, skills = object.core, object.eventsLib, object.behaviorLib, object.metadata, object.skills

local print, ipairs, pairs, string, table, next, type, tinsert, tremove, tsort, format, tostring, tonumber, strfind, strsub
    = _G.print, _G.ipairs, _G.pairs, _G.string, _G.table, _G.next, _G.type, _G.table.insert, _G.table.remove, _G.table.sort, _G.string.format, _G.tostring, _G.tonumber, _G.string.find, _G.string.sub
local ceil, floor, pi, tan, atan, atan2, abs, cos, sin, acos, max, random
    = _G.math.ceil, _G.math.floor, _G.math.pi, _G.math.tan, _G.math.atan, _G.math.atan2, _G.math.abs, _G.math.cos, _G.math.sin, _G.math.acos, _G.math.max, _G.math.random

local BotEcho, VerboseLog, BotLog = core.BotEcho, core.VerboseLog, core.BotLog
local Clamp = core.Clamp

BotEcho('loading Gemini_main...')

---------------------------------------------------
---------------------------------------------------
--Important variables and const.
---------------------------------------------------
---------------------------------------------------

object.heroName = 'Hero_Gemini'

--avaible states for wolves (Fire and Ice)
object.Recombining = -1
object.Farming = 0
object.Fountain = 1
object.Ganking = 2
object.Retreat = 3

--supported items
--[[
local tSupportedItems = {core.itemPostHaste, core.itemLightning, core.itemSavageMace, core.itemBrutalizer, 
                        core.itemIcebrand, core.itemAbyssalSkull, core.itemSteamboots, core.itemEnergizer, 
                        core.itemNullfireBlade, core.itemHatchet, core.itemRoT}
]]--

-- skillbuild table, 0=q, 1=w, 2=e, 3=r, 4=attri
-- TwinBreath, TwinFangs, TwinStrikes, FireAndIce
object.tSkills = {
    2, 1, 0, 0, 0,
    3, 0, 1, 1, 1,
    3, 2, 2, 2, 4,
    3, 4, 4, 4, 4,
    4, 4, 4, 4, 4,
}

---------------------------------------------------
--Harass related const.
---------------------------------------------------

--bonus aggression if allied hero near
object.nAllyBonus = 5

--minus aggression if additional enemy heroes near
object.nEnemyThreat = 10
object.nHeroRange = 1000

--extra malus for low HP
object.nLowHPMalus = 25

--extra bonus for low HP (enemy)
object.nLowHPBonus = 20

--Spelluse increase aggression for short duration
object.TwinBreathUseBonus = 30
object.TwinFangsUseBonus = 30
object.FireAndIceUseBonus = 40

--Skills allowed to be used
local useCombo = 0

--Avaible combos
object.FullCombo = 4
object.NormalCombo = 2
object.BreathOnly = 1

---------------------------------------------------
--Retreat related const.
---------------------------------------------------

--enemy heroes generate more threat if near
object.nWolfThreatMultiplier = {1.5,1.3,1.1}


---------------------------------------------------
--Fire and Ice related stuff
---------------------------------------------------

--Time to live calculation wolves
local TimeToLive = {}

--time TimeToLive values will be updated
object.TimeFrame = 500

object.nRecombineTreshold = 15
local tOwnedUnits = {}
local Fire = "Fire"
local Ice = "Ice"
object.Breath = 0
object.Fangs = 1
object.Teleport = 2
object.Recombine = 3
local bForceRecombine = false
local bNormalForm = true
local tHeroForm={}

object.CreepThreatMultiplicator = 11
--5 Seconds till unit will die
object.DeathTimer = 5
object.RetreatDifference = 2
local tSlowerDecay = {}

local unitHealingAtWell

---------------------------------------------------
---------------------------------------------------
-- Skillbuild
---------------------------------------------------
---------------------------------------------------
function object:SkillBuild()
    --core.VerboseLog("SkillBuild()")

    local unitSelf = self.core.unitSelf

    if skills.TwinBreath == nil then
        skills.TwinBreath = unitSelf:GetAbility(0)
        skills.TwinFangs = unitSelf:GetAbility(1)
        skills.TwinStrike = unitSelf:GetAbility(2)
        skills.FireAndIce = unitSelf:GetAbility(3)
        skills.attributeBoost = unitSelf:GetAbility(4)
        skills.Taunt = unitSelf:GetAbility(8)
    end
    
    if unitSelf:GetAbilityPointsAvailable() <= 0 then
        return
    end
    
    local nlev = unitSelf:GetLevel()
    local nlevpts = unitSelf:GetAbilityPointsAvailable()
    for i = nlev, nlev+nlevpts do
        unitSelf:GetAbility( object.tSkills[i] ):LevelUp()
    end
end

object.nEnergizerUse = 10
object.nNullfireBladeUse = 10
--Gemini ability use gives bonus to harass util for a while
function object:oncombateventOverride(EventData)
    self:oncombateventOld(EventData)
    
    local addBonus = 0
    
    if EventData.Type == "Ability" then
        --BotEcho("  ABILILTY EVENT!  InflictorName: "..EventData.InflictorName)
        if EventData.InflictorName == "Ability_Gemini1" then
            addBonus = addBonus + object.TwinBreathUseBonus
        elseif EventData.InflictorName == "Ability_Gemini2" then
            addBonus = addBonus + object.TwinFangsUseBonus
        elseif EventData.InflictorName == "Ability_Gemini4" then
            addBonus = addBonus + object.FireAndIceUseBonus
        end
    elseif EventData.Type == "Item" then
        if core.itemEnergizer and EventData.SourceUnit == core.unitSelf:GetUniqueID() and EventData.InflictorName == core.itemEnergizer:GetName() then
            addBonus = addBonus + object.nEnergizerUse
        elseif core.itemNullfireBlade and EventData.SourceUnit == core.unitSelf:GetUniqueID() and EventData.InflictorName == core.itemNullfireBlade:GetName() then
            addBonus = addBonus + object.nNullfireBladeUse
        end
    end
    
    if addBonus > 0 then
        --decay before we add
        core.DecayBonus(self)
    
        core.nHarassBonus = core.nHarassBonus + addBonus
    end
end
object.oncombateventOld = object.oncombatevent
object.oncombatevent    = object.oncombateventOverride

---------------------------------------------------
---------------------------------------------------
-- On Think
---------------------------------------------------
---------------------------------------------------
local bIsFireAndIce = false
--Change behaviors, if we transform between Gemini and Fire and Ice
function object:onthinkOverride(tGameVariables)
    self:onthinkOld(tGameVariables)
    
    --ToDO Change behaviors
    local bUltimateActive = core.unitSelf:HasState("State_Gemini_Ability4_Self")
    
    if bIsFireAndIce ~= bUltimateActive then
        bNormalForm = not bUltimateActive
        bIsFireAndIce = bUltimateActive
        behaviorLib.tBehaviors = tHeroForm[bNormalForm] 
    end
    
end
object.onthinkOld = object.onthink
object.onthink  = object.onthinkOverride



---------------------------------------------------
---------------------------------------------------
-- Harass
---------------------------------------------------
---------------------------------------------------

--Twinbreath damage
local function abilTwinBreathDamage(level)
    return level*75
end

--Twinfangs damage
local function abilTwinFangsDamage(level)
    return (level+1)*60
end

--Breath damage (both wolves)
local function abilUltimateBreath (level)
    return 75+level * 80
end

--Fangs damage (both wolves)
local function abilUltimateFangs (level)
    return (level+1)*40
end



-- A fixed list seems to be better then to check on each cycle if its  exist
-- so we create it here
local tRelativeMovements = {}
local function createRelativeMovementTable(key)
    --BotEcho('Created a relative movement table for: '..key)
    tRelativeMovements[key] = {
        vLastPos = Vector3.Create(),
        vRelMov = Vector3.Create(),
        timestamp = 0
    }
--  BotEcho('Created a relative movement table for: '..tRelativeMovements[key].timestamp)
end
createRelativeMovementTable("TwinFangs") -- for TwinFangs

-- tracks movement for targets based on a list, so its reusable
-- key is the identifier for different uses (fe. RaMeteor for his path of destruction)
-- vTargetPos should be passed the targets position of the moment
-- to use this for prediction add the vector to a units position and multiply it
-- the function checks for 100ms cycles so one second should be multiplied by 20
local function relativeMovement(sKey, vTargetPos)
    local debugEchoes = false
    
    local gameTime = HoN.GetGameTime()
    local key = sKey
    local vLastPos = tRelativeMovements[key].vLastPos
    local nTS = tRelativeMovements[key].timestamp
    local timeDiff = gameTime - nTS 
    
    if debugEchoes then
        BotEcho('Updating relative movement for key: '..key)
        BotEcho('Relative Movement position: '..vTargetPos.x..' | '..vTargetPos.y..' at timestamp: '..nTS)
        BotEcho('Relative lastPosition is this: '..vLastPos.x)
    end
    
    if timeDiff >= 90 and timeDiff <= 140 then -- 100 should be enough (every second cycle)
        local relativeMov = vTargetPos-vLastPos
        
        if vTargetPos.LengthSq > vLastPos.LengthSq
        then relativeMov =  relativeMov*-1 end
        
        tRelativeMovements[key].vRelMov = relativeMov
        tRelativeMovements[key].vLastPos = vTargetPos
        tRelativeMovements[key].timestamp = gameTime
        
        
        if debugEchoes then
            BotEcho('Relative movement -- x: '..relativeMov.x..' y: '..relativeMov.y)
            BotEcho('^r---------------Return new-'..tRelativeMovements[key].vRelMov.x)
        end
        
        return relativeMov
    elseif timeDiff >= 150 then
        tRelativeMovements[key].vRelMov =  Vector3.Create(0,0)
        tRelativeMovements[key].vLastPos = vTargetPos
        tRelativeMovements[key].timestamp = gameTime
    end
    
    if debugEchoes then BotEcho('^g---------------Return old-'..tRelativeMovements[key].vRelMov.x) end
    return tRelativeMovements[key].vRelMov
end


--This function returns the position of the enemy hero.
--If he is not shown on map it returns the last visible spot
--as long as it is not older than 10s
local function funcGetEnemyPosition (unitEnemy)

    if unitEnemy == nil  then return Vector3.Create(20000, 20000) end 
    --BotEcho(unitEnemy:GetTypeName())
    local tEnemyPosition = core.unitSelf.tEnemyPosition
    local tEnemyPositionTimestamp = core.unitSelf.tEnemyPositionTimestamp
    
    if tEnemyPosition == nil then
        -- initialize new table
        core.unitSelf.tEnemyPosition = {}
        core.unitSelf.tEnemyPositionTimestamp = {}
        
        tEnemyPosition = core.unitSelf.tEnemyPosition
        tEnemyPositionTimestamp = core.unitSelf.tEnemyPositionTimestamp
        
        local tEnemyTeam = HoN.GetHeroes(core.enemyTeam)
        --vector beyond map
        for x, hero in pairs(tEnemyTeam) do
            tEnemyPosition[hero:GetUniqueID()] = Vector3.Create(20000, 20000)
            tEnemyPositionTimestamp[hero:GetUniqueID()] = HoN.GetGameTime()
        end
        
    end
    
    local vecPosition = unitEnemy:GetPosition()
    
    --enemy visible?
    if vecPosition then
        --update table
        tEnemyPosition[unitEnemy:GetUniqueID()] = vecPosition
        tEnemyPositionTimestamp[unitEnemy:GetUniqueID()] = HoN.GetGameTime()
    end
    
    --BotEcho(tostring(unitEnemy).." is at position"..tostring(tEnemyPosition[unitEnemy:GetUniqueID()]))
    
    --return position, 10s memory
    if tEnemyPositionTimestamp[unitEnemy:GetUniqueID()] <= HoN.GetGameTime() + 10000 then
        return tEnemyPosition[unitEnemy:GetUniqueID()]
    else
        return Vector3.Create(20000, 20000)
    end
end

--This function returns the values for physical and magical
--resistance
local function getHeroResistance(unit)
    
    if unit == nil  then return end 
    
    local nUnitID = unit:GetUniqueID()
    --BotEcho(unit:GetTypeName())
    local tPhysicalResistance = core.unitSelf.tPhysicalResistance
    local tMagicalResistance = core.unitSelf.tMagicalResistance
    
    if tPhysicalResistance == nil then
        -- initialize new table
        core.unitSelf.tPhysicalResistance = {}
        core.unitSelf.tMagicalResistance = {}
        
        tPhysicalResistance = core.unitSelf.tPhysicalResistance
        tMagicalResistance = core.unitSelf.tMagicalResistance
        
        local tEnemyTeam = HoN.GetHeroes(core.enemyTeam)
        --vector beyond map
        for x, hero in pairs(tEnemyTeam) do
            local nHeroID = hero:GetUniqueID()
            tPhysicalResistance[nHeroID] = hero:GetPhysicalResistance() or 0
            tMagicalResistance[nHeroID] = hero:GetMagicResistance() or 0
        end
    end
    
    local enemyPhysicalResistance = unit:GetPhysicalResistance() 
    if enemyPhysicalResistance then
        tPhysicalResistance[nUnitID] = enemyPhysicalResistance
    end
    
    local enemyMagicResistance = unit:GetMagicResistance() 
    if enemyMagicResistance then
        tMagicalResistance[nUnitID] = enemyMagicResistance
    end
        
    --return armor values
    
    return tPhysicalResistance[nUnitID],tMagicalResistance[nUnitID]
end

----------------------------------
--  Gemini harass utility
----------------------------------
local function CustomHarassUtilityOverride(hero)
    
    useCombo = object.BreathOnly
    --no target, no harrass
    local unitTarget = behaviorLib.heroTarget
    if not unitTarget then return 0 end
    
    local nUtility = 0
    
    --info about myself
    local unitSelf = core.unitSelf
    local myMana = unitSelf:GetMana()
    local myMPPercent = unitSelf:GetManaPercent()
    local myHPPercent = unitSelf:GetHealthPercent()
    local myAttackDamage = unitSelf:GetFinalAttackDamageMin() 
    
    --good idea to harass?
    local potentialAttacks = 0
    local potentialDmg = 0
    
    --get enemy info
    local enemyHP = unitTarget:GetHealth()
    local enemyHPPercent = unitTarget:GetHealthPercent()
    local enemyPhysicalResistance, enemyMagicResistance = getHeroResistance(unitTarget)
    
    local abilTwinBreath = skills.TwinBreath
    if abilTwinBreath:CanActivate() then
        myMana = myMana - abilTwinBreath:GetManaCost()
        potentialDmg = abilTwinBreathDamage(abilTwinBreath:GetLevel())
        potentialAttacks = 2
    end
    
    local abilTwinFangs = skills.TwinFangs
    if abilTwinFangs:CanActivate() and abilTwinFangs:GetManaCost() <= myMana then
        myMana = myMana - abilTwinFangs:GetManaCost()
        potentialDmg = potentialDmg+ abilTwinFangsDamage(abilTwinFangs:GetLevel())
        potentialAttacks = potentialAttacks + 2
    end 
    
    local abilFireAndIce = skills.FireAndIce
    if abilFireAndIce:CanActivate() then
        if myMana >= 100 then
        myMana = myMana - 100
        potentialDmg = potentialDmg+ abilUltimateBreath(abilFireAndIce:GetLevel())
        potentialAttacks = potentialAttacks + 1
        end
        if myMana >= 75 then
        potentialDmg = potentialDmg+ abilUltimateFangs(abilFireAndIce:GetLevel())
        potentialAttacks = potentialAttacks + 1
        end
    end
    
    --getItems ToDo
    local tSupportedItems = {core.itemPostHaste, core.itemLightning, core.itemSavageMace, core.itemBrutalizer, 
                        core.itemIcebrand, core.itemAbyssalSkull, core.itemSteamboots, core.itemEnergizer, 
                        core.itemNullfireBlade, core.itemHatchet, core.itemRoT}
                        
    local itemLightning = core.itemLightning
    if itemLightning and itemLightning:GetCharges() then
        potentialDmg = potentialDmg + itemLightning.Dmg
        --BotEcho("Thunderclaw rdy: Dmg ~"..tostring(itemLightning.Dmg))
    end
    
    --[[
    local itemSavageMace = core.itemSavageMace
    if itemSavageMace then
    
    end
    --]]
        
    local itemBrutalizer = core.itemBrutalizer
    if itemBrutalizer and itemBrutalizer:CanActivate() then
        nUtility = nUtility + 5
        --BotEcho("Brutalizer rdy")
    end
    
    --no chargesystem
    local itemIcebrand = core.itemIcebrand
    if itemIcebrand and (unitTarget:HasState("State_ItemHackSlow") or 
        unitTarget:HasState("State_ItemFirenIceSlow") or unitTarget:HasState("State_ItemDawnbringerSlow")) then
        nUtility = nUtility + itemIcebrand.slowPerAttack
        --BotEcho("Slow Applied")
    end
    
    --BotEcho("Potential damage pre-migration: "..potentialDmg.." Potential attacks: "..potentialAttacks)
    --BotEcho("Magic Damage Modifier: "..enemyMagicResistance.." Potential Armor Modifier "..enemyPhysicalResistance)
    
    --potential damage
    potentialDmg = potentialDmg * (1-enemyMagicResistance) 
                    + myAttackDamage * potentialAttacks * (1-enemyPhysicalResistance)
    
    if enemyHP < potentialDmg then
        nUtility = nUtility + 30
        useCombo = object.FullCombo
    elseif myMPPercent > 0.8 then
        nUtility = nUtility + 10
        useCombo = object.NormalCombo
    end
    
    --BotEcho("Potential Damage after reduciton:"..potentialDmg.." and utility: "..nUtility.." Combo = "..useCombo)
    
    --Adjust Enemies 
    --bonus of allies
    local allies = core.localUnits["AllyHeroes"]
    local nAllies = core.NumberElements(allies)
    local nAllyBonus = object.nAllyBonus
    
    nUtility = nUtility + nAllies * nAllyBonus
    
    --number of enemies near target decrease utility
    local nEnemyThreat = object.nEnemyThreat
    local nHeroRange = object.nHeroRange
        
    local tEnemyTeam = HoN.GetHeroes(core.enemyTeam)
    local nEnemiesNear = 0
    
    --units close to unitTarget
    for id, enemy in pairs(tEnemyTeam) do
        if  enemy:GetUniqueID() ~= unitTarget:GetUniqueID() and 
                Vector3.Distance2DSq(unitTarget:GetPosition(), funcGetEnemyPosition (enemy)) < nHeroRange * nHeroRange then
            nUtility = nUtility - nEnemyThreat
            nEnemiesNear = nEnemiesNear + 1
        end
    end
    
    --Team-Advantage Use NormalCombo
    if nAllies > nEnemiesNear then useCombo = object.NormalCombo end
    
    --Low HP reduces wish to Chase / Low HP Enemy increase wish to chase
    nUtility = nUtility - (1-myHPPercent) * object.nLowHPMalus + (1-enemyHPPercent) * object.nLowHPBonus
    
    --if close do an attack
    if Vector3.Distance2DSq(unitSelf:GetPosition(), unitTarget:GetPosition()) < 40000 then 
        nUtility = nUtility + 15
    end
    
    --BotEcho("Allies near: "..nAllies.." and utility after enemyThreat: "..nUtility)
    return Clamp(nUtility, 0, 100)
end
behaviorLib.CustomHarassUtility = CustomHarassUtilityOverride   

----------------------------------
--  Gemini harass execute
----------------------------------
local function HarassHeroExecuteOverride(botBrain)
        
    local unitTarget = behaviorLib.heroTarget 
    if unitTarget == nil then return flase end
    
    local unitSelf = core.unitSelf
    local vecMyPosition =unitSelf:GetPosition()
    local vecTargetPosition = unitTarget:GetPosition()
    local distanceTargetSq = Vector3.Distance2DSq(vecMyPosition, vecTargetPosition)
    
    local bImmobile = unitTarget:IsStunned() or unitTarget:IsImmobilized()
        
    -- this needs to be called every cycle to ensure up to date values for relative movement
    local nPredictTwinFangs = 4
    local relativeMov = relativeMovement("TwinFangs", vecTargetPosition) * nPredictTwinFangs
    
    
    local bActionTaken = false
        
        --TwinBreath
        local TwinBreath = skills.TwinBreath
        if not bActionTaken and TwinBreath:CanActivate() 
            and not (useCombo == object.BreathOnly and unitSelf:GetManaPercent() < 0.7)then

            local TwinBreathRange = TwinBreath:GetRange()
                if distanceTargetSq <= TwinBreathRange * TwinBreathRange  then
                    bActionTaken = core.OrderAbilityPosition(botBrain, TwinBreath, vecTargetPosition)
                end
        end
        
        --TwinFangs
        local abilTwinFangs = skills.TwinFangs
        if not bActionTaken and abilTwinFangs:CanActivate() and useCombo >= object.NormalCombo then
            local nRange = abilTwinFangs:GetRange()
            local nVaryTwinFangs = abilTwinFangs:GetTargetRadius() - 70 --instead of 250, more costy, but safe for HoN updates
            
            if  core.CanSeeUnit(botBrain, unitTarget) then -- Do moving-to prediction defined above
                local newDistance = Vector3.Distance2DSq(vecMyPosition, (vecTargetPosition+relativeMov))
                if  (newDistance > 500000 and newDistance < 800000) then
                    
                        if bDebugEchos then BotEcho("Checking predicted Range was valid") end
                        bActionTaken = core.OrderAbilityPosition(botBrain, abilTwinFangs, vecTargetPosition+relativeMov)
                    
                end
            elseif (nRange - nVaryTwinFangs)*(nRange - nVaryTwinFangs) < distanceTargetSq and distanceTargetSq < (nRange + nVaryTwinFangs)*(nRange + nVaryTwinFangs) then -- cant see, so we guess with build in prediction 'GetPosition()'
                if bDebugEchos then BotEcho("Checking standard Range was valid") end
                bActionTaken = core.OrderAbilityPosition(botBrain, abilTwinFangs, vecTargetPosition)
            end
        end


        --Lightning2
        if not bActionTaken then
            local itemLightning2 = core.itemLightning
            if itemLightning2 and itemLightning2.bAbility and useCombo >= object.NormalCombo then
                if itemLightning2:CanActivate() then
                    bActionTaken = core.OrderItemClamp(botBrain, unitSelf, itemLightning2)
                end
            end
        end
        
        --Nullfire
        if not bActionTaken and not bImmobile then
            local itemNullfireBlade = core.itemNullfireBlade
            if itemNullfireBlade and itemNullfireBlade:CanActivate() and useCombo >= object.NormalCombo then
                local itemNullfireBladeRange = itemNullfireBlade:GetRange()
                if distanceTargetSq <= itemNullfireBladeRange * itemNullfireBladeRange then
                    bActionTaken = core.OrderItemEntityClamp(botBrain, unitSelf, itemNullfireBlade, unitTarget)
                end
            end
        end
        
        --Energizer
        if not bActionTaken then
            local itemEnergizer = core.itemEnergizer
            if itemEnergizer and itemEnergizer:CanActivate() and useCombo >= object.NormalCombo then
                bActionTaken = core.OrderItemClamp(botBrain, unitSelf, itemEnergizer)
            end
        end
        
        --normal harass
        if not bActionTaken then
            if bDebugEchos then BotEcho("No action taken, running my base harass") end
            return object.harassExecuteOld(botBrain)
        end
    
end
object.harassExecuteOld = behaviorLib.HarassHeroBehavior["Execute"]
behaviorLib.HarassHeroBehavior["Execute"] = HarassHeroExecuteOverride


---------------------------------------------------
---------------------------------------------------
-- Retreat
---------------------------------------------------
---------------------------------------------------

---------------------------------------------------------------
--This function calculates how threatening an enemy hero is
--return the thread value
---------------------------------------------------------------
local function funcGetThreatOfEnemy (unitSelf, unitEnemy)
    --no unit selected or is dead
    if unitEnemy == nil or not unitEnemy:IsAlive() then return 0 end
    
    local vecMyPosition = unitSelf:GetPosition()
    local vecEnemyPosition = funcGetEnemyPosition (unitEnemy)
    local nDistanceSq = Vector3.Distance2DSq(vecMyPosition, vecEnemyPosition)
    
    --BotEcho("Distance: MyPosition"..tostring(vecMyPosition).." your position "..tostring(vecEnemyPosition).." Square "..nDistanceSq)
    
    
    --unit is probably far away
    if nDistanceSq > 4000000 then
    
        --BotEcho("UnitEnemy is"..unitEnemy:GetTypeName().."Distance"..nDistanceSq)
        return 0
    end
            
    local nMyLevel = unitSelf:GetLevel()
    local nEnemyLevel = unitEnemy:GetLevel()
    
    --Level differences increase / decrease actual nThreat
    local nThreat = 7 + Clamp(nEnemyLevel - nMyLevel, 0, 0)
    
    --Magic-Formel: Threat to Range, T(700²) = 2, T(1100²) = 1.5, T(2000²)= 0.75
    nThreat = Clamp (3*(112810000-nDistanceSq) / (4*(19*nDistanceSq+32810000)),0.75,2) * 5

    
    --BotEcho("UnitEnemy is"..unitEnemy:GetTypeName().." and Threat"..nThreat.." and position " ..tostring(vecEnemyPosition))   
    return nThreat
end


--create a new instance of TimeToLive
function TimeToLive.Create(life)
    local tLife = {life, life, life, life, life}
    
    return tLife
end

--update table of TimeToLive
function TimeToLive.update(tLife, newLife)
    local tNewLife = {}
    nLife = core.NumberElements(tLife)
    tNewLife[1] = newLife
    for id, life in pairs(tLife) do
            if id ~= nLife then
                tNewLife[id+1] = life
            end
        end
    return tNewLife
end

--Returns the time the unit will probably die
function TimeToLive.getTimeTendenz(tLife)     
    nLife = core.NumberElements(tLife)
    if not nLife then return -1 end
    local middle = math.floor(nLife/2+1) 
    local nLongLost = tLife[nLife] - tLife[middle]
    local nShortLost = tLife[middle] - tLife[1]
    local nTendenz = 0
    if nShortLost * 1.2 < nLongLost then
        Tendenz = nShortLost + nLongLost / 2
    elseif nShortLost > nLongLost * 1.2 then
        nTendenz = 2 * nShortLost + nLongLost 
    else
        nTendenz = nShortLost + nLongLost 
    end
      
    if nTendenz ~= 0 then 
        return 2 * tLife[1] / nTendenz
    end
end

------------------------------------------------------------------
--Returns the saved TimeToLive value
------------------------------------------------------------------
local function funcTimeToLive (unit)

    if unit == nil  then return 9999 end 
    
    local unitHP = unit:GetHealth()
    local unitID = unit:GetUniqueID()
    
    --BotEcho(unitEnemy:GetTypeName())
    local tHealthMemory = core.unitSelf.tHealthMemory
    local tHealthMemoryTimestamp = core.unitSelf.tHealthMemoryTimestamp
    
    if tHealthMemory == nil then
        -- initialize new table
        core.unitSelf.tHealthMemory = {}
        core.unitSelf.tHealthMemoryTimestamp = {}
        tHealthMemory = core.unitSelf.tHealthMemory
        tHealthMemoryTimestamp = core.unitSelf.tHealthMemoryTimestamp       
    end
    
    local timeStamp = HoN.GetGameTime()
    
    if not tHealthMemory[unitID] then
        tHealthMemory[unitID] = TimeToLive.Create(unitHP)
        tHealthMemoryTimestamp[unitID] = timeStamp
    end
    
    if timeStamp >= tHealthMemoryTimestamp[unitID] + object.TimeFrame then
        tHealthMemory[unitID] = TimeToLive.update(tHealthMemory[unitID], unitHP)
        tHealthMemoryTimestamp[unitID] = timeStamp
    end
    
    return TimeToLive.getTimeTendenz(tHealthMemory[unitID])
end

--Return a threatening value and the TimeToLive-value
local function TimeToLiveUtilityFn(unitHero)
    --Increases as your time to live based on your damage velocity decreases
    local nUtility = 0
    
    local nTimeToLive = funcTimeToLive(unitHero) or 1000000
    local nYIntercept = 75
    local nXIntercept = 60
    local nOrder = 2
    nUtility = core.ExpDecay(nTimeToLive, nYIntercept, nXIntercept, nOrder)
    

    nUtility = Clamp(nUtility, 0, 100)
    
    --BotEcho(format("%d timeToLive: %g  utility: %g", HoN.GetGameTime(), nTimeToLive, nUtility))

    return nUtility, nTimeToLive
end

local function CustomRetreatFromThreatUtilityFnOverride(botBrain)
    local bDebugEchos = false
    local nUtility =0
        
    local nUtility, nTimeToLive = TimeToLiveUtilityFn(core.unitSelf)
        
    local unitSelf = core.unitSelf
    local tEnemyCreeps = core.localUnits["EnemyCreeps"]
    local tEnemyTowers = core.localUnits["EnemyTowers"]

    --Creep aggro
    local nCreepAggro = 0
    for id, enemyCreep in pairs(tEnemyCreeps) do
        local unitAggroTarget = enemyCreep:GetAttackTarget()
        if unitAggroTarget and unitAggroTarget:GetUniqueID() == unitSelf:GetUniqueID() then
            nCreepAggro = nCreepAggro + 1
        end
    end

    --Tower Aggro
    local nTowerAggroUtility = 0
    for id, tower in pairs(tEnemyTowers) do
        local unitAggroTarget = tower:GetAttackTarget()
            if unitAggroTarget ~= nil and unitAggroTarget == core.unitSelf then
            nTowerAggroUtility = behaivorLib.nTowerAggroUtility
            break
        end
    end
    
    nUtility  = nUtility + nCreepAggro * object.CreepThreatMultiplicator + nTowerAggroUtility
    
        --bonus of allies decrease fear
        local allies = core.localUnits["AllyHeroes"]
        local nAllies = core.NumberElements(allies) + 1 
        
        --get enemy heroes
        local tEnemyTeam = HoN.GetHeroes(core.enemyTeam)
        
        --calculate the threat-value and increase utility value
        for id, enemy in pairs(tEnemyTeam) do
        --BotEcho (id.." Hero "..enemy:GetTypeName())
            nUtility = nUtility + funcGetThreatOfEnemy(core.unitSelf, enemy) / nAllies
        end
    return Clamp(nUtility, 0, 100)
    
end
object.RetreatFromThreatUtilityOld =  behaviorLib.RetreatFromThreatUtility
behaviorLib.RetreatFromThreatBehavior["Utility"] = CustomRetreatFromThreatUtilityFnOverride

local function funcRetreatFromThreatExecuteOverride(botBrain)

    local unitSelf = core.unitSelf  
    local vecSelfPosition = unitSelf:GetPosition()
    local bSlowed = unitSelf:GetMoveSpeed() < 350
    
    local vecPos = behaviorLib.PositionSelfBackUp()

    local nlastRetreatUtil = behaviorLib.lastRetreatUtil
    
    local unitTarget = behaviorLib.heroTarget
    local vecTargetPosition = funcGetEnemyPosition(unitTarget)
    
    local bCanSeeUnit = unitTarget and core.CanSeeUnit(botBrain, unitTarget) 

    --TwinBreath
        local TwinBreath = skills.TwinBreath
        if not bActionTaken and nlastRetreatUtil > 30  and TwinBreath:CanActivate() then

            local TwinBreathRange = TwinBreath:GetRange()
                if distanceTargetSq <= TwinBreathRange * TwinBreathRange  then
                    bActionTaken = core.OrderAbilityPosition(botBrain, TwinBreath, vecTargetPosition)
                end
        end
        
        --TwinFangs
        local abilTwinFangs = skills.TwinFangs
        if not bActionTaken and nlastRetreatUtil > 30 and abilTwinFangs:CanActivate() then
            --BotEcho ("trying really hard to twinfang")
            bActionTaken = core.OrderAbilityPosition(botBrain, abilTwinFangs, 2*vecSelfPosition-vecTargetPosition)
        end
    
        --Lightning2
        if not bActionTaken and nlastRetreatUtil > 35 then
            local itemLightning2 = core.itemLightning
            if itemLightning2 and itemLightning2.bAbility then
                if itemLightning2:CanActivate() then
                    bActionTaken = core.OrderItemClamp(botBrain, unitSelf, itemLightning2)
                end
            end
        end
        
        --Nullfire
        if not bActionTaken and nlastRetreatUtil > 35 then
            local itemNullfireBlade = core.itemNullfireBlade
            if itemNullfireBlade and itemNullfireBlade:CanActivate() then
                if bSlowed then
                    bActionTaken = core.OrderItemEntityClamp(botBrain, unitSelf, itemNullfireBlade, unitSelf)
                elseif bCanSeeUnit then 
                        local itemNullfireBladeRange = itemNullfireBlade:GetRange()
                        if distanceTargetSq <= itemNullfireBladeRange * itemNullfireBladeRange then
                            bActionTaken = core.OrderItemEntityClamp(botBrain, unitSelf, itemNullfireBlade, unitTarget)
                        end
                end
            end
        end
        
        --Energizer
        if not bActionTaken and nlastRetreatUtil > 40 then
            local itemEnergizer = core.itemEnergizer
            if itemEnergizer and itemEnergizer:CanActivate() then
                bActionTaken = core.OrderItemClamp(botBrain, unitSelf, itemEnergizer)
            end
        end
        
    if not bActionTaken then
        core.OrderMoveToPosClamp(botBrain, core.unitSelf, vecPos, false)
    end
end
object.RetreatFromThreatExecuteOld = behaviorLib.RetreatFromThreatExecute
behaviorLib.RetreatFromThreatBehavior["Execute"] = funcRetreatFromThreatExecuteOverride

---------------------------------------------------
---------------------------------------------------
-- Pushing
---------------------------------------------------
---------------------------------------------------

local function funcGroupCenter(tGroup, nMinCount)
    if nMinCount == nil then nMinCount = 1 end
     
    if tGroup ~= nil then
        local vGroupCenter = Vector3.Create()
        local nGroupCount = 0
        for id, creep in pairs(tGroup) do
            vGroupCenter = vGroupCenter + creep:GetPosition()
            nGroupCount = nGroupCount + 1
        end
         
        if nGroupCount < nMinCount then
            return nil
        else
            return vGroupCenter / nGroupCount --center vector
        end
    else
        return nil
    end
end

local function PushExecuteFnOverride(botBrain)
    
    local unitSelf = core.unitSelf
    if unitSelf:IsChanneling() then 
        return
    end
    local bActionTaken = false
    
    local myManaPercent = unitSelf:GetManaPercent()
    local tCreeps = core.localUnits['EnemyCreeps']
    local vecCenter = funcGroupCenter(tCreeps,3)
    
    if vecCenter then
        distanceTargetSq = Vector3.Distance2DSq(unitSelf:GetPosition(), vecCenter)
        --toDo Skills while pushing

        --TwinBreath
        local TwinBreath = skills.TwinBreath
        if not bActionTaken and TwinBreath:CanActivate() and myManaPercent > 0.8 then
            local TwinBreathRange = TwinBreath:GetRange()
            if distanceTargetSq <= TwinBreathRange * TwinBreathRange  then
                bActionTaken = core.OrderAbilityPosition(botBrain, TwinBreath, vecCenter)
            end
        end
    end
    
    if not bActionTaken then
        object.PushExecuteOld(botBrain)
    end
end
object.PushExecuteOld = behaviorLib.PushExecute
behaviorLib.PushBehavior["Execute"] = PushExecuteFnOverride

---------------------------------------------------
---------------------------------------------------
-- Back To Base
---------------------------------------------------
---------------------------------------------------

---------------------------------------------------
-- Back To Base Utility
---------------------------------------------------
local function CustomHealAtWellUtilityFnOverride(botBrain)
    local utility = 0
    local unitSelf = core.unitSelf
    
    local hpPercent = unitSelf:GetHealthPercent()
    local mpPercent = unitSelf:GetManaPercent()
    
    if hpPercent < 0.90 then
        local wellPos = core.allyWell and core.allyWell:GetPosition() or Vector3.Create()
        local nDist = Vector3.Distance2D(wellPos, core.unitSelf:GetPosition())

        utility = behaviorLib.WellHealthUtility(hpPercent) + behaviorLib.WellProximityUtility(nDist)
    end

    if mpPercent < 0.90 then
        utility = utility + mpPercent * 10
    end
        
    return Clamp(utility, 0, 50)
end
object.HealAtWellUtilityOld =  behaviorLib.HealAtWellUtility
behaviorLib.HealAtWellBehavior["Utility"] = CustomHealAtWellUtilityFnOverride

---------------------------------------------------
-- Back To Base Execute
---------------------------------------------------
local function HealAtWellExecuteFnOverride(botBrain)
    --BotEcho("Returning to well!")
    local wellPos = core.allyWell and core.allyWell:GetPosition() or behaviorLib.PositionSelfBackUp()
    --local distanceWellSq =  Vector3.Distance2DSq(core.unitSelf:GetPosition(), wellPos)
    

        --use nergizer
        
        --use twinfang on the last 
        
        --go home
        core.OrderMoveToPosAndHoldClamp(botBrain, core.unitSelf, wellPos, false)
end
object.HealAtWellExecuteOld = behaviorLib.HealAtWellExecute
behaviorLib.HealAtWellBehavior["Execute"] = HealAtWellExecuteFnOverride


---------------------------------------------------
---------------------------------------------------
-- Shopping
---------------------------------------------------
---------------------------------------------------

--Function removes any item that is not valid // tSupportedItems
local function funcRemoveInvalidItems()
    
    if core.itemPostHaste and not core.itemPostHaste:IsValid() then core.itemPostHaste = nil end
    if core.itemLightning and not core.itemLightning:IsValid() then core.itemLightning = nil end
    if core.itemSavageMace and not core.itemSavageMace:IsValid() then core.itemSavageMace = nil end
    if core.itemBrutalizer and not core.itemBrutalizer:IsValid() then core.itemBrutalizer = nil end
    if core.itemIcebrand and not core.itemIcebrand:IsValid() then core.itemIcebrand = nil end
    if core.itemHatchet and not core.itemHatchet:IsValid() then core.itemHatchet = nil end
    if core.itemRoT and not core.itemRoT:IsValid() then core.itemRoT = nil end
    if core.itemSteamboots and not core.itemSteamboots:IsValid() then core.itemSteamboots = nil end
    if core.itemEnergizer and not core.itemEnergizer:IsValid() then core.itemEnergizer = nil end
    if core.itemNullfireBlade and not core.itemNullfireBlade:IsValid() then core.itemNullfireBlade = nil end
    
end

---------------------------------------------------
-- Find Items
---------------------------------------------------
local function funcFindItemsOverride(botBrain)  

    --Alternate item wasn't checked, so you don't need to look for new items.
    if core.bCheckForAlternateItems then return end

    funcRemoveInvalidItems()

        --We only need to know about our current inventory. Stash items are not important.
        local inventory = core.unitSelf:GetInventory(true)
        for slot = 1, 6, 1 do
            local curItem = inventory[slot]
            if curItem then
                if core.itemPostHaste == nil and curItem:GetName() == "Item_PostHaste" then
                    core.itemPostHaste = core.WrapInTable(curItem)
                elseif core.itemLightning == nil and curItem:GetName() == "Item_Lightning1" then
                    core.itemLightning = core.WrapInTable(curItem)
                    core.itemLightning.Dmg = 150
                elseif core.itemLightning == nil and curItem:GetName() == "Item_Lightning2" then
                    core.itemLightning = core.WrapInTable(curItem)
                    core.itemLightning.Dmg = 200
                    core.itemLightning.bAbility = true
                elseif core.itemSavageMace == nil and curItem:GetName() == "Item_Weapon3" then
                    core.itemSavageMace = core.WrapInTable(curItem)
                elseif core.itemBrutalizer == nil and curItem:GetName() == "Item_Brutalizer" then
                    core.itemBrutalizer = core.WrapInTable(curItem)
                elseif core.itemIcebrand == nil and curItem:GetName() == "Item_Strength6" then
                    core.itemIcebrand = core.WrapInTable(curItem)
                    core.itemIcebrand.slowPerAttack = 3
                    core.itemIcebrand.slowCharges = 5
                elseif core.itemIcebrand == nil and curItem:GetName() == "Item_StrengthAgility" then
                    core.itemIcebrand = core.WrapInTable(curItem)
                    core.itemIcebrand.slowPerAttack = 5
                    core.itemIcebrand.slowCharges = 3
                elseif core.itemIcebrand == nil and curItem:GetName() == "Item_Dawnbringer" then
                    core.itemIcebrand = core.WrapInTable(curItem)   
                    core.itemIcebrand.slowPerAttack = 6
                    core.itemIcebrand.slowCharges = 3
                    core.itemIcebrand.bBonusDamage = true
                elseif core.itemHatchet == nil and curItem:GetName() == "Item_LoggersHatchet" then
                    core.itemHatchet = core.WrapInTable(curItem)
                    if core.unitSelf:GetAttackType() == "melee" then
                        core.itemHatchet.creepDamageMul = 1.32
                    else
                        core.itemHatchet.creepDamageMul = 1.12
                    end
                elseif core.itemRoT == nil and curItem:GetName() == "Item_ManaRegen3" then
                    core.itemRoT = core.WrapInTable(curItem)
                    core.itemRoT.bHeroesOnly = (curItem:GetActiveModifierKey() == "ringoftheteacher_heroes")
                    core.itemRoT.nNextUpdateTime = 0
                    core.itemRoT.Update = function() 
                        local nCurrentTime = HoN.GetGameTime()
                        if nCurrentTime > core.itemRoT.nNextUpdateTime then
                            core.itemRoT.bHeroesOnly = (core.itemRoT:GetActiveModifierKey() == "ringoftheteacher_heroes")
                            core.itemRoT.nNextUpdateTime = nCurrentTime + 800
                        end
                    end     
                elseif core.itemRoT == nil and curItem:GetName() == "Item_LifeSteal5" then
                    core.itemRoT = core.WrapInTable(curItem)    
                    core.itemRoT.bHeroesOnly = (curItem:GetActiveModifierKey() == "abyssalskull_heroes")
                    core.itemRoT.nNextUpdateTime = 0
                    core.itemRoT.Update = function() 
                        local nCurrentTime = HoN.GetGameTime()
                        if nCurrentTime > core.itemRoT.nNextUpdateTime then
                            core.itemRoT.bHeroesOnly = (core.itemRoT:GetActiveModifierKey() == "abyssalskull_heroes")
                            core.itemRoT.nNextUpdateTime = nCurrentTime + 800
                        end
                    end                         
                elseif core.itemSteamboots == nil and curItem:GetName() == "Item_Steamboots" then
                    core.itemSteamboots = core.WrapInTable(curItem)
                elseif core.itemEnergizer == nil and curItem:GetName() == "Item_Energizer" then
                    core.itemEnergizer = core.WrapInTable(curItem)
                elseif core.itemNullfireBlade == nil and curItem:GetName() == "Item_ManaBurn1" then
                    core.itemNullfireBlade = core.WrapInTable(curItem)
                end
            end
    end
end
object.FindItemsOld = core.FindItems
core.FindItems = funcFindItemsOverride


--Check for alternate items before shopping
local function funcCheckforAlternateItemBuild(botbrain)
    
    --no further check till next shopping round
    core.bCheckForAlternateItems = false
    
    --toDo Check for Nullfire Blade, Shrunken? 

    --[[
    local unitSelf = core.unitSelf
    
    --initialize item choices
    if unitSelf.getPK == nil then
        --BotEcho("Initialize item choices")
    end
    
    local nGPM = botbrain:GetGPM()
    local nXPM = unitSelf:GetXPM()
    local nMatchTime = HoN.GetMatchTime()
    local bBuyStateLow = behaviorLib.buyState < 3
    
    --Bad early game: skip GhostMarchers and go for more defensive items
    if bBuyStateLow and nXPM < 170 and nMatchTime > 300000  and not unitSelf.getSteamboots   then 
        --BotEcho("My early Game sucked. I will go for a defensive Build.")
        unitSelf.getSteamboots = true
        behaviorLib.MidItems = 
        {"Item_Steamboots", "Item_MysticVestments", "Item_Scarab",  "Item_SacrificialStone", "Item_Silence"}
        
    --Mid game: Bad farm, so go for a tablet
    elseif unitSelf:GetLevel() > 10 and  nGPM < 240 and not unitSelf.getPushStaff then
        --BotEcho("Well, it's not going as expected. Let's try a Tablet!")
        unitSelf.getPushStaff=true
        tinsert(behaviorLib.curItemList, 1, "Item_PushStaff")
    
    --Good farm and you finished your Boots. Now it is time to pick a portal key
    elseif nGPM >= 300 and (core.itemGhostMarchers or core.itemSteamboots) and not unitSelf.getPK then
        --BotEcho("The Game is going good. Soon I will kill them with a fresh PK!")
        unitSelf.getPK=true
        tinsert(behaviorLib.curItemList, 1, "Item_PortalKey")
    end 
    --]]
end


---------------------------------------------------
-- Standard Item Lists
---------------------------------------------------
--[[ list code:
    "# Item" is "get # of these"
    "Item #" is "get this level of the item" 
Item_Lightning2 ChagedHammer  || Item_Weapon3 Savage ||     Item_Brutalizer Brutalizer ||   Item_ManaBurn1 Nullfire || Item_Sicarius firebrand
Item_Strength6 Icebrand ||  Item_Dawnbringer  Dawnbringer ||    Item_LifeSteal5 || abyssal
Boots // abyssal // savage // chargedhammer // Dawnbringer // Nullfire/ Brutalizer  
--]]
behaviorLib.StartingItems = {"Item_LoggersHatchet", "Item_IronBuckler", "Item_RunesOfTheBlight"}
behaviorLib.LaneItems = {"Item_Marchers", "Item_ManaRegen3", "Item_Energizer", "Item_Steamboots"} --Item_Strength6 is Frostbrand
behaviorLib.MidItems = {"Item_LifeSteal5", "Item_Lightning1", "Item_Strength6", "Item_Sicarius"} --Immunity is Shrunken Head, Item_StrengthAgility is Frostburn
behaviorLib.LateItems = {"Item_Brutalizer", "Item_Weapon3", "Item_Dawnbringer", "Item_Lightning2", "Item_PostHaste", "Item_Damage9"} --Item_Damage9 is doombringer

---------------------------------------------------
-- Shopping Execute
---------------------------------------------------
local function funcShopExecuteOverride(botBrain) --done

    --Initialize check for alternate items
    if core.bCheckForAlternateItems == nil then
        core.bCheckForAlternateItems = true
    end
    
    --check item choices
    if core.bCheckForAlternateItems then
        --BotEcho("Checking Alternate Builds")
        funcCheckforAlternateItemBuild(botBrain)
    end
    
    local oldShopping = object.ShopExecuteOld (botBrain)

    --update item links and reset the check
    if behaviorLib.finishedBuying then
        core.FindItems()
        core.bCheckForAlternateItems = true
        --BotEcho("FindItems")
    end
    
    return oldShopping
end
object.ShopExecuteOld = behaviorLib.ShopExecute
behaviorLib.ShopBehavior["Execute"] = funcShopExecuteOverride

local function GoldTreshold()
    local gold = 0
    
    local nNow = HoN.GetMatchTime() 
    --300000 = 5 * 60(1min) * 1000(ms)
    local minute = 60000
    if nNow < 10 * minute then
        gold = 1500
    elseif nNow < 25 * minute then
        gold = 2500
    elseif nNow < 45 * minute then
        gold = 3500
    else
        gold = 6000
    end
    
    return gold
end

---------------------------------------------------
---------------------------------------------------
-- Fire and Ice
---------------------------------------------------
---------------------------------------------------

local function PositionSelfBackUp(unit)
    StartProfile('PositionSelfBackUp')
    
    local vecMyPos = unit:GetPosition()
    local tLaneSet = core.tMyLane
    local nLaneSetSize = nil
    local vecDesiredPos = nil
    local nodePrev = nil
    local nPrevNode = nil

    if tLaneSet then
        nLaneSetSize = #tLaneSet
        nodePrev,nPrevNode = core.GetPrevWaypoint(tLaneSet, vecMyPos, core.bTraverseForward)
        if nodePrev then
            vecDesiredPos = nodePrev:GetPosition()
        end
    else
        --BotEcho('PositionSelfBackUp - invalid lane set')
    end

    if nodePrev then
        local nodePrevPrev = nil
        if core.bTraverseForward and nPrevNode > 1 then
            nodePrevPrev = tLaneSet[nPrevNode - 1]
        elseif not core.bTraverseForward and nPrevNode < nLaneSetSize then
            nodePrevPrev = tLaneSet[nPrevNode + 1]
        end

        if nodePrevPrev ~= nil then
            local vecNodePrevPos = nodePrev:GetPosition()
            local vecNodePrevPrevPos = nodePrevPrev:GetPosition()
            local vecForward = Vector3.Normalize(vecNodePrevPos - vecNodePrevPrevPos)
            if core.RadToDeg(core.AngleBetween(vecNodePrevPos - vecMyPos, vecForward)) < 135 then
                vecDesiredPos = vecNodePrevPrevPos
            end
        end
    else
        --BotEcho('PositionSelfBackUp - unable to find previous node!')
    end
    
    if not vecDesiredPos then
        vecDesiredPos = core.allyWell:GetPosition()
    end

    StopProfile()
    --BotEcho("I'm here"..tostring(unit:GetPosition()).." I want to be there "..tostring(vecDesiredPos))
    return vecDesiredPos
end


local function getFireAndIce()
    --still ok
    if tOwnedUnits[Fire] and tOwnedUnits[Fire]:IsValid() then 
        return tOwnedUnits[Fire],tOwnedUnits[Ice]
    end
    
    --looking for Fire and Ice
    tUnits = HoN.GetUnitsInRadius(core.unitSelf:GetPosition(), 20000, core.UNIT_MASK_UNIT+core.UNIT_MASK_ALIVE)
            for x, unit in pairs(tUnits) do
                if unit:GetTypeName() == "Heropet_Gemini_Ability4_Fire" and unit:GetOwnerPlayerID() == core.unitSelf:GetOwnerPlayerID() then
                    --BotEcho("found Fire")
                    tOwnedUnits[Fire] = unit
                elseif unit:GetTypeName() == "Heropet_Gemini_Ability4_Ice" and unit:GetOwnerPlayerID() == core.unitSelf:GetOwnerPlayerID() then
                    --BotEcho("found Ice")
                    tOwnedUnits[Ice] = unit
                end
            end
    return tOwnedUnits[Fire],tOwnedUnits[Ice]
end

---------------------------------------------------
---------------------------------------------------
-- Splitting in FireAndIce
---------------------------------------------------
---------------------------------------------------
--Recombine utility
local function SplittingFireAndIceUtility(botBrain) --done
    
    nUtility = 0
    
    local FireAndIce = skills.FireAndIce
    if FireAndIce and FireAndIce:CanActivate() then
        if botBrain:GetGold() > GoldTreshold() then
            nUtility = 30
        end
    
        if useCombo == object.FullCombo then
            local TwinBreath = skills.TwinBreath 
            if TwinBreath and not TwinBreath:CanActivate() then
                nUtility =  40 + behaviorLib.lastHarassUtil
                --BotEcho("now")
            end
        end
    end
    
    return nUtility
end

--Recombine Execute
local function SplittingFireAndIceExecute(botBrain) --done

    bForceRecombine = false
    --FireAndIce
    local FireAndIce = skills.FireAndIce
    if FireAndIce then      
        if FireAndIce:CanActivate()  then
            core.OrderAbility(botBrain, FireAndIce)
            unitHealingAtWell = nil 
        end
    end
end
behaviorLib.SplittingFireAndIceBehavior = {}
behaviorLib.SplittingFireAndIceBehavior["Utility"] = SplittingFireAndIceUtility
behaviorLib.SplittingFireAndIceBehavior["Execute"] = SplittingFireAndIceExecute
behaviorLib.SplittingFireAndIceBehavior["Name"] = "Splitting"
tinsert(behaviorLib.tBehaviors, behaviorLib.SplittingFireAndIceBehavior)

---------------------------------------------------
---------------------------------------------------
-- PetControl
---------------------------------------------------
---------------------------------------------------

--get unitTarget for pets
local function getUnitTarget(botBrain, unit) --done
    local tEnemyTeam = HoN.GetHeroes(core.enemyTeam)
    local unitMostDelicious = nil
    local nMostDeliciousPoints = 0
    --units close to unitTarget
    for id, enemy in pairs(tEnemyTeam) do
        if enemy:IsAlive() and not enemy:IsInvulnerable() then
            if core.CanSeeUnit(botBrain, enemy) then
                if Vector3.Distance2DSq(unit:GetPosition(), funcGetEnemyPosition (enemy)) < object.nHeroRange * object.nHeroRange then
                    local nDeliciousPoints = 10000 - enemy:GetHealth()
                    if nDeliciousPoints > nMostDeliciousPoints then
                        unitMostDelicious = enemy
                        nMostDeliciousPoints = nDeliciousPoints
                    end
                end
            end
        end
    end
    return unitMostDelicious
end

--get unitTarget for pets
local function getNearEnemy(botBtain, unit) --done
    local tEnemyTeam = HoN.GetHeroes(core.enemyTeam)
    local unitEnemy = nil
    local nEnemyDistance = 400000000
    --units close to unitTarget
    for id, enemy in pairs(tEnemyTeam) do
        if enemy:IsAlive() and not enemy:IsInvulnerable() then
            local distance = Vector3.Distance2DSq(unit:GetPosition(), funcGetEnemyPosition (enemy))
            if nEnemyDistance > distance then
                unitEnemy = enemy
                nEnemyDistance = distance
            end
        end
    end
    return unitEnemy, nEnemyDistance
end

---------------------------------------------------
-- Harass
---------------------------------------------------
local tUnitTarget={}
local function PetHarassUtilityFn(botBrain, unit)
    
    tUnitTarget[unit] = getUnitTarget(botBrain, unit)
    local unitTarget = tUnitTarget[unit]
    
    if not unitTarget then return 0 end
    
    local nUtility = 0 
    
    local abilBreath = unit:GetAbility(object.Breath)
    local abilFangs = unit:GetAbility(object.Fangs)
    
    if abilBreath and abilBreath:CanActivate() then
        nUtility = nUtility + 10
    end
    if abilFangs and abilFangs:CanActivate() then
        nUtility = nUtility +10
    end
    
    if core.CanSeeUnit(botBrain, unitTarget) then
        nUtility = nUtility + (1-unitTarget:GetHealthPercent()) * 50
    end
    
    return nUtility 
end

local function PetHarassExecuteFn(botBrain, unit)

    if unitHealingAtWell and unitHealingAtWell == unit then unitHealingAtWell = nil end
    
    --BotEcho(tostring(unit:GetTypeName()).." harass")
    local unitTarget = tUnitTarget[unit]
    if not unitTarget then return false end
    local vecMyPosition =unit:GetPosition()
    local vecTargetPosition = unitTarget:GetPosition()
    local distanceTargetSq = Vector3.Distance2DSq(vecMyPosition, vecTargetPosition)

    local bActionTaken = false
--Fire and Ice
        local Fire,Ice = getFireAndIce()
        --Fire and Ice Fangs
        if not bActionTaken then
            if core.CanSeeUnit(botBrain, unitTarget) then
                local abilFangs = unit:GetAbility(object.Fangs)
                local nRange = abilFangs:GetRange()
                if abilFangs:CanActivate() and distanceTargetSq <= nRange * nRange then
                    bActionTaken = core.OrderAbilityEntity(botBrain, abilFangs, unitTarget)
                end
            end
        end
                
        --Fire and Ice Breath       
        if not bActionTaken then
                local abilBreath = unit:GetAbility(object.Breath)
                local nRange = abilBreath:GetRange()
                if abilBreath:CanActivate() and distanceTargetSq <= nRange * nRange then
                    bActionTaken = core.OrderAbilityPosition(botBrain, abilBreath, vecTargetPosition)
                end
        end
        
        --Normal Attacks
        if not bActionTaken then
            if core.CanSeeUnit(botBrain, unitTarget) then
                bActionTaken = core.OrderAttack(botBrain, unit, unitTarget)
            else
                bActionTaken = core.OrderMoveToPosClamp(botBrain, unit, vecTargetPosition, false)
            end
        end
end

---------------------------------------------------
-- PetRetreat
---------------------------------------------------
local tUnitsInRange =   {}
local tUnitsInRangeTimestamp = {}
object.Timeschedule = 5*1000
local function getUnitsInRange(unit)
    
    local nUnitID = unit:GetUniqueID()
    local nNow = HoN.GetGameTime()
    local nLastTime = tUnitsInRangeTimestamp[nUnitID]
    if not nLastTime or nNow > nLastTime + object.Timeschedule then
        tUnitsInRangeTimestamp[nUnitID] = nNow
        tUnitsInRange[nUnitID] = HoN.GetUnitsInRadius(unit:GetPosition(), 1000, core.UNIT_MASK_ALIVE + core.UNIT_MASK_UNIT)
    end
    return tUnitsInRange[nUnitID]
end

local function PetRetreatUtilityFn(botBrain, unit)
    local bDebugEchos = false
    local nUtility =0
    local increasedThreat = object.nWolfThreatMultiplier[skills.FireAndIce:GetLevel()]
    
    
    local tUnitsNear = getUnitsInRange(unit)

    --Creep aggro
    local nCreepAggro = 0
    for id, unitNear in pairs(tUnitsNear) do
        local unitAggroTarget = unitNear:GetAttackTarget()
        if unitNear and unitNear:IsValid() and unitAggroTarget and unitAggroTarget:GetUniqueID() == unit:GetUniqueID() then
            nCreepAggro = nCreepAggro + 1
        end
    end
    
    nUtility  = nUtility + nCreepAggro * object.CreepThreatMultiplicator 
    
    local tEnemyTeam = HoN.GetHeroes(core.enemyTeam)
    
    --calculate the threat-value and increase utility value
    for id, enemy in pairs(tEnemyTeam) do
    --BotEcho (id.." Hero "..enemy:GetTypeName())
        nUtility = nUtility + funcGetThreatOfEnemy(unit, enemy) * increasedThreat
    end
    
    --calculate lifetime 
    local nDamageUtility, nTimeToLive = TimeToLiveUtilityFn(unit)
    
    nUtility = nUtility + nDamageUtility

    --Got hit by High-Dmg? Retreat for longer time to get out of here
    local SlowerDecayEntry = tSlowerDecay[unit]
    if  SlowerDecayEntry then
        if SlowerDecayEntry > nUtility + object.RetreatDifference then
            nUtility = SlowerDecayEntry - object.RetreatDifference
            tSlowerDecay[unit] = nUtility
        elseif nDamageUtility < object.RetreatDifference then
            tSlowerDecay[unit] = nil
        else 
            tSlowerDecay[unit] = nUtility
        end
    end 
    
    if nTimeToLive <= object.DeathTimer then
        tSlowerDecay[unit] = nUtility
    end
    --BotEcho("ReatreatUtil "..tostring(nUtility).."> 20")
    return nUtility
end

local function PetRetreatExecuteFn(botBrain, unit)

    if unitHealingAtWell and unitHealingAtWell == unit then unitHealingAtWell = nil end
    
    local vecPos = PositionSelfBackUp(unit)
    local vecunit = unit:GetPosition()
    if not unit or not unit:IsValid() or unit:IsChanneling() then return end
    
    
    local nUnitHP = unit:GetHealthPercent()
    if nUnitHP then
        if nUnitHP < 0.3 then 
            bForceRecombine = true
        end
    else 
        return 
    end
    
    local bActionTaken = false
    
    --Ice use Slow
    if unit == tOwnedUnits[Ice] then
        local abilIceBreath = unit:GetAbility(object.Breath)
        if abilIceBreath and abilIceBreath:CanActivate() then
            local nRange = abilIceBreath:GetRange()
            local unitEnemy, distanceIceSq = getNearEnemy(botBrain,unit)
            local vecEnemyPosition = unitEnemy and unitEnemy:GetPosition()
            if abilIceBreath:CanActivate() and distanceIceSq <= nRange * nRange and vecEnemyPosition then
                bActionTaken = core.OrderAbilityPosition(botBrain, abilIceBreath, vecEnemyPosition)
            end
        end
    end
    --BotEcho("Im gonna move now retreating")
    if not bActionTaken then
        core.OrderMoveToPos(botBrain, unit, vecPos, true)
    end
    
end

---------------------------------------------------
-- PetLaning
---------------------------------------------------
local function PetLaningUtilityFn(botBrain, unit)
    --no lanin support atm just idle there
    --[[
    if unitHealingAtWell and unitHealingAtWell ~= unit then
        return 20
    end
    --]]
    return 20
end

local function PetLaningExecuteFn(botBrain, unit)
    
    if unitHealingAtWell and unitHealingAtWell == unit then unitHealingAtWell = nil end
    
    local tUnitsNear = getUnitsInRange(unit)
    
    --BotEcho(tostring(unit:GetTypeName()).." laning")
    --Creep aggro
    local unitCreep =nil
    local targetHP = 10000
    for id, unitNear in pairs(tUnitsNear) do
        local unitHealth = unitNear:GetHealth()
        if unitNear and unitNear:IsValid() and unitHealth and unitHealth <= targetHP then
            unitCreep = unitNear
            targetHP = unitHealth
        end
    end
    if unitCreep then
        local nMyDamage = unit:GetAttackDamageMin()
        if nMyDamage >= targetHP then
            core.OrderAttack(botBrain, unit, unitCreep)
        else 
            core.OrderMoveToPos(botBrain, unit, unitCreep:GetPosition(), false)
        end
    end
end

---------------------------------------------------
-- PetHealing
---------------------------------------------------
local function PetHealAtWellUtilityFn(botBrain, unit)
    
        -- no unit avaible or another unit is going home
        if unit == nil or (unitHealingAtWell and unitHealingAtWell ~= unit) then return 0 end
        
        local nUtility = 0
        local hpPercent = unit:GetHealthPercent()
        local mpPercent = unit:GetManaPercent()
        
        --enough gold to buy
        if botBrain:GetGold() > GoldTreshold() then 
            nUtility = nUtility + 30 
        end
        
        if hpPercent < 0.90 then
            local wellPos = core.allyWell and core.allyWell:GetPosition() or Vector3.Create()
            local nDist = Vector3.Distance2D(wellPos, core.unitSelf:GetPosition())

            nUtility = nUtility+ behaviorLib.WellHealthUtility(hpPercent) + behaviorLib.WellProximityUtility(nDist)
        end
        
        if mpPercent < 0.90 then
            nUtility = nUtility + mpPercent * 10
        end
        
        if nUtility == 0 then
            unitHealingAtWell = nil
            bForceRecombine = true
        end
        
        return Clamp(nUtility,0,50)
end

local function PetHealAtWellExecuteFn(botBrain, unit)
    
    local wellPos = core.allyWell and core.allyWell:GetPosition() or PositionSelfBackUp()
    --local distanceWellSq =  Vector3.Distance2DSq(core.unitSelf:GetPosition(), wellPos)
    --BotEcho(tostring(unit:GetTypeName()).." healing")
    local success = core.OrderMoveToPosAndHold(botBrain, unit, wellPos, false)
    if success then
        unitHealingAtWell = unit
    end

    return success
end

---------------------------------------------------
-- Pet Controling 
---------------------------------------------------
local function GetAction (botBrain, unit) --done
    
    if unit == nil then return end
    
    local nMission = object.Recombining
    local nUtility = object.nRecombineTreshold
    local temp = 0
    
    --harass
    temp = PetHarassUtilityFn(botBrain, unit)
    if temp > nUtility then
        nMission = object.Ganking
        nUtility = temp
    end
    --retreat
    temp = PetRetreatUtilityFn(botBrain, unit)
    if temp > nUtility then
        nMission = object.Retreat
        nUtility = temp
    end
    --laning
    temp = PetLaningUtilityFn(botBrain, unit)
    if temp > nUtility then
        nMission = object.Farming
        nUtility = temp
    end
    --healing
    temp = PetHealAtWellUtilityFn(botBrain, unit)
    if temp > nUtility then
        nMission = object.Fountain
        nUtility = temp
    end
    
    return nMission
end

local function OrderMission(botBrain, unit, mission) --done

    if unit == nil then return end
    
    if mission == object.Farming then PetLaningExecuteFn(botBrain, unit)
    elseif mission == object.Ganking then PetHarassExecuteFn(botBrain, unit)
    elseif mission == object.Retreat then PetRetreatExecuteFn(botBrain, unit)
    elseif mission == object.Fountain then PetHealAtWellExecuteFn(botBrain, unit)
    else
        bForceRecombine = true
    end
end

local function PetControlUtility(botBrain) --do this till shopping or recombine

    return 40
end

local function PetControlExecute(botBrain)
    
    --get Fire and Ice
    local Fire,Ice = getFireAndIce()
    
    --mission for Fire
    local missionFire = GetAction(botBrain, Fire)
    OrderMission(botBrain, Fire, missionFire)
    
    --mission for Ice
    local missionIce = GetAction(botBrain, Ice)
    if missionFire == object.Farming and missionIce == object.Farming then
        missionIce = object.Recombining
    end
    OrderMission(botBrain, Ice, missionIce)
end
behaviorLib.PetControlBehavior = {}
behaviorLib.PetControlBehavior["Utility"] = PetControlUtility
behaviorLib.PetControlBehavior["Execute"] = PetControlExecute
behaviorLib.PetControlBehavior["Name"] = "PetControl"

---------------------------------------------------
---------------------------------------------------
-- Recombine
---------------------------------------------------
---------------------------------------------------
local function RecombineAtUnitLocation(botBrain, callingUnit)
    
    local bActionTaken = false
    
    local unitType = callingUnit:GetTypeName()
    
    local Fire,Ice = getFireAndIce()
    local distanceFireAndIceSq = Vector3.Distance2DSq(Fire:GetPosition(),Ice:GetPosition())
    
    local bFireToIceTeleport = Ice:GetTypeName() == unitType
    
    --Is one of the wolves teleporting? 
    if Fire:IsChanneling() or Ice:IsChanneling() then return end
    
    -- If we are far away from each other use teleport to get close
    if distanceFireAndIceSq > 1000 * 1000 then
        local FireTeleport = Fire:GetAbility(object.Teleport)
        local IceTeleport = Ice:GetAbility(object.Teleport)
        if FireTeleport:CanActivate() and bFireToIceTeleport then
            bActionTaken = core.OrderAbility(botBrain, FireTeleport)
        end
        if not bActionTaken and IceTeleport:CanActivate() then
            bActionTaken = core.OrderAbility(botBrain, IceTeleport)
        end
    end
    
    --In range to recombine? 
    if not bActionTaken then
        local Recombine = Ice:GetAbility(object.Recombine)
        if Recombine:CanActivate() then
            --doIt
            core.OrderAbility(botBrain, Recombine)
        else
            --Get close to each other
            core.OrderFollow(botBrain, Ice, Fire)
            core.OrderFollow(botBrain, Fire, Ice)
        end
    end

end

--Recombine utility
local function RecombineFireAndIceUtility(botBrain)
    
    if bForceRecombine then return 100 end 
    
    return 0
end

--Recombine Execute
local function RecombineFireAndIceExecute(botBrain)

    local Fire, Ice = getFireAndIce()
        --Is one of the wolves teleporting? 
    if not Fire or not Fire:IsValid() or Fire:IsChanneling() or Ice:IsChanneling() then return end
    
    local nFireHPPercent = Fire:GetHealthPercent()
    local nIceHPPercent = Ice:GetHealthPercent()
    if nFireHPPercent and nIceHPPercent then 
        if nFireHPPercent >= nIceHPPercent then
            RecombineAtUnitLocation(botBrain, Ice)
        else
            RecombineAtUnitLocation(botBrain, Fire)
        end
    end
end
behaviorLib.RecombineFireAndIceBehavior = {}
behaviorLib.RecombineFireAndIceBehavior["Utility"] = RecombineFireAndIceUtility
behaviorLib.RecombineFireAndIceBehavior["Execute"] = RecombineFireAndIceExecute
behaviorLib.RecombineFireAndIceBehavior["Name"] = "Recombine"


tHeroForm[bNormalForm] = behaviorLib.tBehaviors
--FireAndIce
tFireAndIceBehaviors = {}
tinsert(tFireAndIceBehaviors, behaviorLib.RecombineFireAndIceBehavior)
tinsert(tFireAndIceBehaviors, behaviorLib.PetControlBehavior)
tinsert(tFireAndIceBehaviors, behaviorLib.ShopBehavior)
tHeroForm[not bNormalForm] = tFireAndIceBehaviors

BotEcho('finished loading Gemini_main')
