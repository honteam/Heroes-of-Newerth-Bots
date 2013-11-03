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
local ceil, floor, pi, tan, atan, atan2, abs, cos, sin, acos, max, random
    = _G.math.ceil, _G.math.floor, _G.math.pi, _G.math.tan, _G.math.atan, _G.math.atan2, _G.math.abs, _G.math.cos, _G.math.sin, _G.math.acos, _G.math.max, _G.math.random

local BotEcho, VerboseLog, BotLog = core.BotEcho, core.VerboseLog, core.BotLog
local Clamp = core.Clamp


BotEcho(object:GetName()..' loading <hero>_main...')


-- hero_<hero>  to reference the internal hon name of a hero, Hero_Yogi ==wildsoul
object.heroName = 'Hero_Dampeer'


--   item buy order. internal names  
behaviorLib.StartingItems  = {"Item_RunesOfTheBlight", "Item_IronBuckler", "Item_LoggersHatchet"}
behaviorLib.LaneItems  = {"Item_Marchers", "Item_EnhancedMarchers", "Item_GraveLocket", "Item_MysticVestments"}
behaviorLib.MidItems  = {"Item_Silence", "Item_Immunity"}
behaviorLib.LateItems  = {"Item_Dawnbringer", "Item_Protect"}


-- skillbuild table, 0=q, 1=w, 2=e, 3=r, 4=attri
object.tSkills = {
    1, 0, 1, 0, 1,
    3, 0, 0, 1, 2, 
    3, 2, 2, 2, 4,
    3, 4, 4, 4, 4,
    4, 4, 4, 4, 4,
}

-- bonus agression points if a skill/item is available for use
object.abilQUp = 10
object.abilWUp = 10
object.abilRUp = 30
object.nImmunityUp = 18
object.nIllusionUp = 20
object.nSilenceUp = 15
object.nPortalKeyUp = 15
-- bonus agression points that are applied to the bot upon successfully using a skill/item
object.abilQUse = 10
object.abilWUse = 15
object.abilRUse = 60
object.nImmunityUse = 18
object.nIllusionUse = 20
object.nSilenceUse = 10
object.nPortalKeyUse = 18
--thresholds of aggression the bot must reach to use these abilities
object.abilQThreshold = 30
object.abilWThreshold = 40
object.abilRThreshold = 35
object.nImmunityThreshold = 20
object.nIllusionThreshold = 30
object.nSilenceThreshold = 15
object.nPortalKeyThreshold = 10

------------------------------
--     skills               --
------------------------------
-- @param: none
-- @return: none
function object:SkillBuild()
    core.VerboseLog("skillbuild()")

-- takes care at load/reload, <name_#> to be replaced by some convinient name.
    local unitSelf = self.core.unitSelf
    if  skills.abilQ == nil then
        skills.abilQ = unitSelf:GetAbility(0)
        skills.abilW = unitSelf:GetAbility(1)
        skills.abilE = unitSelf:GetAbility(2)
        skills.abilR = unitSelf:GetAbility(3)
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
   
   local bDebugEchos = false
   local addBonus = 0
   
   if EventData.Type == "Ability" then
   if bDebugEchos then BotEcho(" ABILITY EVENT! InflictorName: "..EventData.InflictorName) end
        if EventData.InflictorName == "Ability_Dampeer1" then
            addBonus = addBonus + object.abilQUse
            object.abilQUseTime = EventData.TimeStamp
            BotEcho(object.abilQUseTime)
   elseif EventData.InflictorName == "Ability_Dampeer2" then
            addBonus = addBonus + object.abilWUse
            object.abilWUseTime = EventData.TimeStamp
            BotEcho(object.abilWUseTime)
    elseif EventData.InflictorName == "Ability_Dampeer4" then
            addBonus = addBonus + object.abilRUse
            object.abilRUseTime = EventData.TimeStamp
            BotEcho(object.abilWUseTime)
     end
     elseif EventData.Type == "Item" then
            if core.itemPortalkey ~= nil and EventData.SourceUnit == core.unitSelf:GetUniqueID() and EventData.InflictorName == core.itemPortalkey:GetName() then
            nAddBonus = nAddBonus + self.nPortalkeyUse
            end
            if core.itemImmunity ~= nil and EventData.SourceUnit == core.unitSelf:GetUniqueID() and EventData.InflictorName == core.itemImmunity:GetName() then
            nAddBonus = nAddBonus + self.nImmunityUse
            end
            if core.itemIllusion ~= nil and EventData.SourceUnit == core.unitSelf:GetUniqueID() and EventData.InflictorName == core.itemIllusion:GetName() then
            addBonus = addBonus + self.nIllusionUse
            end
            if core.itemSilence ~= nil and EventData.SourceUnit == core.unitSelf:GetUniqueID() and EventData.InflictorName == core.itemSilence:GetName() then
            addBonus = addBonus + self.nSilenceUse
            end
   end
   if addBonus > 0 then
        core.DecayBonus(self)
        core.nHarassBonus = core.nHarassBonus + addBonus

    end
end     
-- override combat event trigger function.
object.oncombateventOld = object.oncombatevent
object.oncombatevent     = object.oncombateventOverride


------------------------------------------------------
--            customharassutility override          --
-- change utility according to usable spells here   --
------------------------------------------------------
-- @param: iunitentity hero
-- @return: number
local function AbilitiesUpUtility(hero)
local nUtility = 0

local unitSelf = core.unitSelf

    if skills.abilQ:CanActivate() then
        nUtility = nUtility + object.abilQUp
    end

    if skills.abilW:CanActivate() then
        nUtility = nUtility + object.abilWUp
    end
    
    if skills.abilR:CanActivate() then
        nUtility = nUtility + object.abilRUp
    end
    
    if object.itemImmunity and object.itemImmunity:CanActivate() then
        nUtility = nUtility + object.nImmunityUp
    end
    
    if object.itemSilence and object.itemSilence:CanActivate() then
        nUtility = nUtility + object.nSilenceUp
    end

    return nUtility
end

local function CustomHarassUtilityFnOverride(hero)
    local nUtility = AbilitiesUpUtility(hero)   
    
    return Clamp(nUtility, 0, 100)
end

-- assisgn custom Harrass function to the behaviourLib object
behaviorLib.CustomHarassUtility = CustomHarassUtilityFnOverride

--Find Items 
local function funcFindItemsOverride(botBrain)
    local bUpdated = object.FindItemsOld(botBrain)

    if core.itemImmunity ~= nil and not core.itemImmunity:IsValid() then
        core.itemImmunity = nil
    end
    
    if core.itemSilence ~= nil and not core.itemSilence:IsValid() then
        core.itemSilence = nil
    end

    if bUpdated then
        if core.itemImmunity and core.itemSilence then
            return
        end

        local inventory = core.unitSelf:GetInventory(true)
        for slot = 1, 12, 1 do
            local curItem = inventory[slot]
            if curItem then
                if core.itemImmunity == nil and curItem:GetName() == "Item_Immunity" then
                    core.itemImmunity = core.WrapInTable(curItem)
                elseif core.itemSilence == nil and curItem:GetName() == "Item_Silence" then
                    core.itemSilence = core.WrapInTable(curItem)
                end
            end
        end
    end
end
object.FindItemsOld = core.FindItems
core.FindItems = funcFindItemsOverride


--------------------------------------------------------------
--                    Harass Behavior                       --
-- All code how to use abilities against enemies goes here  --
--------------------------------------------------------------
-- @param botBrain: CBotBrain
-- @return: none
--
local function HarassHeroExecuteOverride(botBrain)
    
    local unitTarget = behaviorLib.heroTarget
    if unitTarget == nil then
        return object.harassExecuteOld(botBrain) --Target is invalid, move on to the next behavior
    end
    
    
    local unitSelf = core.unitSelf
    local vecMyPosition = unitSelf:GetPosition() 
    local nAttackRange = core.GetAbsoluteAttackRangeToUnit(unitSelf, unitTarget)
    local nMyExtraRange = core.GetExtraRange(unitSelf)
    
    local vecTargetPosition = unitTarget:GetPosition()
    local nTargetExtraRange = core.GetExtraRange(unitTarget)
    local nTargetDistanceSq = Vector3.Distance2DSq(vecMyPosition, vecTargetPosition)
    
    local nLastHarassUtility = behaviorLib.lastHarassUtil
    local bCanSee = core.CanSeeUnit(botBrain, unitTarget)    
    local bActionTaken = false
    
    if core.CanSeeUnit(botBrain, unitTarget) then
        local bTargetVuln = unitTarget:IsStunned() or unitTarget:IsImmobilized() or unitTarget:IsPerplexed()
        core.FindItems()
        local itemPortalKey = core.itemPortalKey
    
    if not bActionTaken then
       if itemPortalKey then
                local nPortalKeyRange = itemPortalKey:GetRange()
                if itemPortalKey:CanActivate() and nLastHarassUtility > botBrain.nPortalkeyThreshold then--and unitSelf:GetMana()>315 and nLastHarassUtility > botBrain.nPortalkeyThreshold then
                    --BotEcho(" " .. nTargetDistanceSq .. " " .. (nRange*nRange));
                    if nTargetDistanceSq <= (nPortalKeyRange*nPortalKeyRange) and nTargetDistanceSq>(750*750) then
                        bActionTaken = core.OrderItemPosition(botBrain, unitSelf, itemPortalKey, vecTargetPosition) --teleport on that mofo
                        
                    
                        bActionTaken = core.OrderAttackClamp(botBrain, unitSelf, unitTarget, false, true)
                        
                    elseif nTargetDistanceSq>(nPortalKeyRange*nPortalKeyRange) then
                        bActionTaken = core.OrderMoveToUnitClamp(botBrain, unitSelf, unitTarget)
                    end
                end
            end
    end
    
    if not bActionTaken then 
            core.FindItems()
            local itemSilence = core.itemSilence
            if itemSilence then
                local nRange = itemSilence:GetRange()
                if itemSilence:CanActivate() and nLastHarassUtility > botBrain.nSilenceThreshold then
                    if nTargetDistanceSq < (nRange * nRange) then
                        bActionTaken = core.OrderItemEntityClamp(botBrain, unitSelf, itemSilence, unitTarget)
                    end
                end
            end
        end
    
    if not bActionTaken then
        core.FindItems()
        local itemImmunity = core.itemImmunity
        if itemImmunity then
            if itemImmunity:CanActivate() and nLastHarassUtility > botBrain.nImmunityThreshold then
                if nTargetDistanceSq <= ( 500 * 500 ) then
                bActionTaken = core.OrderItemClamp(botBrain, unitSelf, itemImmunity)
                end
            end
        end 
    end
    
    if not bActionTaken then 
        local abilFlight = skills.abilW
            if abilFlight:CanActivate() and nLastHarassUtility > botBrain.abilWThreshold then
                local nRange = abilFlight:GetRange()
                if nTargetDistanceSq < (nRange * nRange) then --- distance?
                    bActionTaken = core.OrderAbilityEntity(botBrain, abilFlight, unitTarget)
                end
            end
        end 
    
    if not bActionTaken then
        local abilTerrorize = skills.abilQ
        if abilTerrorize:CanActivate() and nLastHarassUtility > botBrain.abilQThreshold then
            local nRange = 250
            if nTargetDistanceSq < (nRange * nRange) then
                bActionTaken = core.OrderAbility(botBrain, abilTerrorize)
            else
                bActionTaken = core.OrderMoveToUnitClamp(botBrain, unitSelf, unitTarget)
            end
        end
    end 
        
        if not bActionTaken then
        local abilConsume = skills.abilR
        local potentialDamage = (skills.abilR:GetLevel()*100+100)
                    if abilConsume:CanActivate() and nLastHarassUtility > botBrain.abilRThreshold and unitTarget:GetHealth() <= potentialDamage then
                        local nRange = abilConsume:GetRange()
                        if nTargetDistanceSq < (nRange * nRange) then
                            bActionTaken = core.OrderAbilityEntity(botBrain, abilConsume, unitTarget)
                        else
                            bActionTaken = core.OrderMoveToUnitClamp(botBrain, unitSelf, unitTarget)
                        end
                    end
                end  
    if not bActionTaken then    
        return object.harassExecuteOld(botBrain)
    end 
end
end
-- overload the behaviour stock function with custom 
object.harassExecuteOld = behaviorLib.HarassHeroBehavior["Execute"]
behaviorLib.HarassHeroBehavior["Execute"] = HarassHeroExecuteOverride

function AttackCreepsExecuteCustom(botBrain)

local unitSelf = core.unitSelf
    local currentTarget = core.unitCreepTarget
    local bActionTaken = false

    if currentTarget and core.CanSeeUnit(botBrain, currentTarget) then      
        local vecTargetPos = currentTarget:GetPosition()
        local nDistSq = Vector3.Distance2DSq(unitSelf:GetPosition(), vecTargetPos)
        local nAttackRangeSq = core.GetAbsoluteAttackRangeToUnit(unitSelf, currentTarget, true)

        if currentTarget ~= nil then            
            
            core.FindItems(botBrain)
            local itemHatchet = core.itemHatchet
            if nDistSq < nAttackRangeSq and unitSelf:IsAttackReady() then
                --BotEcho("Attacking Creep")
                --only attack when in nRange, so not to aggro towers/creeps until necessary, and move forward when attack is on cd
                bActionTaken = core.OrderAttackClamp(botBrain, unitSelf, currentTarget)
            elseif (itemHatchet and itemHatchet:CanActivate()) then
                local nHatchRange = itemHatchet:GetRange()
                if nDistSq < ( nHatchRange * nHatchRange ) and currentTarget:GetTeam() ~= unitSelf:GetTeam() then                   
                    --BotEcho("Attempting Hatchet")
                    bActionTaken = core.OrderItemEntityClamp(botBrain, unitSelf, itemHatchet, currentTarget)
                end         
            else
                --BotEcho("MOVIN OUT")
                local vecDesiredPos = core.AdjustMovementForTowerLogic(vecTargetPos)
                bActionTaken = core.OrderMoveToPosClamp(botBrain, unitSelf, vecDesiredPos, false)
            end
        end
    else
        return false
    end
    
    if not bActionTaken then
        return object.AttackCreepsExecuteOld(botBrain)
    end 
end

object.AttackCreepsExecuteOld = behaviorLib.AttackCreepsBehavior["Execute"]
behaviorLib.AttackCreepsBehavior["Execute"] = AttackCreepsExecuteCustom