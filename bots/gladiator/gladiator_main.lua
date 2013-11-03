----------------------------------------------------------------------
----------------------------------------------------------------------
--   ____    ___                __                __                   
--  /\  _`\ /\_ \              /\ \  __          /\ \__                
--  \ \ \L\_\//\ \      __     \_\ \/\_\     __  \ \ ,_\   ___   _ __  
--   \ \ \L_L \ \ \   /'__`\   /'_` \/\ \  /'__`\ \ \ \/  / __`\/\`'__\
--    \ \ \/, \\_\ \_/\ \L\.\_/\ \L\ \ \ \/\ \L\.\_\ \ \_/\ \L\ \ \ \/ 
--     \ \____//\____\ \__/.\_\ \___,_\ \_\ \__/.\_\\ \__\ \____/\ \_\ 
--      \/___/ \/____/\/__/\/_/\/__,_ /\/_/\/__/\/_/ \/__/\/___/  \/_/ 
----------------------------------------------------------------------
----------------------------------------------------------------------
-- GladiatorBot v0.1

--####################################################################
--####################################################################
--#                                                                 ##
--#                       Bot Initiation                            ##
--#                                                                 ##
--####################################################################
--####################################################################

local _G = getfenv(0)
local object = _G.object

object.myName = object:GetName()

object.bRunLogic         = true
object.bRunBehaviors    = true
object.bUpdates         = true
object.bUseShop         = true

object.bRunCommands     = true 
object.bMoveCommands     = true
object.bAttackCommands     = true
object.bAbilityCommands = true
object.bOtherCommands     = true

object.bReportBehavior = false
object.bDebugUtility = false

object.logger = {}
object.logger.bWriteLog = false
object.logger.bVerboseLog = false

object.core         = {}
object.eventsLib     = {}
object.metadata     = {}
object.behaviorLib     = {}
object.skills         = {}

runfile "bots/core.lua"
runfile "bots/botbraincore.lua"
runfile "bots/eventsLib.lua"
runfile "bots/metadata.lua"
runfile "bots/behaviorLib.lua"

local core, eventsLib, behaviorLib, metadata, skills = object.core, object.eventsLib, object.behaviorLib, object.metadata, object.skills

local print, ipairs, pairs, string, table, next, type, tinsert, tremove, tsort, format, tostring, tonumber, strfind, strsub
    = _G.print, _G.ipairs, _G.pairs, _G.string, _G.table, _G.next, _G.type, _G.table.insert, _G.table.remove, _G.table.sort, _G.string.format, _G.tostring, _G.tonumber, _G.string.find, _G.string.sub
local ceil, floor, pi, tan, atan, atan2, abs, cos, sin, acos, max, min, random
    = _G.math.ceil, _G.math.floor, _G.math.pi, _G.math.tan, _G.math.atan, _G.math.atan2, _G.math.abs, _G.math.cos, _G.math.sin, _G.math.acos, _G.math.max, _G.math.min, _G.math.random

local BotEcho, VerboseLog, BotLog = core.BotEcho, core.VerboseLog, core.BotLog
local Clamp = core.Clamp

local ravenor = {}


BotEcho(object:GetName()..' GladiatorBor is starting up ...')




--####################################################################
--####################################################################
--#                                                                 ##
--#                  bot constant definitions                       ##
--#                                                                 ##
--####################################################################
--####################################################################

-- hero_<hero>  to reference the internal hon name of a hero, Hero_Yogi ==wildsoul
object.heroName = 'Hero_Gladiator'


--   item buy order. internal names  
behaviorLib.StartingItems  = {"Item_LoggersHatchet", "Item_RunesOfTheBlight", "Item_IronBuckler"}
behaviorLib.LaneItems  = {"Item_Marchers", "Item_BloodChalice", "Item_Lifetube"}
behaviorLib.MidItems  = {"Item_EnhancedMarchers", "Item_Shield2", "Item_Stealth"} -- Item_Shield2 is Helm of the black legion, Item_LifeSteal5 is Abyssal Skull, Item_MagicArmor2 is Shamans Headdress
behaviorLib.LateItems  = {"Item_Critical1 4", "Item_Sasuke", "Item_Immunity"} -- Item_Freeze is Frostwolf Skull


-- skillbuild table, 0=q, 1=w, 2=e, 3=r, 4=attri
object.tSkills = {
    2, 0, 2, 0, 2,
    3, 2, 0, 1, 1, 
    3, 0, 1, 1, 4,
    3, 4, 4, 4, 4,
    4, 4, 4, 4, 4,
}

--melee weight overrides
behaviorLib.nCreepPushbackMul = 0.5
behaviorLib.nTargetPositioningMul = 0.6

-- bonus agression points if a skill/item is available for use

object.nPitfallUp = 18
object.nShowdownUp = 18
object.nFlagelationUp = 13
object.nCallUp = 40 

-- bonus agression points that are applied to the bot upon successfully using a skill/item

object.nPitfallUse = 13
object.nShowdownUse = 7 
object.nCallUse = 20

-- thresholds of aggression the bot must reach to use these abilities

object.nPifallThreshold = 33
object.nShowndownThreshold = 27
object.nCallThreshold = 40


--####################################################################
--####################################################################
--#                                                                 ##
--#   bot function overrides                                        ##
--#                                                                 ##
--####################################################################
--####################################################################

------------------------------
--     skills               --
------------------------------
-- @param: none
-- @return: none
function object:SkillBuild()
    core.VerboseLog("skillbuild()")

-- takes care at load/reload, <name_#> to be replaced by some convinient name.
    local unitSelf = self.core.unitSelf
    if  skills.abilPitfall == nil then
        skills.abilPitfall = unitSelf:GetAbility(0)
        skills.abilShowdown = unitSelf:GetAbility(1)
        skills.abilFlagelation = unitSelf:GetAbility(2)
        skills.abilCall = unitSelf:GetAbility(3)
        skills.abilAttributeBoost = unitSelf:GetAbility(4)
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

------------------------------------------------------
--            onthink override                      --
-- Called every bot tick, custom onthink code here  --
------------------------------------------------------
-- @param: tGameVariables
-- @return: none
function object:onthinkOverride(tGameVariables)
    self:onthinkOld(tGameVariables)

    -- custom code here
end
object.onthinkOld = object.onthink
object.onthink  = object.onthinkOverride

----------------------------------------------
--            oncombatevent override        --
-- use to check for infilictors (fe. buffs) --
----------------------------------------------
-- @param: eventdata
-- @return: none
function object:oncombateventOverride(EventData)
    self:oncombateventOld(EventData)
 
    local nAddBonus = 0
    
    if EventData.Type == "Ability" then
        if EventData.InflictorName == "Ability_Gladiator1" then
            nAddBonus = nAddBonus + object.nPitfallUse
        elseif EventData.InflictorName == "Ability_Gladiator3" then
            nAddBonus = nAddBonus + object.nShowdownUse
            object.unitShowdownTarget = EventData.TargetUnit
            object.vecShowdownPosition = EventData.TargetUnit:GetPosition()
            object.nShowdownDuration = HoN.GetGameTime() + 1000 * skills.abilShowdown:GetLevel()
        elseif EventData.InflictorName == "Ability_Gladiator4" then
            nAddBonus = nAddBonus + object.nCallUse
        end
    end
 
    if nAddBonus > 0 then
        -- BotEcho ("Total nAddBonus = ".. nAddBonus) 
        core.DecayBonus(self)
        core.nHarassBonus = core.nHarassBonus + nAddBonus
    end
end
-- override combat event trigger function.
object.oncombateventOld = object.oncombatevent
object.oncombatevent     = object.oncombateventOverride

------------------------------------------------------
--            calculate utility Values              --
-- change utility according to usable spells here   --
------------------------------------------------------
-- @tparam IUnitEntity hero
-- @treturn number
local function AbilitiesUpUtilityFn(hero)
    local bDebugEchos = false
    
    local nUtil = 0
    local unitSelf = core.unitSelf

    if skills.abilPitfall:CanActivate() then
        nUtil = nUtil + object.nPitfallUp
    end
 
    if skills.abilShowdown:CanActivate() then
        nUtil = nUtil + object.nShowdownUp
    end
    
    if skills.abilCall:CanActivate() then
        nUtil = nUtil + object.nCallUp
    end

    if skills.abilFlagelation:GetLevel() > 0 and skills.abilFlagelation:GetActualRemainingCooldownTime() == 0 then
        nUtil = nUtil + object.nFlagelationUp
    end
    
    if bDebugEchos then BotEcho(" HARASS - abilitiesUp: "..nUtil) end
    
    return nUtil
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
createRelativeMovementTable("GladPitfall") -- for harrass meteor

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

------------------------------------------------------
--            customharassutility override          --
-- change utility according to usable spells here   --
------------------------------------------------------
-- @tparam IUnitEntity hero
-- @treturn number
local function CustomHarassUtilityOverride(hero)
    local nUtility = AbilitiesUpUtilityFn(hero)
    --return 0
    return nUtility
end
behaviorLib.CustomHarassUtility = CustomHarassUtilityOverride   


object.unitShowdownTarget = nil
object.vecShowdownPosition = nil
object.nShowdownDuration = HoN.GetGameTime()  

object.vecPitfallPosition = nil
object.nPitfallDuration = HoN.GetGameTime()

object.vecCallPosition = nil
object.nCallTravelTime = 2666
object.nCallImpactTime = HoN.GetGameTime()

function object.GetCallDistanceSq()
    -- body
    return 1000 * 1000
end

--------------------------------------------------------------
--                    Harass Behavior                       --
-- All code how to use abilities against enemies goes here  --
--------------------------------------------------------------
-- @param botBrain: CBotBrain
-- @return: none
--

local function HarassHeroExecuteOverride(botBrain)
    local bDebugEchos = false
    local bUseOldHarass = false

    if bDebugEchos then BotEcho("Executing custom harras behavior") end
    
    local unitTarget = behaviorLib.heroTarget
    local unitSelf = core.unitSelf

    if unitTarget == nil then
        return object.harassExecuteOld(botBrain) --Target is invalid, move on to the next behavior
    end

    if bUseOldHarass then
        return object.harassExecuteOld(botBrain)
    end
    
    local vecMyPosition = unitSelf:GetPosition() 
    local nAttackRange = core.GetAbsoluteAttackRangeToUnit(unitSelf, unitTarget)
    local nMyExtraRange = core.GetExtraRange(unitSelf)
    
    local vecTargetPosition = unitTarget:GetPosition()
    local nTargetExtraRange = core.GetExtraRange(unitTarget)
    local nTargetDistanceSq = Vector3.Distance2DSq(vecMyPosition, vecTargetPosition)   
    local bTargetRooted = unitTarget:IsStunned() or unitTarget:IsImmobilized() or unitTarget:GetMoveSpeed() < 200
    local nAttackRangeSq = core.GetAbsoluteAttackRangeToUnit(unitSelf, unitTarget, true)
    
    local nLastHarassUtility = behaviorLib.lastHarassUtil
    local bCanSee = core.CanSeeUnit(botBrain, unitTarget)    
    local bActionTaken = false

    -- this needs to be called every cycle to ensure up to date values for relative movement
    local nPredictPitfall = 8
    local vecRelativeMov = relativeMovement("GladPitfall", vecTargetPosition) * nPredictPitfall
    
    --- Insert abilities code here, set bActionTaken to true 
    --- if an ability command has been given successfully
    
    --since we are using an old pointer, ensure we can still see the target for entity targeting
    if core.CanSeeUnit(botBrain, unitTarget) then
        if not bActionTaken and not bTargetRooted then
            -- Showdown
            if nLastHarassUtility > botBrain.nShowndownThreshold then
                local abilShowdown = skills.abilShowdown
                if HoN.GetGameTime() > object.nShowdownDuration then
                    if abilShowdown:CanActivate() and not unitSelf:HasState("State_Gladiator_Ability3_Return") then
                        local nRange = abilShowdown:GetRange()
                        if nTargetDistanceSq < (nRange * nRange) then
                            bActionTaken = core.OrderAbilityEntity(botBrain, abilShowdown, unitTarget)
                            object.unitShowdownTarget = unitTarget
                            object.vecShowdownPosition = unitTarget:GetPosition()
                            object.nShowdownDuration = HoN.GetGameTime() + 1000 * abilShowdown:GetLevel()
                        end
                    end
                end
            end
        end

        if not bActionTaken then
            -- Pitfall
            if nLastHarassUtility > botBrain.nPifallThreshold then
                local abilPitfall = skills.abilPitfall

                if abilPitfall:CanActivate() then
                    local nRange = abilPitfall:GetRange()
                    if object.vecShowdownPosition ~= nil and HoN.GetGameTime() < object.nShowdownDuration - 700 then
                        if HoN.GetGameTime() > object.nShowdownDuration - 1200 then
                            -- there is an active showdown, so we can cast pitfall on top
                            local vecShowdownPosition = object.vecShowdownPosition
                            local nShowdownDistanceSq = Vector3.Distance2DSq(vecMyPosition, vecShowdownPosition)
                            if nShowdownDistanceSq < (nRange * nRange) then
                                bActionTaken = core.OrderAbilityPosition(botBrain, abilPitfall, vecShowdownPosition, false)
                                object.vecPitfallPosition = vecShowdownPosition
                                object.nPitfallDuration = HoN.GetGameTime() + 1500
                            end
                        end
                    else
                        -- no active showdown, cast pitfall on the target
                        if nTargetDistanceSq < (nRange * nRange) then
                            bActionTaken = core.OrderAbilityPosition(botBrain, abilPitfall, vecTargetPosition + vecRelativeMov, false)
                            object.vecPitfallPosition = vecTargetPosition
                            object.nPitfallDuration = HoN.GetGameTime() + 1500
                        end
                    end
                end
            end

            -- Call to Arms
            if nLastHarassUtility > botBrain.nCallThreshold then
                local abilCall = skills.abilCall

                if abilCall:CanActivate() then
                    local nCallDistanceSq = 1000 * 1000
                    local nCurrentGameTime = HoN.GetGameTime()

                    if object.vecShowdownPosition ~= nil and nCurrentGameTime < object.nShowdownDuration - 1800 then
                        if nCurrentGameTime > object.nShowdownDuration - object.nCallTravelTime then
                            local vecShowdownPosition = object.vecShowdownPosition
                            local nCurrentDistanceSq = Vector3.Distance2DSq(vecMyPosition, vecShowdownPosition)

                            if (nCurrentDistanceSq < nCallDistanceSq + 200 * 200) and (nCurrentDistanceSq > nCallDistanceSq - 200 * 200) then
                                local vecToward = Vector3.Normalize(vecShowdownPosition - vecMyPosition)
                                local vecAbilityTarget = vecMyPosition + vecToward * 1000

                                bActionTaken = core.OrderAbilityPosition(botBrain, abilCall, vecAbilityTarget)
                                object.vecCallPosition = vecAbilityTarget
                                object.nCallImpactTime = nCurrentGameTime + object.nCallTravelTime
                            end
                        end
                    elseif object.vecPitfallPosition ~= nil and nCurrentGameTime < (object.nPitfallDuration + 1530) -  1800 then
                        --BotEcho("There is an active pitfall, try to target pitfall location")
                        if nCurrentGameTime > (object.nPitfallDuration + 1530) - object.nCallTravelTime then
                            local vecPitfallPosition = object.vecPitfallPosition
                            local nCurrentDistanceSq = Vector3.Distance2DSq(vecMyPosition, vecPitfallPosition)

                            if (nCurrentDistanceSq < nCallDistanceSq + 200 * 200) and (nCurrentDistanceSq > nCallDistanceSq - 200 * 200) then
                                local vecToward = Vector3.Normalize(vecPitfallPosition - vecMyPosition)
                                local vecAbilityTarget = vecMyPosition + vecToward * 1000

                                bActionTaken = core.OrderAbilityPosition(botBrain, abilCall, vecAbilityTarget)
                                object.vecCallPosition = vecAbilityTarget
                                object.nCallImpactTime = nCurrentGameTime + object.nCallTravelTime
                            end
                        end
                    else
                        local nCurrentDistanceSq = Vector3.Distance2DSq(vecMyPosition, vecTargetPosition)

                        if (nCurrentDistanceSq < nCallDistanceSq + 200 * 200) and (nCurrentDistanceSq > nCallDistanceSq - 200 * 200) then
                            local vecToward = Vector3.Normalize(vecTargetPosition - vecMyPosition)
                            local vecAbilityTarget = vecMyPosition + vecToward * 1000

                            bActionTaken = core.OrderAbilityPosition(botBrain, abilCall, vecAbilityTarget)
                            object.vecCallPosition = vecAbilityTarget
                            object.nCallImpactTime = nCurrentGameTime + object.nCallTravelTime
                        end
                    end
                end
            end
        end
    end

    
    if not bActionTaken then
        if bDebugEchos then BotEcho("No action taken, fall back to default harras execute") end
        return object.harassExecuteOld(botBrain)
    end 
end
-- overload the behaviour stock function with custom 
object.harassExecuteOld = behaviorLib.HarassHeroBehavior["Execute"]
behaviorLib.HarassHeroBehavior["Execute"] = HarassHeroExecuteOverride

----------------------------------------------------
-- function: IsInBag
-- Checks if the IEntityItem is in the Bot's Inventory
-- Takes IEntityItem, Returns Boolean
----------------------------------------------------
local function IsInBag(item)
    local unitSelf = core.unitSelf
    local sItemName = item:GetName()
    if unitSelf then
        local unitInventory = unitSelf:GetInventory(true)
        if unitInventory then
            for slot = 1, 6, 1 do
                local curItem = unitInventory[slot]
                if curItem then
                    if curItem:GetName() == sItemName and not curItem:IsRecipe() then
                        return true
                    end
                end
            end
        end
    end
    return false
end

----------------------------------------------------
-- function: BloodChaliceUtility
-- @treturn Number number from 0-100 indicating if we want to use blood chalice
----------------------------------------------------
function behaviorLib.BloodChaliceUtility(botBrain)
    local nUtil = 0

    core.FindItems(botBrain)
    local itemChalice = core.itemChalice

    if itemChalice and itemChalice:CanActivate() and IsInBag(itemChalice) then
        local unitSelf = core.unitSelf
        local nHealth = unitSelf:GetHealth()
        local nHealthPercent = unitSelf:GetHealthPercent()
        local nManaPercent = unitSelf:GetManaPercent()
        local nMissingMana = unitSelf:GetMaxMana() - unitSelf:GetMana()

        if nHealthPercent > nManaPercent and nMissingMana > 85 and nHealth > 300 then
            nUtil = nUtil + 33
        end
    end

    return nUtil
end

----------------------------------------------------
-- function: BloodChaliceExecute
----------------------------------------------------
function behaviorLib.BloodChaliceExecute(botBrain)
    local unitSelf = core.unitSelf

    local bActionTaken = false

    core.FindItems(botBrain)
    local itemChalice = core.itemChalice

    if itemChalice and itemChalice:CanActivate() and IsInBag(itemChalice) then
        local unitSelf = core.unitSelf
        local nHealth = unitSelf:GetHealth()
        local nHealthPercent = unitSelf:GetHealthPercent()
        local nManaPercent = unitSelf:GetManaPercent()
        local nMissingMana = unitSelf:GetMaxMana() - unitSelf:GetMana()

        if nHealthPercent > nManaPercent and nMissingMana > 85 and nHealth > 300 then
            bActionTaken = core.OrderItemClamp(botBrain, unitSelf, itemChalice, false)
        end
    end

    return bActionTaken
end

behaviorLib.BloodChaliceBehavior = {}
behaviorLib.BloodChaliceBehavior["Utility"] = behaviorLib.BloodChaliceUtility
behaviorLib.BloodChaliceBehavior["Execute"] = behaviorLib.BloodChaliceExecute
behaviorLib.BloodChaliceBehavior["Name"] = "BloodChaliceBehavior"
tinsert(behaviorLib.tBehaviors, behaviorLib.BloodChaliceBehavior)

----------------------------------
--  AttackCreeps behavior
--
--  Utility: 21 if deny, 24 if ck, only if it predicts it can kill in one hit
--  Execute: Attacks target
----------------------------------

function behaviorLib.GetCreepAttackTarget(botBrain, unitEnemyCreep, unitAllyCreep)
    local bDebugEchos = false
    -- no predictive last hitting, just wait and react when they have 1 hit left
    -- prefers LH over deny

    local unitSelf = core.unitSelf
    local nDamageMin = unitSelf:GetFinalAttackDamageMin()
    local vecSelfPosition = unitSelf:GetPosition()
    local nMoveSpeed = unitSelf:GetMoveSpeed()
    --local nDamageAverage = core.GetFinalAttackDamageAverage(unitSelf)
    
    core.FindItems(botBrain)
    if core.itemHatchet then
        nDamageMin = nDamageMin * core.itemHatchet.creepDamageMul
    end 
    
    -- [Difficulty: Easy] Make bots worse at last hitting
    if core.nDifficulty == core.nEASY_DIFFICULTY then
        nDamageMin = nDamageMin * 1.35
    end

    local nDamageHatchet = nDamageMin

    local abilFlagelation = skills.abilFlagelation

    if abilFlagelation:GetLevel() > 0 and abilFlagelation:GetActualRemainingCooldownTime() == 0 then
        nDamageMin = nDamageMin + 15 * abilFlagelation:GetLevel()
    end

    if unitEnemyCreep and core.CanSeeUnit(botBrain, unitEnemyCreep) then

        local nTargetHealth = unitEnemyCreep:GetHealth()
        local tNearbyAllyCreeps = core.localUnits['AllyCreeps']
        local tNearbyAllyTowers = core.localUnits['AllyTowers']
        local nExpectedCreepDamage = 0
        local nExpectedTowerDamage = 0

        local vecTargetPos = unitEnemyCreep:GetPosition()

        -- Calculate our travel time to the creep
        local nTravelTime = core.TimeToPosition(vecSelfPosition, vecTargetPos, nMoveSpeed)
        local nTimeToAttack = (nTravelTime + unitSelf:GetAdjustedAttackActionTime()) / 1000
        if bDebugEchos then BotEcho ("Time to attack: " .. nTimeToAttack ) end 

        --Determine the damage expected on the creep by other creeps
        for i, unitCreep in pairs(tNearbyAllyCreeps) do
            if unitCreep:GetAttackTarget() == unitEnemyCreep then
                local nCreepAttacks = math.floor(nTimeToAttack / unitCreep:GetAttackSpeed())
                if not unitCreep:IsAttackReady() and nCreepAttacks > 0 then nCreepAttacks = nCreepAttacks - 1 end
                nExpectedCreepDamage = nExpectedCreepDamage + unitCreep:GetFinalAttackDamageMin() * nCreepAttacks
            end
        end

        --Determine the damage expected on the creep by towers
        for i, unitTower in pairs(tNearbyAllyTowers) do
            if unitTower:GetAttackTarget() == unitEnemyCreep then
                local nTowerAttacks = math.floor(nTimeToAttack / unitTower:GetAttackSpeed())
                if not unitTower:IsAttackReady() and nTowerAttacks > 0 then nTowerAttacks = nTowerAttacks - 1 end
                nExpectedTowerDamage = nExpectedTowerDamage + unitTower:GetFinalAttackDamageMin() * nTowerAttacks
            end
        end
        
        -- Only attack if, by the time our attack reaches the target
        -- the damage done by other sources brings the target's health
        -- below our minimum damage
        if nDamageMin >= (nTargetHealth - nExpectedCreepDamage - nExpectedTowerDamage) then
            if bDebugEchos then BotEcho("Returning an enemy") end
            return unitEnemyCreep
        else
            -- Check if we can kill the target with loggers hatchet
            core.FindItems(botBrain)
            local itemHatchet = core.itemHatchet
            if (itemHatchet and itemHatchet:CanActivate() and IsInBag(itemHatchet)) then
                -- Loggers Hatchet can be used. Since we are a melee hero this might be the safer choice
                local nProjectileSpeed = 900
                local nProjectileTravelTime = Vector3.Distance2D(vecSelfPosition, vecTargetPos) / nProjectileSpeed
                if bDebugEchos then BotEcho ("Hatchet projectile travel time: " .. nProjectileTravelTime ) end 
                
                --Determine the damage expected on the creep by other creeps
                for i, unitCreep in pairs(tNearbyAllyCreeps) do
                    if unitCreep:GetAttackTarget() == unitEnemyCreep then
                        local nCreepAttacks = math.floor(nProjectileTravelTime / unitCreep:GetAttackSpeed())
                        if not unitCreep:IsAttackReady() and nCreepAttacks > 0 then nCreepAttacks = nCreepAttacks - 1 end
                        nExpectedCreepDamage = nExpectedCreepDamage + unitCreep:GetFinalAttackDamageMin() * nCreepAttacks
                    end
                end

                --Determine the damage expected on the creep by towers
                for i, unitTower in pairs(tNearbyAllyTowers) do
                    if unitTower:GetAttackTarget() == unitEnemyCreep then
                        local nTowerAttacks = math.floor(nProjectileTravelTime / unitTower:GetAttackSpeed())
                        if not unitTower:IsAttackReady() and nTowerAttacks > 0 then nTowerAttacks = nTowerAttacks - 1 end
                        nExpectedTowerDamage = nExpectedTowerDamage + unitTower:GetFinalAttackDamageMin() * nTowerAttacks
                    end
                end
                
                --Only attack if, by the time our attack reaches the target
                -- the damage done by other sources brings the target's health
                -- below our minimum damage
                if nDamageHatchet >= (nTargetHealth - nExpectedCreepDamage - nExpectedTowerDamage) then
                    if bDebugEchos then BotEcho("Returning an enemy") end
                    return unitEnemyCreep
                end
            end
        end        
    end

    if unitAllyCreep then
        local nTargetHealth = unitAllyCreep:GetHealth()
        local tNearbyEnemyCreeps = core.localUnits['EnemyCreeps']
        local tNearbyEnemyTowers = core.localUnits['EnemyTowers']
        local nExpectedCreepDamage = 0
        local nExpectedTowerDamage = 0

        local sName = core.GetCurrentBehaviorName(botBrain)
        if core.teamBotBrain.nPushState == 2 then
            return nil
        end

        local vecTargetPos = unitAllyCreep:GetPosition()
        local nTravelTime = core.TimeToPosition(vecSelfPosition, vecTargetPos, nMoveSpeed)
        local nTimeToAttack = (nTravelTime + unitSelf:GetAdjustedAttackActionTime()) / 1000
        if bDebugEchos then BotEcho ("Time to attack: " .. nTimeToAttack ) end 
        
        --Determine the damage expected on the creep by other creeps
        for i, unitCreep in pairs(tNearbyEnemyCreeps) do
            if unitCreep:GetAttackTarget() == unitAllyCreep then
                local nCreepAttacks = math.floor(nTimeToAttack / unitCreep:GetAttackSpeed())
                if not unitCreep:IsAttackReady() and nCreepAttacks > 0 then nCreepAttacks = nCreepAttacks - 1 end
                nExpectedCreepDamage = nExpectedCreepDamage + unitCreep:GetFinalAttackDamageMin() * nCreepAttacks
            end
        end

        --Determine the damage expected on the creep by towers
        for i, unitTower in pairs(tNearbyEnemyTowers) do
            if unitTower:GetAttackTarget() == unitAllyCreep then
                local nTowerAttacks = math.floor(nTimeToAttack / unitTower:GetAttackSpeed())
                if not unitTower:IsAttackReady() and nTowerAttacks > 0 then nTowerAttacks = nTowerAttacks - 1 end
                nExpectedTowerDamage = nExpectedTowerDamage + unitTower:GetFinalAttackDamageMin() * nTowerAttacks
            end
        end
        
        --Only attack if, by the time our attack reaches the target
        -- the damage done by other sources brings the target's health
        -- below our minimum damage
        if nDamageMin >= (nTargetHealth - nExpectedCreepDamage - nExpectedTowerDamage) then
            local bActuallyDeny = true
            
            --[Difficulty: Easy] Don't deny
            if core.nDifficulty == core.nEASY_DIFFICULTY then
                bActuallyDeny = false
            end         
            
            -- [Tutorial] Hellbourne *will* deny creeps after shit gets real
            if core.bIsTutorial and core.bTutorialBehaviorReset == true and core.myTeam == HoN.GetHellbourneTeam() then
                bActuallyDeny = true
            end
            
            if bActuallyDeny then
                if bDebugEchos then BotEcho("Returning an ally") end
                return unitAllyCreep
            end
        end
    end

    return nil
end

---------------------------------------------
-- Attack Creeps Override
---------------------------------------------

local function AttackCreepsExecuteCustom(botBrain)
    local bDebugEchos = false

    local unitSelf = core.unitSelf
    local unitCreepTarget = core.unitCreepTarget
    local bActionTaken = false
    local nMoveSpeed = unitSelf:GetMoveSpeed()
    local bActionTaken = false

    if unitCreepTarget and core.CanSeeUnit(botBrain, unitCreepTarget) then      
        --Get info about the target we are about to attack

        local vecSelfPos = unitSelf:GetPosition()
        local vecTargetPos = unitCreepTarget:GetPosition()
        local nDistSq = Vector3.Distance2DSq(vecSelfPos, vecTargetPos)
        local nAttackRangeSq = core.GetAbsoluteAttackRangeToUnit(unitSelf, currentTarget, true)       
        local nTargetHealth = unitCreepTarget:GetHealth()
        local nDamageMin = unitSelf:GetFinalAttackDamageMin()
        local bUseHatchet = false

        local sName = core.GetCurrentBehaviorName(botBrain)
        local bIsPushing = false

        if core.teamBotBrain.nPushState == 2 then
            bIsPushing = true
            nDamageMin = nDamageMin * 3
        end

        core.FindItems(botBrain)
        local itemHatchet = core.itemHatchet
        if core.itemHatchet then
            nDamageMin = nDamageMin * core.itemHatchet.creepDamageMul
        end 
        local nDamageHatchet = nDamageMin

        local nProjectileTravelTime = 0
        local nTravelTime = core.TimeToPosition(vecSelfPos, vecTargetPos, nMoveSpeed)
        nProjectileTravelTime = (nTravelTime + unitSelf:GetAdjustedAttackActionTime()) / 1000

        local abilFlagelation = skills.abilFlagelation

        if abilFlagelation:GetLevel() > 0 and abilFlagelation:GetActualRemainingCooldownTime() == 0 then
            nDamageMin = nDamageMin + 15 * abilFlagelation:GetLevel()
        end

        --Get projectile info
        if bDebugEchos then BotEcho ("Time to attack: " .. nProjectileTravelTime ) end 
        
        local nExpectedCreepDamage = 0
        local nExpectedTowerDamage = 0
        local tNearbyAttackingCreeps = nil
        local tNearbyAttackingTowers = nil

        --Get the creeps and towers on the opposite team
        -- of our target
        if unitCreepTarget:GetTeam() == unitSelf:GetTeam() then
            tNearbyAttackingCreeps = core.localUnits['EnemyCreeps']
            tNearbyAttackingTowers = core.localUnits['EnemyTowers']
        else
            tNearbyAttackingCreeps = core.localUnits['AllyCreeps']
            tNearbyAttackingTowers = core.localUnits['AllyTowers']
        end
    
        --Determine the damage expected on the creep by other creeps
        for i, unitCreep in pairs(tNearbyAttackingCreeps) do
            if unitCreep:GetAttackTarget() == unitCreepTarget then
                local nCreepAttacks = math.floor(nProjectileTravelTime / unitCreep:GetAttackSpeed())
                if not unitCreep:IsAttackReady() and nCreepAttacks > 0 then nCreepAttacks = nCreepAttacks - 1 end
                nExpectedCreepDamage = nExpectedCreepDamage + unitCreep:GetFinalAttackDamageMin() * nCreepAttacks
            end
        end
    
        --Determine the damage expected on the creep by other towers
        for i, unitTower in pairs(tNearbyAttackingTowers) do
            if unitTower:GetAttackTarget() == unitCreepTarget then
                local nTowerAttacks = math.floor(nProjectileTravelTime / unitTower:GetAttackSpeed())
                    if not unitTower:IsAttackReady() and nTowerAttacks > 0 then nTowerAttacks = nTowerAttacks - 1 end
                nExpectedTowerDamage = nExpectedTowerDamage + unitTower:GetFinalAttackDamageMin() * nTowerAttacks
            end
        end

        --BotEcho(format("nExpectedCreepDamage: %i - nExpectedTowerDamage: %i", nExpectedCreepDamage, nExpectedTowerDamage))
    
        -- Only attack if, by the time our attack reaches the target
        -- the damage done by other sources brings the target's health
        -- below our minimum damage, and we are in range and can attack right now
        if nDistSq < nAttackRangeSq and unitSelf:IsAttackReady() and (nDamageMin >= (nTargetHealth - nExpectedCreepDamage - nExpectedTowerDamage) or bIsPushing) then
            if bDebugEchos then BotEcho ("Attacking target") end
            bActionTaken = core.OrderAttackClamp(botBrain, unitSelf, unitCreepTarget)
        elseif (itemHatchet and itemHatchet:CanActivate() and IsInBag(itemHatchet)) then
            -- maybe we can kill the target with hatchet
            local nProjectileSpeed = 900
            nProjectileTravelTime = Vector3.Distance2D(vecSelfPos, vecTargetPos) / nProjectileSpeed

            --Get projectile info
            if bDebugEchos then BotEcho ("Hatchet Projectile travel time: " .. nProjectileTravelTime ) end 
            
            local nExpectedCreepDamage = 0
            local nExpectedTowerDamage = 0
            local tNearbyAttackingCreeps = nil
            local tNearbyAttackingTowers = nil

            --Get the creeps and towers on the opposite team
            -- of our target
            if unitCreepTarget:GetTeam() == unitSelf:GetTeam() then
                tNearbyAttackingCreeps = core.localUnits['EnemyCreeps']
                tNearbyAttackingTowers = core.localUnits['EnemyTowers']
            else
                tNearbyAttackingCreeps = core.localUnits['AllyCreeps']
                tNearbyAttackingTowers = core.localUnits['AllyTowers']
            end
        
            --Determine the damage expected on the creep by other creeps
            for i, unitCreep in pairs(tNearbyAttackingCreeps) do
                if unitCreep:GetAttackTarget() == unitCreepTarget then
                    local nCreepAttacks = math.floor(nProjectileTravelTime / unitCreep:GetAttackSpeed())
                    if not unitCreep:IsAttackReady() and nCreepAttacks > 0 then nCreepAttacks = nCreepAttacks - 1 end
                    nExpectedCreepDamage = nExpectedCreepDamage + unitCreep:GetFinalAttackDamageMin() * nCreepAttacks
                end
            end
        
            --Determine the damage expected on the creep by other towers
            for i, unitTower in pairs(tNearbyAttackingTowers) do
                if unitTower:GetAttackTarget() == unitCreepTarget then
                    local nTowerAttacks = math.floor(nProjectileTravelTime / unitTower:GetAttackSpeed())
                    if not unitTower:IsAttackReady() and nTowerAttacks > 0 then nTowerAttacks = nTowerAttacks - 1 end
                    nExpectedTowerDamage = nExpectedTowerDamage + unitTower:GetFinalAttackDamageMin() * nTowerAttacks
                end
            end

            nAttackRangeSq = 600 * 600

            -- Only attack if, by the time our attack reaches the target
            -- the damage done by other sources brings the target's health
            -- below our minimum damage, and we are in range and can attack right now
            if nDistSq < nAttackRangeSq and unitSelf:IsAttackReady() and (nDamageHatchet >= (nTargetHealth - nExpectedCreepDamage - nExpectedTowerDamage) or bIsPushing) then
                if bDebugEchos then BotEcho ("Attacking target with hatchet") end
                bActionTaken = core.OrderItemEntityClamp(botBrain, unitSelf, itemHatchet, unitCreepTarget)
            end
        else
            --BotEcho("MOVIN OUT")
            local vecDesiredPos = core.AdjustMovementForTowerLogic(vecTargetPos)
            bActionTaken = core.OrderMoveToPosAndHoldClamp(botBrain, unitSelf, vecDesiredPos, false)
        end
    else
        return false
    end

    if not bActionTaken then
        --BotEcho("No action yet, trying old behavior")
        return object.AttackCreepsExecuteOld(botBrain)
    end 
end

object.AttackCreepsExecuteOld = behaviorLib.AttackCreepsBehavior["Execute"]
behaviorLib.AttackCreepsBehavior["Execute"] = AttackCreepsExecuteCustom

----------------------------------
--  FindItems Override
----------------------------------
local function funcFindItemsOverride(botBrain)
    local bUpdated = object.FindItemsOld(botBrain)

    if core.itemBattery ~= nil and not core.itemBattery:IsValid() then
        core.itemBattery = nil
    end

    if core.itemChalice ~= nil and not core.itemChalice:IsValid() then
        core.itemChalice = nil
    end
    
    if bUpdated then
        --only update if we need to
        if core.itemBattery and core.itemChalice then
            return
        end
        
        local inventory = core.unitSelf:GetInventory(true)
        for slot = 1, 12, 1 do
            local curItem = inventory[slot]
            if curItem then
                if core.itemBattery == nil and (curItem:GetName() == "Item_ManaBattery" or curItem:GetName() == "Item_PowerSupply") then
                    core.itemBattery = core.WrapInTable(curItem)
                end
                if core.itemChalice == nil and (curItem:GetName() == "Item_BloodChalice") then
                    core.itemChalice = core.WrapInTable(curItem)
                end
            end
        end
    end
end
object.FindItemsOld = core.FindItems
core.FindItems = funcFindItemsOverride