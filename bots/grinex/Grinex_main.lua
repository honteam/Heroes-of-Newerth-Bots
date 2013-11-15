-----------------------------------------------------
--   _____      _                 ____        _    --
--  / ____|    (_)               |  _ \      | |   --
-- | |  __ _ __ _ _ __   _____  _| |_) | ___ | |_  --
-- | | |_ | '__| | '_ \ / _ \ \/ /  _ < / _ \| __| --
-- | |__| | |  | | | | |  __/>  <| |_) | (_) | |_  --
--  \_____|_|  |_|_| |_|\___/_/\_\____/ \___/ \__| --
--                       -v0.7 By: DarkFire-       --
-----------------------------------------------------

------------------------------------------
--          Bot Initialization          --
------------------------------------------

local _G = getfenv(0)
local object = _G.object

object.myName = object:GetName()

object.bRunLogic = true
object.bRunBehaviors = true
object.bUpdates = true
object.bUseShop = true

object.bRunCommands = true 
object.bMoveCommands = true
object.bAttackCommands = true
object.bAbilityCommands = true
object.bOtherCommands = true

object.bReportBehavior = false
object.bDebugUtility = false

object.logger = {}
object.logger.bWriteLog = false
object.logger.bVerboseLog = false

object.core = {}
object.eventsLib = {}
object.metadata = {}
object.behaviorLib = {}
object.skills = {}

runfile "bots/core.lua"
runfile "bots/botbraincore.lua"
runfile "bots/eventsLib.lua"
runfile "bots/metadata.lua"
runfile "bots/behaviorLib.lua"

local core, eventsLib, behaviorLib, metadata, skills = object.core, object.eventsLib, object.behaviorLib, object.metadata, object.skills

local print, ipairs, pairs, string, table, next, type, tinsert, tremove, tsort, format, tostring, tonumber, strfind, strsub
    = _G.print, _G.ipairs, _G.pairs, _G.string, _G.table, _G.next, _G.type, _G.table.insert, _G.table.remove, _G.table.sort, _G.string.format, _G.tostring, _G.tonumber, _G.string.find, _G.string.sub
local ceil, floor, pi, tan, atan, atan2, abs, cos, sin, acos, asin, max, random
    = _G.math.ceil, _G.math.floor, _G.math.pi, _G.math.tan, _G.math.atan, _G.math.atan2, _G.math.abs, _G.math.cos, _G.math.sin, _G.math.acos, _G.math.asin, _G.math.max, _G.math.random

local BotEcho, VerboseLog, BotLog = core.BotEcho, core.VerboseLog, core.BotLog
local Clamp = core.Clamp

BotEcho('loading Grinex_main...')

---------------------------------
--          Constants          --
---------------------------------

-- Grinex
object.heroName = 'Hero_Grinex'

-- Item buy order. internal names  
behaviorLib.StartingItems  = {"Item_IronBuckler", "Item_RunesOfTheBlight", "Item_LoggersHatchet"}
behaviorLib.LaneItems  = {"Item_Marchers", "Item_Steamboots", "Item_Lightbrand", "Item_Sicarius"}
behaviorLib.MidItems  = {"Item_Pierce 3", "Item_Critical1 4"}
behaviorLib.LateItems  = {"Item_Weapon3", "Item_DaemonicBreastplate"}

-- Skillbuild table, 0=q, 1=w, 2=e, 3=r, 4=attri
object.tSkills = {
	0, 2, 2, 1, 2,
	3, 2, 0, 0, 0,
	3, 1, 1, 1, 4,
	3, 4, 4, 4, 4,
	4, 4, 4, 4, 4,
}

-- Bonus agression points if a skill/item is available for use

object.nStepUp = 20
object.nStalkUp = 12
object.nAssaultUp = 38

object.nStrike1Up = 6
object.nStrike2Up = 9
object.nStrike3Up = 13
object.nStrike4Up = 18

-- Bonus agression points that are applied to the bot upon successfully using a skill/item

object.nStepUse = 18
object.nStalkUse = 12
object.nAssaultUse = 40

-- Thresholds of aggression the bot must reach to use these abilities

object.nStepThreshold = 28
object.nStalkThreshold = 22
object.nAssaultThreshold = 48

-- Other variables

behaviorLib.nCreepPushbackMul = 0.5
behaviorLib.nTargetPositioningMul = 0.6

------------------------------
--          Skills          --
------------------------------

function object:SkillBuild()
    local unitSelf = self.core.unitSelf
    if  skills.abilStep == nil then
        skills.abilStep = unitSelf:GetAbility(0)
        skills.abilStalk = unitSelf:GetAbility(1)
        skills.abilStrike = unitSelf:GetAbility(2)
        skills.abilAssault = unitSelf:GetAbility(3)
        skills.abilAttributeBoost = unitSelf:GetAbility(4)
    end
	
	local nPoints = unitSelf:GetAbilityPointsAvailable()
	if nPoints <= 0 then
		return
	end
	
	local nLevel = unitSelf:GetLevel()
	for i = nLevel, (nLevel + nPoints) do
		unitSelf:GetAbility( self.tSkills[i] ):LevelUp()
	end
end

------------------------------------------
--          FindItems Override          --
------------------------------------------

local function funcFindItemsOverride(botBrain)
    local bUpdated = object.FindItemsOld(botBrain)
 
	if core.itemSteamboots ~= nil and not core.itemSteamboots:IsValid() then
		core.itemSteamboots = nil
	end
     
    if bUpdated then
        --only update if we need to
        if core.itemSteamboots and  core.itemHellflower and core.itemSheepstick then
            return
        end
         
        local inventory = core.unitSelf:GetInventory(true)
        for slot = 1, 12, 1 do
            local curItem = inventory[slot]
            if curItem then
				if core.itemSteamboots == nill and curItem:GetName() == "Item_Steamboots" then
					core.itemSteamboots = core.WrapInTable(curItem)
                end
            end
        end
    end
end

object.FindItemsOld = core.FindItems
core.FindItems = funcFindItemsOverride

----------------------------------------
--          OnThink Override          --
----------------------------------------

function object:onthinkOverride(tGameVariables)
    self:onthinkOld(tGameVariables)
--[[
	local unitSelf = core.unitSelf
	core.FindItems()
	
	-- Toggle Steamboots for more Health/Mana
	local itemSteamboots = core.itemSteamboots
	if itemSteamboots then
		if itemSteamboots:CanActivate() then
			local sKey = itemSteamboots:GetActiveModifierKey()
			-- Toggle away from STR if health is high enough
			if sKey == "str" then
				if unitSelf:GetHealthPercent() > .575 then
					core.OrderItem(itemSteamboots)
				end
			-- Always toggle past AGI
			elseif sKey == "agi" then
					core.OrderItem(itemSteamboots)
			-- Toggle away from INT if health gets too low
			elseif sKey == "int" then
				if unitSelf:GetHealthPercent() < .375 then
					core.OrderItem(itemSteamboots)
				end
			end
		end
	end
--]]
end

object.onthinkOld = object.onthink
object.onthink = object.onthinkOverride

----------------------------------------------
--          OnCombatEvent Override          --
----------------------------------------------

function object:oncombateventOverride(EventData)
	self:oncombateventOld(EventData)

	local nAddBonus = 0
	
	if EventData.Type == "Ability" then
        if EventData.InflictorName == "Ability_Grinex1" then
            nAddBonus = nAddBonus + self.nStepUse
		elseif EventData.InflictorName == "Ability_Grinex2" then
			nAddBonus = nAddBonus + self.nStalkUse
        elseif EventData.InflictorName == "Ability_Grinex4" then
            nAddBonus = nAddBonus + self.nAssaultUse
        end
    end
 
    if nAddBonus > 0 then
        core.DecayBonus(self)
        core.nHarassBonus = core.nHarassBonus + nAddBonus
    end
end

object.oncombateventOld = object.oncombatevent
object.oncombatevent = object.oncombateventOverride

----------------------------------------------------
--          CustomHarassUtility Override          --
----------------------------------------------------

local function CustomHarassUtilityFnOverride(hero)
	local nUtility = 0

    if skills.abilStep:CanActivate() then
        nUtility = nUtility + object.nStepUp
    end
 
    if skills.abilStalk:CanActivate() then
        nUtility = nUtility + object.nStalkUp
    end
 
    if skills.abilAssault:CanActivate() then
        nUtility = nUtility + object.nAssaultUp
    end

	-- Use diiferent Utility values for each level of Nether Strike
	local nStrikeLevel = skills.abilStrike:GetLevel()
	if nStrikeLevel == 1 then
        nUtility = nUtility + object.nStrike1Up
	elseif nStrikeLevel == 2 then
        nUtility = nUtility + object.nStrike2Up
	elseif nStrikeLevel == 3 then
        nUtility = nUtility + object.nStrike3Up
	elseif nStrikeLevel == 4 then
        nUtility = nUtility + object.nStrike4Up
	end
	
    return nUtility
end

behaviorLib.CustomHarassUtility = CustomHarassUtilityFnOverride   

-----------------------------------------
--          Shadow Step Logic          --
-----------------------------------------

-- Filters a group to be within a given range. Modified from St0l3n_ID's Chronos bot
local function filterGroupRange(tGroup, vecCenter, nRange)
	if tGroup and vecCenter and nRange then
		local tResult = {}
		for _, unitTarget in pairs(tGroup) do
			if Vector3.Distance2DSq(unitTarget:GetPosition(), vecCenter) <= (nRange * nRange) then
				tinsert(tResult, unitTarget)
			end
		end	
	
		if #tResult > 0 then
			return tResult
		end
	end
	
	return nil
end

-- Cycles through the table to find the closest target to the position, then returns the direction to that target
local function getClosestUnitDirectionFromTable(vecPosition, tUnitTable)
	local vecDirection = nil
	local nDistanceSq = nil
	local nBestDistanceSq = (350 * 350)
	local vecTargetPosition = nil
	local vecBestPosition = nil
	for _, unitTarget in pairs(tUnitTable) do
		vecTargetPosition = unitTarget:GetPosition()
		core.DrawXPosition(vecTargetPosition, "Yellow", 100)
		nDistanceSq = Vector3.Distance2DSq(vecPosition, vecTargetPosition)
		if nDistanceSq <= nBestDistanceSq and nDistanceSq ~= 0 then
			vecBestPosition = vecTargetPosition
			nBestDistanceSq = nDistanceSq
		end
	end

	if vecBestPosition then
		vecDirection = Vector3.Normalize(vecBestPosition - vecPosition)
	end
	
	return vecDirection
end

-- Find the best direction to cast Shadow Step
local function getStepDirection(botBrain, unitTarget)
	local bSuccess = false
	local vecDirection = nil
	local vecTargetPosition = unitTarget:GetPosition()
	
	local tLocalUnits = core.localUnits
	if tLocalUnits then
		-- Check Enemy Heroes
		if not bSuccess then
			local tLocalEnemyHeroes = filterGroupRange(tLocalUnits["EnemyHeroes"], vecTargetPosition, 350)
			if core.NumberElements(tLocalEnemyHeroes) > 1 then
				vecDirection = getClosestUnitDirectionFromTable(vecTargetPosition, tLocalEnemyHeroes)
				if vecDirection then
					core.DrawDebugArrow(vecTargetPosition, vecTargetPosition + vecDirection * 350, "Red")
					bSuccess = true
				end
			end
		end
		
		-- Check Allied Heroes
		if not bSuccess then
			local tLocalAllyHeroes = filterGroupRange(tLocalUnits["AllyHeroes"], vecTargetPosition, 350)
			if core.NumberElements(tLocalAllyHeroes) > 0 then
				vecDirection = getClosestUnitDirectionFromTable(vecTargetPosition, tLocalAllyHeroes)
				if vecDirection then
					core.DrawDebugArrow(vecTargetPosition, vecTargetPosition + vecDirection * 350, "Red")
					bSuccess = true
				end
			end
		end
		
		-- Check Enemy Buildings
		if not bSuccess then
			local tLocalEnemyBuildings = filterGroupRange(tLocalUnits["EnemyBuildings"], vecTargetPosition, 350)
			if core.NumberElements(tLocalEnemyBuildings) > 0 then
				vecDirection = getClosestUnitDirectionFromTable(vecTargetPosition, tLocalEnemyBuildings)
				if vecDirection then
					core.DrawDebugArrow(vecTargetPosition, vecTargetPosition + vecDirection * 350, "Red")
					bSuccess = true
				end
			end
		end
		
		-- Check Allied Buildings
		if not bSuccess then
			local tLocalAllyBuildings = filterGroupRange(tLocalUnits["AllyBuildings"], vecTargetPosition, 350)
			if core.NumberElements(tLocalAllyBuildings) > 0 then
				vecDirection = getClosestUnitDirectionFromTable(vecTargetPosition, tLocalAllyBuildings)
				if vecDirection then
					core.DrawDebugArrow(vecTargetPosition, vecTargetPosition + vecDirection * 350, "Red")
					bSuccess = true
				end
			end
		end
	end
	
	-- Check Trees
	if not bSuccess then
		local tLocalTrees = HoN.GetTreesInRadius(vecTargetPosition, 350)
		if tLocalTrees then
			if core.NumberElements(tLocalTrees) > 0 then
				vecDirection = getClosestUnitDirectionFromTable(vecTargetPosition, tLocalTrees)
				if vecDirection then
					core.DrawDebugArrow(vecTargetPosition, vecTargetPosition + vecDirection * 350, "Green")
					bSuccess = true
				end
			end
		end
	end 

	--[[ Check Cliffs
	if not bSuccess then

	
	
	
	
	
	
	
	
	
	end
	--]]
	
	-- Push Towards Ally Well
	if not bSuccess then
		local unitAllyWell = core.allyWell
		if unitAllyWell then
			vecDirection = Vector3.Normalize(unitAllyWell:GetPosition() - vecTargetPosition)
			if vecDirection then
				core.DrawDebugArrow(vecTargetPosition, vecTargetPosition + vecDirection * 350, "Blue")
				bSuccess = true
			end
		end
	end
	
	return vecDirection
end

---------------------------------------
--          Harass Behavior          --
---------------------------------------

local function HarassHeroExecuteOverride(botBrain)
    
    local unitTarget = behaviorLib.heroTarget
    if unitTarget == nil then
        return object.harassExecuteOld(botBrain)
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
	
	-- Stop the bot from trying to harass heroes while dead
	if not bActionTaken and not unitSelf:IsAlive() then
		bActionTaken = true
	end
	
	-- Don't cast spells while the bot has the Nether Strike buff
	if unitSelf:HasState("State_Grinex_Ability3") then
        return object.harassExecuteOld(botBrain)
	end
	
	-- Rift Stalk (Out of Shadow Step range)
	if not bActionTaken then
		local abilStalk = skills.abilStalk
		if abilStalk:CanActivate() and nLastHarassUtility > object.nStalkThreshold then
			-- Only use if the enemy is far away and the bot has follow up mana,
			-- or the target is at critical health levels
			if (nTargetDistanceSq > (450 * 450) and (unitSelf:GetManaPercent() > .35) or unitTarget:GetHealthPercent() < .125) then
				bActionTaken = core.OrderAbility(botBrain, abilStalk)
			end
		end
	end
	
	-- Shadow Step
	if not bActionTaken then
		local abilStep = skills.abilStep
		if abilStep:CanActivate() and nLastHarassUtility > object.nStepThreshold then
			if nTargetDistanceSq < (450 * 450) then
				local vecPushDirection = getStepDirection(botBrain, unitTarget)
				if vecPushDirection then
					-- bActionTaken = core.OrderAbilityEntity(botBrain, abilStep)
				end
			end
		end
	end	
	
	-- Illusory Assault
	if not bActionTaken then
		local abilAssault = skills.abilAssault
		if abilAssault:CanActivate() and nLastHarassUtility > object.nAssaultThreshold then
			-- Only use if target is close to melee range
			if nTargetDistanceSq < (300 * 300) then
				bActionTaken = core.OrderAbility(botBrain, abilAssault)
			end
		end
	end
	
	-- Rift Stalk (In Shadow Step range)
	if not bActionTaken then
		local abilStalk = skills.abilStalk
		if abilStalk:CanActivate() and nLastHarassUtility > object.nStalkThreshold then
			-- Don't use if Shadow Step is up
			local abilStep = skills.abilStep
			if not abilStep:CanActivate() then
				bActionTaken = core.OrderAbility(botBrain, abilStalk)
			end
		end
	end

	if not bActionTaken then
        return object.harassExecuteOld(botBrain)
    end 
end

object.harassExecuteOld = behaviorLib.HarassHeroBehavior["Execute"]
behaviorLib.HarassHeroBehavior["Execute"] = HarassHeroExecuteOverride

--------------------------------------------------
--          RetreatFromThreat Override          --
--------------------------------------------------

function funcRetreatFromThreatExecuteOverride(botBrain)
	local bActionTaken = false
	local abilStalk = skills.abilStalk
	
	-- Use Rift Stalk to retreat if possible
	if abilStalk:CanActivate() then
		local unitSelf = core.unitSelf
		if unitSelf:GetHealthPercent() < .55 then
			bActionTaken = core.OrderAbility(botBrain, abilStalk)
		end
	end
	
	if not bActionTaken then
		return object.RetreatFromThreatExecuteOld(botBrain)
	end
end

object.RetreatFromThreatExecuteOld = behaviorLib.RetreatFromThreatExecute
behaviorLib.RetreatFromThreatBehavior["Execute"] = funcRetreatFromThreatExecuteOverride

-------------------------------------------------
--          HealAtWellExecute Overide          --
-------------------------------------------------

local function HealAtWellOveride(botBrain)
    local bActionTaken = false
    local abilStalk = skills.abilStalk
 
	-- Use Rift Stalk on way to well
	if abilStalk:CanActivate() then
		local unitSelf = core.unitSelf
		local vecAllyWell = core.allyWell:GetPosition()
		local nDistToWellSq = Vector3.Distance2DSq(unitSelf:GetPosition(), vecAllyWell)
		if nDistToWellSq > (1000 * 1000) then
			bActionTaken = core.OrderAbility(botBrain, abilStalk)
		end
	end
 
    if not bActionTaken then
        return object.HealAtWellBehaviorOld(botBrain)
    end
end

object.HealAtWellBehaviorOld = behaviorLib.HealAtWellBehavior["Execute"]
behaviorLib.HealAtWellBehavior["Execute"] = HealAtWellOveride

BotEcho(object:GetName()..' finished loading Grinex_main')