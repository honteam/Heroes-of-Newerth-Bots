-- SilhouetteBot v1.0

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
object.eventsLib    = {}
object.metadata     = {}
object.behaviorLib  = {}
object.skills       = {}

runfile "bots/core.lua"
runfile "bots/botbraincore.lua"
runfile "bots/eventslib.lua"
runfile "bots/metadata.lua"
runfile "bots/behaviorlib.lua"
runfile "bots/illusions.lua"

local core, eventsLib, behaviorLib, metadata, skills = object.core, object.eventsLib, object.behaviorLib, object.metadata, object.skills

local print, ipairs, pairs, string, table, next, type, tinsert, tremove, tsort, format, tostring, tonumber, strfind, strsub
    = _G.print, _G.ipairs, _G.pairs, _G.string, _G.table, _G.next, _G.type, _G.table.insert, _G.table.remove, _G.table.sort, _G.string.format, _G.tostring, _G.tonumber, _G.string.find, _G.string.sub
local ceil, floor, pi, tan, atan, atan2, abs, cos, sin, acos, max, random, sqrt
    = _G.math.ceil, _G.math.floor, _G.math.pi, _G.math.tan, _G.math.atan, _G.math.atan2, _G.math.abs, _G.math.cos, _G.math.sin, _G.math.acos, _G.math.max, _G.math.random, _G.math.sqrt

local BotEcho, VerboseLog, BotLog = core.BotEcho, core.VerboseLog, core.BotLog
local Clamp = core.Clamp

local sqrtTwo = math.sqrt(2)
local gold=0

BotEcho('loading silhouette_main...')

--####################################################################
--####################################################################
--#                                                                 ##
--#                  bot constant definitions                       ##
--#                                                                 ##
--####################################################################
--####################################################################

-- hero_<hero>  to reference the internal hon name of a hero, Hero_Yogi ==wildsoul
object.heroName = 'Hero_Silhouette'


--   item buy order. internal names  
behaviorLib.StartingItems  = {"Item_RunesOfTheBlight", "Item_HealthPotion", "2 Item_MinorTotem", "Item_DuckBoots"}
behaviorLib.LaneItems  = {"Item_Marchers", "Item_ManaRegen3", "Item_Regen"}
behaviorLib.MidItems  = {"Item_Steamboots", "Item_Protect"}
behaviorLib.LateItems  = {"Item_StrengthAgility", "Item_Weapon3", "Item_Immunity"}


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
    core.VerboseLog("SkillBuild()")

    local unitSelf = self.core.unitSelf
    if  skills.abilLotus == nil then
        skills.abilLotus = unitSelf:GetAbility(0)
        skills.abilGrapple = unitSelf:GetAbility(1)
        skills.abilSalvo = unitSelf:GetAbility(2)
        skills.abilShadow = unitSelf:GetAbility(3)
        skills.abilAttributeBoost = unitSelf:GetAbility(4)
        skills.abilGo = unitSelf:GetAbility(5)
        skills.abilPull = unitSelf:GetAbility(6)
        skills.abilSwap = unitSelf:GetAbility(7)
    end
    if unitSelf:GetAbilityPointsAvailable() <= 0 then
        return
    end
    
    
    -- automatically levels stats in the end
    -- stats have to be leveld manually if needed inbetween
    tSkills ={
                2, 0, 0, 1, 0,
                2, 0, 2, 2, 3, 
                3, 1, 1, 1, 4,
                3
            }
    
    local nLev = unitSelf:GetLevel()
    local nLevPts = unitSelf:GetAbilityPointsAvailable()
    local i = nLev
    BotEcho("Start: "..tostring(nLev))
    BotEcho("End: "..tostring(nLev + nLevPts))
    while i < nLev + nLevPts do
        local nSkill = tSkills[i]
        if nSkill == nil then nSkill = 4 end

        local currentAbil = unitSelf:GetAbility(nSkill)
        
        currentAbil:LevelUp()

        BotEcho("Skill: "..currentAbil:GetTypeName())
        BotEcho("Skill #: "..nSkill)

        if nSkill == 0 and unitSelf:GetAbility(nSkill):GetActualRemainingCooldownTime() == 0 then
            BotEcho("Leveled Up Death Lotus - Reseting Spawn time")
            local nCurrentTime = HoN.GetGameTime()
            object.nLotusTime = nCurrentTime
        end

        i = i + 1
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

    local nRangeSq = 1000 * 1000
    local nCurrentTime = HoN.GetGameTime()

    local nSecondsElapsed = (nCurrentTime - object.nLotusTime) / 1000
    local nDegreeTraveled = nSecondsElapsed * 90
    local abilLotus = skills.abilLotus
    local tLotusVectors = object.tLotusVectors[abilLotus:GetLevel()]

    --[[
    if abilLotus:GetActualRemainingCooldownTime() == 0 then
        local vecMyPosition = core.unitSelf:GetPosition()
        -- go to all vectors we have for the current level and compare their direction to our direction towards the target
        for k,vecLotus in pairs(tLotusVectors) do
            local vecRotated = core.RotateVec2D(vecLotus, -nDegreeTraveled)
            core.DrawDebugArrow(vecMyPosition, vecMyPosition + vecRotated * 200, 'blue')
        end
    end
    ]]

    if core.unitSelf:HasState("State_Silhouette_Ability4_On") then
        if object.unitShadowIllusion == nil or not object.unitShadowIllusion:IsValid() or not object.unitShadowIllusion:IsAlive() then
            local unitShadowIllusion = nil
            for k,illusion in pairs(core.ownedIllusions) do
                if illusion:HasState("State_Silhouette_Ability4_Shadow") then
                    if illusion:IsValid() and illusion:IsAlive() then
                        unitShadowIllusion = illusion
                        break
                    end
                end
            end
            object.unitShadowIllusion = unitShadowIllusion
        end
    else
        object.unitShadowIllusion = nil
    end
end
object.onthinkOld = object.onthink
object.onthink  = object.onthinkOverride

-- this variable holds a reference to our shadow illusion
object.unitShadowIllusion = nil

-- These are bonus agression points if a skill/item is available for use
object.nLotusUp = 13
object.nGrappleUp = 10 
object.nSalvoUp = 5 
object.nShadowUp = 20

object.nSolvoApplied = 3
object.nSalvoActive = 20
 
-- These are bonus agression points that are applied to the bot upon successfully using a skill/item
object.nLotusUse = 13
object.nGrappleUse = 10
object.nShadowUse = 20
 
--These are thresholds of aggression the bot must reach to use these abilities
object.nLotusThreshold = 13
object.nGrappleThreshold = 10 
object.nSalvoThreshold = 7 
object.nShadowThreshold = 20

object.nLotusTime = HoN.GetGameTime()


----------------------------------------------
--            oncombatevent override        --
-- use to check for infilictors (fe. buffs) --
----------------------------------------------
-- @param: eventdata
-- @return: none
function object:oncombateventOverride(EventData)
    self:oncombateventOld(EventData)
    local nAddBonus = 0
    local unitSelf = core.unitSelf
    local abilLotus = skills.abilLotus
    local nCurrentTime = HoN.GetGameTime()
    if EventData.Type == "Ability" then
        if EventData.InflictorName == "Ability_Silhouette1" then
            object.nLotusTime = nCurrentTime + 12000
            nAddBonus = nAddBonus + object.nLotusUse
        elseif EventData.InflictorName == "Ability_Silhouette2" then
            nAddBonus = nAddBonus + object.nGrappleUse
        elseif EventData.InflictorName == "Ability_Silhouette4" then
            nAddBonus = nAddBonus + object.nShadowUse
            self:trackIllusions()
            if core.unitSelf:HasState("State_Silhouette_Ability4_On") then
                if object.unitShadowIllusion == nil or not object.unitShadowIllusion:IsValid() or not object.unitShadowIllusion:IsAlive() then
                    local unitShadowIllusion = nil
                    for k,illusion in pairs(core.ownedIllusions) do
                        if illusion:HasState("State_Silhouette_Ability4_Shadow") then
                            if illusion:IsValid() and illusion:IsAlive() then
                                unitShadowIllusion = illusion
                                break
                            end
                        end
                    end
                    object.unitShadowIllusion = unitShadowIllusion
                end
            else
                object.unitShadowIllusion = nil
            end
        end
    elseif EventData.Type == "Respawn" then
        local nCooldownTime = abilLotus:GetActualRemainingCooldownTime()
            
        object.nLotusTime = nCurrentTime + nCooldownTime
    end
 
   if nAddBonus > 0 then
        core.DecayBonus(self)
        core.nHarassBonus = core.nHarassBonus + nAddBonus
    end
end
-- override combat event trigger function.
object.oncombateventOld = object.oncombatevent
object.oncombatevent = object.oncombateventOverride



local function funcFindItemsOverride(botBrain)
    local bUpdated = object.FindItemsOld(botBrain)

    if core.itemImmunity ~= nil and not core.itemImmunity:IsValid() then
        core.itemImmunity = nil
    end

    if bUpdated then
        if core.itemImmunity then
            return
        end

        local inventory = core.unitSelf:GetInventory(true)
        for slot = 1, 12, 1 do
            local curItem = inventory[slot]
            if curItem then
                if core.itemImmunity == nil and curItem:GetName() == "Item_Immunity" then
                    core.itemImmunity = core.WrapInTable(curItem)
                end
            end
        end
    end
end
object.FindItemsOld = core.FindItems
core.FindItems = funcFindItemsOverride

object.tLotusVectors = {}
function createLotusVectors()
    -- body
    object.tLotusVectors[1] = {
        Vector3.Create(0,1)
    }
    object.tLotusVectors[2] = {
        Vector3.Create(0,1), Vector3.Create(0,-1)
    }
    object.tLotusVectors[3] = {
        Vector3.Create(0,1) , core.RotateVec2D(Vector3.Create(1,0), 210), core.RotateVec2D(Vector3.Create(1,0), 330)
    }
    object.tLotusVectors[4] = {
        Vector3.Create(0,1), Vector3.Create(1,0), Vector3.Create(0,-1), Vector3.Create(-1,0)
    }
end
createLotusVectors()

object.vecCurrentTreePosition = nil

------------------------------------------------------
--            customharassutility override          --
-- change utility according to usable spells here   --
------------------------------------------------------
-- @param: iunitentity hero
-- @return: number
local function CustomHarassUtilityOverride(enemyHero) --how much to harrass, doesn't change combo order or anything
    local nUtil = 0
    
    --BotEcho("Rethinking hass")
    
    local unitSelf = core.unitSelf

    --Death Lotus up bonus
    if skills.abilLotus:CanActivate() then
        nUtil = nUtil + object.nLotusUp
    end
 
    --Tree Grapple up bonus
    if skills.abilGrapple:CanActivate() or skills.abilGo:CanActivate() or skills.abilPull:CanActivate() then
        nUtil = nUtil + object.nGrappleUp
    end

    --Relentless Salvo up bonus
    if skills.abilSalvo:GetActualRemainingCooldownTime() == 0 then
        nUtil = nUtil + object.nSalvoUp
    end

    --Tree Grapple up bonus
    if skills.abilShadow:CanActivate() then
        nUtil = nUtil + object.nShadowUp
    end

    if unitSelf:HasState("State_Silhouette_Ability3") then
        nUtil = nUtil + object.nSalvoActive
    end

    if enemyHero:HasState("State_Silhouette_Ability3_Enemy") then
        nUtil = nUtil + object.nSolvoApplied
    end
 
    return nUtil -- no desire to attack AT ALL if 0.
end
-- assisgn custom Harrass function to the behaviourLib object
behaviorLib.CustomHarassUtility = CustomHarassUtilityOverride  

local function printLotusDebug(nLotusTime, nTimePassed, nDegreeTraveled, vecRotated, vecToward, nAngleBetween)
    -- body
    BotEcho("==================================================================")
    BotEcho("Lotus Spawn Time: "..nLotusTime)
    BotEcho("Seconds Passed: "..nTimePassed)
    BotEcho("Degree Traveled: "..nDegreeTraveled)
    BotEcho(format("Rotated Vector: (%f , %f)", vecRotated.x, vecRotated.y))
    BotEcho(format("Direction Vector: (%f , %f)", vecToward.x, vecToward.y))
    BotEcho("Angle Between: "..nAngleBetween)
    BotEcho("==================================================================")
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
    local bDebugHarassUtility = false and bDebugEchos
    
    local unitTarget = behaviorLib.heroTarget
    if unitTarget == nil then
        return false --can not execute, move on to the next behavior
    end
    
    local unitSelf = core.unitSelf
    
    --Positioning and distance info
    local vecMyPosition = unitSelf:GetPosition()
    local vecTargetPosition = unitTarget:GetPosition()
    local vecToward = Vector3.Normalize(vecTargetPosition - vecMyPosition)
    local nTargetDistanceSq = Vector3.Distance2DSq(vecMyPosition, vecTargetPosition)
    local nAttackRangeSq = core.GetAbsoluteAttackRangeToUnit(unitSelf, unitTarget, true) 
    local nLastHarassUtility = behaviorLib.lastHarassUtil

    core.DrawDebugArrow(vecMyPosition, vecMyPosition + vecToward * 200, 'green')
    
    --Skills
    local abilLotus = skills.abilLotus
    local abilGrapple = skills.abilGrapple
    local abilShadow = skills.abilShadow
    local abilPull = skills.abilPull
    local abilGo = skills.abilGo
    local abilSalvo = skills.abilSalvo
    
    if bDebugHarassUtility then BotEcho("Silhouette HarassHero at "..nLastHarassUtility) end

    local funcRadToDeg = core.RadToDeg
    local funcAngleBetween = core.AngleBetween

    --Used to keep track of whether something has been used
    -- If so, any other action that would have taken place
    -- gets queued instead of instantly ordered
    local bActionTaken = false

    if core.CanSeeUnit(botBrain, unitTarget) then
        if unitSelf:HasState("State_Silhouette_Ability4_On") then
            local unitShadowIllusion = object.unitShadowIllusion
            if unitShadowIllusion ~= nil and unitShadowIllusion:IsValid() and unitShadowIllusion:IsAlive() then
                core.OrderAttack(botBrain, unitShadowIllusion, unitTarget, false)
            end
        end

        if nLastHarassUtility > object.nLotusThreshold and not bActionTaken then
            if abilLotus:CanActivate() then
                local nLotusLevel = abilLotus:GetLevel()
                local nTargetMagicResistance = unitTarget:GetMagicResistance()
                local nLotusDamage = (40 + nLotusLevel * 60) * (1 - nTargetMagicResistance)

                if nLotusDamage > unitTarget:GetHealth() or (abilSalvo:GetActualRemainingCooldownTime() == 0 and nAttackRangeSq < nTargetDistanceSq) then
                    local nRangeSq = 1000 * 1000
                    local nCurrentTime = HoN.GetGameTime()

                    local nSecondsElapsed = (nCurrentTime - object.nLotusTime) / 1000
                    local nDegreeTraveled = nSecondsElapsed * 90

                    local tLotusVectors = object.tLotusVectors[abilLotus:GetLevel()]

                    -- go to all vectors we have for the current level and compare their direction to our direction towards the target
                    for k,vecLotus in pairs(tLotusVectors) do
                        local vecRotated = core.RotateVec2D(vecLotus, -nDegreeTraveled)
                        local nAngle = core.RadToDeg(core.AngleBetween(vecToward, vecRotated))
                        if nTargetDistanceSq < nRangeSq and nAngle < 6.0 then
                            printLotusDebug(object.nLotusTime, nSecondsElapsed, nDegreeTraveled, vecRotated, vecToward, nAngle)
                            bActionTaken = core.OrderAbility(botBrain, abilLotus, true)
                            break
                        end
                    end
                end
            end
        end

        if nLastHarassUtility > object.nGrappleThreshold and not bActionTaken then
            if abilGrapple:CanActivate() then
                local bestTree = nil
                local vecBestPosition = nil
                local nBestAngle = 999

                -- this will get us all trees in a 1000 units radius. 
                -- while grapple can target up to 1200 units, it might be better to have a little buffer
                core.UpdateLocalTrees()
                local tTrees = core.localTrees
                for key, tree in pairs(tTrees) do
                    if bestTree == nil then
                        local vecTreePosition = tree:GetPosition()
                        local nAngle = abs(funcRadToDeg(funcAngleBetween(vecTreePosition - vecMyPosition, vecToward))) 
                        local nDistanceSq = Vector3.Distance2DSq(vecMyPosition, vecTreePosition)
                        if nAngle < 7 and nDistanceSq > nTargetDistanceSq then
                            nBestAngle = nAngle
                            bestTree = tree
                            vecBestPosition = vecTreePosition
                        end
                    else
                        local vecTreePosition = tree:GetPosition()
                        local nCurrentAngle = abs(funcRadToDeg(funcAngleBetween(vecTreePosition - vecMyPosition, vecToward))) 
                        local nDistanceSq = Vector3.Distance2DSq(vecMyPosition, vecTreePosition)
                        -- check if the angle to current tree is smaller than the angle to best tree
                        if nCurrentAngle < nBestAngle and nCurrentAngle < 7 and nDistanceSq > nTargetDistanceSq  then
                            bestTree = tree
                            vecBestPosition = vecTreePosition
                        end
                    end
                end

                if bestTree ~= nil then
                    object.vecCurrentTreePosition = vecBestPosition
                    bActionTaken = core.OrderAbilityPosition(botBrain, abilGrapple, vecBestPosition, false)
                end
            end
        end

        if nLastHarassUtility > object.nShadowThreshold and not bActionTaken then
            if abilShadow:CanActivate() then
                if nAttackRangeSq < nTargetDistanceSq then
                    bActionTaken = core.OrderAbility(botBrain, abilShadow, true)
                else
                    if not unitSelf:IsAttackReady() then
                        core.DrawXPosition(vecTargetPosition, 'teal')
                        core.OrderMoveToPosClamp(botBrain, unitSelf, vecTargetPosition, false)
                        bActionTaken = true
                    end
                end
            end
        end

        if not bActionTaken then
            if abilPull:CanActivate() or abilGo:CanActivate() then
                local vecTreeToSelf = Vector3.Normalize(vecMyPosition - object.vecCurrentTreePosition)
                local vecTreeToEnemy = Vector3.Normalize(vecTargetPosition - object.vecCurrentTreePosition)
                local nAngleBetween = abs(funcRadToDeg(funcAngleBetween(vecTreeToSelf, vecTreeToEnemy)))

                core.DrawDebugArrow(object.vecCurrentTreePosition, object.vecCurrentTreePosition + vecTreeToSelf * 500, 'lime')
                core.DrawDebugArrow(object.vecCurrentTreePosition, object.vecCurrentTreePosition + vecTreeToEnemy * 500, 'teal')

                if nAngleBetween < 7.0 then
                    local nTreeDistanceSq = Vector3.Distance2DSq(object.vecCurrentTreePosition, vecTargetPosition)
                    if nTreeDistanceSq < nTargetDistanceSq then
                        -- Tree is closer to target than we are, use sky dance
                        bActionTaken = core.OrderAbility(botBrain, abilGo, true)
                    else
                        -- We are closer to target than the tree, use log bola
                        bActionTaken = core.OrderAbility(botBrain, abilPull, true)
                    end
                else
                    if not unitSelf:IsAttackReady() then
                        -- try to move into position for skydance / log bola
                        -- we need the non squared distance here, to calculate a point that has the enemy between it and the tree
                        local nDistance = Vector3.Distance2D(object.vecCurrentTreePosition, vecTargetPosition)
                        nDistance = max(nDistance + 200, 1700)
                        local vecDesiredPos = object.vecCurrentTreePosition + vecTreeToEnemy * nDistance
                        bActionTaken = core.OrderMoveToPosAndHoldClamp(botBrain, unitSelf, vecDesiredPos, false)
                    end
                end
                --BotEcho("Can use log bola or sky dance")
            end
        end
    end

    
    if not bActionTaken then
        return object.harassExecuteOld(botBrain)
    end
end
-- overload the behaviour stock function with custom 
object.harassExecuteOld = behaviorLib.HarassHeroBehavior["Execute"]
behaviorLib.HarassHeroBehavior["Execute"] = HarassHeroExecuteOverride


function behaviorLib.GetCreepAttackTarget(botBrain, unitEnemyCreep, unitAllyCreep) --called pretty much constantly
    local bDebugEchos = false

    --Get info about self
    local unitSelf = core.unitSelf

    local nDamageMin = unitSelf:GetFinalAttackDamageMin()
    local vecSelfPosition = unitSelf:GetPosition()
    local nProjectileSpeed = unitSelf:GetAttackProjectileSpeed()

    if unitEnemyCreep and core.CanSeeUnit(botBrain, unitEnemyCreep) then
        local nTargetPhysResistance = unitEnemyCreep:GetPhysicalResistance()
        nDamageMin = nDamageMin * (1 - nTargetPhysResistance)
        local nTargetHealth = unitEnemyCreep:GetHealth()
        local tNearbyAllyCreeps = core.localUnits['AllyCreeps']
        local tNearbyAllyTowers = core.localUnits['AllyTowers']
        local nExpectedCreepDamage = 0
        local nExpectedTowerDamage = 0

        local vecTargetPos = unitEnemyCreep:GetPosition()
        local nProjectileTravelTime = Vector3.Distance2D(vecSelfPosition, vecTargetPos) / nProjectileSpeed
        if bDebugEchos then BotEcho ("Projectile travel time: " .. nProjectileTravelTime ) end 
        
        --Determine the damage expected on the creep by other creeps
        for i, unitCreep in pairs(tNearbyAllyCreeps) do
            if unitCreep:GetAttackTarget() == unitEnemyCreep then
                local nCreepAttacks = 1 + math.floor(unitCreep:GetAttackSpeed() * nProjectileTravelTime)
                nExpectedCreepDamage = nExpectedCreepDamage + (unitCreep:GetFinalAttackDamageMin() * nCreepAttacks) * (1 - nTargetPhysResistance)
            end
        end

        --Determine the damage expected on the creep by towers
        for i, unitTower in pairs(tNearbyAllyTowers) do
            if unitTower:GetAttackTarget() == unitEnemyCreep then
                local nTowerAttacks = 1 + math.floor(unitTower:GetAttackSpeed() * nProjectileTravelTime)
                nExpectedTowerDamage = nExpectedTowerDamage + (unitTower:GetFinalAttackDamageMin() * nTowerAttacks) * (1 - nTargetPhysResistance)
            end
        end
        
        --Only attack if, by the time our attack reaches the target
        -- the damage done by other sources brings the target's health
        -- below our minimum damage
        if nDamageMin >= (nTargetHealth - nExpectedCreepDamage - nExpectedTowerDamage) then
            if bDebugEchos then BotEcho("Returning an enemy") end
            return unitEnemyCreep
        end
    end

    if unitAllyCreep then
        local nTargetPhysResistance = unitAllyCreep:GetPhysicalResistance()
        nDamageMin = nDamageMin * (1 - nTargetPhysResistance)
        local nTargetHealth = unitAllyCreep:GetHealth()
        local tNearbyEnemyCreeps = core.localUnits['EnemyCreeps']
        local tNearbyEnemyTowers = core.localUnits['EnemyTowers']
        local nExpectedCreepDamage = 0
        local nExpectedTowerDamage = 0

        local vecTargetPos = unitAllyCreep:GetPosition()
        local nProjectileTravelTime = Vector3.Distance2D(vecSelfPosition, vecTargetPos) / nProjectileSpeed
        if bDebugEchos then BotEcho ("Projectile travel time: " .. nProjectileTravelTime ) end 
        
        --Determine the damage expected on the creep by other creeps
        for i, unitCreep in pairs(tNearbyEnemyCreeps) do
            if unitCreep:GetAttackTarget() == unitAllyCreep then
                local nCreepAttacks = 1 + math.floor(unitCreep:GetAttackSpeed() * nProjectileTravelTime)
                nExpectedCreepDamage = nExpectedCreepDamage + (unitCreep:GetFinalAttackDamageMin() * nCreepAttacks) * (1 - nTargetPhysResistance)
            end
        end

        --Determine the damage expected on the creep by towers
        for i, unitTower in pairs(tNearbyEnemyTowers) do
            if unitTower:GetAttackTarget() == unitAllyCreep then
                local nTowerAttacks = 1 + math.floor(unitTower:GetAttackSpeed() * nProjectileTravelTime)
                nExpectedTowerDamage = nExpectedTowerDamage + (unitTower:GetFinalAttackDamageMin() * nTowerAttacks) * (1 - nTargetPhysResistance)
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

function AttackCreepsExecuteOverride(botBrain)
    local unitSelf = core.unitSelf
    local unitCreepTarget = core.unitCreepTarget

    if unitCreepTarget and core.CanSeeUnit(botBrain, unitCreepTarget) then      
        --Get info about the target we are about to attack
        local vecSelfPos = unitSelf:GetPosition()
        local vecTargetPos = unitCreepTarget:GetPosition()
        local nDistSq = Vector3.Distance2DSq(vecSelfPos, vecTargetPos)
        local nAttackRangeSq = core.GetAbsoluteAttackRangeToUnit(unitSelf, currentTarget, true)       
        local nTargetHealth = unitCreepTarget:GetHealth()
        local nDamageMin = unitSelf:GetFinalAttackDamageMin()    
        local nTargetPhysResistance = unitCreepTarget:GetPhysicalResistance()
        nDamageMin = nDamageMin * (1 - nTargetPhysResistance)

        --Get projectile info
        local nProjectileSpeed = unitSelf:GetAttackProjectileSpeed() 
        local nProjectileTravelTime = Vector3.Distance2D(vecSelfPos, vecTargetPos) / nProjectileSpeed
        if bDebugEchos then BotEcho ("Projectile travel time: " .. nProjectileTravelTime ) end 
        
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
                local nCreepAttacks = 1 + math.floor(unitCreep:GetAttackSpeed() * nProjectileTravelTime)
                nExpectedCreepDamage = nExpectedCreepDamage + (unitCreep:GetFinalAttackDamageMin() * nCreepAttacks) * (1 - nTargetPhysResistance)
            end
        end
    
        --Determine the damage expected on the creep by other towers
        for i, unitTower in pairs(tNearbyAttackingTowers) do
            if unitTower:GetAttackTarget() == unitCreepTarget then
                local nTowerAttacks = 1 + math.floor(unitTower:GetAttackSpeed() * nProjectileTravelTime)
                nExpectedTowerDamage = nExpectedTowerDamage + (unitTower:GetFinalAttackDamageMin() * nTowerAttacks) * (1 - nTargetPhysResistance)
            end
        end

    
        --Only attack if, by the time our attack reaches the target
        -- the damage done by other sources brings the target's health
        -- below our minimum damage, and we are in range and can attack right now
        if nDistSq < nAttackRangeSq and unitSelf:IsAttackReady() and nDamageMin >= (nTargetHealth - nExpectedCreepDamage - nExpectedTowerDamage) then
            core.OrderAttackClamp(botBrain, unitSelf, unitCreepTarget)

        --Otherwise get within 70% of attack range if not already
        -- This will decrease travel time for the projectile
        elseif (nDistSq > nAttackRangeSq * 0.5) then 
            local vecDesiredPos = core.AdjustMovementForTowerLogic(vecTargetPos)
            core.OrderMoveToPosClamp(botBrain, unitSelf, vecDesiredPos, false)

        --If within a good range, just hold tight
        else
            core.OrderHoldClamp(botBrain, unitSelf, false)
        end
    else
        return false
    end
end
object.AttackCreepsExecuteOld = behaviorLib.HarassHeroBehavior["Execute"]
behaviorLib.AttackCreepsBehavior["Execute"] = AttackCreepsExecuteOverride


-- attetntion:
--[[
x               x
 x       -
              x
              
    Imagine x are creeps, and - is their center
    this will be correctly calculated, however
    it does not state that creeps are in range
    of certain abilities
]]
local function groupCenter(tGroup, nMinCount)
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
            return vGroupCenter/nGroupCount-- center vector
        end
    else
        return nil  
    end
end

-- This function allowes ra to use his ability while pushing
-- Has prediction, however it might need some repositioning so he is in correct range more often
local function abilityPush(botBrain, unitSelf)
    local debugAbilityPush = false
    local vecMyPosition = unitSelf:GetPosition()
    local vecCreepCenter = groupCenter(core.localUnits["EnemyCreeps"], 1) -- the 3 basicly wont allow abilities under 3 creeps
    
    if vecCreepCenter == nil then 
        return false
    end
    

    local abilLotus = skills.abilLotus
    local abilGrapple = skills.abilGrapple
    local abilShadow = skills.abilShadow
    local nNeededMana = abilLotus:GetManaCost() * 2 + abilGrapple:GetManaCost()
    if abilShadow:GetActualRemainingCooldownTime() < 30000 then
        nNeededMana = nNeededMana + abilShadow:GetManaCost()
    end
    
    if  abilLotus:CanActivate() then 
        local nDistanceSq = Vector3.Distance2DSq(unitSelf:GetPosition(), vecCreepCenter)
        if nDistanceSq > 50 * 50 then
            core.OrderMoveToPosAndHoldClamp(botBrain, unitSelf, vecCreepCenter, false)
        else
            local tNearbyEnemyCreeps = core.localUnits["EnemyCreeps"]

            --Determine information about nearby creeps
            local nLowHealthCreepsInRange = 0
            local nCreepsInRange = 0
            for i, unitCreep in pairs(tNearbyEnemyCreeps) do
                if unitCreep:GetHealth() < 40 + abilLotus:GetLevel() * 60 then
                    nLowHealthCreepsInRange = nLowHealthCreepsInRange + 1
                end
            end

            local bShouldCast = nLowHealthCreepsInRange > 2

            --Cast judgement if a condition is met
            if bShouldCast then
                return core.OrderAbility(botBrain, abilLotus)
            end
        end
    end
    
    return false
end


function object.CreepPush(botBrain)
    VerboseLog("PushExecute("..tostring(botBrain)..")")
    local debugPushLines = false
    if debugPushLines then BotEcho('^yGotta execute em *greedy*') end
    
    local bSuccess = false
        
    local unitSelf = core.unitSelf
    if unitSelf:IsChanneling() then 
        return
    end

    local unitTarget = core.unitEnemyCreepTarget
    if unitTarget then
        bSuccess = abilityPush(botBrain, unitSelf)
        if debugPushLines then 
            BotEcho('^p-----------------------------Got em')
            if bSuccess then BotEcho('Gotemhard') else BotEcho('at least i tried') end
        end
    end
    
    return bSuccess
end

-- both functions below call for the creep push, however 
function object.PushExecuteOverride(botBrain)
    if not object.CreepPush(botBrain) then 
        object.PushExecuteOld(botBrain)
    end
end
object.PushExecuteOld = behaviorLib.PushBehavior["Execute"]
behaviorLib.PushBehavior["Execute"] = object.PushExecuteOverride


local function TeamGroupBehaviorOverride(botBrain)
    object.TeamGroupBehaviorOld(botBrain)
    object.CreepPush(botBrain)
end
object.TeamGroupBehaviorOld = behaviorLib.TeamGroupBehavior["Execute"]
behaviorLib.TeamGroupBehavior["Execute"] = TeamGroupBehaviorOverride

BotEcho('finished loading silhouette_main')
