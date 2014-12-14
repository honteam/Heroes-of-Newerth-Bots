--DefilerBot v1.0


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

BotEcho('loading defiler_main...')

--------------------------------
-- Lanes
--------------------------------
core.tLanePreferences = {Jungle = 0, Mid = 5, ShortSolo = 5, LongSolo = 4, ShortSupport = 2, LongSupport = 2, ShortCarry = 3, LongCarry = 2}

object.heroName = 'Hero_Defiler'

--------------------------------
-- Skills
--------------------------------
local bSkillsValid = false
function object:SkillBuild()
	local unitSelf = self.core.unitSelf	
	
	if not bSkillsValid then
		skills.abilWaveOfDeath		= unitSelf:GetAbility(0)
		skills.abilGraveSilence		= unitSelf:GetAbility(1)
		skills.abilPowerInDeath		= unitSelf:GetAbility(2)
		skills.abilUnholyExpulsion	= unitSelf:GetAbility(3)
		skills.abilAttributeBoost	= unitSelf:GetAbility(4)
		
		if skills.abilWaveOfDeath and skills.abilGraveSilence and skills.abilPowerInDeath and skills.abilUnholyExpulsion and skills.abilAttributeBoost then
			bSkillsValid = true
		else
			return
		end
	end
	
	if unitSelf:GetAbilityPointsAvailable() <= 0 then
		return
	end
	
	if skills.abilUnholyExpulsion:CanLevelUp() then
		skills.abilUnholyExpulsion:LevelUp()
	elseif skills.abilWaveOfDeath:CanLevelUp() then
		skills.abilWaveOfDeath:LevelUp()
	elseif skills.abilPowerInDeath:GetLevel() < 1 then
		skills.abilPowerInDeath:LevelUp()
	elseif skills.abilGraveSilence:GetLevel() < 1 then
		skills.abilGraveSilence:LevelUp()
	elseif skills.abilPowerInDeath:CanLevelUp() then
		skills.abilPowerInDeath:LevelUp()
	elseif skills.abilGraveSilence:CanLevelUp() then
		skills.abilGraveSilence:LevelUp()
	else
		skills.abilAttributeBoost:LevelUp()
	end
end

local function GetUnholyExpulsionDuration()
	return 30000
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
--	Defiler's specific harass bonuses
--
--  Abilities off cd increase harass util
--  Ability use increases harass util for a time
----------------------------------

object.nWaveOfDeathUp = 8
object.nGraveSilenceUp = 4
object.nUnholyExpulsionUp = 40
object.nSheepstickUp = 12
object.nFrostfieldUp = 12

object.nWaveOfDeathUse = 15
object.nGraveSilenceUse = 7
object.nSheepstickUse = 16
object.nFrostfieldUse = 10

object.nUnholyExpulsionActive = 70

object.nWaveOfDeathThreshold = 30
object.nGraveSilenceThreshold = 40
object.nUnholyExpulsionThreshold = 65
object.nSheepstickThreshold = 30
object.nFrostfieldThreshold = 12

local function AbilitiesUpUtility(hero)
	local bDebugLines = false
	local bDebugEchos = false
	
	local nUtility = 0
	
	if skills.abilWaveOfDeath:CanActivate() then
		nUtility = nUtility + object.nWaveOfDeathUp
	end
	
	if skills.abilGraveSilence:CanActivate() then
		nUtility = nUtility + object.nGraveSilenceUp
	end
	
	if skills.abilUnholyExpulsion:CanActivate() then
		nUtility = nUtility + object.nUnholyExpulsionUp
	end
	
	if object.itemSheepstick and object.itemSheepstick:CanActivate() then
		nUtility = nUtility + object.nSheepstickUp
	end
	
	if object.itemFrostfieldPlate and object.itemFrostfieldPlate:CanActivate() then
		nUtility = nUtility + object.nFrostfieldUp
	end
	
	if bDebugEchos then BotEcho(" HARASS - abilitiesUp: "..nUtility) end
	if bDebugLines then
		local lineLen = 150
		local myPos = core.unitSelf:GetPosition()
		local vTowards = Vector3.Normalize(hero:GetPosition() - myPos)
		local vOrtho = Vector3.Create(-vTowards.y, vTowards.x) --quick 90 rotate z
		core.DrawDebugArrow(myPos - vOrtho * lineLen * 1.4, (myPos - vOrtho * lineLen * 1.4 ) + vTowards * nUtility * (lineLen/100), 'cyan')
	end
	
	return nUtility
end

local function IsUnholyExpulsionActive()
	return object.nUnholyExpulsionExpireTime > HoN.GetGameTime()
end

local function UnholyExpulsionActiveUtility()
	local nUtility = 0
	if IsUnholyExpulsionActive() then
		nUtility = object.nUnholyExpulsionActive
	end
		
	return nUtility
end

--Defiler ability use gives bonus to harass util for a while
object.nUnholyExpulsionExpireTime = 0
function object:oncombateventOverride(EventData)
	self:oncombateventOld(EventData)
	
	local nAddBonus = 0
	
	if EventData.Type == "Ability" then
		if EventData.InflictorName == "Ability_Defiler1" then
			nAddBonus = nAddBonus + self.nWaveOfDeathUse
		elseif EventData.InflictorName == "Ability_Defiler2" then
			nAddBonus = nAddBonus + self.nGraveSilenceUse
		elseif EventData.InflictorName == "Ability_Defiler4" then
			self.nUnholyExpulsionExpireTime = EventData.TimeStamp + GetUnholyExpulsionDuration()
		end
	elseif EventData.Type == "Item" then
		if core.itemSheepstick ~= nil and EventData.SourceUnit == core.unitSelf:GetUniqueID() and EventData.InflictorName == core.itemSheepstick:GetName() then
			nAddBonus = nAddBonus + self.nSheepstickUse
		end
		if core.itemFrostfieldPlate ~= nil and EventData.SourceUnit == nSelfUniqueId and EventData.InflictorName == core.itemFrostfieldPlate:GetName() then
			nAddBonus = nAddBonus + self.nFrostfieldUse
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
local function CustomHarassUtilityFnOverride(hero)
	local nUtility = AbilitiesUpUtility(hero) + UnholyExpulsionActiveUtility()
	
	return nUtility
end
behaviorLib.CustomHarassUtility = CustomHarassUtilityFnOverride   


----------------------------------
--	Defiler harass actions
----------------------------------
local function HarassHeroExecuteOverride(botBrain)
	local bDebugEchos = false
	
	local unitTarget = behaviorLib.heroTarget
	if unitTarget == nil or not unitTarget:IsValid() then
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
	--local bTargetRooted = unitTarget:IsStunned() or unitTarget:IsImmobilized() or unitTarget:GetMoveSpeed() < 200
	
	local nLastHarassUtility = behaviorLib.lastHarassUtil
	--local bCanSee = core.CanSeeUnit(botBrain, unitTarget)	
	
	if bDebugEchos then BotEcho("Defiler HarassHero at "..nLastHarassUtility) end
	local bActionTaken = false

	--since we are using an old pointer, ensure we can still see the target for entity targeting
	if core.CanSeeUnit(botBrain, unitTarget) then
		local bTargetVuln = unitTarget:IsStunned() or unitTarget:IsImmobilized()
	
		--Sheepstick
		if not bActionTaken and not bTargetVuln then
			local itemSheepstick = core.itemSheepstick
			if itemSheepstick then
				local nRange = itemSheepstick:GetRange()
				if itemSheepstick:CanActivate() and nLastHarassUtility > botBrain.nSheepstickThreshold then
					if nTargetDistanceSq < (nRange * nRange) then
						bActionTaken = core.OrderItemEntityClamp(botBrain, unitSelf, itemSheepstick, unitTarget)
					end
				end
			end
		end
	end
	
	--Frostfield
	if not bActionTaken and not bTargetVuln then 
		local itemFrostfieldPlate = core.itemFrostfieldPlate
		if itemFrostfieldPlate then
			if itemFrostfieldPlate:CanActivate() and nLastHarassUtility > botBrain.nFrostfieldThreshold then
				local nRange = itemFrostfieldPlate:GetTargetRadius()
				if nTargetDistanceSq < (nRange * nRange) * 0.9 then
					if bDebugEchos then BotEcho("Using frostfield") end
					bActionTaken = core.OrderItemClamp(botBrain, unitSelf, itemFrostfieldPlate, false)
				end
			end
		end
	end
	
	--Unholy Expulsion
	if not bActionTaken and nLastHarassUtility > botBrain.nUnholyExpulsionThreshold then
		if bDebugEchos then BotEcho("  No action yet, checking silver bullet") end
		local abilUnholyExpulsion = skills.abilUnholyExpulsion
		if abilUnholyExpulsion:CanActivate() then
			bActionTaken = core.OrderAbility(botBrain, abilUnholyExpulsion)
		end
	end
	
	--Wave of Death
	if not bActionTaken and not bTargetRooted and nLastHarassUtility > botBrain.nWaveOfDeathThreshold then
		if bDebugEchos then BotEcho("  No action yet, checking wave of death") end
		local abilWaveOfDeath = skills.abilWaveOfDeath
		if abilWaveOfDeath:CanActivate() then
			local nRange = abilWaveOfDeath:GetRange()
			if nTargetDistanceSq < (nRange * nRange) then
				bActionTaken = core.OrderAbilityPosition(botBrain, abilWaveOfDeath, vecTargetPosition)
			end
		end
	end
	
	--Grave Silence
	if not bActionTaken and nLastHarassUtility > botBrain.nGraveSilenceThreshold then
		if bDebugEchos then BotEcho("  No action yet, checking grave silence") end
		local abilGraveSilence = skills.abilGraveSilence
		if abilGraveSilence:CanActivate() then
			local nRange = abilGraveSilence:GetRange()
			if nTargetDistanceSq < (nRange * nRange) then
				bActionTaken = core.OrderAbilityPosition(botBrain, abilGraveSilence, vecTargetPosition)
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
	core.ValidateItem(core.itemFrostfieldPlate)
	
	--only update if we need to
	if core.itemSheepstick and core.itemFrostfieldPlate then
		return
	end
	
	local inventory = core.unitSelf:GetInventory(false)
	for slot = 1, 6, 1 do
		local curItem = inventory[slot]
		if curItem and not curItem:IsRecipe() then
			if core.itemSheepstick == nil and curItem:GetName() == "Item_Morph" then
				core.itemSheepstick = core.WrapInTable(curItem)
			elseif core.itemFrostfieldPlate == nil and curItem:GetName() == "Item_FrostfieldPlate" then
				core.itemFrostfieldPlate = core.WrapInTable(curItem)
			end
		end
	end
end
object.FindItemsOld = core.FindItems
core.FindItems = funcFindItemsOverride


----------------------------------
--	Defiler specific push
----------------------------------

object.nUnholyExpulsionPushWeight = 1.0

--Ghosts out, towers goin down
local function UnholyExpulsionPushUtility()
	return (IsUnholyExpulsionActive() and 100) or 0
end

local function PushingStrengthUtilityOverride(myHero)
	local nUtility = object.funcPushStrengthUtilityOld(myHero)
	
	local nUnholyExpulsionUtility = UnholyExpulsionPushUtility() * object.nUnholyExpulsionPushWeight
	
	nUtility = nUtility + nUnholyExpulsionUtility
	nUtility = Clamp(nUtility, 0, 100)

	return nUtility
end
object.funcPushStrengthUtilityOld = behaviorLib.PushingStrengthUtility
behaviorLib.PushingStrengthUtility = PushingStrengthUtilityOverride


local function HitBuildingExecuteOverride(botBrain)
	local bActionTaken = false
	local abilUnholyExpulsion = skills.abilUnholyExpulsion
	if abilUnholyExpulsion:CanActivate() and core.GetLastBehaviorName(botBrain) == "Push" then
		bActionTaken = core.OrderAbility(botBrain, abilUnholyExpulsion)
	end
	
	if not bActionTaken then
		botBrain.funcHitBuildingExecuteOld(botBrain)
	end
end
object.funcHitBuildingExecuteOld = behaviorLib.HitBuildingBehavior["Execute"]
behaviorLib.HitBuildingBehavior["Execute"] = HitBuildingExecuteOverride


----------------------------------
--	Defiler items
----------------------------------
--[[ list code:
	"# Item" is "get # of these"
	"Item #" is "get this level of the item" --]]
	
behaviorLib.StartingItems = 
	{"Item_GuardianRing", "Item_RunesOfTheBlight", "Item_HealthPotion", "2 Item_ManaPotion", "2 Item_MinorTotem", }
behaviorLib.LaneItems = 
	{"Item_ManaRegen3", "Item_Marchers", "Item_Shield2", "Item_PlatedGreaves"} --ManaRegen3 is Ring of the Teacher, Shield2 is Helm of the Black Legion
behaviorLib.MidItems = 
	{"Item_MysticVestments", "Item_Lightbrand", "Item_MagicArmor2", "Item_GrimoireOfPower"} --MagicArmor2 is Shaman's
behaviorLib.LateItems = 
	{"Item_FrostfieldPlate", "Item_Morph", "Item_BehemothsHeart", 'Item_Damage9'} --Morph is Sheepstick. Item_Damage9 is Doombringer



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

BotEcho('finished loading defiler_main')
