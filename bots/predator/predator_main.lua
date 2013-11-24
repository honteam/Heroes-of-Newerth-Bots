--PredatorBot v1.1

--[[ Change Log: 
(v1.1)	Adjusted Predator's code and skill build to match his new Ult mechanics
--]]

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

BotEcho('loading predator_main...')

--------------------------------
-- Lanes
--------------------------------
core.tLanePreferences = {Jungle = 0, Mid = 1, ShortSolo = 1, LongSolo = 1, ShortSupport = 1, LongSupport = 1, ShortCarry = 5, LongCarry = 5}

object.heroName = 'Hero_Predator'

--------------------------------
-- Skills
--------------------------------
function object:SkillBuild()

	local unitSelf = self.core.unitSelf

	if skills.abilLeap == nil then
		skills.abilLeap = unitSelf:GetAbility(0)
		skills.abilStoneHide = unitSelf:GetAbility(1)
		skills.abilCarnivorous = unitSelf:GetAbility(2)
		skills.abilTerror = unitSelf:GetAbility(3)
		skills.attributeBoost = unitSelf:GetAbility(4)
	end
	
	if unitSelf:GetAbilityPointsAvailable() <= 0 then
		return
	end
	
	--max leap, 1 lvl stonehide, max {ult, carnivorous, stonehide, stats}
	if skills.abilTerror:CanLevelUp() then
		skills.abilTerror:LevelUp()		
	elseif skills.abilLeap:CanLevelUp() then
		skills.abilLeap:LevelUp()
	elseif skills.abilStoneHide:GetLevel() < 1 then
		skills.abilStoneHide:LevelUp()
	elseif skills.abilCarnivorous:CanLevelUp() then
		skills.abilCarnivorous:LevelUp()	
	elseif skills.abilStoneHide:CanLevelUp() then
		skills.abilStoneHide:LevelUp()
	else
		skills.attributeBoost:LevelUp()
	end	
end

---------------------------------------------------
--                   Overrides                   --
---------------------------------------------------

object.bHadTerrorLast = nil
function object:onthinkOverride(tGameVariables)
	local bDebugEchos = false

	--Check to see if we applied Terror to our target this last frame
	if self.bRunLogic ~= false and self.bRunBehaviors ~= false and core.botBrainInitialized and core.unitSelf ~= nil and core.unitSelf:GetHealth() > 0 then
		local bHadTerrorLast = object.bHadTerrorLast
		--if bHadTerrorLast ~= true then
			--Update
			local unitTarget = behaviorLib.heroTarget
			if unitTarget ~= nil then
				local nAddBonus = 0			
				local bHasTerrorNow = unitTarget:HasState("State_Predator_Ability4")
				
				if bDebugEchos then BotEcho(format("%s: now: %s  before: %s", unitTarget:GetTypeName(), tostring(bHasTerrorNow), tostring(object.bHadTerrorLast))) end
				
				if bHadTerrorLast ~= nil and (bHasTerrorNow and not bHadTerrorLast) then
					nAddBonus = nAddBonus + object.nTerrorAppliedBonus
				end
				
				if nAddBonus > 0 then
					core.DecayBonus(self) --decay before we add
					core.nHarassBonus = core.nHarassBonus + nAddBonus
					
					if bDebugEchos then BotEcho("Applied Terror! Adding "..nAddBonus.." momentium!") end
				end
				
				object.bHadTerrorLast = bHasTerrorNow
			end
		--end
	end
	
	self:onthinkOld(tGameVariables)
	
	--[[ TEST
		core.unitSelf:TeamShare();
		
		-- Insert code here
	--]]
end
object.onthinkOld = object.onthink
object.onthink 	= object.onthinkOverride


--Override core.BehaviorsSwitched so we can reset our Terror watch variable
local function BehaviorsSwitchedOverride()
	object.BehaviorsSwitchedOld()
	
	object.bHadTerrorLast = nil
end
object.BehaviorsSwitchedOld = core.BehaviorsSwitched
core.BehaviorsSwitched = BehaviorsSwitchedOverride



behaviorLib.nCreepPushbackMul = 0.5
behaviorLib.nTargetPositioningMul = 0.6

----------------------------------
--	Pred specific harass bonuses
--
--  Abilities off cd increase harass util
--  Ability use increases harass util for a time
----------------------------------

object.nLeapUpBonus = 13
--object.stoneHideUpBonus = ?
object.nTerrorSkilledBonusPerLevel = 7

object.nLeapUseBonus = 35
object.nTerrorAppliedBonus = 13

object.leapUtilThreshold = 35

local function AbilitiesUpUtilityFn(hero)
	local bDebugLines = false
	local bDebugEchos = false
	
	local val = 0
	
	if skills.abilLeap:CanActivate() then
		val = val + object.nLeapUpBonus
	end
	
	--if skills.abilStoneHide:CanActivate() then
	--	val = val + object.stoneHideUpBonus
	--end
	
	local nTerrorLevel = skills.abilTerror:GetLevel()
	if nTerrorLevel >= 1 then
		val = val + object.nTerrorSkilledBonusPerLevel * nTerrorLevel
	end
	
	if bDebugEchos then BotEcho(" HARASS - abilitiesUp: "..val) end
	if bDebugLines then
		local lineLen = 150
		local myPos = core.unitSelf:GetPosition()
		local vTowards = Vector3.Normalize(hero:GetPosition() - myPos)
		local vOrtho = Vector3.Create(-vTowards.y, vTowards.x) --quick 90 rotate z
		core.DrawDebugArrow(myPos - vOrtho * lineLen * 1.4, (myPos - vOrtho * lineLen * 1.4 ) + vTowards * val * (lineLen/100), 'cyan')
		core.DrawDebugLine( (myPos - vOrtho * lineLen * 0.6) + vTowards * lineLen * (object.leapUtilThreshold/100) - (vOrtho * 0.15 * lineLen),
								(myPos - vOrtho * lineLen * 0.6) + vTowards * lineLen * (object.leapUtilThreshold/100) + (vOrtho * 0.15 * lineLen), 'white')
	end
	
	return val
end

--Pred ability use gives bonus to harass util for a while
function object:oncombateventOverride(EventData)
	self:oncombateventOld(EventData)
	
	local addBonus = 0
	
	if EventData.Type == "Ability" then
		--BotEcho("  ABILILTY EVENT!  InflictorName: "..EventData.InflictorName)
		if EventData.InflictorName == "Ability_Predator1" then
			addBonus = addBonus + object.nLeapUseBonus
		end
	end
	
	if addBonus > 0 then
		--decay before we add
		core.DecayBonus(self)
	
		core.nHarassBonus = core.nHarassBonus + addBonus
	end
end
object.oncombateventOld = object.oncombatevent
object.oncombatevent 	= object.oncombateventOverride

--Util calc override
local function CustomHarassUtilityOverride(hero)
	local nUtility = AbilitiesUpUtilityFn(hero)
	
	return nUtility
end
behaviorLib.CustomHarassUtility = CustomHarassUtilityOverride   


----------------------------------
--	Pred harass actions
----------------------------------
local function HarassHeroExecuteOverride(botBrain)
	local bDebugEchos = false
	
	--[[
	if object.myName == "Bot5" then
		bDebugEchos = true
	end--]]
	
	local unitSelf = core.unitSelf
	local target = behaviorLib.heroTarget 
	
	local bActionTaken = false
	--since we are using an old pointer, ensure we can still see the target for entity targeting
	if target ~= nil and core.CanSeeUnit(botBrain, target) then 
		local dist = Vector3.Distance2D(unitSelf:GetPosition(), target:GetPosition())
		local attackRange = core.GetAbsoluteAttackRangeToUnit(unitSelf, target);
		
		--leap
		local leap = skills.abilLeap
		local leapRange = leap:GetRange() + core.GetExtraRange(unitSelf) + core.GetExtraRange(target)
		if not bActionTaken then
			if bDebugEchos then BotEcho("No action taken, considering Leap") end			
			local bLeapUsable = leap:CanActivate() and dist < leapRange
			local bShouldLeap = false 
			
			if bLeapUsable and behaviorLib.lastHarassUtil > botBrain.leapUtilThreshold then
				bShouldLeap = true
			end
			
			if bShouldLeap then
				if bDebugEchos then BotEcho('LEAPIN!') end
				bActionTaken = core.OrderAbilityEntity(botBrain, leap, target)
			end
		end
	end
	
	if not bActionTaken then
		if bDebugEchos then BotEcho("No action taken, running my base harass") end
		return object.harassExecuteOld(botBrain)
	end
end
object.harassExecuteOld = behaviorLib.HarassHeroBehavior["Execute"]
behaviorLib.HarassHeroBehavior["Execute"] = HarassHeroExecuteOverride


----------------------------------
--	Predator items
----------------------------------
--[[ list code:
	"# Item" is "get # of these"
	"Item #" is "get this level of the item" --]]
behaviorLib.StartingItems = {"Item_LoggersHatchet", "Item_IronBuckler", "Item_RunesOfTheBlight"}
behaviorLib.LaneItems = {"Item_Marchers", "Item_Strength5", "Item_Steamboots", "Item_ElderParasite", "Item_Insanitarius"} --Item_Strength6 is Frostbrand
behaviorLib.MidItems = {"Item_Strength6", "Item_Immunity", "Item_StrengthAgility" } --Immunity is Shrunken Head, Item_StrengthAgility is Frostburn
behaviorLib.LateItems = {"Item_SolsBulwark", "Item_DaemonicBreastplate", "Item_BehemothsHeart", "Item_Damage9"} --Item_Damage9 is doombringer



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

BotEcho('finished loading predator_main')

