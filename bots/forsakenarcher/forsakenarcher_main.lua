--FABot v1.0


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

BotEcho('loading forsakenarcher_main...')

--------------------------------
-- Lanes
--------------------------------
core.tLanePreferences = {Jungle = 0, Mid = 5, ShortSolo = 5, LongSolo = 3, ShortSupport = 1, LongSupport = 2, ShortCarry = 5, LongCarry = 4}

object.heroName = 'Hero_ForsakenArcher'

--------------------------------
-- Skills
--------------------------------
local bSkillsValid = false
function object:SkillBuild()
	local unitSelf = self.core.unitSelf	
	
	if not bSkillsValid then
		skills.abilCripplingVolley	= unitSelf:GetAbility(0)
		skills.abilSplitFire		= unitSelf:GetAbility(1)
		skills.abilCallOfTheDamned	= unitSelf:GetAbility(2)
		skills.abilPiercingArrows	= unitSelf:GetAbility(3)
		skills.abilAttributeBoost	= unitSelf:GetAbility(4)
		
		if skills.abilCripplingVolley and skills.abilSplitFire and skills.abilCallOfTheDamned and skills.abilPiercingArrows and skills.abilAttributeBoost then
			bSkillsValid = true
		else
			return
		end
	end
	
	if unitSelf:GetAbilityPointsAvailable() <= 0 then
		return
	end
	
	--Ult, Crippling Volley, Call Of the Damned, Split Fire, Stats
	if skills.abilPiercingArrows:CanLevelUp() then
		skills.abilPiercingArrows:LevelUp()
	elseif skills.abilCripplingVolley:CanLevelUp() then
		skills.abilCripplingVolley:LevelUp()
	elseif skills.abilCallOfTheDamned:CanLevelUp() then
		skills.abilCallOfTheDamned:LevelUp()
	elseif skills.abilSplitFire:CanLevelUp() then
		skills.abilSplitFire:LevelUp()
	else
		skills.abilAttributeBoost:LevelUp()
	end
end

function object.GetCripplingVolleyRadius()
	return 200
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
--	Forsaken Archer specific harass bonuses
--
--  Abilities off cd increase harass util
--  Ability use increases harass util for a time
----------------------------------

object.nCripplingVolleyUp = 8
object.nPiercingArrowsUp = 20

object.nCripplingVolleyUse = 10
object.nPiercingArrowsUse = 55

object.nSkeletonOutUtil = 3

object.nCripplingVolleyThreshold = 35
object.nPiercingArrowsThreshold = 45

local function AbilitiesUpUtilityFn(hero)
	local bDebugLines = false
	local bDebugEchos = false
	
	local val = 0
	
	if skills.abilCripplingVolley:CanActivate() then
		val = val + object.nCripplingVolleyUp
	end
	
	if skills.abilPiercingArrows:CanActivate() then
		val = val + object.nPiercingArrowsUp
	end
	
	if bDebugEchos then BotEcho(" HARASS - abilitiesUp: "..val) end
	if bDebugLines then
		local lineLen = 150
		local myPos = core.unitSelf:GetPosition()
		local vTowards = Vector3.Normalize(hero:GetPosition() - myPos)
		local vOrtho = Vector3.Create(-vTowards.y, vTowards.x) --quick 90 rotate z
		core.DrawDebugArrow(myPos - vOrtho * lineLen * 1.4, (myPos - vOrtho * lineLen * 1.4 ) + vTowards * val * (lineLen/100), 'cyan')
	end
	
	return val
end

--[[
local function ImmobilizedUtilityFn(hero)
	if hero:IsImmobilized() or hero:IsStunned() then
		--if 
	end
end
--]]

--Forsaken Archer ability use gives bonus to harass util for a while
function object:oncombateventOverride(EventData)
	self:oncombateventOld(EventData)
	
	local bDebugEchos = false
	local nAddBonus = 0
	
	if EventData.Type == "Ability" then
		if bDebugEchos then BotEcho("  ABILILTY EVENT!  InflictorName: "..EventData.InflictorName) end
		if EventData.InflictorName == "Ability_ForsakenArcher1" then
			nAddBonus = nAddBonus + object.nCripplingVolleyUse
		elseif EventData.InflictorName == "Ability_ForsakenArcher4" then
			nAddBonus = nAddBonus + object.nPiercingArrowsUse
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

local function SkeletonUtility()
	--fa is more aggressive if she has skeletons out
	local nCharges = skills.abilCallOfTheDamned:GetCharges()
	
	--BotEcho("Skeletons: "..nCharges)
	
	return nCharges * object.nSkeletonOutUtil
end

--Util calc override
local function CustomHarassUtilityFnOverride(hero)
	local nUtility = AbilitiesUpUtilityFn(hero) + SkeletonUtility()
	
	return nUtility
end
behaviorLib.CustomHarassUtility = CustomHarassUtilityFnOverride   

----------------------------------
--	Forsaken Archer harass actions
----------------------------------
object.nAttackBuffer = 100

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
	
	local nLastHarassUtility = behaviorLib.lastHarassUtil
	local bCanSee = core.CanSeeUnit(botBrain, unitTarget)	
	local bTargetRooted = unitTarget:IsStunned() or unitTarget:IsImmobilized() or unitTarget:GetMoveSpeed() < 200
	
	if bDebugEchos then BotEcho("Forsaken Archer HarassHero at "..nLastHarassUtility) end
	local bActionTaken = false
	
	--Crippling Volley
	if not bActionTaken and nLastHarassUtility > botBrain.nCripplingVolleyThreshold then
		if bDebugEchos then BotEcho("  No action yet, checking crippling volley") end
		local abilCripplingVolley = skills.abilCripplingVolley
		if abilCripplingVolley:CanActivate() then
			local nRange = abilCripplingVolley:GetRange()
			if nTargetDistanceSq < (nRange * nRange) then
				local vecTarget = vecTargetPosition
				
				--prediction
				if unitTarget.bIsMemoryUnit then
					--core.teamBotBrain:UpdateMemoryUnit(unitTarget)
					if unitTarget.storedPosition and unitTarget.lastStoredPosition then
						local vecLastDirection = Vector3.Normalize(unitTarget.storedPosition - unitTarget.lastStoredPosition)
						vecTarget = vecTarget + vecLastDirection * object.GetCripplingVolleyRadius()
						--core.DrawDebugArrow(vecTargetPosition, vecTarget, 'orange')
						--core.DrawXPosition(vecTarget, 'red', 400)
					end
				end
				
				bActionTaken = core.OrderAbilityPosition(botBrain, abilCripplingVolley, vecTarget)
			end
		end 
	end
	
	--Piercing Arrows
	if not bActionTaken and nLastHarassUtility > botBrain.nPiercingArrowsThreshold and bTargetRooted then
		if bDebugEchos then BotEcho("  No action yet, piercing arrows") end
		local abilPiercingArrows = skills.abilPiercingArrows
		if abilPiercingArrows:CanActivate() then
			local nRange = abilPiercingArrows:GetRange()
			if nTargetDistanceSq < (nRange * nRange) then
				bActionTaken = core.OrderAbilityPosition(botBrain, abilPiercingArrows, vecTargetPosition)
			end
		end
	end
	
	--Auto attack if you are in range(-ish), without attack-dancing so the skeletons can do work
	local nSkeletons = skills.abilCallOfTheDamned:GetCharges()
	if not bActionTaken and nSkeletons > 0 then
		local nAttackRangeAndBufferSq = core.GetAbsoluteAttackRangeToUnit(unitSelf, unitTarget) + object.nAttackBuffer
		nAttackRangeAndBufferSq = nAttackRangeAndBufferSq * nAttackRangeAndBufferSq
		local itemGhostMarchers = core.itemGhostMarchers

		if nTargetDistanceSq < nAttackRangeAndBufferSq and bCanSee then
			local bInTowerRange = core.NumberElements(core.GetTowersThreateningUnit(unitSelf)) > 0
			local bShouldDive = behaviorLib.lastHarassUtil >= behaviorLib.diveThreshold
			
			--BotEcho(format("inTowerRange: %s  bShouldDive: %s", tostring(bInTowerRange), tostring(bShouldDive)))
			
			if not bInTowerRange or bShouldDive then
				if bDebugEchos then BotEcho("ATTAKIN NOOBS! divin: "..tostring(bShouldDive)) end
				core.OrderAttackClamp(botBrain, unitSelf, unitTarget)
			end
		else
			--BotEcho("MOVIN OUT")
			local desiredPos = vecTargetPosition
			local bUseTargetPosition = true

			--leave some space if we are ranged
			if unitSelf:GetAttackRange() > 200 then
				desiredPos = vecTargetPosition + Vector3.Normalize(unitSelf:GetPosition() - vecTargetPosition) * behaviorLib.rangedHarassBuffer
				bUseTargetPosition = false
			end

			if itemGhostMarchers and itemGhostMarchers:CanActivate() then
				local bSuccess = core.OrderItemClamp(botBrain, unitSelf, itemGhostMarchers)
				if bSuccess then
					return
				end
			end
			
			if behaviorLib.lastHarassUtil < behaviorLib.diveThreshold then
				if bDebugEchos then BotEcho("DON'T DIVE!") end
				local bChanged = false
				desiredPos, bChanged = core.AdjustMovementForTowerLogic(desiredPos)
				
				if bUseTargetPosition and not bChanged then
					core.OrderMoveToUnitClamp(botBrain, unitSelf, unitTarget, false)
				else
					core.OrderMoveToPosClamp(botBrain, unitSelf, desiredPos, false)
				end
			else
				if bDebugEchos then BotEcho("DIVIN! util: "..behaviorLib.lastHarassUtil.." > "..behaviorLib.diveThreshold) end
				core.OrderMoveToPosClamp(botBrain, unitSelf, desiredPos, false)
			end
		end
		bActionTaken = true
	end
	
	if not bActionTaken then
		if bDebugEchos then BotEcho("  No action yet, proceeding with normal harass execute.") end
		return object.harassExecuteOld(botBrain)
	end
end
object.harassExecuteOld = behaviorLib.HarassHeroBehavior["Execute"]
behaviorLib.HarassHeroBehavior["Execute"] = HarassHeroExecuteOverride


----------------------------------
--	Forsaken Archer specific push
----------------------------------

object.nSplitFirePushWeight = 0.4

--fa's split fire is {14%, 21%, 28%, 35%} shot on 2 extra targets in attack range
local function SplitFirePushUtility()
	local nLevel = skills.abilSplitFire:GetLevel()
	local m = 25 --(100/4)
	
	local nUtility = m * nLevel
	
	return nUtility
end

local function PushingStrengthUtilityOverride(myHero)
	local nUtility = object.funcPushUtilityOld(myHero)
	
	local nSplitFireUtility = SplitFirePushUtility() * object.nSplitFirePushWeight
	
	nUtility = nUtility + nSplitFireUtility
	nUtility = Clamp(nUtility, 0, 100)

	return nUtility
end
object.funcPushUtilityOld = behaviorLib.PushingStrengthUtility
behaviorLib.PushingStrengthUtility = PushingStrengthUtilityOverride


----------------------------------
--	Forsaken Archer items
----------------------------------
--[[ list code:
	"# Item" is "get # of these"
	"Item #" is "get this level of the item" --]]
behaviorLib.StartingItems = {"2 Item_DuckBoots", "2 Item_MinorTotem", "Item_HealthPotion", "Item_RunesOfTheBlight"}
behaviorLib.LaneItems = {"Item_Marchers", "2 Item_Soulscream", "Item_EnhancedMarchers"}
behaviorLib.MidItems = {"Item_StrengthAgility"} --StrengthAgility is frostburn
--TODO: break into frostwolf skull and geometer's bane
behaviorLib.LateItems = {"Item_Weapon3", "Item_BehemothsHeart", "Item_Damage9" } --Weapon3 is Savage Mace. Item_Sicarius is Firebrand. ManaBurn2 is Geomenter's Bane. Item_Damage9 is Doombringer






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

BotEcho('loading forsakenarcher_main')

