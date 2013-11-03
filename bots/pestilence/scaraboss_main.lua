--------------------------------------------------------------------- -- -- 
--------------------------------------------------------------------- -- -- 
-- 
--  .::::::.   .,-:::::   :::.    :::::::..    :::.     :::::::.      ...      .::::::.  .::::::. 
-- ;;;`    ` ,;;;'````'   ;;`;;   ;;;;``;;;;   ;;`;;     ;;;'';;'  .;;;;;;;.  ;;;`    ` ;;;`    ` 
-- '[==/[[[[,[[[         ,[[ '[[,  [[[,/[[['  ,[[ '[[,   [[[__[[\.,[[     \[[,'[==/[[[[,'[==/[[[[,
--   '''    $$$$        c$$$cc$$$c $$$$$$c   c$$$cc$$$c  $$""""Y$$$$$,     $$$  '''    $  '''    $
--  88b    dP`88bo,__,o, 888   888,888b "88bo,888   888,_88o,,od8P"888,_ _,88P 88b    dP 88b    dP
--   "YMmMY"   "YUMMMMMP"YMM   ""` MMMM   "W" YMM   ""` ""YUMMMP"   "YMMMMMP"   "YMmMY"   "YMmMY" 
-- 
                                                              
--------------------------------------------------------------------- -- -- 
--------------------------------------------------------------------- -- -- 
-- Scaraboss v0.1

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
local ceil, floor, pi, tan, atan, atan2, abs, cos, sin, acos, max, random
    = _G.math.ceil, _G.math.floor, _G.math.pi, _G.math.tan, _G.math.atan, _G.math.atan2, _G.math.abs, _G.math.cos, _G.math.sin, _G.math.acos, _G.math.max, _G.math.random

local BotEcho, VerboseLog, BotLog = core.BotEcho, core.VerboseLog, core.BotLog
local Clamp = core.Clamp

BotEcho(object:GetName()..' loading scaraboss_main...')




--####################################################################
--####################################################################
--#                                                                 ##
--#                  Bot Constant Definitions                       ##
--#                                                                 ##
--####################################################################
--####################################################################

-- Hero_<hero>  to reference the internal HoN name of a hero, Hero_Yogi ==Wildsoul
object.heroName = 'Hero_Pestilence'


--   Item Buy order. Internal names  
behaviorLib.StartingItems  = { "Item_RunesOfTheBlight", "Item_IronBuckler", "Item_LoggersHatchet"}
behaviorLib.LaneItems  = {"Item_Lifetube","Item_Marchers"}
behaviorLib.MidItems  = {"Item_Shield2","Item_PortalKey","Item_Steamboots","Item_SolsBulwark","Item_Pierce","Item_Immunity"}
behaviorLib.LateItems  = {"Item_DaemonicBreastplate","Item_BehemothsHeart","Item_LifeSteal5"}


-- Skillbuild table, 0=Q, 1=W, 2=E, 3=R, 4=Attri
object.tSkills = {
    1, 0, 1, 0, 1,
    3, 1, 0, 0, 2, 
    3, 2, 2, 2, 4,
    3, 4, 4, 4, 4,
    4, 4, 4, 4, 4,
}

-- bonus agression points if a skill/item is available for use

object.nFlightUp = 20
object.nImpaleUp = 28
object.nSwarmUp = 10
object.nImmunityUp = 15
object.nPortalKeyUp = 15

-- bonus agression points that are applied to the bot upon successfully using a skill/item

object.nFlightUse = 40
object.nImpaleUse = 35 
object.nSwarmUse = 20

--thresholds of aggression the bot must reach to use these abilities

object.nFlightThreshold = 50
object.nImpaleThreshold = 45
object.nSwarmThreshold = 12

object.nImmunityThreshold = 55
object.nPortalKeyThreshold = 45


--####################################################################
--####################################################################
--#                                                                 ##
--#   Bot Function Overrides                                        ##
--#                                                                 ##
--####################################################################
--####################################################################

------------------------------
--     Skills               --
------------------------------
-- @param: none
-- @return: none
function object:SkillBuild()
    core.VerboseLog("SkillBuild()")

-- takes care at load/reload, <NAME_#> to be replaced by some convinient name.
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
    
   
    local nLev = unitSelf:GetLevel()
    local nLevPts = unitSelf:GetAbilityPointsAvailable()
    for i = nLev, nLev+nLevPts do
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
object.onthink 	= object.onthinkOverride


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
		if EventData.InflictorName == "Ability_Pestilence1" then
		    nAddBonus = nAddBonus + object.nFlightUse
		elseif EventData.InflictorName == "Ability_Pestilence2" then
		    nAddBonus = nAddBonus + object.nImpaleUse
		elseif EventData.InflictorName == "Ability_Pestilence3" then
		    nAddBonus = nAddBonus + object.nMarkUse
		elseif EventData.InflictorName == "Ability_Pestilence4" then
		    nAddBonus = nAddBonus + object.nSwarmUse
		end
	end
 
	if nAddBonus > 0 then
		core.DecayBonus(self)
		core.nHarassBonus = core.nHarassBonus + nAddBonus
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
local function CustomHarassUtilityFnOverride(hero)
    local nUtil = 0
     
    if skills.abilQ:CanActivate() then
        nUnil = nUtil + object.nFlightUp
    end
 
    if skills.abilW:CanActivate() then
        nUtil = nUtil + object.nImpaleUp
    end

    if skills.abilR:CanActivate() then
        nUtil = nUtil + object.nSwarmUp
    end

    if object.itemImmunity and object.itemImmunity:CanActivate() then
        nUtil = nUtil + object.nImmunityUp
    end
 
    return nUtil
end
-- assisgn custom Harrass function to the behaviourLib object
behaviorLib.CustomHarassUtility = CustomHarassUtilityFnOverride   


----------------------------------
--  FindItems Override
----------------------------------
local function funcFindItemsOverride(botBrain)
	local bUpdated = object.FindItemsOld(botBrain)

	if core.itemImmunity ~= nil and not core.itemImmunity:IsValid() then
		core.itemImmunity = nil
	end
	if core.itemPortalKey ~= nil and not core.itemPortalKey:IsValid() then
		core.itemPortalKey = nil
	end
	
	if bUpdated then
		--only update if we need to
		if core.itemImmunity and core.itemPortalKey then
			return
		end
		
		local inventory = core.unitSelf:GetInventory(true)
		for slot = 1, 12, 1 do
			local curItem = inventory[slot]
			if curItem then
				if core.itemImmunity == nil and curItem:GetName() == "Item_Immunity" then
					core.itemImmunity = core.WrapInTable(curItem)
				elseif core.itemPortalKey == nil and curItem:GetName() == "Item_PortalKey" then
					core.itemPortalKey = core.WrapInTable(curItem)
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
    local bDebugEchos = true
	
	

	
    local unitTarget = behaviorLib.heroTarget
    if unitTarget == nil then
        return object.harassExecuteOld(botBrain)  --Target is invalid, move on to the next behavior
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
       
    --- Insert abilities code here, set bActionTaken to true 
    --- if an ability command has been given successfully
    
     -- Flight Activation
    if core.CanSeeUnit(botBrain, unitTarget) then
        local abilFlight = skills.abilQ
        if not bActionTaken then
            if abilFlight:CanActivate() and nLastHarassUtility > botBrain.nFlightThreshold and not unitSelf:HasState("State_Pestilence_Ability1") then
		bActionTaken = core.OrderAbility(botBrain, abilFlight)
            end
        end 
    end 

     -- Flight for Flee
    
     -- Impale for Damage
     
     -- Impale Activation
    if core.CanSeeUnit(botBrain, unitTarget) then
        local abilImpale = skills.abilW
        if not bActionTaken then --and bTargetVuln then
            if abilImpale:CanActivate() and nLastHarassUtility > botBrain.nImpaleThreshold then
                if nTargetDistanceSq < (300 * 300) then --- distance?
			bActionTaken = core.OrderAbility(botBrain, abilImpale)
                end
            end
        end 
    end

     -- Swarm Anti-Invi
     
     -- Swarm Refresh

     -- Swarm Activation for Kill
    if core.CanSeeUnit(botBrain, unitTarget) then
        local abilSwarm = skills.abilR
        if not bActionTaken then --and bTargetVuln then
            if abilSwarm:CanActivate() and nLastHarassUtility > botBrain.nSwarmThreshold and not unitTarget:HasState("State_Pestilence_Ability4") then
                local nRange = abilSwarm:GetRange()
                if nTargetDistanceSq < (nRange * nRange) then --- distance?
                    bActionTaken = core.OrderAbilityEntity(botBrain, abilSwarm, unitTarget)
                end
            end
        end 
    end

	--portalkey
	if not bActionTaken then --and 
		core.FindItems()
		local itemPortalKey = core.itemPortalKey
		if itemPortalKey then
			local nPortalKeyRange = itemPortalKey:GetRange()
			local ImpaleRange = 300
			if itemPortalKey:CanActivate() and behaviorLib.lastHarassUtil > object.nPortalKeyThreshold then
				if nTargetDistanceSq > (ImpaleRange * ImpaleRange) and nTargetDistanceSq < (nPortalKeyRange*nPortalKeyRange + ImpaleRange*ImpaleRange) then
					if vecTargetPosition then
						bActionTaken = core.OrderItemPosition(botBrain, unitSelf, itemPortalKey, vecTargetPosition)
					end
				end
			end
		end
	end

     -- Shrunken Head Offensive Activation
     
    if core.CanSeeUnit(botBrain, unitTarget) then
    	core.FindItems()
	local itemImmunity = core.itemImmunity -- reel name?
        if not bActionTaken then 
            if itemImmunity and itemImmunity:CanActivate() and nLastHarassUtility > botBrain.nImmunityThreshold then
                if nTargetDistanceSq < (750 * 750) then --- distance?
					bActionTaken = core.OrderItemClamp(botBrain, unitSelf, itemImmunity)
                end
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

--Kairus101's last hitter
function behaviorLib.GetCreepAttackTarget(botBrain, unitEnemyCreep, unitAllyCreep) 
--called pretty much constantly 
   unitSelf=core.unitSelf
    local bDebugEchos = false
    -- predictive last hitting, don't just wait and react when they have 1 hit left (that would be stupid. T_T)
 
 
    local unitSelf = core.unitSelf
    local nDamageAverage = unitSelf:GetFinalAttackDamageMin()+40 --make the hero go to the unit when it is 40 hp away
    core.FindItems(botBrain)
    if core.itemHatchet then
        nDamageAverage = nDamageAverage * core.itemHatchet.creepDamageMul
    end   
    -- [Difficulty: Easy] Make bots worse at last hitting
    if core.nDifficulty == core.nEASY_DIFFICULTY then
        nDamageAverage = nDamageAverage + 120
    end
    if unitEnemyCreep and core.CanSeeUnit(botBrain, unitEnemyCreep) then
        local nTargetHealth = unitEnemyCreep:GetHealth()
        if nDamageAverage >= nTargetHealth then
            local bActuallyLH = true
            if bDebugEchos then BotEcho("Returning an enemy") end
            return unitEnemyCreep
        end
    end
 
 
    if unitAllyCreep then
        local nTargetHealth = unitAllyCreep:GetHealth()
        if nDamageAverage >= nTargetHealth then
            local bActuallyDeny = true
 
 
            --[Difficulty: Easy] Don't deny
            if core.nDifficulty == core.nEASY_DIFFICULTY then
                bActuallyDeny = false
            end           
 
 
            -- [Tutorial] Hellbourne *will* deny creeps after **** gets real
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

function KaiAttackCreepsExecuteOverride(botBrain)
    local unitSelf = core.unitSelf
    local currentTarget = core.unitCreepTarget
 
 
    if currentTarget and core.CanSeeUnit(botBrain, currentTarget) then       
        local vecTargetPos = currentTarget:GetPosition()
        local nDistSq = Vector3.Distance2DSq(unitSelf:GetPosition(), vecTargetPos)
        local nAttackRangeSq = core.GetAbsoluteAttackRangeToUnit(unitSelf, currentTarget, true)
         
        local nDamageAverage = unitSelf:GetFinalAttackDamageMin()
 
 
        if currentTarget ~= nil then
            if nDistSq < nAttackRangeSq and unitSelf:IsAttackReady() and nDamageAverage>=currentTarget:GetHealth() then --only kill if you can get gold
                --only attack when in nRange, so not to aggro towers/creeps until necessary, and move forward when attack is on cd
                core.OrderAttackClamp(botBrain, unitSelf, currentTarget)
            elseif (nDistSq > nAttackRangeSq) then
                local vecDesiredPos = core.AdjustMovementForTowerLogic(vecTargetPos)
                core.OrderMoveToPosClamp(botBrain, unitSelf, vecDesiredPos, false) --moves hero to target
            else
                core.OrderHoldClamp(botBrain, unitSelf, false) --this is where the magic happens. Wait for the kill.
            end
        end
    else
        return false
    end
end
object.AttackCreepsExecuteOld = behaviorLib.HarassHeroBehavior["Execute"]
behaviorLib.AttackCreepsBehavior["Execute"] = KaiAttackCreepsExecuteOverride

