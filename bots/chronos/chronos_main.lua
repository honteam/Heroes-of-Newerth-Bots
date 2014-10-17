--ChronosBot v1.0


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

BotEcho('loading chronos_main...')

--------------------------------
-- Lanes
--------------------------------
core.tLanePreferences = {Jungle = 0, Mid = 1, ShortSolo = 5, LongSolo = 5, ShortSupport = 1, LongSupport = 1, ShortCarry = 5, LongCarry = 5}

object.heroName = 'Hero_Chronos'

--------------------------------
-- Skills
--------------------------------
local bSkillsValid = false
function object:SkillBuild()
	local unitSelf = self.core.unitSelf	
	
	if not bSkillsValid then
		skills.abilTimeLeap			= unitSelf:GetAbility(0)
		skills.abilRewind			= unitSelf:GetAbility(1)
		skills.abilCurseOfAges		= unitSelf:GetAbility(2)
		skills.abilChronosphere		= unitSelf:GetAbility(3)
		skills.abilAttributeBoost	= unitSelf:GetAbility(4)
		
		if skills.abilTimeLeap and skills.abilRewind and skills.abilCurseOfAges and skills.abilChronosphere and skills.abilAttributeBoost then
			bSkillsValid = true
		else
			return
		end
	end
	
	if unitSelf:GetAbilityPointsAvailable() <= 0 then
		return
	end
	
	if skills.abilChronosphere:CanLevelUp() then
		skills.abilChronosphere:LevelUp()
	elseif skills.abilTimeLeap:CanLevelUp() then
		skills.abilTimeLeap:LevelUp()
	elseif skills.abilRewind:GetLevel() < 1 then
		skills.abilRewind:LevelUp()
	elseif skills.abilCurseOfAges:CanLevelUp() then
		skills.abilCurseOfAges:LevelUp()
	elseif skills.abilRewind:CanLevelUp() then
		skills.abilRewind:LevelUp()
	else
		skills.abilAttributeBoost:LevelUp()
	end
end

local function GetTimeLeapRadius()
	return 300
end

local function GetChronosphereRadius()
	return 400
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

--melee weight overrides
behaviorLib.nCreepPushbackMul = 0.5
behaviorLib.nTargetPositioningMul = 0.6

----------------------------------
--	Chronos' specific harass bonuses
--
--  Abilities off cd increase harass util
--  Ability use increases harass util for a time
----------------------------------

object.nTimeLeapUp = 13
object.nChronosphereUp = 40

object.nTimeLeapUse = 45
object.nChronosphereUse = 70

object.nCurseOfAgesNext = 6

object.nTimeLeapThreshold = 35
object.nChronosphereThreshold = 50

local function IsCurseOfAgesNext()
	return skills.abilCurseOfAges and skills.abilCurseOfAges:GetCharges() <= 1 
end

local function AbilitiesUpUtility(hero)
	local bDebugLines = false
	local bDebugEchos = false
	
	local nUtility = 0
	
	if skills.abilTimeLeap and skills.abilTimeLeap:CanActivate() then
		nUtility = nUtility + object.nTimeLeapUp
	end
	
	if IsCurseOfAgesNext() then
		nUtility = nUtility + object.nCurseOfAgesNext
	end
	
	if skills.abilChronosphere and skills.abilChronosphere:CanActivate() then
		nUtility = nUtility + object.nChronosphereUp
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

--Chronos ability use gives bonus to harass util for a while
function object:oncombateventOverride(EventData)
	self:oncombateventOld(EventData)
	
	local bDebugEchos = false
	local nAddBonus = 0
	
	if EventData.Type == "Ability" then
		if bDebugEchos then BotEcho("  ABILILTY EVENT!  InflictorName: "..EventData.InflictorName) end
		if EventData.InflictorName == "Ability_Chronos1" then
			nAddBonus = nAddBonus + self.nTimeLeapUse
		elseif EventData.InflictorName == "Ability_Chronos4" then
			nAddBonus = nAddBonus + self.nChronosphereUse
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
	local nUtility = AbilitiesUpUtility(hero)
	
	return nUtility
end
behaviorLib.CustomHarassUtility = CustomHarassUtilityFnOverride   

----------------------------------
--	Chronos harass actions
----------------------------------
object.nTimeLeapRadiusBuffer = 100
object.nChronosphereCheckRangeBuffer = 200
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
	local bTargetRooted = unitTarget:IsStunned() or unitTarget:IsImmobilized() or unitTarget:GetMoveSpeed() < 200
	
	local nLastHarassUtility = behaviorLib.lastHarassUtil
	--local bCanSee = core.CanSeeUnit(botBrain, unitTarget)	
	
	if bDebugEchos then BotEcho("Defiler HarassHero at "..nLastHarassUtility) end
	local bActionTaken = false
	
	--Time Leap
	if not bActionTaken and not bTargetRooted and nLastHarassUtility > botBrain.nTimeLeapThreshold then
		if bDebugEchos then BotEcho("  No action yet, checking time leap") end
		local abilTimeLeap = skills.abilTimeLeap
		if abilTimeLeap and abilTimeLeap:CanActivate() then
			local vecTargetTraveling = nil
			if unitTarget.bIsMemoryUnit and unitTarget.lastStoredPosition then
				vecTargetTraveling = Vector3.Normalize(vecTargetPosition - unitTarget.lastStoredPosition)
			else
				local unitEnemyWell = core.enemyWell
				if unitEnemyWell then
					--TODO: use heading
					vecTargetTraveling = Vector3.Normalize(unitEnemyWell:GetPosition() - vecTargetPosition)
				end
			end
			
			local vecAbilityTarget = vecTargetPosition
			if vecTargetTraveling then
				vecAbilityTarget = vecTargetPosition + vecTargetTraveling * (GetTimeLeapRadius() - object.nTimeLeapRadiusBuffer)
			end
			
			bActionTaken = core.OrderAbilityPosition(botBrain, abilTimeLeap, vecAbilityTarget)
		end
	end
	
	--Chronosphere
	if not bActionTaken and nLastHarassUtility > botBrain.nChronosphereThreshold then
		if bDebugEchos then BotEcho("  No action yet, checking chronosphere") end
		local abilChronosphere = skills.abilChronosphere
		if abilChronosphere and abilChronosphere:CanActivate() then
			local nCheckRange = abilChronosphere:GetRange() + object.nChronosphereCheckRangeBuffer
			local nRadius = GetChronosphereRadius()
					
			local vecAbilityPosition = core.AoETargeting(core.unitSelf, nCheckRange, nRadius, true, unitTarget, core.enemyTeam, nil)
	
			if vecAbilityPosition == nil then
				vecAbilityPosition = vecTargetPosition
			end
			
			bActionTaken = core.OrderAbilityPosition(botBrain, abilChronosphere, vecAbilityPosition)
		end
	end
		
	if not bActionTaken then
		if bDebugEchos then BotEcho("  No action yet, proceeding with normal harass execute.") end
		return object.harassExecuteOld(botBrain)
	end
end
object.harassExecuteOld = behaviorLib.HarassHeroBehavior["Execute"]
behaviorLib.HarassHeroBehavior["Execute"] = HarassHeroExecuteOverride

-----------------------
-- Return to well
-----------------------
--this is a great function to override with using retreating skills, such as blinks, travels, stuns or slows.
function behaviorLib.CustomReturnToWellExecute(botBrain)
	return core.OrderBlinkAbilityToEscape(botBrain, skills.abilTimeLeap, true)
end


----------------------------------
--	Chronos items
----------------------------------
--[[ list code:
	"# Item" is "get # of these"
	"Item #" is "get this level of the item" --]]
	
behaviorLib.StartingItems = 
	{"Item_LoggersHatchet", "Item_IronBuckler", "Item_RunesOfTheBlight"}
behaviorLib.LaneItems = 
	{"Item_IronShield", "Item_Marchers", "Item_Steamboots", "Item_ElderParasite"}
behaviorLib.MidItems = 
	{"Item_SolsBulwark", "Item_Weapon3", "Item_Critical1 4"} --Item_Weapon3 is Savage Mace, Item_Critical1 is Riftshards
behaviorLib.LateItems = 
	{"Item_DaemonicBreastplate", "Item_Lightning2", "Item_BehemothsHeart", 'Item_Damage9'} --Item_Lightning2 is Charged Hammer. Item_Damage9 is Doombringer


BotEcho('finished loading chronos_main')

--[[
-- example of how to override default item behaviors. To disable the default, use tinsert(behaviorLib.tDontUseDefaultItemBehavior, "Item_ElderParasite")
function behaviorLib.ElderParasiteExecute(botBrain)
	BotEcho("overridden!")
end
behaviorLib.ElderParasiteBehavior["Execute"] = behaviorLib.ElderParasiteExecute
]]
