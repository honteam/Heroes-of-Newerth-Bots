-- Bastardo v0.2

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


BotEcho(object:GetName()..' loading <hero>_main...')




--####################################################################
--####################################################################
--#                                                                 ##
--#                  bot constant definitions                       ##
--#                                                                 ##
--####################################################################
--####################################################################

-- hero_<hero>  to reference the internal hon name of a hero, Hero_Yogi ==wildsoul
object.heroName = 'Hero_Voodoo'


--   item buy order. internal names  
behaviorLib.StartingItems  = {"Item_RunesOfTheBlight", "Item_MinorTotem", "Item_MinorTotem", "Item_MarkOfTheNovice", "Item_MarkOfTheNovice", "Item_ManaPotion", "Item_ManaPotion" }
behaviorLib.LaneItems  = {"Item_Marchers", "Item_Striders", "Item_Nuke 1", "Item_Intelligence5"}
behaviorLib.MidItems  = {"Item_GraveLocket", "Item_Immunity"}
behaviorLib.LateItems  = {"Item_Intelligence7", "Item_Nuke 5"}


-- skillbuild table, 0=q, 1=w, 2=e, 3=r, 4=attri
object.tSkills = {
    0, 2, 2, 0, 2,
    3, 2, 0, 0, 1, 
    3, 1, 1, 1, 4,
    3, 4, 4, 4, 4,
    4, 4, 4, 4, 4,
}

-- These are bonus agression points if a skill/item is available for use
object.nCaskUp = 35
object.nCurseUp = 38
object.nMojoUp = 22
object.nWardUp = 35
object.nNukeUp = 40
 
-- These are bonus agression points that are applied to the bot upon successfully using a skill/item
object.nCaskUse = 38
object.nCurseUse = 40
object.nMojoUse = 28
object.nWardUse = 0
object.nNukeUse = 40
 
 
--These are thresholds of aggression the bot must reach to use these abilities
object.nCurseThreshold = 40
object.nCaskThreshold = 24
object.nMojoThreshold = 60
object.nWardThreshold = 60
object.nNukeThreshold = 20


-- detrimines if codex will kill a target, taken from SPENNERINO's codex scout bot
local function GetCanNukeKillTarget(unitTarget)
	local nLevel = core.itemNuke:GetLevel()
	local nHealth = unitTarget:GetHealth()
	
	local nDamage = 400
	if nLevel == 1 then
		nDamage = 400
	elseif nLevel == 2 then
		nDamage = 500
	elseif nLevel == 3 then
		nDamage = 600
	elseif nLevel == 4 then
		nDamage = 700
	elseif nLevel == 5 then
		nDamage = 800
	end
	
	local nDamageMultiplier = 1 - unitTarget:GetMagicResistance()
	local nTrueDamage = nDamage * nDamageMultiplier

	if nTrueDamage > nHealth then
		return true
	else
		return false
	end
end


--####################################################################
--####################################################################
--#                                                                 ##
--#   bot function overrides                                        ##
--#                                                                 ##
--####################################################################
--####################################################################

----------------------------------
--  FindItems Override
----------------------------------
local function funcFindItemsOverride(botBrain)
    local bUpdated = object.FindItemsOld(botBrain)
 
    if core.itemNuke ~= nil and not core.itemNuke:IsValid() then
        core.itemNuke = nil
    end
    if core.itemImmunity ~= nil and not core.itemImmunity:IsValid() then
        core.itemImmunity = nil
    end
    if bUpdated then
        --only update if we need to
        if core.itemNuke and core.itemImmunity then
            return
        end
         
        local inventory = core.unitSelf:GetInventory(true)
        for slot = 1, 12, 1 do
            local curItem = inventory[slot]
            if curItem then
                if core.itemNuke == nil and curItem:GetName() == "Item_Nuke" then
                    core.itemNuke = core.WrapInTable(curItem)
				elseif core.itemImmunity == nil and curItem:GetName() == "Item_Immunity" then
				core.itemImmunity = core.WrapInTable(curItem)
                end
            end
        end
    end
end
object.FindItemsOld = core.FindItems
core.FindItems = funcFindItemsOverride

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

	
end
object.onthinkOld = object.onthink
object.onthink 	= object.onthinkOverride

----------------------------------------------
--            retreat override        --
-- retreat behavior --
----------------------------------------------

local function funcRetreatFromThreatExecuteOverride(botBrain)
	local bActionTaken = nil
	local unitSelf = core.unitSelf
	local unitTarget = behaviorLib.heroTarget
	local abilCask = skills.abilQ
	local nlastRetreatUtil = behaviorLib.lastRetreatUtil
	
	local tEnemies = core.localUnits["EnemyHeroes"]
	local nCount = 0
	local unitClosestEnemy
	local nClosestEnemyDist = 90001

	
	for id, unitEnemy in pairs(tEnemies) do
		if core.CanSeeUnit(botBrain, unitEnemy) then
			nCount = nCount + 1
			if Vector3.Distance2DSq(unitSelf:GetPosition(), unitEnemy:GetPosition()) < nClosestEnemyDist then
				nClosestEnemyDist = Vector3.Distance2DSq(unitSelf:GetPosition(), unitEnemy:GetPosition())
				unitClosestEnemy = unitEnemy
			end
		end
	end
	
	
	if (unitSelf:GetHealthPercent() < .4 or nCount > 1) and unitClosestEnemy ~= nil then
		if abilCask:CanActivate() then
			-- use cask to retreat
			BotEcho("Running away using cask on: " .. unitClosestEnemy:GetTypeName())
			bActionTaken = core.OrderAbilityEntity(botBrain, abilCask, unitClosestEnemy)
		end
	end
		
		
	if not bActionTaken then
		return object.RetreatFromThreatExecuteOld(botBrain)
	end
	
end
object.RetreatFromThreatExecuteOld = behaviorLib.RetreatFromThreatExecute
behaviorLib.RetreatFromThreatBehavior["Execute"] = funcRetreatFromThreatExecuteOverride

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
		if EventData.InflictorName == "Ability_Voodoo1" then
            nAddBonus = nAddBonus + object.nCaskUse
        elseif EventData.InflictorName == "Ability_Voodoo2" then
            nAddBonus = nAddBonus + object.nMojoUse
       elseif EventData.InflictorName == "Ability_Voodoo3" then
            nAddBonus = nAddBonus + object.nCurseUse
        elseif EventData.InflictorName == "Ability_Voodoo4" then
            nAddBonus = nAddBonus + object.nWardUse
        end
    elseif EventData.Type == "Item" then
        if core.itemNuke ~= nil and EventData.SourceUnit == core.unitSelf:GetUniqueID() and EventData.InflictorName == core.itemNuke:GetName() then
            nAddBonus = nAddBonus + self.nNukeUse
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
        nUtil = nUtil + object.nCaskUp
    end
 
    if skills.abilW:CanActivate() then
        nUtil = nUtil + object.nMojoUp
    end
	if skills.abilE:CanActivate() then
        nUtil = nUtil + object.nCurseUp
    end
    if skills.abilR:CanActivate() then
        nUtil = nUtil + object.nWardUp
    end
 
    if object.itemNuke and object.itemNuke:CanActivate() then
        nUtil = nUtil + object.nNukeUp
    end
 
    return nUtil
end
-- assisgn custom Harrass function to the behaviourLib object
behaviorLib.CustomHarassUtilityFn = CustomHarassUtilityFnOverride   




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
    
    
    --- Insert abilities code here, set bActionTaken to true 
    --- if an ability command has been given successfully
    local bTargetVuln = unitTarget:IsStunned() or unitTarget:IsImmobilized()
	core.FindItems()
	local abilCask = skills.abilQ
	local abilMojo = skills.abilW
	local abilCurse = skills.abilE
	local abilWard = skills.abilR
	local itemNuke = core.itemNuke
	local itemImmunity = core.itemImmunity


    if core.CanSeeUnit(botBrain, unitTarget) then
	
		if core.unitSelf:IsChanneling() then
			local nRange = 700 --manually setting spirit ward's attack range since it's cast range is completely different
			if nTargetDistanceSq < (nRange * nRange) and core.CanSeeUnit(botBrain, unitTarget) then -- go ahead and break channels if they are out of spirit ward range
				--use shrunken head while channeling
				if not bActionTaken and itemImmunity then           
					if itemImmunity:CanActivate() then
						bActionTaken = core.OrderItemClamp(botBrain, unitSelf, itemImmunity)
					end
				end
			
				return
			end
		end
		
        -- if codex can instagib go ahead and use it
        if not bActionTaken and not bTargetVuln then           
            if itemNuke then
                local nRange = itemNuke:GetRange()
                if itemNuke:CanActivate() and GetCanNukeKillTarget(unitTarget) then
                    if nTargetDistanceSq < (nRange*nRange) then
                        bActionTaken = core.OrderItemEntityClamp(botBrain, unitSelf, itemNuke, unitTarget)
					else
						bActionTaken = core.OrderMoveToUnitClamp(botBrain, unitSelf, unitTarget)
                    end
                end
            end
        end
		
		-- start with cask
        if not bActionTaken and not bTargetVuln then
            if abilCask:CanActivate() and nLastHarassUtility > botBrain.nCaskThreshold then
                local nRange = abilCask:GetRange()
                if nTargetDistanceSq < (nRange * nRange) then
                    bActionTaken = core.OrderAbilityEntity(botBrain, abilCask, unitTarget)
					bComboing = true
                else
                    bActionTaken = core.OrderMoveToUnitClamp(botBrain, unitSelf, unitTarget)
                end
            end
        end 
    end
 
  -- curse CC'd targets
    if not bActionTaken and (bTargetVuln or nLastHarassUtility > botBrain.nCurseThreshold) then
		if abilCurse:CanActivate() and unitTarget:GetHealthPercent() > .25 then
			local nRange = abilCurse:GetRange()
			if nTargetDistanceSq < (nRange * nRange) then
				bComboing = false
				bActionTaken = core.OrderAbilityPosition(botBrain, abilCurse, vecTargetPosition)
			else
				bActionTaken = core.OrderMoveToUnitClamp(botBrain, unitSelf, unitTarget)
			end          
		end
	end
    
	if core.CanSeeUnit(botBrain, unitTarget) then
        -- post curse codex
        if not bActionTaken then           
            if itemNuke then
                local nRange = itemNuke:GetRange()
                if itemNuke:CanActivate() and nLastHarassUtility > botBrain.nNukeThreshold then
                    if nTargetDistanceSq < (nRange*nRange) then
                        bActionTaken = core.OrderItemEntityClamp(botBrain, unitSelf, itemNuke, unitTarget)
					else
						bActionTaken = core.OrderMoveToUnitClamp(botBrain, unitSelf, unitTarget)
                    end
                end
            end
        end
		
		-- throw mojo on there
        if not bActionTaken then
            if abilMojo:CanActivate() and nLastHarassUtility > botBrain.nMojoThreshold and (abilMojo:GetManaCost() + abilWard:GetManaCost()) >= unitSelf:GetMana() then
                local nRange = abilMojo:GetRange()
                if nTargetDistanceSq < (nRange * nRange) then
                    bActionTaken = core.OrderAbilityEntity(botBrain, abilMojo, unitTarget)
                else
                    bActionTaken = core.OrderMoveToUnitClamp(botBrain, unitSelf, unitTarget)
                end
            end
        end 
		
		--use spirit ward
        if not bActionTaken then
            if abilWard:CanActivate() and nLastHarassUtility > botBrain.nWardThreshold and unitTarget:GetHealthPercent() > .25 then
                local nRange = 700 --manually setting spirit ward's attack range since it's cast range is completely different
                if nTargetDistanceSq < (nRange * nRange) then
                    bActionTaken = core.OrderAbilityPosition(botBrain, abilWard, vecMyPosition)
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






