--BehemothBot v0.0.7
-- Created by Djulio
local _G = getfenv(0)
local object = _G.object

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

BotEcho('loading behemoth_main...')

-- Defining hero name
object.heroName = 'Hero_Behemoth'

--------------------------------
-- Skills
--------------------------------
function object:SkillBuild()
	local unitSelf = self.core.unitSelf

	-- Fetching and defining skills
	if  skills.abilFissure == nil then
		skills.abilFissure		= unitSelf:GetAbility(0)
		skills.abilEnrage		= unitSelf:GetAbility(1)
		skills.abilHeavyWeight	= unitSelf:GetAbility(2)
		skills.abilShockwave	= unitSelf:GetAbility(3)
		skills.abilAttributeBoost	= unitSelf:GetAbility(4)
	end
	
	if unitSelf:GetAbilityPointsAvailable() <= 0 then
		return
	end
	

	-- Defining skills table and skill building
	-- Q, E, Q, W, Q, R, Q, E, E, E, R, W, W, W, Att, R, Attr...
	tSkills ={
				0, 2, 0, 1, 0,
				3, 0, 2, 2, 2,
				3, 1, 1, 1, 4,
				3
			}
	
	local nLev = unitSelf:GetLevel()						-- Get bot's current level
    local nLevPts = unitSelf:GetAbilityPointsAvailable()	-- Get the available points to spend

	-- Leveling the skills by fetching numbers in tSkills and skilling Attribute when none more skills selected
    for i = nLev, nLev+nLevPts do
		local nSkill = tSkills[i]
		if nSkill == nil then nSkill = 4 end
		unitSelf:GetAbility(nSkill):LevelUp()
    end
end



---------------------------------------------------
--             Weight-Overrides                  --
---------------------------------------------------
behaviorLib.nCreepPushbackMul = 0.5
behaviorLib.nTargetPositioningMul = 3
behaviorLib.nTargetCriticalPositioningMul = 1

----------------------------------
--	Behemoth specific harass bonuses
--
--  Abilities off cd increase harass util
--  Ability use increases harass util for a time
----------------------------------

object.nFissureUp = 10
object.nEnrageUp = 15
object.nShockwaveUp = 40
object.nFrostfieldUp = 13

object.nFissureUse = 30
object.nEnrageUse = 45
object.nShockwaveUse = 60
object.nFrostfieldUse = 15

object.nFissureThreshold = 45
object.nEnrageThreshold = 55
object.nShockwaveThreshold = 65
object.nFrostfieldThreshold = 35


---------------------------------------------------
--            Util Calculation                   --
-- TODO: Frostfield plate calculation			 --
---------------------------------------------------
local function AbilitiesUpUtilityFn(hero)
	local bDebugEchos = false
	
	local nUtility = 0
	
	-- Increase utility when Fissure is activatable
	if skills.abilFissure:CanActivate() then
		nUtility = nUtility + object.nFissureUp
	end

	-- Increase utility when Enrage is activatable
	if skills.abilEnrage:CanActivate() then
		nUtility = nUtility + object.nEnrageUp
	end
	
	-- Increase utility when Shockwave is activatable
	if skills.abilShockwave:CanActivate() then
		nUtility = nUtility + object.nShockwaveUp
	end
	
	-- Increase utility when Frostfield Plate is activatable
	if object.itemFrostfield and object.itemFrostfield:CanActivate() then
		nUtility = nUtility + object.nFrostfieldUp
	end
	
	if bDebugEchos then BotEcho(" HARASS - abilitiesUp: "..nUtility) end
	
	return nUtility
end

-- Behemoth abilityUse gives bonus to harass util for a while
function object:oncombateventOverride(EventData)
	self:oncombateventOld(EventData)
	
	local bDebugEchos = false
	local nAddBonus = 0
	
	if EventData.Type == "Ability" then
		if bDebugEchos then BotEcho("  ABILILTY EVENT!  InflictorName: "..EventData.InflictorName) end
		if EventData.InflictorName == "Ability_Behemoth1" then
			nAddBonus = nAddBonus + object.nFissureUse
		elseif EventData.InflictorName == "Ability_Behemoth2" then
			nAddBonus = nAddBonus + object.nEnrageUse
		elseif EventData.InflictorName == "Ability_Behemoth4" then
			nAddBonus = nAddBonus + object.nShockwaveUse
		end
	elseif EventData.Type == "Item" then
		if core.itemFrostfield ~= nil and EventData.SourceUnit == core.unitSelf:GetUniqueID() and EventData.InflictorName == core.itemFrostfield:GetName() then
			nAddBonus = nAddBonus + self.nFrostfieldUse
		end
	end
	
	if nAddBonus > 0 then
		-- Decay before we add
		core.DecayBonus(self)
	
		core.nHarassBonus = core.nHarassBonus + nAddBonus
	end
end
object.oncombateventOld = object.oncombatevent
object.oncombatevent 	= object.oncombateventOverride

-- Util calc override
local function CustomHarassUtilityOverride(hero)
	local nUtility = AbilitiesUpUtilityFn(hero)
	
	return nUtility
end
behaviorLib.CustomHarassUtility = CustomHarassUtilityOverride   

----------------------------------
--	Behemoth harass actions
--
-- TODO: Frostfield plate harass
----------------------------------
local function HarassHeroExecuteOverride(botBrain)
	local bDebugEchos = false
	
	local unitTarget = behaviorLib.heroTarget
	if unitTarget == nil then
		return false --can not execute, move on to the next behavior
	end
	
	local unitSelf = core.unitSelf
	
	local vecMyPosition = unitSelf:GetPosition()
	local nAttackRangeSq = core.GetAbsoluteAttackRangeToUnit(unitSelf, unitTarget)
	nAttackRangeSq = nAttackRangeSq * nAttackRangeSq
	local nMyExtraRange = core.GetExtraRange(unitSelf)
	
	local vecTargetPosition = unitTarget:GetPosition()
	local nTargetExtraRange = core.GetExtraRange(unitTarget)
	local nTargetDistanceSq = Vector3.Distance2DSq(vecMyPosition, vecTargetPosition)
	local bTargetRooted = unitTarget:IsStunned() or unitTarget:IsImmobilized() or unitTarget:GetMoveSpeed() < 200 -- Defining a rooted target (stunned/immobilized/<200 ms)
	
	local nLastHarassUtility = behaviorLib.lastHarassUtil
	local bCanSee = core.CanSeeUnit(botBrain, unitTarget)	-- Target is visible?
	
	if bDebugEchos then BotEcho("Behemoth HarassHero at "..nLastHarassUtility) end
	local bActionTaken = false
		
	
	--Fissure		
	if not bActionTaken then
		if bDebugEchos then BotEcho("  No action yet, checking Fissure") end
		
		local abilFissure = skills.abilFissure			-- fetch Fissure ability
		local nFissureLevel = abilFissure:GetLevel() 	-- get Fissure level
		local nFissureRange = abilFissure:GetRange()	-- get Fissure range
		local nFissureCost = abilFissure:GetManaCost() 	-- get Fissure mana cost
		
		-- Defining damage for Fissure depending on its level
		local nFissureDamage = 125
		if nFissureLevel == 2 then
			nFissureDamage = 175
		elseif nFissureLevel == 3 then
			nFissureDamage = 225
		elseif nFissureLevel == 4 then
			nFissureDamage = 275
		end
		
		-- Getting the target's magic resistance
		local nTargetMagicResistance = unitTarget:GetMagicResistance()
		if nTargetMagicResistance == nil then
			nTargetMagicResistance = 0
		end
		
		-- Getting target's health and calculating the damage that could be done according to their magic resistance
		local nTargetHealth = unitTarget:GetHealth()
		local nDamageMultiplier = 1 - nTargetMagicResistance
		local nTrueDamage = nFissureDamage * nDamageMultiplier
		
		
		local bShouldFissure = false 
		local bFissureUsable = abilFissure:CanActivate() and nTargetDistanceSq < (nFissureRange * nFissureRange) -- Use Fissure if it can be activated and is in enough range
		
		if bFissureUsable then
		
			-- Fetching Shockwave skill and checking whether we have a level in it
			-- Then get its mana cost, to determine whether to use Fissure
			local abilShockwave = skills.abilShockwave
			local nShockwaveLevel = abilShockwave:GetLevel() -- get Shockwave level
			local nShockwaveCost = abilShockwave:GetManaCost() -- get Shockwave mana cost
			
				-- if its level can not be determined, set to 0
				if nShockwaveLevel == nil then
					nShockwaveLevel = 0
				end

				-- Check, if we have ult and whether we can use it
				if nShockwaveLevel == 0 or not abilShockwave:CanActivate() then
					-- true, if the target has low enough health to get one-shot by the Fissure
					if nTrueDamage > nTargetHealth then
						bShouldFissure = true
					else
						-- true, if target is rooted and the threshold has been overcome
						if not bTargetRooted and nLastHarassUtility > botBrain.nFissureThreshold then
							bShouldFissure = true
						end
					end
				else
					-- Don't use Fissure, if it means we can't use Ult
					if unitSelf:GetMana() - nShockwaveCost > nFissureCost then
						-- true, if the target has low enough health to get one-shot by the Fissure
						if nTrueDamage > nTargetHealth then
							if bDebugEchos then BotEcho("  KS-ing like a baws - has ult, not on cd and enough mana!") end
							bShouldFissure = true
						else
							-- true, if target is rooted and the threshold has been overcome
							if not bTargetRooted and nLastHarassUtility > botBrain.nFissureThreshold then
								bShouldFissure = true
							end
						end
					end
				end
		end	
		
			-- If bshouldFissure gets changed to 'true', use Fissure
			if bShouldFissure then
				bActionTaken = core.OrderAbilityPosition(botBrain, abilFissure, vecTargetPosition)  -- execute ability
			end
	end
	

	
	--Enrage
	-- used if target is rooted and we overcome the threshold for Enrage
	if not bActionTaken and bTargetRooted and nLastHarassUtility > botBrain.nEnrageThreshold then
		if bDebugEchos then BotEcho("  No action yet, checking Enrage") end
		
		local abilEnrage = skills.abilEnrage -- fetch Enrage ability
		-- Can we activate the skill?
		if abilEnrage:CanActivate() then
			-- Casting it in specific range, so it can also trigger Heavy Weigth,if skilled
			if nTargetDistanceSq < (250 * 250) then
				bActionTaken = core.OrderAbility(botBrain, abilEnrage) -- execute ability
			end
		end 
	end
	
	--Shockwave
	if not bActionTaken and bCanSee and nLastHarassUtility > botBrain.nShockwaveThreshold then
		if bDebugEchos then BotEcho("  No action yet, checking Shockwave") end
		
		-- Fetching Shockwave ability
		local abilShockwave = skills.abilShockwave
		-- Get Shockwave range
		local nShockwaveRange = abilShockwave:GetRange()
		-- Define Shockwave range squared and adding additional distance by falsely making the range smaller, so that it won't try to ult when it's just on the border
		local nShockwaveCloseDistanceSq = nShockwaveRange * nShockwaveRange * 0.25
		
		if abilShockwave:CanActivate() then

			-- Continue,if distance from self to target is longer than the possible
			if nTargetDistanceSq > nShockwaveCloseDistanceSq then
				
				-- Checking for Portal Key
				core.FindItems()
				local itemPortalKey = core.itemPortalKey
				local bSuccessful = false
				-- Continue,if there's a Portal Key and we can activate it
				if itemPortalKey and itemPortalKey:CanActivate() then
				
					local nPKRange = itemPortalKey:GetRange()			-- Get Portal Key range
					local nPKRangeSqt = nPKRange * nPKRange				-- Get Portal Key's range squared
					local vecTargetPosition = unitTarget:GetPosition() 	-- Get target's position
					local nDistance = Vector3.Distance2D(unitSelf:GetPosition(), vecTargetPosition) -- Detect distance between self and target in vector
					
						-- Continue, if the distance between self and target is in Portal Key range
						if nDistance < nPKRangeSqt then
							if bDebugEchos then BotEcho("Portal Key in - aand ulting!") end
							bSuccessful = core.OrderItemPosition(botBrain, unitSelf, itemPortalKey, unitTarget:GetPosition()) -- Use PK to target's position
							if bSuccessful then
								bActionTaken = core.OrderAbility(botBrain, abilShockwave, false, true) -- Use ult
								return
							end
						-- Otherwise walk in to ult (TODO: change it to the distance needed for PK only?)
						else
							if bDebugEchos then BotEcho("Moving in to ult  - range too long!") end
							bSuccessful = core.OrderMoveToUnitClamp(botBrain, unitSelf, unitTarget) -- Walk in
							if bSuccessful then
								-- Use ult
								bActionTaken = core.OrderAbility(botBrain, abilShockwave, false, true)  -- Use ult
								return
							end
						end
				-- Otherwise walk in to ult
				else
					if bDebugEchos then BotEcho("Moving in to ult - no pk or on cd!") end
					bSuccessful = core.OrderMoveToUnitClamp(botBrain, unitSelf, unitTarget) -- Walk in
					if bSuccessful then
						bActionTaken = core.OrderAbility(botBrain, abilShockwave, false, true)  -- Use ult
						return
					end
				end
	
			-- No need to PK, since we're in Range
			elseif nTargetDistanceSq < nShockwaveCloseDistanceSq then
				if bDebugEchos then BotEcho("Ult - in range!") end
				bActionTaken = core.OrderAbility(botBrain, abilShockwave, false, true)  -- Use ult
			end
			
				--[[ DO DA Wombo Combo after ult (Enrage, attack, Fissure)
				local abilEnrage = skills.abilEnrage
				if abilEnrage:CanActivate() and nTargetDistanceSq < (250 * 250) then
					BotEcho("Wombo Combo - Fissure plus attack!")
					-- Enrage - Casting it in specific range, so it can also trigger Heavy Weigth,if skilled
					local EnrageSuccess = core.OrderAbility(botBrain, abilEnrage)
					-- Attack afterwards
					if EnrageSuccess then core.OrderAttackClamp(botBrain, unitSelf, unitTarget) end
				end
				
				local abilFissure = skills.abilFissure
				local nFissureRange = abilFissure:GetRange()
				if abilFissure:CanActivate() and nTargetDistanceSq < (nFissureRange * nFissureRange) then
					-- Fissure
					BotEcho("Wombo Combo - Fissure!")
					core.OrderAbilityPosition(botBrain, abilFissure, vecTargetPosition)
				end
				--/DO DA Wombo Combo after ult (Enrage, attack, Fissure)]]
		end
	end

	-- If no action was determined to take place, back to normal harass
	if not bActionTaken then
		if bDebugEchos then BotEcho("  No action yet, proceeding with normal harass execute.") end
		object.harassExecuteOld(botBrain)
	end
end
object.harassExecuteOld = behaviorLib.HarassHeroBehavior["Execute"]
behaviorLib.HarassHeroBehavior["Execute"] = HarassHeroExecuteOverride



----------------------------------
--  FindItems Override
----------------------------------
local function funcFindItemsOverride(botBrain)
	local bUpdated = object.FindItemsOld(botBrain)

	-- Define Ring of Sorcery
	if core.itemRoS ~= nil and not core.itemRoS:IsValid() then
		core.itemRoS = nil
	end
	-- Define Portal Key
	if core.itemPortalKey ~= nil and not core.itemPortalKey:IsValid() then
		core.itemPortalKey = nil
	end

	-- Define Frostfield plate
	if core.itemFrostfield ~= nil and not core.itemFrostfield:IsValid() then
		core.itemFrostfield = nil
	end
	
	if bUpdated then
		-- Only update, if we need to
		if core.itemPortalKey and core.itemRoS and core.itemFrostfield then
			return
		end

		-- Checking inventory
		local inventory = core.unitSelf:GetInventory(true)
		for slot = 1, 12, 1 do
			local curItem = inventory[slot]
			if curItem then
				-- Check for Ring of Sorcery
				if core.itemRoS == nil and curItem:GetName() == "Item_Replenish" then
					core.itemRoS = core.WrapInTable(curItem)
					core.itemRoS.nReplenishValue = 135
					core.itemRoS.nRadius = 500
				-- Check for Portal Key
				elseif core.itemPortalKey == nil and curItem:GetName() == "Item_PortalKey" then
					core.itemPortalKey = core.WrapInTable(curItem)
					core.itemPortalKey.nRadius = 1200
				-- Check for Frostfield Plate
				elseif core.itemFrostfield == nil and curItem:GetName() == "Item_FrostfieldPlate" then
					core.itemFrostfield = core.WrapInTable(curItem)
					core.itemFrostfield.nRadius = 1000
				end
			end
		end
	end
end
object.FindItemsOld = core.FindItems
core.FindItems = funcFindItemsOverride



----------------------------------
--	Behemoth's Help behavior
--	
--	Utility: 
--	Execute: Use Ring of Sorcery (edited Astrolabe code)
----------------------------------

behaviorLib.nReplenishUtilityMul = 1.3
behaviorLib.nReplenishManaUtilityMul = 1.0
behaviorLib.nReplenishTimeToLiveUtilityMul = 0.5

function behaviorLib.ReplenishManaUtilityFn(unitHero)
	local nUtility = 0
	
	local nYIntercept = 100
	local nXIntercept = 100
	local nOrder = 2

	nUtility = core.ExpDecay(unitHero:GetManaPercent() * 100, nYIntercept, nXIntercept, nOrder)
	
	return nUtility
end

function behaviorLib.TimeToLiveUtilityFn(unitHero)
	--Increases as your time to live based on your damage velocity decreases
	local nUtility = 0
	
	local nManaVelocity = unitHero:GetManaRegen()	-- Get mana regen
	local nMana = unitHero:GetMana()				-- Get mana
	local nTimeToLive = 9999
	if nManaVelocity < 0 then
		nTimeToLive = nMana / (-1 * nManaVelocity)
		
		local nYIntercept = 100
		local nXIntercept = 20
		local nOrder = 2
		nUtility = core.ExpDecay(nTimeToLive, nYIntercept, nXIntercept, nOrder)
	end
	
	nUtility = Clamp(nUtility, 0, 100)
	
	--BotEcho(format("%d timeToLive: %g  healthVelocity: %g", HoN.GetGameTime(), nTimeToLive, nManaVelocity))
	
	return nUtility, nTimeToLive
end

behaviorLib.nReplenishCostBonus = 10
behaviorLib.nReplenishCostBonusCooldownThresholdMul = 4.0
function behaviorLib.AbilityCostBonusFn(unitSelf, ability)
	local bDebugEchos = false
	
	local nCost =		ability:GetManaCost()		-- Get item mana cost
	local nCooldownMS =	ability:GetCooldownTime()	-- Get item cooldown
	local nRegen =		unitSelf:GetManaRegen()		-- Get bot's mana regeneration
	
	local nTimeToRegenMS = nCost / nRegen * 1000
	
	if bDebugEchos then BotEcho(format("AbilityCostBonusFn - nCost: %d  nCooldown: %d  nRegen: %g  nTimeToRegen: %d", nCost, nCooldownMS, nRegen, nTimeToRegenMS)) end
	if nTimeToRegenMS < nCooldownMS * behaviorLib.nReplenishCostBonusCooldownThresholdMul then
		return behaviorLib.nReplenishCostBonus
	end
	
	return 0
end

behaviorLib.unitReplenishTarget = nil
behaviorLib.nReplenishTimeToLive = nil
function behaviorLib.ReplenishUtility(botBrain)
	local bDebugEchos = false
	
	if bDebugEchos then BotEcho("ReplenishUtility") end
	
	local nUtility = 0

	local unitSelf = core.unitSelf
	behaviorLib.unitReplenishTarget = nil
	
	core.FindItems()
	local itemRoS = core.itemRoS
	
	local nHighestUtility = 0
	local unitTarget = nil
	local nTargetTimeToLive = nil
	local sAbilName = ""
	if itemRoS and itemRoS:CanActivate() then
		local tTargets = core.CopyTable(core.localUnits["AllyHeroes"]) 	-- Get allies close to the bot
		tTargets[unitSelf:GetUniqueID()] = unitSelf 					-- Identify bot as a target too
		for key, hero in pairs(tTargets) do
			--Don't mana ourself if we are going to head back to the well anyway, 
			--	as it could cause us to retrace half a walkback
			if hero:GetUniqueID() ~= unitSelf:GetUniqueID() or core.GetCurrentBehaviorName(botBrain) ~= "HealAtWell" then
				local nCurrentUtility = 0
				
				local nManaUtility = behaviorLib.ReplenishManaUtilityFn(hero) * behaviorLib.nReplenishManaUtilityMul
				local nTimeToLiveUtility = nil
				local nCurrentTimeToLive = nil
				nTimeToLiveUtility, nCurrentTimeToLive = behaviorLib.TimeToLiveUtilityFn(hero)
				nTimeToLiveUtility = nTimeToLiveUtility * behaviorLib.nReplenishTimeToLiveUtilityMul
				nCurrentUtility = nManaUtility + nTimeToLiveUtility
				
				if nCurrentUtility > nHighestUtility then
					nHighestUtility = nCurrentUtility
					nTargetTimeToLive = nCurrentTimeToLive
					unitTarget = hero
					if bDebugEchos then BotEcho(format("%s Replenish util: %d  health: %d  ttl:%d", hero:GetTypeName(), nCurrentUtility, nReplenishUtility, nTimeToLiveUtility)) end
				end
			end
		end

		if unitTarget then
			nUtility = nHighestUtility				
			sAbilName = "Replenish"
		
			behaviorLib.unitReplenishTarget = unitTarget
			behaviorLib.nReplenishTimeToLive = nTargetTimeToLive
		end		
	end
	
	if bDebugEchos then BotEcho(format("    abil: %s util: %d", sAbilName, nUtility)) end
	
	nUtility = nUtility * behaviorLib.nReplenishUtilityMul
	
	if botBrain.bDebugUtility == true and nUtility ~= 0 then
		BotEcho(format("  HelpUtility: %g", nUtility))
	end
	
	return nUtility
end

-- Executing the behavior to use the Ring of Sorcery
function behaviorLib.ReplenishExecute(botBrain)
	core.FindItems()
	local itemRoS = core.itemRoS
	
	local unitReplenishTarget = behaviorLib.unitReplenishTarget
	local nReplenishTimeToLive = behaviorLib.nReplenishTimeToLive
	
	if unitReplenishTarget and itemRoS and itemRoS:CanActivate() then 
		local unitSelf = core.unitSelf													-- Get bot's position
		local vecTargetPosition = unitReplenishTarget:GetPosition()						-- Get target's position
		local nDistance = Vector3.Distance2D(unitSelf:GetPosition(), vecTargetPosition)	-- Get distance between bot and target
		if nDistance < itemRoS.nRadius then
			core.OrderItemClamp(botBrain, unitSelf, itemRoS) -- Use Ring of Sorcery, if in range
		else
			core.OrderMoveToUnitClamp(botBrain, unitSelf, unitReplenishTarget) -- Move closer to target
		end
	else
		return false
	end
	
	return true
end

behaviorLib.ReplenishBehavior = {}
behaviorLib.ReplenishBehavior["Utility"] = behaviorLib.ReplenishUtility
behaviorLib.ReplenishBehavior["Execute"] = behaviorLib.ReplenishExecute
behaviorLib.ReplenishBehavior["Name"] = "Replenish"
tinsert(behaviorLib.tBehaviors, behaviorLib.ReplenishBehavior)


----------------------------------
--  RetreatFromThreat Override
----------------------------------
-- TODO


----------------------------------
--	ProcessDeathChat Override
----------------------------------
-- TODO

----------------------------------
--	ProcessKillChat Override
----------------------------------
-- TODO

----------------------------------
--	ProcessRespawnChat Override
----------------------------------
-- TODO


----------------------------------
--	Behemoth items
----------------------------------
behaviorLib.StartingItems = {"Item_PretendersCrown", "Item_MarkOfTheNovice", "Item_RunesOfTheBlight", "2 Item_ManaPotion"}
behaviorLib.LaneItems = {"Item_Replenish", "Item_Marchers", "Item_Striders", "Item_MysticVestments"} -- Item_Replenish is Ring of Sorcer, Item_Strength5 is Fortified Bracelet
behaviorLib.MidItems = {"Item_PortalKey", "Item_SpellShards 3", "Item_FrostfieldPlate"} -- Immunity is Shrunken Head
behaviorLib.LateItems = {"Item_Immunity", "Item_SolsBulwark", "Item_DaemonicBreastplate", "Item_BehemothsHeart", "Item_Damage9"} -- Item_Damage9 is doombringer



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

BotEcho('finished loading Behemoth_main')

