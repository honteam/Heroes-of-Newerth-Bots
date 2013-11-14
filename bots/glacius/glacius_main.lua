--GlaciusBot v1.0


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

local sqrtTwo = math.sqrt(2)

BotEcho('loading glacius_main...')

--------------------------------
-- Lanes
--------------------------------
core.tLanePreferences = {Jungle = 0, Mid = 3, ShortSolo = 1, LongSolo = 1, ShortSupport = 5, LongSupport = 4, ShortCarry = 1, LongCarry = 1}

object.heroName = 'Hero_Frosty'

--------------------------------
-- Skills
--------------------------------
function object:SkillBuild()
local unitSelf = self.core.unitSelf

	if skills.abilTundraBlast == nil then
		skills.abilTundraBlast		= unitSelf:GetAbility(0)
		skills.abilIceImprisonment	= unitSelf:GetAbility(1)
		skills.abilChillingPresence	= unitSelf:GetAbility(2)
		skills.abilGlacialDownpour	= unitSelf:GetAbility(3)
		skills.abilAttributeBoost	= unitSelf:GetAbility(4)
	end

	if unitSelf:GetAbilityPointsAvailable() <= 0 then
		return
	end
	
	--speicific level 1 and two skills
	if skills.abilTundraBlast:GetLevel() < 1 then
		skills.abilTundraBlast:LevelUp()
	elseif skills.abilIceImprisonment:GetLevel() < 1 then
		skills.abilIceImprisonment:LevelUp()
	--max in this order {glacial downpour, chilling presence, ice imprisonment, tundra blast, stats}
	elseif skills.abilGlacialDownpour:CanLevelUp() then
		skills.abilGlacialDownpour:LevelUp()
	elseif skills.abilChillingPresence:CanLevelUp() then
		skills.abilChillingPresence:LevelUp()
	elseif skills.abilIceImprisonment:CanLevelUp() then
		skills.abilIceImprisonment:LevelUp()
	elseif skills.abilTundraBlast:CanLevelUp() then
		skills.abilTundraBlast:LevelUp()
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
	
	core.unitSelf:TeamShare()
	
	-- Insert code here
end
object.onthinkOld = object.onthink
object.onthink 	= object.onthinkOverride
--]]

----------------------------------
--	Glacius specific harass bonuses
--
--  Abilities off cd increase harass util
--  Ability use increases harass util for a time
----------------------------------

object.nTundraBlastUpBonus = 8
object.nIceImprisonmentUpBonus = 10
object.nGlacialDownpourUpBonus = 18
object.nSheepstickUp = 12

object.nTundraBlastUseBonus = 12
object.nIceImprisonmentUseBonus = 17.5
object.nGlacialDownpourUseBonus = 35
object.nSheepstickUse = 16

object.nTundraBlastThreshold = 30
object.nIceImprisonmentThreshold = 35
object.nGlacialDownpourThreshold = 40
object.nSheepstickThreshold = 30

local function AbilitiesUpUtilityFn()
	local nUtility = 0
	
	if skills.abilTundraBlast:CanActivate() then
		nUtility = nUtility + object.nTundraBlastUpBonus
	end
	
	if skills.abilIceImprisonment:CanActivate() then
		nUtility = nUtility + object.nIceImprisonmentUpBonus
	end
		
	if skills.abilGlacialDownpour:CanActivate() then
		nUtility = nUtility + object.nGlacialDownpourUpBonus
	end
	
	if object.itemSheepstick and object.itemSheepstick:CanActivate() then
		nUtility = nUtility + object.nSheepstickUp
	end
	
	return nUtility
end

--ability use gives bonus to harass util for a while
function object:oncombateventOverride(EventData)
	self:oncombateventOld(EventData)
	
	local nAddBonus = 0
	
	if EventData.Type == "Ability" then
		--BotEcho("ABILILTY EVENT!  InflictorName: "..EventData.InflictorName)		
		if EventData.InflictorName == "Ability_Frosty1" then
			nAddBonus = nAddBonus + object.nTundraBlastUseBonus
		elseif EventData.InflictorName == "Ability_Frosty2" then
			nAddBonus = nAddBonus + object.nIceImprisonmentUseBonus
		elseif EventData.InflictorName == "Ability_Frosty4" then
			nAddBonus = nAddBonus + object.nGlacialDownpourUseBonus
		end
	elseif EventData.Type == "Item" then
		if core.itemSheepstick ~= nil and EventData.SourceUnit == core.unitSelf:GetUniqueID() and EventData.InflictorName == core.itemSheepstick:GetName() then
			nAddBonus = nAddBonus + self.nSheepstickUse
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

--Utility calc override
local function CustomHarassUtilityOverride(hero)
	local nUtility = AbilitiesUpUtilityFn()
	
	return nUtility
end
behaviorLib.CustomHarassUtility = CustomHarassUtilityOverride  


----------------------------------
--	Glacius harass actions
----------------------------------
function object.GetTundraBlastRadius()
	return 400
end

function object.GetGlacialDownpourRadius()
	return 635
end

local function HarassHeroExecuteOverride(botBrain)
	local bDebugEchos = false
	
	local unitTarget = behaviorLib.heroTarget
	if unitTarget == nil then
		return false --can not execute, move on to the next behavior
	end
	
	local unitSelf = core.unitSelf
	local vecMyPosition = unitSelf:GetPosition()
	local nMyExtraRange = core.GetExtraRange(unitSelf)
	
	local vecTargetPosition = unitTarget:GetPosition()
	local nTargetExtraRange = core.GetExtraRange(unitTarget)
	local nTargetDistanceSq = Vector3.Distance2DSq(vecMyPosition, vecTargetPosition)
	local bTargetRooted = unitTarget:IsStunned() or unitTarget:IsImmobilized() or unitTarget:GetMoveSpeed() < 200
	
	local nLastHarassUtil = behaviorLib.lastHarassUtil
	local bCanSee = core.CanSeeUnit(botBrain, unitTarget)	
	
	if bDebugEchos then BotEcho("Glacius HarassHero at "..nLastHarassUtil) end
	local bActionTaken = false
	
	if unitSelf:IsChanneling() then
		--continue to do so
		--TODO: early break logic
		return
	end

	--since we are using an old pointer, ensure we can still see the target for entity targeting
	if core.CanSeeUnit(botBrain, unitTarget) then
		local bTargetVuln = unitTarget:IsStunned() or unitTarget:IsImmobilized()

		--Sheepstick
		if not bActionTaken and not bTargetVuln then
			local itemSheepstick = core.itemSheepstick
			if itemSheepstick then
				local nRange = itemSheepstick:GetRange()
				if itemSheepstick:CanActivate() and nLastHarassUtil > object.nSheepstickThreshold then
					if nTargetDistanceSq < (nRange * nRange) then
						bActionTaken = core.OrderItemEntityClamp(botBrain, unitSelf, itemSheepstick, unitTarget)
					end
				end
			end
		end

		
		--ice imprisonment
		if not bActionTaken and not bTargetRooted and nLastHarassUtil > botBrain.nIceImprisonmentThreshold and bCanSee then
			if bDebugEchos then BotEcho("  No action yet, checking ice imprisonment") end
			local abilIceImprisonment = skills.abilIceImprisonment
			if abilIceImprisonment:CanActivate() then
				local nRange = abilIceImprisonment:GetRange()
				if nTargetDistanceSq < (nRange * nRange) then
					bActionTaken = core.OrderAbilityEntity(botBrain, abilIceImprisonment, unitTarget)
				end
			end
		end
	end
	
	--tundra blast
	if not bActionTaken and nLastHarassUtil > botBrain.nTundraBlastThreshold then
		if bDebugEchos then BotEcho("  No action yet, checking tundra blast") end
		local abilTundraBlast = skills.abilTundraBlast
		if abilTundraBlast:CanActivate() then
			local abilTundraBlast = skills.abilTundraBlast
			local nRadius = botBrain.GetTundraBlastRadius()
			local nRange = (skills.abilTundraBlast ~= nil and skills.abilTundraBlast:GetRange()) or nil
			local vecTarget = core.AoETargeting(unitSelf, nRange, nRadius, true, unitTarget, core.enemyTeam, nil)
				
			if vecTarget then
				bActionTaken = core.OrderAbilityPosition(botBrain, abilTundraBlast, vecTarget)
			end
		end
	end
	
	--ult
	if not bActionTaken and nLastHarassUtil > botBrain.nGlacialDownpourThreshold then
		if bDebugEchos then BotEcho("  No action yet, checking glacial downpour.") end
		local abilGlacialDownpour = skills.abilGlacialDownpour
		if abilGlacialDownpour:CanActivate() then
			--get the target well within the radius for maximum effect
			local nRadius = botBrain.GetGlacialDownpourRadius()
			local nHalfRadiusSq = nRadius * nRadius * 0.25
			if nTargetDistanceSq <= nHalfRadiusSq then
				bActionTaken = core.OrderAbility(botBrain, abilGlacialDownpour)
			elseif not unitSelf:IsAttackReady() then
				--move in when we aren't attacking
				core.OrderMoveToUnit(botBrain, unitSelf, unitTarget)
				bActionTaken = true
			end
		end
	end
		
	if not bActionTaken then
		if bDebugEchos then BotEcho("  No action yet, proceeding with normal harass execute.") end
		return object.harassExecuteOld(botBrain)
	end
end
object.harassExecuteOld = behaviorLib.HarassHeroBehavior["Execute"]
behaviorLib.HarassHeroBehavior["Execute"] = HarassHeroExecuteOverride


----------------------------------
--  FindItems Override
----------------------------------
local function funcFindItemsOverride(botBrain)
	object.FindItemsOld(botBrain)

	core.ValidateItem(core.itemAstrolabe)
	core.ValidateItem(core.itemSheepstick)
	
	--only update if we need to
	if core.itemSheepstick and core.itemAstrolabe then
		return
	end

	local inventory = core.unitSelf:GetInventory(false)
	for slot = 1, 6, 1 do
		local curItem = inventory[slot]
		if curItem and not curItem:IsRecipe() then
			if core.itemAstrolabe == nil and curItem:GetName() == "Item_Astrolabe" then
				core.itemAstrolabe = core.WrapInTable(curItem)
				core.itemAstrolabe.nHealValue = 200
				core.itemAstrolabe.nRadius = 600
				--Echo("Saving astrolabe")
			elseif core.itemSheepstick == nil and curItem:GetName() == "Item_Morph" then
				core.itemSheepstick = core.WrapInTable(curItem)
			end
		end
	end
end
object.FindItemsOld = core.FindItems
core.FindItems = funcFindItemsOverride


--TODO: extract this out to behaviorLib
----------------------------------
--	Glacius's Help behavior
--	
--	Utility: 
--	Execute: Use Astrolabe
----------------------------------
behaviorLib.nHealUtilityMul = 0.8
behaviorLib.nHealHealthUtilityMul = 1.0
behaviorLib.nHealTimeToLiveUtilityMul = 0.5

function behaviorLib.HealHealthUtilityFn(unitHero)
	local nUtility = 0
	
	local nYIntercept = 100
	local nXIntercept = 100
	local nOrder = 2

	nUtility = core.ExpDecay(unitHero:GetHealthPercent() * 100, nYIntercept, nXIntercept, nOrder)
	
	return nUtility
end

function behaviorLib.TimeToLiveUtilityFn(unitHero)
	--Increases as your time to live based on your damage velocity decreases
	local nUtility = 0
	
	local nHealthVelocity = unitHero:GetHealthVelocity()
	local nHealth = unitHero:GetHealth()
	local nTimeToLive = 9999
	if nHealthVelocity < 0 then
		nTimeToLive = nHealth / (-1 * nHealthVelocity)
		
		local nYIntercept = 100
		local nXIntercept = 20
		local nOrder = 2
		nUtility = core.ExpDecay(nTimeToLive, nYIntercept, nXIntercept, nOrder)
	end
	
	nUtility = Clamp(nUtility, 0, 100)
	
	--BotEcho(format("%d timeToLive: %g  healthVelocity: %g", HoN.GetGameTime(), nTimeToLive, nHealthVelocity))
	
	return nUtility, nTimeToLive
end

behaviorLib.nHealCostBonus = 10
behaviorLib.nHealCostBonusCooldownThresholdMul = 4.0
function behaviorLib.AbilityCostBonusFn(unitSelf, ability)
	local bDebugEchos = false
	
	local nCost =		ability:GetManaCost()
	local nCooldownMS =	ability:GetCooldownTime()
	local nRegen =		unitSelf:GetManaRegen()
	
	local nTimeToRegenMS = nCost / nRegen * 1000
	
	if bDebugEchos then BotEcho(format("AbilityCostBonusFn - nCost: %d  nCooldown: %d  nRegen: %g  nTimeToRegen: %d", nCost, nCooldownMS, nRegen, nTimeToRegenMS)) end
	if nTimeToRegenMS < nCooldownMS * behaviorLib.nHealCostBonusCooldownThresholdMul then
		return behaviorLib.nHealCostBonus
	end
	
	return 0
end

behaviorLib.unitHealTarget = nil
behaviorLib.nHealTimeToLive = nil
function behaviorLib.HealUtility(botBrain)
	local bDebugEchos = false
	
	--[[
	if object.myName == "Bot1" then
		bDebugEchos = true
	end
	--]]
	if bDebugEchos then BotEcho("HealUtility") end
	
	local nUtility = 0

	local unitSelf = core.unitSelf
	behaviorLib.unitHealTarget = nil
	
	local itemAstrolabe = core.itemAstrolabe
	
	local nHighestUtility = 0
	local unitTarget = nil
	local nTargetTimeToLive = nil
	local sAbilName = ""
	if itemAstrolabe and itemAstrolabe:CanActivate() and itemAstrolabe:IsValid() then
		local tTargets = core.CopyTable(core.localUnits["AllyHeroes"])
		tTargets[unitSelf:GetUniqueID()] = unitSelf --I am also a target
		for key, hero in pairs(tTargets) do
			--Don't heal ourself if we are going to head back to the well anyway, 
			--	as it could cause us to retrace half a walkback
			if hero:GetUniqueID() ~= unitSelf:GetUniqueID() or core.GetCurrentBehaviorName(botBrain) ~= "HealAtWell" then
				local nCurrentUtility = 0
				
				local nHealthUtility = behaviorLib.HealHealthUtilityFn(hero) * behaviorLib.nHealHealthUtilityMul
				local nTimeToLiveUtility = nil
				local nCurrentTimeToLive = nil
				nTimeToLiveUtility, nCurrentTimeToLive = behaviorLib.TimeToLiveUtilityFn(hero)
				nTimeToLiveUtility = nTimeToLiveUtility * behaviorLib.nHealTimeToLiveUtilityMul
				nCurrentUtility = nHealthUtility + nTimeToLiveUtility
				
				if nCurrentUtility > nHighestUtility then
					nHighestUtility = nCurrentUtility
					nTargetTimeToLive = nCurrentTimeToLive
					unitTarget = hero
					if bDebugEchos then BotEcho(format("%s Heal util: %d  health: %d  ttl:%d", hero:GetTypeName(), nCurrentUtility, nHealthUtility, nTimeToLiveUtility)) end
				end
			end
		end

		if unitTarget then
			nUtility = nHighestUtility				
			sAbilName = "Astrolabe"
		
			behaviorLib.unitHealTarget = unitTarget
			behaviorLib.nHealTimeToLive = nTargetTimeToLive
		end		
	end
	
	if bDebugEchos then BotEcho(format("    abil: %s util: %d", sAbilName, nUtility)) end
	
	nUtility = nUtility * behaviorLib.nHealUtilityMul
	
	if botBrain.bDebugUtility == true and nUtility ~= 0 then
		BotEcho(format("  HelpUtility: %g", nUtility))
	end
	
	return nUtility
end

function behaviorLib.HealExecute(botBrain)
	local itemAstrolabe = core.itemAstrolabe
	
	local unitHealTarget = behaviorLib.unitHealTarget
	local nHealTimeToLive = behaviorLib.nHealTimeToLive
	
	if unitHealTarget and itemAstrolabe and itemAstrolabe:CanActivate() and itemAstrolabe:IsValid() then 
		local unitSelf = core.unitSelf
		local vecTargetPosition = unitHealTarget:GetPosition()
		local nDistance = Vector3.Distance2D(unitSelf:GetPosition(), vecTargetPosition)
		if nDistance < itemAstrolabe.nRadius then
			core.OrderItemClamp(botBrain, unitSelf, itemAstrolabe)
		else
			core.OrderMoveToUnitClamp(botBrain, unitSelf, unitHealTarget)
		end
	else
		return false
	end
	
	return true
end

behaviorLib.HealBehavior = {}
behaviorLib.HealBehavior["Utility"] = behaviorLib.HealUtility
behaviorLib.HealBehavior["Execute"] = behaviorLib.HealExecute
behaviorLib.HealBehavior["Name"] = "Heal"
tinsert(behaviorLib.tBehaviors, behaviorLib.HealBehavior)


----------------------------------
--	Glacius items
----------------------------------
--[[ list code:
	"# Item" is "get # of these"
	"Item #" is "get this level of the item" --]]
behaviorLib.StartingItems = 
	{"Item_GuardianRing", "Item_PretendersCrown", "Item_MinorTotem", "Item_HealthPotion", "Item_RunesOfTheBlight"}
behaviorLib.LaneItems = 
	{"Item_ManaRegen3", "Item_Marchers", "Item_Striders", "Item_Strength5"} --ManaRegen3 is Ring of the Teacher, Item_Strength5 is Fortified Bracer
behaviorLib.MidItems = 
	{"Item_Astrolabe", "Item_GraveLocket", "Item_SacrificialStone", "Item_Intelligence7"} --Intelligence7 is Staff of the Master
behaviorLib.LateItems = 
	{"Item_Morph", "Item_BehemothsHeart", 'Item_Damage9'} --Morph is Sheepstick. Item_Damage9 is Doombringer



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

BotEcho('finished loading glacius_main')
