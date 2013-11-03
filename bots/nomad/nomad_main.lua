-- Nomadbot v0.01
--Created by Shoarmaboer/KapiteinKoektrommel
--Features TODO
--Implement ulti [semi done, only uses it defensively now]
--Implement smart and effective item usage [marchers, shroud done]
--Implement factoring in the amount of money we have when running the RetreatToWell util (or implement proper courier usage) [semi done, need to tweak values]
--Balance nUtil calculations (as they are now they roughly provide the wanted aggressive behaviour)
--Clean up code and further optimize where possible

--Fixes/unwanted behaviour TODO
--Breaks truestrike
--Runs back to a lane when he regens enough health to trigger the "go back to well behaviour", this is undesirable behaviour
--Doesn't last hit when he has the opportunity
--Doesn't pick up runes when he passes them
--Keeps backpeddling when in front of creep wave and facing enemy creepwave despite sometimes being able to tank the wave with ease

--Current Botstate
--Basics work, it can handle chronosbot at mid without using it's ultimate (though I'm far from happy with the current state)
--Bot can effectivly chase down targets with proper usage of truestrike/miragestrike + sandstorm (he has a good "sense" for what ability to use at what time)

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

BotEcho(object:GetName()..' loading nomad...')


----------------------------------
--	PositionSelfLogic
----------------------------------
behaviorLib.nHeroInfluencePercent = 4
behaviorLib.nCreepPushbackMul = 0.5
behaviorLib.nTargetPositioningMul = 0.5

--####################################################################
--####################################################################
--#                                                                 ##
--#                  Bot Constant Definitions                       ##
--#                                                                 ##
--####################################################################
--####################################################################

-- Hero_<hero>  to reference the internal HoN name of a hero, Hero_Yogi ==Wildsoul
object.heroName = 'Hero_Nomad'


-- Item Buy order. Internal names  
behaviorLib.StartingItems  = { "Item_RunesOfTheBlight", "Item_LoggersHatchet", "Item_IronBuckler"}
behaviorLib.LaneItems  = {"Item_Marchers"}
behaviorLib.MidItems  = {"Item_EnhancedMarchers", "Item_Lifetube", "Item_Shield2", "Item_MysticVestments"}
behaviorLib.LateItems  = {"Item_Pierce 3", "Item_Immunity", "Item_Stealth", "Item_Sasuke"}


-- Skillbuild table, 0= Sandstorm, 1= Miragestrike fake/real, 2=Wanderer, 3=Counteredge, 4=Attri
object.tSkills = {
    1, 2, 0, 1, 1,
    3, 1, 2, 2, 2, 
    3, 0, 0, 0, 4,
    3, 4, 4, 4, 4,
    4, 4, 4, 4, 4
}

--These are thresholds of aggression the bot must reach to use these abilities
object.nOffensiveChaseTreshold = 60
object.nTruestrikeTreshold = 45
object.nMiragestrikeTreshold = 25
object.nShroudTreshold = 30
object.nImmunityTreshold = 0

-- These are bonus agression points that are applied to the bot upon successfully using a skill/item
object.nSandStormUse = 10
object.nMiragestrikeUse = 5
object.nTruestrikeUse = 20
object.nCounterEdgeUse = 15
object.nImmunityUse = 40
object.nShroudUse = 15
object.nGenjuroUse = 20

--Tresholds for using counteredge
object.nCounterEdgeHealthVelocityTreshold = 0.25
object.nCounterEdgeRelativeHealthVelocityTreshold = 0.35

--Misc tresholds and factors
object.nHOTBLAggressionFactor = 0.125
object.nEnemyLowManaAggressionTreshold = 0.15
object.nEnemyLowManaAggresionFactor = 0.125
object.nSelfLowHealthAggressionTreshold = 0.25
object.nSelfLowHealthAggressionFactor = 0.25
object.nMaxRetreatToWellSpeedIncreaseActivationDistance = 2000
object.nSandstormRetreatFromWellHealthTreshold = 0.35
object.nMinCounterEdgeCooldownConsideration = 30

--We create a table for all the items, to make it more convient to use them later in the code
--We have an assetName for the ingame name of the item, and an item that references the actual object
--And on a sidenote, I dislike the fact that the assetnames do not always match those of the items in the actual game....
--BELIEVE IT!

--Assetname for shrunken head is Item_Immunity
--Assetname for assasin's shroud is Item_Stealth, and genjuro is Item_Sasuke
object.tItems = {}
object.tItems["HoTBL"] = {assetName = "Item_Shield2", item = nil}
object.tItems["Shroud"] = {assetName = "Item_Stealth", item = nil}
object.tItems["Genjuro"] = {assetName = "Item_Sasuke", item = nil}
object.tItems["Shrunken"] = {assetName = "Item_Immunity", item = nil}
object.tItems["ShieldBreaker"] = {assetName = "Item_Pierce", item = nil}

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
    local unitSelf = self.core.unitSelf;	
    if  skills.abilQ == nil then
        skills.abilQ = unitSelf:GetAbility(0)
        skills.abilW = unitSelf:GetAbility(5)
        skills.abilE = unitSelf:GetAbility(6)
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

local nPrevHealthPercent = 0

function object:onthinkOverride(tGameVariables)
    self:onthinkOld(tGameVariables)
	
	--Potential estimations for estimating whether to counteredge or not
	local botBrain = self
	local unitSelf = self.core.unitSelf
	local nHealthPercent = unitSelf:GetHealthPercent()
	local nHealthPercentVelocity = nPrevHealthPercent - nHealthPercent
	local nRelativeHealthPercentVelocity = nHealthPercentVelocity / nHealthPercent

	--BotEcho(format("Health velocity: %.4f", nHealthPercentVelocity * 100))
	--BotEcho(format("Relative health velocity: %.4f", nRelativeHealthPercentVelocity * 100))
	
	--Activate counteredge when we suddenly detect a huge spike of damage
	--Health will be lower, thus the theoretical chance of being attacked is higher and counteredge will be more succesful
	--Sadly we there is no support for tracking incoming spells (just projectiles) at this point of the bot api, so we cannot put that advantage to use
	
	local abilCounterEdge = skills.abilR
	if abilCounterEdge:CanActivate() then
		local nEnemyHeroes = GetEnemyHeroesInRadius(600)
		if nEnemyHeroes >= 2 then
			core.OrderAbility(botBrain, abilCounterEdge)
		end
	end
	
	if nHealthPercentVelocity > object.nCounterEdgeHealthVelocityTreshold or nRelativeHealthPercentVelocity > object.nCounterEdgeRelativeHealthVelocityTreshold then
		local nEnemyHeroes = GetEnemyHeroesInRadius(600)
		if nEnemyHeroes > 0 then
			if abilCounterEdge:CanActivate() then
				core.OrderAbility(botBrain, abilCounterEdge)
			end
		end
	end
	nPrevHealthPercent = nHealthPercent
end

object.onthinkOld = object.onthink
object.onthink 	= object.onthinkOverride

----------------------------------------------
--            OncombatEvent Override        --
-- Use to check for Infilictors (fe. Buffs) --
----------------------------------------------
-- @param: EventData
-- @return: none 
function object:oncombateventOverride(EventData)
    self:oncombateventOld(EventData)

    local nAddBonus = 0

    if EventData.Type == "Ability" then
        if EventData.InflictorName == "Ability_Nomad1" then
            nAddBonus = nAddBonus + object.nSandStormUse
        elseif EventData.InflictorName == "Ability_Nomad2a" then
            nAddBonus = nAddBonus + object.nTruestrikeUse
        elseif EventData.InflictorName == "Ability_Nomad2b" then
            nAddBonus = nAddBonus + object.nMiragestrikeUse
      elseif EventData.InflictorName == "Ability_Nomad4" then
            nAddBonus = nAddBonus + object.nCounterEdgeUse
        end
	elseif EventData.Type == "Item" then
		if object.tItems["Shrunken"].item ~= nil and EventData.SourceUnit == core.unitSelf:GetUniqueID() and EventData.InflictorName == object.tItems["Shrunken"].assetName then
			nAddBonus = nAddBonus + self.nImmunityUse
			if object.tItems["Shroud"].item ~= nil and EventData.SourceUnit == core.unitSelf:GetUniqueID() and EventData.InflictorName == object.tItems["Shroud"].assetName then
				nAddBonus = nAddBonus + self.nShroudUse
			end
			if object.tItems["Genjuro"] ~= nil and EventData.SourceUnit == core.unitSelf:GetUniqueID() and EventData.InflictorName == object.tItems["Genjuro"].assetName then
				nAddBonus = nAddBonus + self.nGenjuroUse
			end
		end
	end

   if nAddBonus > 0 then
        core.DecayBonus(self)
        core.nHarassBonus = core.nHarassBonus + nAddBonus
    end
end
-- override combat event trigger function.
object.oncombateventOld = object.oncombatevent
object.oncombatevent = object.oncombateventOverride



------------------------------------------------------
--            CustomHarassUtility Override          --
-- Change Utility according to usable spells here   --
------------------------------------------------------

--We use a bit more information to determine our nUtil compared to most other bots
--We try to express the bots "desire" to harass and kill the enemy hero
--The easier it is to kill the enemy bot, the higher it's killing intent gets
--We want the bot to have a proper estimation of what it's capable of given the enemy state and it's own state
local function CustomHarassUtilityFnOverride(hero)	
	local nUtil = 0
	local unitSelf = core.unitSelf
    local nEnemyLevel = hero:GetLevel()
	local nLevelSelf = unitSelf:GetLevel()
	local nLevelDiff = nLevelSelf - nEnemyLevel
	local nLevelDiffValue = 5
	
	--We increase the bot's desire to harass when the level is higher, but do not decrease it when it is lower
	--The bot can permit itself to stay aggresive, due to it's high amount of escape abilities
	if(nLevelDiff > 0) then
		nUtil = nUtil + (nLevelDiff * nLevelDiffValue)
	end
	
	local nEnemyMaxHealth = hero:GetMaxHealth()
	local nEnemyHealth = hero:GetHealth()
	local nEnemyMana = hero:GetMana()
	local nEnemyArmor = hero:GetArmor()
	
	--We can't see the enemy, thus we cannot not retrieve his armor value (nor any other information at this point), exit the function
	if nEnemyArmor == nil then
		return 0
	end
	
	local nDamageAverage = core.GetFinalAttackDamageAverage(unitSelf)
	nDamageAverage = nDamageAverage + GetExtraDamageFromWanderer(nDamageAverage)
	
	local nArmorPenetration = 0;
	local itemShieldBreaker = object.tItems["ShieldBreaker"].item
	
	--factor in the armor penetration from shieldbreaker
	if itemShieldBreaker ~= nil then
		nArmorPenetration = nArmorPenetration + itemShieldBreaker:GetLevel() * 2
	end
		
	local nFinalArmor = nEnemyArmor - nArmorPenetration
	--calculate how much "real" damage we do on a regular auto attack
	local nEffectiveAutoAttackDamage = GetEffectivePhysicalDamage(nFinalArmor, nDamageAverage)
	
	--calculate a damage to maxhealthpool ratio, how much damage can we inflict in regard to the enemies total healthpool?
	local nEffectiveAutoAttackDamageToMaxHealthRatio = nEffectiveAutoAttackDamage / nEnemyMaxHealth
	local nHitsRequiredForKill = nEnemyHealth / nEffectiveAutoAttackDamage
	
	if nHitsRequiredForKill < 1 then
		nHitsRequiredForKill = 1
	end
	
	--combine the damage to health ratio and the amounts of hits required to kill the enemy bot
	local nAutoAttackEffectivenessFactor = nEffectiveAutoAttackDamageToMaxHealthRatio + (1/nHitsRequiredForKill)
	local nMaxEffectiveAutoAttackDamageUtil = 55
	local nEffectiveAutoAttackDamageUtil = 5 + nMaxEffectiveAutoAttackDamageUtil * nAutoAttackEffectivenessFactor
	nUtil = nUtil + nEffectiveAutoAttackDamageUtil
	
	--Nomad's miragestrike versions both work on the same cooldown, so we only need to check one for activation
    if skills.abilW:CanActivate() then
		--Miragestrike real util
		local abilTrueStrike = skills.abilW
		local nStrikeLvl = abilTrueStrike:GetLevel()
		
		--Calculate how much effective damage we can deal with our miragestrikereal
		local nTrueStrikeDamage = 40 + (40 * nStrikeLvl)
		local nEffectiveTrueStrikeDamage = GetEffectivePhysicalDamage(nFinalArmor, nDamageAverage + nTrueStrikeDamage)
		
		--Exponential fn to calculate added truestrikeUtil
		local nEffectiveTrueStrikeDamageToHealthRatio = nEffectiveTrueStrikeDamage / nEnemyHealth
		local nTrueStrikeUtil =  2 ^ (4.25 * (nEffectiveTrueStrikeDamageToHealthRatio + nEffectiveTrueStrikeDamageToHealthRatio))
		
		--Calculate how much effective damage we can deal with our miragestrikefake
		local nMirageStrikeDamage = 40 + (20 * nStrikeLvl)
		local nEffectiveMirageStrikeDamage = GetEffectivePhysicalDamage(nFinalArmor, nDamageAverage + nMirageStrikeDamage)
		local nMaxMirageStrikeUtil = 30
		local nMirageStrikeUtil = nMaxMirageStrikeUtil * (nEffectiveMirageStrikeDamage / nEnemyMaxHealth)
		
		local nStrikeUtil = nTrueStrikeUtil > nMirageStrikeUtil and nTrueStrikeUtil or nMirageStrikeUtil
		nUtil  = nUtil + nStrikeUtil
		BotEcho(format("nMirageStrikeUtil: %.4f :", nMirageStrikeUtil))
    end
	
	local itemHoTBL = object.tItems["HoTBL"].item
	
	--Make the bot more likely to harass/towerdive when has has a hotbl in his inventory
	if itemHOTBL then
		nUtil = nUtil + (nUtil * nHOTBLAggressionFactor)
	end	
	
	--Low mana means the enemy is less likely to stun/snare/root us or deal high damage
	--Make him a tad more aggressive
	local nEnemyManaPercent = hero:GetManaPercent()
	
	if nEnemyManaPercent < object.nEnemyLowManaAggressionTreshold then
		nUtil = nUtil + (nUtil * object.nEnemyLowManaAggresionFactor)
	end
	
	nUtil = Clamp(nUtil, 0, 100)
	
	--If we are low on health, calm down a bit
	local nHealthPercent = unitSelf:GetHealthPercent()
	if nHealthPercent < object.nSelfLowHealthAggressionTreshold then
		nUtil = nUtil * object.nSelfLowHealthAggressionFactor
	end
	
	BotEcho(format("nUtil: %.4f", nUtil))
	
    return nUtil
end
-- assisgn custom Harrass function to the behaviourLib object
behaviorLib.CustomHarassUtility = CustomHarassUtilityFnOverride   


----------------------------------
--  FindItems Override
----------------------------------
local function funcFindItemsOverride(botBrain)
	local bUpdated = object.FindItemsOld(botBrain)

	for key, value in ipairs(object.tItems) do
		if core.tItems[key].item ~= nil and not core.tItems[key].item:isValid() then
			core.tItems[key].item = nil
		end
	end
	
	if bUpdated then
		local inventory = core.unitSelf:GetInventory(true)
		for index, value in pairs(object.tItems) do
			for slot = 1, 12, 1 do
				local curItem = inventory[slot]
				if curItem then
					if object.tItems[index].item == nil and curItem:GetName() == object.tItems[index].assetName then
						BotEcho(curItem:GetName())
						object.tItems[index].item = core.WrapInTable(curItem)
					end
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

	local unitSelf = core.unitSelf
	local nLastHarassUtility = behaviorLib.lastHarassUtil
	
	--When shroud is active, do not activate any abilities but instead try to get a hit in from stealth
	if unitSelf:HasState("State_Item3G") then
		return object.harassExecuteOld(botBrain) 
    end 
	
	--Check if nomad is charging at a target with truestrike
	--This behaviour still breaks when running other excute functions during the charge
	--We still need to make him tunnelvision but without making him suicide all the time
	if unitSelf:HasState("State_Nomad_Ability2_Self") then
		--BotEcho("True striking!")
		return 
	end	
	
    local unitTarget = behaviorLib.heroTarget
    if unitTarget == nil then
        return false
    end
 
    local vecMyPosition = unitSelf:GetPosition() 
    local nAttackRange = core.GetAbsoluteAttackRangeToUnit(unitSelf, unitTarget)
    local nMyExtraRange = core.GetExtraRange(unitSelf)
    
    local vecTargetPosition = unitTarget:GetPosition()
    local nTargetExtraRange = core.GetExtraRange(unitTarget)
    local nTargetDistanceSq = Vector3.Distance2DSq(vecMyPosition, vecTargetPosition)
  
    local bCanSee = core.CanSeeUnit(botBrain, unitTarget)    
    local bActionTaken = false
	local canSeeUnit = core.CanSeeUnit(botBrain, unitTarget)
	
	-- Nomad has two types of strikes one where he sends the illusion and one where he dashes in himself	
	if not bActionTaken then
		if canSeeUnit then
			local abilTrueStrike = skills.abilW
			if abilTrueStrike:CanActivate() and nLastHarassUtility >= object.nTruestrikeTreshold then
				local nRange = abilTrueStrike:GetRange()
					if nTargetDistanceSq < (nRange * nRange) then
						--BotEcho("Casting truestrike")
						bActionTaken = core.OrderAbilityEntity(botBrain, abilTrueStrike, unitTarget)
					end
			end
		end
	end
	
	--We activate sandstorm/ghostmarchers for chasing purposes, vroom vroom
	if not bActionTaken then
		if nLastHarassUtility >= object.nOffensiveChaseTreshold  then
			--Activate ghost marchers if we can
			local itemGhostMarchers = core.itemGhostMarchers
			if itemGhostMarchers ~= nil then
				if itemGhostMarchers:CanActivate() then
					core.OrderItemClamp(botBrain, unitSelf, itemGhostMarchers)
				end
			end
			
			--Cast sandstorm if we can (http://vocaroo.com/i/s1oychxZEv4x glorius custom sfx)
			local abilSandstorm = skills.abilQ
			if abilSandstorm:CanActivate() then
				bActionTaken = core.OrderAbility(botBrain, abilSandstorm)
			end
		end
    end 
	
	if not bActionTaken then
		if nLastHarassUtility >= botBrain.nShroudTreshold then
		local itemShroud = object.tItems["Shroud"].item
			if itemShroud then
				if itemShroud:CanActivate() then
					bActionTaken = core.OrderItemClamp(botBrain, unitSelf, itemShroud)
				end
			end
		end
	end
		
	if not bActionTaken then	
		if canSeeUnit then
			local abilMirage = skills.abilE
			if abilMirage:CanActivate() and nLastHarassUtility >= object.nMiragestrikeTreshold then
				local nRange = abilMirage:GetRange()
				if nTargetDistanceSq < (nRange * nRange) then
					--BotEcho("Casting Miragestrike")
					bActionTaken = core.OrderAbilityEntity(botBrain, abilMirage, unitTarget)
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

--We override this function because we have to factor in the usage of wanderer, nomad's signature last hitting helper ;)
function behaviorLib.GetCreepAttackTarget(botBrain, unitEnemyCreep, unitAllyCreep)
	local bDebugEchos = false
	-- no predictive last hitting, just wait and react when they have 1 hit left
	-- prefers LH over deny
	local unitSelf = core.unitSelf
	local vecMyPos = unitSelf:GetPosition()
	
	local nDamageAverage = core.GetFinalAttackDamageAverage(core.unitSelf)
	nDamageAverage = nDamageAverage + GetExtraDamageFromWanderer(nDamageAverage)
	
	if core.itemHatchet then
		nDamageAverage = nDamageAverage * core.itemHatchet.creepDamageMul
	end	
	
	if unitEnemyCreep and core.CanSeeUnit(botBrain, unitEnemyCreep) then	
		local nTargetHealth = unitEnemyCreep:GetHealth()
		local nTargetArmor = unitEnemyCreep:GetArmor()
		
		local nArmorPenetration = 0;
		local itemShieldBreaker = object.tItems["ShieldBreaker"].item
		
		if itemShieldBreaker ~= nil then
			nArmorPenetration = nArmorPenetration + itemShieldBreaker:GetLevel() * 2
		end
		
		local nFinalArmor = nTargetArmor - nArmorPenetration
		
		local nEffectiveDamageAverage = GetEffectivePhysicalDamage(nFinalArmor, nDamageAverage)
		
		--BotEcho(format("Effective Damage: %.2f", nEffectiveDamageAverage))
		--BotEcho(format("Creep health: %.2f", nTargetHealth))
		
		if nEffectiveDamageAverage >= nTargetHealth then
			local bActuallyLH = true
			
			if bActuallyLH then
				if bDebugEchos then BotEcho("Returning an enemy") end
				return unitEnemyCreep
			end
		end
	end

	if unitAllyCreep then
		local nTargetHealth = unitAllyCreep:GetHealth()
		local nTargetArmor = unitAllyCreep:GetArmor()
		local nEffectiveDamageAverage = GetEffectivePhysicalDamage(nTargetArmor, nDamageAverage)
		
		if nEffectiveDamageAverage >= nTargetHealth then
			local bActuallyDeny = true
			
			--[Difficulty: Easy] Don't deny
			if core.nDifficulty == core.nEASY_DIFFICULTY then
				bActuallyDeny = false
			end			
			
			if bActuallyDeny then
				if bDebugEchos then BotEcho("Returning an ally") end
				return unitAllyCreep
			end
		end
	end

	return nil
end

function behaviorLib.RetreatFromThreatExecuteOverride(botBrain)
	
    local unitTarget = behaviorLib.heroTarget
	
	--Cast miragestrike at enemy hero when we are retreating from threat
	--Function might need to be partially reworked due harass/mana considerations
	local unitSelf = core.unitSelf
		
	if unitTarget then
	local vecTargetPosition = unitTarget:GetPosition()
	local vecMyPosition = unitSelf:GetPosition()
		if core.CanSeeUnit(botBrain, unitTarget) then
			local abilMirageStrike = skills.abilE
			if abilMirageStrike:CanActivate() then
				local nRange = abilMirageStrike:GetRange()
				local nTargetDistanceSq = Vector3.Distance2DSq(vecMyPosition, vecTargetPosition)
				if nTargetDistanceSq < (nRange * nRange) then
					--BotEcho("Casting Miragestrike in order to flee")
					core.OrderAbilityEntity(botBrain, abilMirageStrike, unitTarget)
				end
			end
		end
	end
	
	local nHealthPercentage = unitSelf:GetHealthPercent()
	--Activate ghost marchers if we can
	local itemGhostMarchers = core.itemGhostMarchers
	if itemGhostMarchers then
		if behaviorLib.lastRetreatUtil >= behaviorLib.retreatGhostMarchersThreshold and itemGhostMarchers:CanActivate() then
			core.OrderItemClamp(botBrain, unitSelf, itemGhostMarchers)
			return
		end
	end
	
	local abilSandstorm = skills.abilQ
	local nHealthPercent = unitSelf:GetHealthPercent()

	local nEnemyHeroes = GetEnemyHeroesInRadius(600)
	if abilSandstorm:CanActivate() and  nHealthPercent <= object.nSandstormRetreatFromWellHealthTreshold  and nEnemyHeroes > 0 then -- and GetEnemyHeroes(600) > 0 
		--BotEcho("Retreating, activating sandstorm because it's up and we are low on health")
		core.OrderAbility(botBrain, abilSandstorm)
	end
	
	local vecPos = behaviorLib.PositionSelfBackUp()
	core.OrderMoveToPosClamp(botBrain, unitSelf, vecPos, false)
end

object.RetreatFromThreatExecuteOld = behaviorLib.RetreatFromThreatBehavior["Execute"]
behaviorLib.RetreatFromThreatBehavior["Execute"] = behaviorLib.RetreatFromThreatExecuteOverride

function behaviorLib.HealAtWellExecuteOverride(botBrain)
	local wellPos = core.allyWell and core.allyWell:GetPosition() or behaviorLib.PositionSelfBackUp()
	local unitSelf = core.unitSelf
	
	--Bot uses the abilities while he is in the well, which is undesirable behaviour due to causing unneccesary cooldowns
	local vecMyPosition = unitSelf:GetPosition()
	local nDistanceToWell = Vector3.Distance2DSq(vecMyPosition, wellPos)
	local bWithinUseDistance = nDistanceToWell > object.nMaxRetreatToWellSpeedIncreaseActivationDistance * object.nMaxRetreatToWellSpeedIncreaseActivationDistance 
	
	--Activate ghostmarchers when retreating to the well, to minimize bot downtime
	local itemGhostMarchers = core.itemGhostMarchers
	if itemGhostMarchers then
		if itemGhostMarchers:CanActivate() and bWithinUseDistance then
			core.OrderItemClamp(botBrain, core.unitSelf, itemGhostMarchers)
		end
	end
	
	--Cast sandstorm when retreating to the well, to minimize bot downtime (http://vocaroo.com/i/s1oychxZEv4x huehuehue)
	local abilSandstorm = skills.abilQ	
	if abilSandstorm:CanActivate() and bWithinUseDistance then
		--BotEcho("Retreating to well, activating sandstorm because it's up")
		core.OrderAbility(botBrain, abilSandstorm)
	end
	
	core.OrderMoveToPosAndHoldClamp(botBrain, unitSelf, wellPos, false)
end

object.HealAtWellBehaviorExecuteOld = behaviorLib.HealAtWellBehavior["Execute"]
behaviorLib.HealAtWellBehavior["Execute"] = behaviorLib.HealAtWellExecuteOverride

--Override the healatwell utility to factor in amount of gold on the bot, I consider 2000 gold an amount that's not too low nor too high to use as base
function behaviorLib.HealAtWellUtilityOverride(botBrain)
	local nUtil = 0
	local hpPercent = core.unitSelf:GetHealthPercent()

	if hpPercent < 0.95 then
		local wellPos = core.allyWell and core.allyWell:GetPosition() or Vector3.Create()
		local nDist = Vector3.Distance2D(wellPos, core.unitSelf:GetPosition())

		nUtil = behaviorLib.WellHealthUtility(hpPercent) + behaviorLib.WellProximityUtility(nDist)
	end

	if botBrain.bDebugUtility == true and nUtil ~= 0 then
		BotEcho(format("  HealAtWellUtility: %g", nUtil))
	end
	
	local nGold = botBrain:GetGold()
	local nGoldUtil = 8 *(nGold/2000)
	
	nUtil = nUtil + nGoldUtil
	
	--BotEcho(format("  HealAtWellUtility: %g", nUtil))
	
	return nUtil
end

object.HealAtWellUtilityOld = behaviorLib.HealAtWellBehavior["Utility"] 
behaviorLib.HealAtWellBehavior["Utility"] = behaviorLib.HealAtWellUtilityOverride

--------------------------------------------------------------
--                     Helper functions                     --
--   														--
--------------------------------------------------------------
local function GetExtraDamageFromWanderer(nDamage)
	local abilWanderer =  core.unitSelf:GetAbility(2)
	local nWandererLvl = abilWanderer:GetLevel()
	local nWandererCharges = abilWanderer:GetCharges()
	local nWandererMaxCharges = abilWanderer:GetMaxCharges()
	
	--Have we leveled wanderer and do we have the minimum amount of charges to apply the extra damage?
	if nWandererLvl > 0 and nWandererCharges >= 25 then
		--Determine the max added crit damage
		local nWandererDamageMulti = 0.2 + nWandererLvl * 0.2
		return (nDamage * (nWandererDamageMulti * (nWandererCharges / nWandererMaxCharges)))
	end
	
	return 0
end

local function GetEffectivePhysicalDamage(nArmor, nDamage)
	--Armor damage reduction formula
	local nDamageReductionBonus = (nArmor*0.06)/(1+(0.06 * nArmor))
	return nDamage - (nDamageReductionBonus * nDamage)
end

local function ConserveManaForCounterEdge(mana)
	local unitSelf = self.core.unitSelf
	local nLevel = unitSelf:GetLevel()
	
	if nLevel < 6 then
		return false
	end
	
	local abilCounterEdge = skills.abilR
	local nCounterEdgeManacost = abilCounterEdge:GetManaCost()	
	if mana - nCounterEdgeManaCost < 0 then
		local nCoolDown = abilCounterEdge:GetCooldown()
		if nCoolDown < object.nMinCounterEdgeCooldownConsideration then
			return true
		end
	end
	
	return false
end

local function GetEnemyHeroesInRadius(nRadius)
	local unitSelf = core.unitSelf
	local vecMyPos = unitSelf:GetPosition()
	local tUnits = HoN.GetUnitsInRadius(vecMyPos, nRadius, core.UNIT_MASK_ALIVE + core.UNIT_MASK_UNIT + core.UNIT_MASK_HERO)
	
	local nHeroCount = 0
	for key, val in pairs(tUnits) do
		if val ~= unitSelf and val:IsHero() and val:GetTeam() ~= unitSelf:GetTeam() then
			--BotEcho("Enemy hero within vicinity")
			nHeroCount = nHeroCount + 1
		end
	end
	
	return nHeroCount
end