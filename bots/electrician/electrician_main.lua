--[[

 ElectroBot v1.1
 by CASHBALLER
 
---------------------------------------------------
--               Recent Changes
---------------------------------------------------

----- 1.1 -----

- Functionality
-- Now purges debuffs on allies and speed buffs on enemies
-- Updated lane preferences

- Code
-- Removed object.nGameTime
-- Renamed val to nUtility
-- Updated SkillBuild function
-- Moved constants around for readability (thanks HagBot)
-- Added bActionTaken back in

---------------------------------------------------
--                   Notes
---------------------------------------------------

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
-- used to remove perplex/snares/slows/silence from nearby allies
-- used to remove haste from nearby enemies
-- used offensively with high harass utility
-- if target is out of range, may use on self for speed boost (very high harass utility)
-- used defensively whenever slowed or snared
-- used to return to well faster

- General
-- should increase well return utility when mana is very low, since he's useless without it
-- harass utility could also use some changes to reflect remaining mana
-- ability weights probably could use adjustments, but these work fairly well
-- to implement: Cleansing Shock enemy summoned units

- Code
-- using a single variable (bDebugLocal) instead of a different bDebugEchos in every method
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

---------------------------------------------------
--                  Constants
---------------------------------------------------

object.heroName = 'Hero_Electrician'

-- Lanes
core.tLanePreferences = {Jungle = 0, Mid = 1, ShortSolo = 1, LongSolo = 1, ShortSupport = 3, LongSupport = 3, ShortCarry = 3, LongCarry = 3}

-- Items (internal names)
behaviorLib.StartingItems = {"2 Item_RunesOfTheBlight", "Item_GuardianRing", "Item_IronBuckler"}
behaviorLib.LaneItems = {"Item_Marchers", "Item_ManaRegen3", "Item_MysticVestments", "Item_Shield2"}
behaviorLib.MidItems = {"Item_EnhancedMarchers", "Item_Replenish", "Item_NomesWisdom", "Item_HealthMana2"}
behaviorLib.LateItems = {"Item_Protect", "Item_SolsBulwark", "Item_DaemonicBreastplate", "Item_BehemothsHeart"}

-- Skillbuild table, 0 = q, 1 = w, 2 = e, 3 = r, 4 = attri
object.tSkills = {
	0, 2, 2, 0, 2,
	3, 2, 0, 0, 1,
	3, 1, 1, 1, 4,
	3, 4, 4, 4, 4,
	4, 4, 4, 4, 4
}

-- Bonus agression points if a skill/item is available for use
object.nStaticGripUp = 12
object.nEnergyAbsorptionUp = 20
object.nCleansingShockUp = 10

-- Bonus agression points that are applied to the bot upon successfully using a skill/item
object.nStaticGripUse = 28
object.nElectricShieldUse = 18
object.nEnergyAbsorptionUse = 0
object.nCleansingShockUse = 16

-- Thresholds of aggression the bot must reach to use these abilities
object.nStaticGripLowThreshold = 39 -- use more freely when mana > 250 since we can still absorb/shock after
object.nStaticGripHighThreshold = 52 -- stricter usage when low mana
object.nElectricShieldLowThreshold = 38 -- high mana remaining - use freely
object.nElectricShieldMedThreshold = 56 -- medium mana remaining - use sparingly
object.nElectricShieldHighThreshold = 74 -- low mana remaining - only use if very aggressive
object.nEnergyAbsorptionThreshold = 10
object.nCleansingShockThreshold = 42
object.nCleansingShockSelfThreshold = 64 -- used to determine if the self speed boost is more important than waiting to get in range for the slow

-- Stores game time at which shield can be cast again (not constant)
object.nShieldCooldown = 0

---------------------------------------------------
--                   Skills
---------------------------------------------------
function object:SkillBuild()
	local unitSelf = self.core.unitSelf
	if  skills.abilStaticGrip == nil then
		skills.abilStaticGrip = unitSelf:GetAbility(0)
		skills.abilElectricShield = unitSelf:GetAbility(1)
		skills.abilEnergyAbsorption = unitSelf:GetAbility(2)
		skills.abilCleansingShock = unitSelf:GetAbility(3)
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

---------------------------------------------------
--            OnCombatEvent Override
---------------------------------------------------
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

---------------------------------------------------
--        CustomHarassUtility Override
---------------------------------------------------
local function CustomHarassUtilityOverride(hero)
	
	local nUtility = 0
	
	if skills.abilStaticGrip:CanActivate() then
		nUtility = nUtility + object.nStaticGripUp
	end
	
	if skills.abilEnergyAbsorption:CanActivate() then
		nUtility = nUtility + object.nEnergyAbsorptionUp
	end
	
	if skills.abilCleansingShock:CanActivate() then
		nUtility = nUtility + object.nCleansingShockUp
	end
	
	return nUtility
end
behaviorLib.CustomHarassUtility = CustomHarassUtilityOverride

---------------------------------------------------
--               Electric Shield
---------------------------------------------------
local function checkElectricShieldCooldown()
	local nGameTime = HoN.GetGameTime()
	if bDebugLocal then BotEcho("ShieldCheck - Checking Shield cooldown at: "..nGameTime) end
	if nGameTime > object.nShieldCooldown then
		if bDebugLocal then BotEcho("ShieldCheck - - Shield ready") end
		return true
	end
	return false
end

-- Short cooldown on shield to prevent spamming
local function activateElectricShield(botBrain, bDebugEchos)
	local nGameTime = HoN.GetGameTime()
	if bDebugEchos then BotEcho("ShieldActivate - Shield casting at: "..nGameTime) end
	object.nShieldCooldown = nGameTime + 4000 -- four second cooldown
	return core.OrderAbility(botBrain, skills.abilElectricShield, false, bDebugEchos)
end

---------------------------------------------------
--         Cleansing Shock TargetFinder
---------------------------------------------------
local function findPurgeTarget(botBrain, unitSelf)
	local tNearbyUnits = HoN.GetUnitsInRadius(unitSelf:GetPosition(), 600, core.UNIT_MASK_ALIVE + core.UNIT_MASK_HERO)
	local tSortedUnits = {}
	core.SortUnitsAndBuildings(tNearbyUnits, tSortedUnits, false)
	local unitPurgePerplex = nil
	local unitPurgeSnare = nil
	local unitPurgeSlow = nil
	local unitPurgeSilence = nil
	local nSlowSpeed = 275
	
	-- Check nearby allies for debuffs we can purge
	for nUID,unitAlly in pairs(tSortedUnits.allyHeroes) do		
		if unitAlly:IsPerplexed() then
			unitPurgePerplex = unitAlly
		end
		if unitAlly:IsImmobilized() then
			unitPurgeSnare = unitAlly
		end
		local nUnitSpeed = unitAlly:GetMoveSpeed()
		if nUnitSpeed < nSlowSpeed then
			unitPurgeSlow = unitAlly
			nSlowSpeed = nUnitSpeed
		end
		if unitAlly:IsSilenced() then
			unitPurgeSilence = unitAlly
		end
	end
	
	-- Purge debuffs if any exist
	if unitPurgePerplex ~= nil then
		if bDebugLocal then BotEcho("PurgeFinder - Targeting ally to remove perplex") end
		return unitPurgePerplex
	elseif unitPurgeSnare ~= nil then
		if bDebugLocal then BotEcho("PurgeFinder - Targeting ally to remove snare") end
		return unitPurgeSnare
	elseif unitPurgeSlow ~= nil then
		if bDebugLocal then BotEcho("PurgeFinder - Targeting ally to remove slow") end
		return unitPurgeSlow
	elseif unitPurgeSilence ~= nil then
		if bDebugLocal then BotEcho("PurgeFinder - Targeting ally to remove silence") end
		return unitPurgeSilence
	else
		
		-- Otherwise check for hasted enemies
		for nUID,unitEnemy in pairs(tSortedUnits.enemyHeroes) do
			if (unitEnemy:GetMoveSpeed() > 500 or unitEnemy:IsStealth()) and botBrain.CanSeeUnit(unitEnemy) then
				if bDebugLocal then BotEcho("PurgeFinder - Targeting enemy to remove speed buff") end
				return unitEnemy
			end
		end
	end
end

---------------------------------------------------
--          Electrician harass actions
---------------------------------------------------
local function HarassHeroExecuteOverride(botBrain)

	local bActionTaken = false
	local unitTarget = behaviorLib.heroTarget
	if unitTarget == nil or not unitTarget:IsValid() then
		if bDebugLocal then BotEcho("HarassHero - No target") end
		return object.harassExecuteOld(botBrain)
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
				bActionTaken = activateElectricShield(botBrain, bDebugLocal)
			elseif nLastHarassUtility > botBrain.nElectricShieldMedThreshold and nManaPercent > 0.4 then
				if bDebugLocal then BotEcho("HarassHero - - Channeling and have mana, using Electric Shield!") end
				bActionTaken = activateElectricShield(botBrain, bDebugLocal)
			elseif nLastHarassUtility > botBrain.nElectricShieldHighThreshold then
				if bDebugLocal then BotEcho("HarassHero - - Channeling and using Electric Shield!") end
				bActionTaken = activateElectricShield(botBrain, bDebugLocal)
			end
		end
		return bActionTaken
	end
	
	local vecMyPosition = unitSelf:GetPosition()	
	local vecTargetPosition = unitTarget:GetPosition()
	local nTargetDistanceSq = Vector3.Distance2DSq(vecMyPosition, vecTargetPosition)
	
	-- Energy Absorption
	if not bActionTaken and nLastHarassUtility > botBrain.nEnergyAbsorptionThreshold then
		local abilEnergyAbsorption = skills.abilEnergyAbsorption
		if bDebugLocal then BotEcho("HarassHero - - Checking Energy Absorption range and activatable...") end
		if abilEnergyAbsorption:CanActivate() and nTargetDistanceSq < (300 * 300) then
			if bDebugLocal then BotEcho("HarassHero - - - Harassing with Energy Absorption") end
			bActionTaken = core.OrderAbility(botBrain, skills.abilEnergyAbsorption, false, bDebugLocal)
		end 
	end
	
	-- Static Grip
	if not bActionTaken then
		local abilStaticGrip = skills.abilStaticGrip
		if abilStaticGrip:CanActivate() then
			if bDebugLocal then BotEcho("HarassHero - - Checking Static Grip worth casting...") end
			if (nLastHarassUtility > botBrain.nStaticGripHighThreshold or (nLastHarassUtility > botBrain.nStaticGripLowThreshold and unitSelf:GetMana() > 250)) and not (unitTarget:IsStunned() or unitTarget:IsImmobilized()) then
				if bDebugLocal then BotEcho("HarassHero - - - Harassing with Static Grip") end
				bActionTaken = core.OrderAbilityEntity(botBrain, abilStaticGrip, unitTarget)
			end 
		end
	end
	
	-- Cleansing Shock
	if not bActionTaken then
		local abilCleansingShock = skills.abilCleansingShock
		if abilCleansingShock:CanActivate() then
			-- Find nearby heroes to Cleansing Shock
			local unitPurgeTarget = findPurgeTarget(botBrain, unitSelf)
			if unitPurgeTarget ~= nil then
				if bDebugLocal then BotEcho("HarassHero - - Casting Cleansing Shock on nearby hero") end
				bActionTaken = core.OrderAbilityEntity(botBrain, abilCleansingShock, unitPurgeTarget)
			elseif nLastHarassUtility > botBrain.nCleansingShockThreshold and unitTarget:GetMoveSpeed() > 275 then
				if nTargetDistanceSq < (600 * 600) then
					if bDebugLocal then BotEcho("HarassHero - - Harassing with Cleansing Shock") end
					bActionTaken = core.OrderAbilityEntity(botBrain, abilCleansingShock, unitTarget)
				elseif nLastHarassUtility > botBrain.nCleansingShockSelfThreshold then
					if bDebugLocal then BotEcho("HarassHero - - Speeding myself up with Cleansing Shock") end
					bActionTaken = core.OrderAbilityEntity(botBrain, abilCleansingShock, unitSelf)
				else
					if bDebugLocal then BotEcho("HarassHero - - Harassing with Cleansing Shock") end
					bActionTaken = core.OrderAbilityEntity(botBrain, abilCleansingShock, unitTarget)
				end
			end
		end
	end
	
	-- Electric Shield
	if not bActionTaken then
		local abilElectricShield = skills.abilElectricShield
		if nTargetDistanceSq < (300 * 300) and abilElectricShield:CanActivate() and checkElectricShieldCooldown() then
			local nManaPercent = unitSelf:GetManaPercent()
			if bDebugLocal then BotEcho("HarassHero - - Checking for Electric Shield with mana percent: "..nManaPercent) end
			if nLastHarassUtility > botBrain.nElectricShieldLowThreshold and nManaPercent > 0.8 then
				if bDebugLocal then BotEcho("HarassHero - - - Harassing with Electric Shield") end
				bActionTaken = activateElectricShield(botBrain, bDebugLocal)
			elseif nLastHarassUtility > botBrain.nElectricShieldMedThreshold and nManaPercent > 0.5 then
				if bDebugLocal then BotEcho("HarassHero - - - Harassing with Electric Shield") end
				bActionTaken = activateElectricShield(botBrain, bDebugLocal)
			elseif nLastHarassUtility > botBrain.nElectricShieldHighThreshold and nManaPercent > 0.3 then
				if bDebugLocal then BotEcho("HarassHero - - - Harassing with Electric Shield") end
				bActionTaken = activateElectricShield(botBrain, bDebugLocal)
			end
		end
	end
	
	if not bActionTaken then
		if bDebugLocal then BotEcho("HarassHero - - No action yet, proceeding with normal harass execute.") end
		return object.harassExecuteOld(botBrain)
	end
	
	return bActionTaken
end
object.harassExecuteOld = behaviorLib.HarassHeroBehavior["Execute"]
behaviorLib.HarassHeroBehavior["Execute"] = HarassHeroExecuteOverride

---------------------------------------------------
--       Electrician specific retreat
---------------------------------------------------
local function CustomRetreatExecuteOverride(botBrain)

	local bActionTaken = false
	local unitSelf = core.unitSelf
	
	-- Use Cleansing Shock if snared (prioritize self)
	if not bActionTaken then
		local abilCleansingShock = skills.abilCleansingShock
		if abilCleansingShock:CanActivate() then
			if unitSelf:GetMoveSpeed() < 275 or unitSelf:IsImmobilized() then
				if bDebugLocal then BotEcho("Retreat - Using Cleansing Shock to remove snare") end
				bActionTaken = core.OrderAbilityEntity(botBrain, abilCleansingShock, unitSelf)
			else
				-- Find nearby heroes to Cleansing Shock
				local unitPurgeTarget = findPurgeTarget(botBrain, unitSelf)
				if unitPurgeTarget ~= nil then
					if bDebugLocal then BotEcho("Retreat - Casting Cleansing Shock on nearby hero") end
					bActionTaken = core.OrderAbilityEntity(botBrain, abilCleansingShock, unitPurgeTarget)
				end
			end
		end
	end
	
	-- Use Energy Absorption if we are near any enemy heroes (speed boost + free harass while retreating)
	if not bActionTaken then
		local abilEnergyAbsorption = skills.abilEnergyAbsorption
		if abilEnergyAbsorption:CanActivate() then
			local tNearbyUnits = HoN.GetUnitsInRadius(unitSelf:GetPosition(), 300, core.UNIT_MASK_ALIVE + core.UNIT_MASK_HERO)
			local tSortedUnits = {}
			core.SortUnitsAndBuildings(tNearbyUnits, tSortedUnits, false)
			local nNearbyEnemyHeroes = core.NumberElements(tSortedUnits.enemyHeroes)
			if bDebugLocal then BotEcho("Retreat - Checking number of nearby enemy heroes: "..nNearbyEnemyHeroes) end
			if nNearbyEnemyHeroes > 0 then
				if bDebugLocal then BotEcho("Retreat - - Using Energy Absorption to retreat faster") end
				bActionTaken = core.OrderAbility(botBrain, abilEnergyAbsorption, false, bDebugLocal)
			end
		end
	end
	
	-- Use Electric Shield if low health and enough extra mana
	if not bActionTaken then
		local abilElectricShield = skills.abilElectricShield
		if abilElectricShield:CanActivate() and checkElectricShieldCooldown() then
			if bDebugLocal then BotEcho("Retreat - Checking if we have enough mana for a decent shield") end
			if unitSelf:GetManaPercent() > unitSelf:GetHealthPercent() * 2 and unitSelf:GetMana() - unitSelf:GetMaxMana() * 0.2 > 25 then
				if bDebugLocal then BotEcho("Retreat - Casting Electric Shield defensively") end
				bActionTaken = activateElectricShield(botBrain, bDebugLocal)
			end
		end
	end
	
	return bActionTaken
end
behaviorLib.CustomRetreatExecute = CustomRetreatExecuteOverride

---------------------------------------------------
--               Return to well
---------------------------------------------------
local function HealAtWellExecuteOverride(botBrain)

	local bActionTaken = false
	local unitSelf = core.unitSelf
	
	-- Use Cleansing Shock
	if not bActionTaken then
		local abilCleansingShock = skills.abilCleansingShock
		if abilCleansingShock:CanActivate() then
			if bDebugLocal then BotEcho("Well Return - Using Cleansing Shock to return faster") end
			bActionTaken = core.OrderAbilityEntity(botBrain, abilCleansingShock, unitSelf)
		end
	end
	
	if not bActionTaken then
		return object.healExecuteOld(botBrain)
	end
	
	return bActionTaken
end
object.healExecuteOld = behaviorLib.HealAtWellBehavior["Execute"]
behaviorLib.HealAtWellBehavior["Execute"] = HealAtWellExecuteOverride

BotEcho('finished loading electrician_main')