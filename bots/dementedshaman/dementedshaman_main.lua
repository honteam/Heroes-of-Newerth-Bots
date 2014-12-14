--DSBot v1.0


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

--[[
if object.myName == "Bot6" then
	object.bDebugUtility = true
end
--]]


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

BotEcho('loading demetnedshaman_main...')

--------------------------------
-- Lanes
--------------------------------
core.tLanePreferences = {Jungle = 0, Mid = 1, ShortSolo = 1, LongSolo = 1, ShortSupport = 5, LongSupport = 5, ShortCarry = 1, LongCarry = 1}

object.heroName = 'Hero_Shaman'

--------------------------------
-- Skills
--------------------------------
local bSkillsValid = false
function object:SkillBuild()
	local unitSelf = self.core.unitSelf

	if not bSkillsValid then
		skills.abilEntangle			= unitSelf:GetAbility(0)
		skills.abilUnbreakable		= unitSelf:GetAbility(1)
		skills.abilHealingWave		= unitSelf:GetAbility(2)
		skills.abilStormCloud		= unitSelf:GetAbility(3)
		skills.abilAttributeBoost	= unitSelf:GetAbility(4)
		
		if skills.abilEntangle and skills.abilUnbreakable and skills.abilHealingWave and skills.abilStormCloud and skills.abilAttributeBoost then
			bSkillsValid = true
		else
			return
		end
	end

	if unitSelf:GetAbilityPointsAvailable() <= 0 then
		return
	end

	--speicific level 1 skill
	if skills.abilEntangle:GetLevel() < 1 then
		skills.abilEntangle:LevelUp()
	--max in this order {healing wave, entangle, storm cloud, unbreakable, stats}
	elseif skills.abilHealingWave:CanLevelUp() then
		skills.abilHealingWave:LevelUp()
	elseif skills.abilEntangle:CanLevelUp() then
		skills.abilEntangle:LevelUp()
	elseif skills.abilStormCloud:CanLevelUp() then
		skills.abilStormCloud:LevelUp()
	elseif skills.abilUnbreakable:CanLevelUp() then
		skills.abilUnbreakable:LevelUp()
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
--	DS tutorial PositionSelfLogic
----------------------------------
object.nTraverseCloseEnoughSq = 450*450
local function funcTraverseToHuman(botBrain)
	local bDebugEchos = false
	
	local vecReturn = nil
	if core.bIsTutorial then
		--[Tutorial] DS sticks with the player
		local teamBotBrain = core.teamBotBrain
		local unitSelf = core.unitSelf
		local vecMyPos = unitSelf:GetPosition()
		local unitHuman = nil
		for _, unit in pairs(core.teamBotBrain.tAllyHumanHeroes) do
			unitHuman = unit
			break
		end
				
		if unitHuman and unitHuman:IsAlive() then
			local vecHumanPosition = unitHuman:GetPosition()
			local nDistanceSq = Vector3.Distance2DSq(vecHumanPosition, vecMyPos)
			if nDistanceSq < object.nTraverseCloseEnoughSq then
				if bDebugEchos then BotEcho("Traverse new, holding") end
				vecReturn = vecMyPos
			else
				if bDebugEchos then BotEcho("Traverse new, moving to meatbag") end
				vecReturn = vecHumanPosition
			end
		end
	end
	
	if vecReturn == nil then
		if bDebugEchos then BotEcho("Traverse new, using old") end
		vecReturn = object.funcPositionSelfTraverseLaneOld(botBrain)
	end
	return vecReturn
end
object.funcPositionSelfTraverseLaneOld = behaviorLib.PositionSelfTraverseLane
behaviorLib.PositionSelfTraverseLane = funcTraverseToHuman

object.nDSLeashRange = 1100
object.nDSLeashRangeSq = object.nDSLeashRange * object.nDSLeashRange
local function PositionSelfLogicOverride(botBrain)
	if core.bIsTutorial then
		--[Tutorial] DS sticks with the player
		core.nOutOfPositionRangeSq = object.nDSLeashRangeSq
	end

	return object.funcPositionSelfLogicOld(botBrain)
end
object.funcPositionSelfLogicOld = behaviorLib.PositionSelfLogic
behaviorLib.PositionSelfLogic = PositionSelfLogicOverride


----------------------------------
--	DS tutorial TeamGroupUtility
----------------------------------
local function TeamGroupUtilityOverride(botBrain)
	if core.bIsTutorial then
		--[Tutorial] DS sticks with the player
		return 0
	end
	
	return object.TeamGroupUtilityOld(botBrain)
end
object.TeamGroupUtilityOld = behaviorLib.TeamGroupUtility
behaviorLib.TeamGroupBehavior["Utility"] = TeamGroupUtilityOverride


----------------------------------
--	DS specific harass bonuses
--
--  Abilities off cd increase harass util
--  Ability use increases harass util for a time
----------------------------------
object.nEntangleUpBonus = 5  --change to 10 at level 3 entangle?
object.nUltUpBonus = 10
object.nSheepstickUp = 12

object.nEntangleUseBonus = 10
object.nUltUseBonus = 10
object.nSheepstickUse = 16

object.nEntangleThreshold = 35
object.nStormCloudThreshold = 45
object.nSheepstickThreshold = 30

local function AbilitiesUpUtilityFn()
	local nUtility = 0

	if skills.abilEntangle:CanActivate() then
		nUtility = nUtility + object.nEntangleUpBonus
	end

	if skills.abilStormCloud:CanActivate() then
		nUtility = nUtility + object.nUltUpBonus
	end

	if object.itemSheepstick and object.itemSheepstick:CanActivate() then
		nUtility = nUtility + object.nSheepstickUp
	end

	return nUtility
end

--DS ability use gives bonus to harass util for a while
function object:oncombateventOverride(EventData)
	self:oncombateventOld(EventData)

	local nAddBonus = 0

	if EventData.Type == "Ability" then
		--BotEcho("ABILILTY EVENT!  InflictorName: "..EventData.InflictorName)
		if EventData.InflictorName == "Ability_Shaman1" then
			nAddBonus = nAddBonus + object.nEntangleUseBonus
		elseif EventData.InflictorName == "Ability_Shaman4" then
			nAddBonus = nAddBonus + object.nUltUseBonus
		end
	elseif EventData.Type == "Item" then
		if core.itemSheepstick ~= nil and EventData.SourceUnit == core.unitSelf:GetUniqueID() and  EventData.InflictorName == core.itemSheepstick:GetName() then
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

--CustomHarassUtility calc override
local function CustomHarassUtilityOverride(hero)
	local nUtility = AbilitiesUpUtilityFn()

	return nUtility
end
behaviorLib.CustomHarassUtility = CustomHarassUtilityOverride

--Utility calc override
local function HarassHeroUtilityOverride(botBrain)
	--[Tutorial] DS doesn't get random aggro pre 9 min
	if core.bTutorial and core.bTutorialBehaviorReset == false then
		core.bEasyRandomAggression = false
	end

	return object.harassUtilityOld(botBrain)
end
object.harassUtilityOld = behaviorLib.HarassHeroBehavior["Utility"]
behaviorLib.HarassHeroBehavior["Utility"] = HarassHeroUtilityOverride

----------------------------------
--	DS harass actions
----------------------------------
function object:funcStormCloudTargetWeighting(unit)
	if unit and unit:GetTeam() ~= core.myTeam then
		return 1.5
	end
	return 1.0
end

function object:GetStormCloudRadius()
	--TODO: Staff of the Master detection
	return 600
end

function object:StormCloudLogic()
	local vecTarget = nil
	--TODO: factor in mana true cost
	local bShouldUse = false

	if behaviorLib.lastHarassUtil > object.nStormCloudThreshold then
		bShouldUse = true
	end

	if bShouldUse then
		local nRange = skills.abilStormCloud and skills.abilStormCloud:GetRange()
		vecTarget = core.AoETargeting(core.unitSelf, nRange, object.GetStormCloudRadius(), true, nil, nil, object.funcStormCloudTargetWeighting)
	end

	return bShouldUse, vecTarget
end

local function HarassHeroExecuteOverride(botBrain)
	local bDebugEchos = false

	local unitTarget = behaviorLib.heroTarget
	if unitTarget == nil or not unitTarget:IsValid() then
		return false --can not execute, move on to the next behavior
	end
	
	local unitSelf = core.unitSelf
	local nMyExtraRange = core.GetExtraRange(unitSelf)
	local nTargetExtraRange = core.GetExtraRange(unitTarget)
	
	local vecTargetPosition = unitTarget:GetPosition()
	local nTargetDistanceSq = Vector3.Distance2DSq(unitSelf:GetPosition(), vecTargetPosition)

	if bDebugEchos then BotEcho("DS HarassHero") end
	local bActionTaken = false
	
	--since we are using an old pointer, ensure we can still see the target for entity targeting
	if core.CanSeeUnit(botBrain, unitTarget) then
		if bDebugEchos then BotEcho("  Can see target!") end
		--ult
		if not bActionTaken then
			if bDebugEchos then BotEcho("  No action yet, checking storm cloud.") end
			local abilStormCloud = skills.abilStormCloud
			local nUltRange = (abilStormCloud and (abilStormCloud:GetRange() + nMyExtraRange)) or 0
			if abilStormCloud:CanActivate() then
				local bShouldUlt, vecTarget = botBrain.StormCloudLogic()

				if bShouldUlt and vecTarget then
					local nDistanceSq = Vector3.Distance2DSq(unitSelf:GetPosition(), vecTarget)
					local bInRange = nDistanceSq < nUltRange * nUltRange

					if bInRange then
						if bDebugEchos then BotEcho("  Casting storm cloud!") end
						bActionTaken = core.OrderAbilityPosition(botBrain, abilStormCloud, vecTarget)
					else
						if bDebugEchos then BotEcho("  Moving to cast storm cloud!") end
						core.OrderMoveToPosClamp(botBrain, unitSelf, vecTarget, false)
						bActionTaken = true
					end
				end
			end
		end

		local bTargetVuln = unitTarget:IsStunned() or unitTarget:IsImmobilized()

		--Sheepstick
		if not bActionTaken and not bTargetVuln then
			local itemSheepstick = core.itemSheepstick
			if itemSheepstick then
				local nRange = itemSheepstick:GetRange()
				if itemSheepstick:CanActivate() and behaviorLib.lastHarassUtil > object.nSheepstickThreshold then
					if nTargetDistanceSq < (nRange * nRange) then
						bActionTaken = core.OrderItemEntityClamp(botBrain, unitSelf, itemSheepstick, unitTarget)
					end
				end
			end
		end

		--entangle
		if not bActionTaken then
			if bDebugEchos then BotEcho("  No action yet, checking entangle.") end
			local bShouldEntangle = behaviorLib.lastHarassUtil > botBrain.nEntangleThreshold
			if bShouldEntangle then
				local abilEntangle = skills.abilEntangle
				--local nEntangleRange = abilEntangle:GetRange() + nMyExtraRange + nTargetExtraRange
				--local nEntangeCost = abilEntangle:GetManaCost()
				--local nEntangleLevel = abilEntangle:GetLevel()

				--local nTargetDistance = Vector3.Distance2D(unitSelf:GetPosition(), unitTarget:GetPosition())
				local bEntangleUsable = abilEntangle:CanActivate()

				if bEntangleUsable then
					if bDebugEchos then BotEcho(format("  Casting entangle on %s!", unitTarget:GetTypeName())) end
					bActionTaken = core.OrderAbilityEntity(botBrain, abilEntangle, unitTarget)
				end
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

	core.ValidateItem(core.itemSheepstick)

	--only update if we need to
	if core.itemSheepstick then
		return
	end

	local inventory = core.unitSelf:GetInventory(false)
	for slot = 1, 6, 1 do
		local curItem = inventory[slot]
		if curItem and not curItem:IsRecipe() then
			if core.itemSheepstick == nil and curItem:GetName() == "Item_Morph" then
				core.itemSheepstick = core.WrapInTable(curItem)
			end
		end
	end
end
object.FindItemsOld = core.FindItems
core.FindItems = funcFindItemsOverride


--TODO: extract this out to behaviorLib
----------------------------------
--	DS's Help behavior
--
--	Utility:
--	Execute: Use HealingWave/Cape
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
	local nTimeToLive = 9999

	if unitHero.bIsMemoryUnit then
		local nHealthVelocity = unitHero:GetHealthVelocity()
		local nHealth = unitHero:GetHealth()
		if nHealthVelocity < 0 then
			nTimeToLive = nHealth / (-1 * nHealthVelocity)

			local nYIntercept = 100
			local nXIntercept = 20
			local nOrder = 2
			nUtility = core.ExpDecay(nTimeToLive, nYIntercept, nXIntercept, nOrder)
		end
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
--behaviorLib.unitUnbreakableUtilityThreshold = 60
behaviorLib.nUnbreakableTimeToLiveThreshold = 6
function behaviorLib.HealUtility(botBrain)
	local bDebugEchos = false

	--[[
	if object.myName == "Bot1" then
		bDebugEchos = true
	end
	--]]
	if bDebugEchos then BotEcho("HealUtility") end

	local nUtility = 0

	local abilUnbreakable = skills.abilUnbreakable
	local abilHealingWave = skills.abilHealingWave
	local unitSelf = core.unitSelf

	behaviorLib.unitHealTarget = nil

	local nHighestUtility = 0
	local unitTarget = nil
	local nTargetTimeToLive = nil
	local sAbilName = ""
	if abilUnbreakable:CanActivate() or abilHealingWave:CanActivate() then
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
			if abilUnbreakable:CanActivate() and nTargetTimeToLive <= behaviorLib.nUnbreakableTimeToLiveThreshold then
				local nCostBonus = behaviorLib.AbilityCostBonusFn(core.unitSelf, abilUnbreakable)

				nUtility = nHighestUtility + nCostBonus
				if bDebugEchos then BotEcho("  Unbreakable bonus util - cost: "..nCostBonus) end

				--if nUtility > behaviorLib.unitUnbreakableUtilityThreshold then
					sAbilName = "Unbreakable"
				--else
				--	nUtility = 0
				--end
			end

			if nUtility == 0 and abilHealingWave:CanActivate() then
				local nCostBonus = behaviorLib.AbilityCostBonusFn(core.unitSelf, abilHealingWave)

				nUtility = nHighestUtility + nCostBonus
				if bDebugEchos then BotEcho("  HealingWave bonus util - cost: "..nCostBonus) end

				sAbilName = "HealingWave"
			end

			if nUtility ~= 0 then
				behaviorLib.unitHealTarget = unitTarget
				behaviorLib.nHealTimeToLive = nTargetTimeToLive
			end
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
	local abilUnbreakable = skills.abilUnbreakable
	local abilHealingWave = skills.abilHealingWave

	local unitHealTarget = behaviorLib.unitHealTarget
	local nHealTimeToLive = behaviorLib.nHealTimeToLive

	if unitHealTarget then
		if nHealTimeToLive <= behaviorLib.nUnbreakableTimeToLiveThreshold and abilUnbreakable:CanActivate() then
			core.OrderAbilityEntity(botBrain, abilUnbreakable, unitHealTarget)
		elseif abilHealingWave:CanActivate() then
			core.OrderAbilityEntity(botBrain, abilHealingWave, unitHealTarget)
		else
			return false
		end
	else
		return false
	end

	return
end

behaviorLib.HealBehavior = {}
behaviorLib.HealBehavior["Utility"] = behaviorLib.HealUtility
behaviorLib.HealBehavior["Execute"] = behaviorLib.HealExecute
behaviorLib.HealBehavior["Name"] = "Heal"
tinsert(behaviorLib.tBehaviors, behaviorLib.HealBehavior)
----------------------------------
--	DS items
----------------------------------
--[[ list code:
	"# Item" is "get # of these"
	"Item #" is "get this level of the item" --]]
behaviorLib.StartingItems =
	{"Item_GuardianRing", "Item_PretendersCrown", "Item_MinorTotem", "Item_HealthPotion", "Item_RunesOfTheBlight"}
behaviorLib.LaneItems =
	{"Item_ManaRegen3", "Item_Marchers", "Item_Striders", "Item_NomesWisdom"} --ManaRegen3 is Ring of the Teacher
behaviorLib.MidItems =
	{"Item_GraveLocket", "Item_SacrificialStone", "Item_Astrolabe", "Item_Intelligence7"} --Intelligence7 is Staff of the Master
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

BotEcho('finished loading demetnedshaman_main')
