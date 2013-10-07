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

object.heroName = 'Hero_Shaman'

--------------------------------
-- Skills
--------------------------------
function object:SkillBuild()
	local unitSelf = self.core.unitSelf

	if skills.abilEntangle == nil then
		skills.abilEntangle			= unitSelf:GetAbility(0)
		skills.abilUnbreakable		= unitSelf:GetAbility(1)
		skills.abilHealingWave		= unitSelf:GetAbility(2)
		skills.abilStormCloud		= unitSelf:GetAbility(3)
		skills.abilAttributeBoost	= unitSelf:GetAbility(4)
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

	local unitSelf = core.unitSelf
	local unitTarget = behaviorLib.heroTarget
	local nMyExtraRange = core.GetExtraRange(unitSelf)
	local nTargetExtraRange = core.GetExtraRange(unitTarget)
	
	local vecTargetPosition = unitTarget:GetPosition()
	local nTargetDistanceSq = Vector3.Distance2DSq(unitSelf:GetPosition(), vecTargetPosition)

	if bDebugEchos then BotEcho("DS HarassHero") end
	local bActionTaken = false
	
	--since we are using an old pointer, ensure we can still see the target for entity targeting
	if unitTarget ~= nil and core.CanSeeUnit(botBrain, unitTarget) then
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
		if curItem then
			if core.itemSheepstick == nil and curItem:GetName() == "Item_Morph" then
				core.itemSheepstick = core.WrapInTable(curItem)
			end
		end
	end
end
object.FindItemsOld = core.FindItems
core.FindItems = funcFindItemsOverride

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
