--[[

 ElectroBot v1.0
 by CASHBALLER
 
- Static Grip
-- used offensively when harass utility is high
-- sometimes stops channelling right after starting (seems to be a problem with other bots too)

- Electric Shield
-- used offensively with very high harass utility or high mana remaining
-- used defensively when health is relatively low compared to mana
-- gave it a short cooldown to prevent spamming

- Energy Absorption
-- used often with low harass utility threshold (maybe too aggressive for new players)
-- used during retreat for speed boost

- Static Shock
-- used offensively with high harass utility
-- if target is out of range, may use on self for speed boost (very high harass utility)
-- used defensively whenever slowed or snared
-- used to return to well faster
-- could be expanded to remove slows/snares on allies or purge speed buffs on enemies

- General
-- should increase well return utility when mana is very low, since he's useless without it
-- harass utility could also use some changes to reflect remaining mana
-- ability weights probably could use adjustments, but these work fairly well

- Code
-- using a single variable (bDebugLocal) instead of a different bDebugEchos in every method
-- got rid of bActionTaken because it seemed unnecessary
-- CustomReturnToWellExecute would not work, so overriding HealAtWellExecute instead

--]]


local _G = getfenv(0)
local object = _G.object

-- Set to true for local debug echo messages
local bDebugLocal = false

object.myName = object:GetName()

object.bRunLogic 		= true
object.bRunBehaviors	= true
object.bUpdates 		= true
object.bUseShop 		= true

object.bRunCommands 	= true
object.bMoveCommands 	= true
object.bAttackCommands 	= true
object.bAbilityCommands = true
object.bOtherCommands 	= true

object.bReportBehavior = false
object.bDebugUtility = false
object.bDebugExecute = false

object.logger = {}
object.logger.bWriteLog = false
object.logger.bVerboseLog = false

object.core 		= {}
object.eventsLib 	= {}
object.metadata 	= {}
object.behaviorLib 	= {}
object.skills 		= {}

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

BotEcho('loading electrician_main...')

--------------------------------
-- Lanes
--------------------------------
core.tLanePreferences = {Jungle = 0, Mid = 1, ShortSolo = 1, LongSolo = 1, ShortSupport = 4, LongSupport = 4, ShortCarry = 2, LongCarry = 2}

object.heroName = 'Hero_Electrician'

--------------------------------
-- Skills
--------------------------------
function object:SkillBuild()

	local unitSelf = self.core.unitSelf
	if  skills.abilStaticGrip == nil then
		skills.abilStaticGrip		= unitSelf:GetAbility(0)
		skills.abilElectricShield	= unitSelf:GetAbility(1)
		skills.abilEnergyAbsorption	= unitSelf:GetAbility(2)
		skills.abilCleansingShock	= unitSelf:GetAbility(3)
		skills.abilAttributeBoost	= unitSelf:GetAbility(4)
	end
	
	if unitSelf:GetAbilityPointsAvailable() <= 0 then
		return
	end
	
	-- Shock > Grip level 1 > Absorption > Grip > Shield > Stats
	if skills.abilCleansingShock:CanLevelUp() then
		skills.abilCleansingShock:LevelUp()
	elseif skills.abilStaticGrip:GetLevel() < 1 then
		skills.abilStaticGrip:LevelUp()	
	elseif skills.abilEnergyAbsorption:CanLevelUp() then
		skills.abilEnergyAbsorption:LevelUp()
	elseif skills.abilStaticGrip:CanLevelUp() then
		skills.abilStaticGrip:LevelUp()
	elseif skills.abilElectricShield:CanLevelUp() then
		skills.abilElectricShield:LevelUp()
	else
		skills.abilAttributeBoost:LevelUp()
	end
end

---------------------------------------------------
--                   Overrides                   --
---------------------------------------------------

--[[for testing
function object:onthinkOverride(tGameVariables)
	self:onthinkOld(tGameVariables)
		
	-- Insert code here
end
object.onthinkOld = object.onthink
object.onthink 	= object.onthinkOverride
--]]

----------------------------------
-- Electrician specific harass bonuses
--
-- Abilities off cd increase harass util
-- Ability use increases harass util for a time
----------------------------------
object.nStaticGripUp = 12
object.nEnergyAbsorptionUp = 20
object.nCleansingShockUp = 10

object.nStaticGripUse = 28
object.nElectricShieldUse = 18
object.nEnergyAbsorptionUse = 0
object.nCleansingShockUse = 16

object.nStaticGripLowThreshold = 39 -- use more freely when mana > 250 since we can still absorb/shock after
object.nStaticGripHighThreshold = 52 -- stricter usage when low mana
object.nElectricShieldLowThreshold = 38 -- high mana remaining - use freely
object.nElectricShieldMedThreshold = 56 -- medium mana remaining - use sparingly
object.nElectricShieldHighThreshold = 74 -- low mana remaining - only use if very aggressive
object.nEnergyAbsorptionThreshold = 10
object.nCleansingShockThreshold = 42
object.nCleansingShockSelfThreshold = 64 -- used to determine if the self speed boost is more important than waiting to get in range for the slow

object.nGameTime = 0
object.nShieldCooldown = 0

-- Increase harass util if abilities are available
local function AbilitiesUpUtilityFn(hero)
	
	local val = 0
	
	if skills.abilStaticGrip:CanActivate() then
		val = val + object.nStaticGripUp
	end
	
	if skills.abilEnergyAbsorption:CanActivate() then
		val = val + object.nEnergyAbsorptionUp
	end
	
	if skills.abilCleansingShock:CanActivate() then
		val = val + object.nCleansingShockUp
	end
	
	return val
end

-- Electrician ability use gives bonus to harass util for a while
function object:oncombateventOverride(EventData)
	self:oncombateventOld(EventData)
	
	local nAddBonus = 0
	
	if EventData.Type == "Ability" then
		if bDebugLocal then BotEcho("Combat Event - InflictorName: "..EventData.InflictorName) end
		if EventData.InflictorName == "Ability_Electrician1" then
			nAddBonus = nAddBonus + object.nStaticGripUse
		elseif EventData.InflictorName == "Ability_Electrician2" then
			nAddBonus = nAddBonus + object.nElectricShieldUse
		elseif EventData.InflictorName == "Ability_Electrician3" then
			nAddBonus = nAddBonus + object.nEnergyAbsorptionUse
		elseif EventData.InflictorName == "Ability_Electrician4" then
			nAddBonus = nAddBonus + object.nCleansingShockUse
		end
	end
	
	if nAddBonus > 0 then
		--decay before we add
		core.DecayBonus(self)
		core.nHarassBonus = core.nHarassBonus + nAddBonus
	end
end
object.oncombateventOld = object.oncombatevent
object.oncombatevent 	= object.oncombateventOverride

-- Util calc override
local function CustomHarassUtilityOverride(hero)
	local nUtility = AbilitiesUpUtilityFn(hero)
	
	-- Increase the weight of Electrician's mana on his utility
	-- Removed because it made him too aggressive early
	-- nUtility = nUtility + (core.unitSelf:GetManaPercent() - 0.5) * 20
	
	return nUtility
end
behaviorLib.CustomHarassUtility = CustomHarassUtilityOverride


----------------------------------
-- Electric Shield
--
-- Gave it a short cooldown so it doesn't get spammed pointlessly
----------------------------------
local function checkElectricShieldCooldown()
	object.nGameTime = HoN.GetGameTime() -- update game time variable
	if bDebugLocal then BotEcho("ShieldCheck - Checking Shield cooldown at: "..object.nGameTime) end
	if object.nGameTime > object.nShieldCooldown then
		if bDebugLocal then BotEcho("ShieldCheck - - Shield ready") end
		return true
	end
	return false
end

local function activateElectricShield(botBrain, bDebugEchos)
	if bDebugEchos then BotEcho("ShieldActivate - Shield casting...") end
	object.nShieldCooldown = object.nGameTime + 4000 -- four second cooldown
	return core.OrderAbility(botBrain, skills.abilElectricShield, false, bDebugEchos)
end


----------------------------------
-- Electrician harass actions
----------------------------------
local function HarassHeroExecuteOverride(botBrain)

	local unitTarget = behaviorLib.heroTarget
	if unitTarget == nil or not unitTarget:IsValid() then
		if bDebugLocal then BotEcho("HarassHero - No target") end
		return false --can not execute, move on to the next behavior
	end
	
	local unitSelf = core.unitSelf
	local nLastHarassUtility = behaviorLib.lastHarassUtil
	if bDebugLocal then BotEcho("HarassHero - Utility: "..nLastHarassUtility) end
	
	if unitSelf:IsChanneling() then
		if bDebugLocal then BotEcho("HarassHero - Channeling...") end
		local abilElectricShield = skills.abilElectricShield
		if abilElectricShield:CanActivate() and checkElectricShieldCooldown() then
			local nManaPercent = unitSelf:GetManaPercent()
			if nLastHarassUtility > botBrain.nElectricShieldLowThreshold and nManaPercent > 0.8 then
				if bDebugLocal then BotEcho("HarassHero - - Channeling and have extra mana, using Electric Shield!") end
				return activateElectricShield(botBrain, bDebugLocal)
			elseif nLastHarassUtility > botBrain.nElectricShieldMedThreshold and nManaPercent > 0.4 then
				if bDebugLocal then BotEcho("HarassHero - - Channeling and have mana, using Electric Shield!") end
				return activateElectricShield(botBrain, bDebugLocal)
			elseif nLastHarassUtility > botBrain.nElectricShieldHighThreshold then
				if bDebugLocal then BotEcho("HarassHero - - Channeling and using Electric Shield!") end
				return activateElectricShield(botBrain, bDebugLocal)
			end
		end
		return
	end
	
	local vecMyPosition = unitSelf:GetPosition()	
	local vecTargetPosition = unitTarget:GetPosition()
	local nTargetDistanceSq = Vector3.Distance2DSq(vecMyPosition, vecTargetPosition)
	
	-- Energy Absorption
	if nLastHarassUtility > botBrain.nEnergyAbsorptionThreshold then
		local abilEnergyAbsorption = skills.abilEnergyAbsorption
		if bDebugLocal then BotEcho("HarassHero - - Checking Energy Absorption range and activatable...") end
		if abilEnergyAbsorption:CanActivate() and nTargetDistanceSq < (300 * 300) then
			if bDebugLocal then BotEcho("HarassHero - - - Harassing with Energy Absorption") end
			return core.OrderAbility(botBrain, skills.abilEnergyAbsorption, false, bDebugLocal)
		end 
	end
	
	-- Static Grip
	local abilStaticGrip = skills.abilStaticGrip
	if abilStaticGrip:CanActivate() then
		if bDebugLocal then BotEcho("HarassHero - - Checking Static Grip worth casting...") end
		if (nLastHarassUtility > botBrain.nStaticGripHighThreshold or (nLastHarassUtility > botBrain.nStaticGripLowThreshold and unitSelf:GetMana() > 250)) and not (unitTarget:IsStunned() or unitTarget:IsImmobilized()) then
			if bDebugLocal then BotEcho("HarassHero - - - Harassing with Static Grip") end
			return core.OrderAbilityEntity(botBrain, abilStaticGrip, unitTarget)
		end 
	end
	
	-- Cleansing Shock
	if nLastHarassUtility > botBrain.nCleansingShockThreshold then
		local abilCleansingShock = skills.abilCleansingShock
		if bDebugLocal then BotEcho("HarassHero - - Checking Cleansing Shock range and activatable...") end
		if abilCleansingShock:CanActivate() and unitTarget:GetMoveSpeed() > 275 then
			local nRange = abilCleansingShock:GetRange()
			if nTargetDistanceSq < (nRange * nRange) then
				if bDebugLocal then BotEcho("HarassHero - - - Harassing with Cleansing Shock") end
				return core.OrderAbilityEntity(botBrain, abilCleansingShock, unitTarget)
			elseif nLastHarassUtility > botBrain.nCleansingShockSelfThreshold then
				if bDebugLocal then BotEcho("HarassHero - - - Speeding myself up with Cleansing Shock") end
				return core.OrderAbilityEntity(botBrain, abilCleansingShock, unitSelf)
			else
				if bDebugLocal then BotEcho("HarassHero - - - Harassing with Cleansing Shock") end
				return core.OrderAbilityEntity(botBrain, abilCleansingShock, unitTarget)
			end
		end 
	end
	
	-- Electric Shield
	local abilElectricShield = skills.abilElectricShield
	if nTargetDistanceSq < (300 * 300) and abilElectricShield:CanActivate() and checkElectricShieldCooldown() then
		local nManaPercent = unitSelf:GetManaPercent()
		if bDebugLocal then BotEcho("HarassHero - - Checking for Electric Shield with mana percent: "..nManaPercent) end
		if nLastHarassUtility > botBrain.nElectricShieldLowThreshold and nManaPercent > 0.8 then
			if bDebugLocal then BotEcho("HarassHero - - - Harassing with Electric Shield") end
			return activateElectricShield(botBrain, bDebugLocal)
		elseif nLastHarassUtility > botBrain.nElectricShieldMedThreshold and nManaPercent > 0.5 then
			if bDebugLocal then BotEcho("HarassHero - - - Harassing with Electric Shield") end
			return activateElectricShield(botBrain, bDebugLocal)
		elseif nLastHarassUtility > botBrain.nElectricShieldHighThreshold and nManaPercent > 0.3 then
			if bDebugLocal then BotEcho("HarassHero - - - Harassing with Electric Shield") end
			return activateElectricShield(botBrain, bDebugLocal)
		end
	end
	
	if bDebugLocal then BotEcho("HarassHero - - No action yet, proceeding with normal harass execute.") end
	return object.harassExecuteOld(botBrain)
end
object.harassExecuteOld = behaviorLib.HarassHeroBehavior["Execute"]
behaviorLib.HarassHeroBehavior["Execute"] = HarassHeroExecuteOverride


----------------------------------
--  Electrician specific retreat
----------------------------------
local function CustomRetreatExecuteOverride(botBrain)

	local unitSelf = core.unitSelf
	
	-- Use Cleansing Shock if snared
	local abilCleansingShock = skills.abilCleansingShock
	if abilCleansingShock:CanActivate() and (unitSelf:GetMoveSpeed() < 275 or unitSelf:IsImmobilized()) then
		if bDebugLocal then BotEcho("Retreat - Using Cleansing Shock to remove snare") end
		return core.OrderAbilityEntity(botBrain, abilCleansingShock, unitSelf)
	end
	
	-- Use Energy Absorption if we are near any enemy heroes (speed boost + free harass while retreating)
	local abilEnergyAbsorption = skills.abilEnergyAbsorption
	if abilEnergyAbsorption:CanActivate() then
		local tNearbyUnits = HoN.GetUnitsInRadius(unitSelf:GetPosition(), 300, core.UNIT_MASK_ALIVE + core.UNIT_MASK_HERO)
		local sortedUnits = {}
		core.SortUnitsAndBuildings(tNearbyUnits, sortedUnits, false)
		local nearbyEnemyHeroes = core.NumberElements(sortedUnits.enemyHeroes)
		if bDebugLocal then BotEcho("Retreat - Checking number of nearby enemy heroes: "..nearbyEnemyHeroes) end
		if nearbyEnemyHeroes > 0 then
			if bDebugLocal then BotEcho("Retreat - - Using Energy Absorption to retreat faster") end
			return core.OrderAbility(botBrain, abilEnergyAbsorption, false, bDebugLocal)
		end
	end
	
	-- Use Electric Shield if low health and enough extra mana
	local abilElectricShield = skills.abilElectricShield
	if abilElectricShield:CanActivate() and checkElectricShieldCooldown() then
		if bDebugLocal then BotEcho("Retreat - Checking if we have enough mana for a decent shield") end
		if unitSelf:GetManaPercent() > unitSelf:GetHealthPercent() * 2 and unitSelf:GetMana() - unitSelf:GetMaxMana() * 0.2 > 25 then
			if bDebugLocal then BotEcho("Retreat - Casting Electric Shield defensively") end
			return activateElectricShield(botBrain, bDebugLocal)
		end
	end
end
behaviorLib.CustomRetreatExecute = CustomRetreatExecuteOverride


-----------------------
-- Return to well
-----------------------
local function HealAtWellExecuteOverride(botBrain)

	local unitSelf = core.unitSelf
	
	-- Use Cleansing Shock
	local abilCleansingShock = skills.abilCleansingShock
	if abilCleansingShock:CanActivate() then
		if bDebugLocal then BotEcho("Well Return - Using Cleansing Shock to return faster") end
		return core.OrderAbilityEntity(botBrain, abilCleansingShock, unitSelf)
	end
	
	return object.healExecuteOld(botBrain)
end
object.healExecuteOld = behaviorLib.HealAtWellBehavior["Execute"]
behaviorLib.HealAtWellBehavior["Execute"] = HealAtWellExecuteOverride


----------------------------------
--	Electrician items
----------------------------------
--[[ list code:
	"# Item" is "get # of these"
	"Item #" is "get this level of the item" --]]
behaviorLib.StartingItems = {"2 Item_RunesOfTheBlight", "Item_GuardianRing", "Item_IronBuckler"}
behaviorLib.LaneItems = {"Item_Marchers", "Item_ManaRegen3", "Item_MysticVestments", "Item_Shield2"} -- Ring of the Teacher and Helm of the Black Legion
behaviorLib.MidItems = {"Item_EnhancedMarchers", "Item_Replenish", "Item_NomesWisdom", "Item_HealthMana2"} -- Ring of Sorcery and Icon of the Goddess
behaviorLib.LateItems = {"Item_Protect", "Item_SolsBulwark", "Item_DaemonicBreastplate", "Item_BehemothsHeart"} --Nullstone



--[[ colors:
	red
	aqua == cyan
	gray
	navy
	teal
	blue
	lime
	black
	brown
	green
	olive
	white
	silver
	purple
	maroon
	yellow
	orange
	fuchsia == magenta
	invisible
--]]

BotEcho('finished loading electrician_main')
