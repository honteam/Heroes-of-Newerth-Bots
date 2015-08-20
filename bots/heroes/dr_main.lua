-- Doctor Repulsor Bot v1.0a

local _G = getfenv(0)
local object = _G.object

object.myName = object:GetName()

object.bRunLogic         = true
object.bRunBehaviors    = true
object.bUpdates         = true
object.bUseShop         = true

object.bRunCommands     = true 
object.bMoveCommands     = true
object.bAttackCommands     = true
object.bAbilityCommands = true
object.bOtherCommands     = true

object.bReportBehavior = false
object.bDebugUtility = false

object.logger = {}
object.logger.bWriteLog = false
object.logger.bVerboseLog = false

object.core         = {}
object.eventsLib     = {}
object.metadata     = {}
object.behaviorLib     = {}
object.skills         = {}

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

BotEcho("loading Doctor Repulsor...")

--####################################################################
--####################################################################
--#                                                                 ##
--#                  bot constant definitions                       ##
--#                                                                 ##
--####################################################################
--####################################################################

object.heroName = 'Hero_DoctorRepulsor'

core.tLanePreferences = {
	Jungle = 0,
	Mid = 6,
	ShortSolo = 3,
	LongSolo = 0,
	ShortSupport = 0,
	LongSupport = 0,
	ShortCarry = 3,
	LongCarry = 4
}

-- item buy order. internal names
behaviorLib.StartingItems  = { "Item_RunesOfTheBlight", "Item_HealthPotion", "4 Item_MinorTotem"}
-- TODO: Add Icon of Goddess maybe?
behaviorLib.LaneItems  = {"Item_Bottle", "Item_Marchers", "Item_Steamboots", "Item_GraveLocket", "Item_Lightbrand"}
behaviorLib.MidItems  = {"Item_GrimoireOfPower", "Item_Silence"}
behaviorLib.LateItems  = {"Item_Protect", "Item_Morph"}

-- skillbuild table, 0=q, 1=w, 2=e, 3=r, 4=attri
object.tSkills = {
	0, 2, 1, 0,		-- Q E W Q	(4)
	1, 3, 0, 0,		-- W R Q Q	(8)		Maxed Q here	(Level 1 ult)
	1, 3, 1, 2,		-- W R W E  (12)	Maxed W here	(Level 2 ult)
	2, 2, 4, 3,		-- E E S R  (16)					(Level 3 ult)
	4, 4, 4, 4,		-- stats	(20)
	4, 4, 4, 4,		-- stats	(24)
	4				-- stats	(25)
}

-- bonus agression points if a skill/item is available for use
object.nContrpUp = 20
object.nOpposingUp = 10
object.nSpeedUp = 40
object.nHFlowerUp = 40
object.nMorphUp = 45

-- bonus agression points that are applied to the bot upon successfully using a skill/item
object.nContrpUse = 30
object.nOpposingUse = 15
object.nSpeedUse = 35
object.nHFlowerUse = 40
object.nMorphUse = 40

--thresholds of aggression the bot must reach to use these abilities
object.nContrpThreshold = 25
object.nOpposingThreshold = 20
object.nSpeedThreshold = 40
object.nHFlowerThreshold = 40
object.nMorphThreshold = 40

-- This is a static variable indicating that we have used our ultimate
-- This is used so we can proc our E
-- Note: Only used in aggression, see HarassHero
object.bToggleUltimateFrenzy = false

------------------------------
--     skills               --
------------------------------
-- @param: none
-- @return: none
function object:SkillBuild()
	local unitSelf = self.core.unitSelf
	if skills.abilQ == nil then
		skills.abilQ = unitSelf:GetAbility(0)
		skills.abilW = unitSelf:GetAbility(1)
		skills.abilR = unitSelf:GetAbility(3)
	end

	if unitSelf:GetAbilityPointsAvailable() <= 0 then
		return
	end

	local nlev = unitSelf:GetLevel()
	local nlevpts = unitSelf:GetAbilityPointsAvailable()
	for i = nlev, nlev+nlevpts do
		unitSelf:GetAbility( object.tSkills[i] ):LevelUp()
	end
end

-- @param: eventdata
-- @return: none
function object:oncombateventOverride(EventData)
	local nBonus = 0

	if EventData.Type == "Ability" then
		if EventData.InflictorName == "Ability_DoctorRepulsor4" then
			local lvl = core.unitSelf:GetLevel()
			if lvl >= 16 then
				nBonus = nBonus + object.nSpeedUse + 10 * lvl / 10
			elseif lvl >= 11 then
				nBonus = nBonus + object.nSpeedUse + 5 * lvl / 10
			else
				nBonus = nBonus + object.nSpeedUse + (lvl / 3) * 2
			end
		elseif EventData.InflictorName == "Ability_DoctorRepulsor1" then
			nBonus = nBonus + object.nContrpUse
		elseif EventData.InflictorName == "Ability_DoctorRepulsor2" then
			nBonus = nBonus + object.nOpposingUse
		else
			nBonus = nBonus + object.nContrpUse
		end
	elseif EventData.Type == "Item" and EventData.SourceUnit == core.unitSelf:GetUniqueID() then
		local itemMorph, itemSilence = core.GetItem("Item_Morph"), core.GetItem("Item_Silence")
		if itemMorph ~= nil and EventData.InflictorName == itemMorph:GetName() then
			nBonus = nBonus + object.nMorphUse
		elseif itemSilence ~= nil and EventData.InflictorName == itemSilence:GetName() then
			nBonus = nBonus + object.nHFlowerUse
		end
	end

	if nBonus > 0 then
		core.DecayBonus(self)
		core.nHarassBonus = core.nHarassBonus + nBonus
	end
end
object.oncombateventOld = object.oncombatevent
object.oncombatevent     = object.oncombateventOverride

-- @param: iunitentity hero
-- @return: number
local function CustomHarassUtilityFnOverride(hero)
	local nValue = 0

	if skills.abilQ:CanActivate() then
		nValue = nValue + object.nContrpUp
	end

	if skills.abilW:CanActivate() then
		nValue = nValue + object.nOpposingUp
	end

	if skills.abilR:CanActivate() then
		nValue = nValue + object.nSpeedUp
	end

	local itemMorph = core.GetItem("Item_Morph")
	if itemMorph and itemMorph:CanActivate() then
		nValue = nValue + object.nMorphUp
	end

	local itemSilence = core.GetItem("Item_Silence")
	if itemSilence and itemSilence:CanActivate() then
		nValue = nValue + object.nHFlowerUp
	end

	return nValue
end
behaviorLib.CustomHarassUtility = CustomHarassUtilityFnOverride  

-- @param botBrain: CBotBrain
-- @return: none
local function CustomRetreatExecuteFnOverride(botBrain)
	-- If we're low HP, run for our life!
	local unitSelf = core.unitSelf
	if unitSelf and unitSelf:GetHealth() > 0 and unitSelf:GetHealth() < 400
		and skills.abilR:CanActivate() and unitSelf:GetMana() > 230
	then
		-- stolen from RallyTest and adjusted a bit to fit
		local vecOrigin = unitSelf:GetPosition()
		local vecDirection = Vector3.Create(1, 0)
		vecDirection = core.RotateVec2D(vecDirection, unitSelf:GetTeam() == 2 and 90 or -90)
		core.OrderAbilityPosition(self, skills.abilR, vecOrigin + vecDirection * 500)

		return true
	end

	return false
end
behaviorLib.CustomRetreatExecute = CustomRetreatExecuteFnOverride

-- @param botBrain: CBotBrain
-- @return: none
--
local function HarassHeroExecuteOverride(botBrain)
	local unitTarget = behaviorLib.heroTarget
	if unitTarget == nil then
		return object.harassExecuteOld(botBrain)
	end
    
	local unitSelf = core.unitSelf
	local vecMyPosition = unitSelf:GetPosition()
--  local nAttackRange = core.GetAbsoluteAttackRangeToUnit(unitSelf, unitTarget)
--  local nMyExtraRange = core.GetExtraRange(unitSelf)
    
	local vecTargetPosition = unitTarget:GetPosition()
--  local nTargetExtraRange = core.GetExtraRange(unitTarget)
	local nTargetDistanceSq = Vector3.Distance2DSq(vecMyPosition, vecTargetPosition)
    
	local nLastHarassUtility = behaviorLib.lastHarassUtil
	local bCanSee = core.CanSeeUnit(botBrain, unitTarget)
	local bActionTaken = false

	if bCanSee then
		local bTargetVuln = unitTarget:IsStunned() or unitTarget:IsImmobilized() or unitTarget:IsPerplexed()

		if not bTargetVuln then
			local bNeedRange = false
			local nRangeNeeded = 0

			local itemMorph = core.GetItem("Item_Morph")
			if itemMorph ~= nil and itemMorph:CanActivate() then
				local range = itemMorph:GetRange()
				if nLastHarassUtility > botBrain.nMorphThreshold and nTargetDistanceSq < (range * range) then
					bActionTaken = core.OrderItemEntityClamp(botBrain, unitSelf, itemMorph, unitTarget)
				end
			end

			if not bActionTaken then
				-- try hell flower or opposing charges
				local itemSilence = core.GetItem("Item_Silence")
				if itemSilence ~= nil and itemSilence:CanActivate()
					and nLastHarassUtility > botBrain.nHFlowerThreshold
				then
					local range = itemSilence:GetRange()
					if nTargetDistanceSq < (range * range) then
						bActionTaken = core.OrderItemEntityClamp(botBrain, unitSelf, itemSilence, unitTarget)
					else
						bNeedRange = true
						nRangeNeeded = (range * range) - nTargetDistanceSq
					end
				elseif skills.abilW:CanActivate() and nLastHarassUtility > botBrain.nOpposingThreshold then
					local range = skills.abilW:GetRange()
					if nTargetDistanceSq < (range * range) then
						bActionTaken = core.OrderAbilityEntity(botBrain, skills.abilW, unitTarget)
					else
						bNeedRange = true
						nRangeNeeded = (range * range) - nTargetDistanceSq
					end
				end
			end

			if skills.abilR:CanActivate() and unitSelf:GetMana() >= 100 then
				local vecTmp = vecTargetPosition
				local bUse = true
				if not bNeedRange then
					if not object.bToggleUltimateFrenzy then
						-- This will move him a bit and then we can proc his E correctly hopefully.
						vecTmp[1] = vecTmp[1] * 1.02
						vecTmp[2] = vecTmp[2] * 1.02
						vecTmp[3] = vecTmp[3] * 0.50
						object.bToggleUltimateFrenzy = true
					else
						bUse = false
						object.bToggleUltimateFrenzy = false
					end
				else
					vecTmp = vecTmp / nRangeNeeded
				end

				if bUse then
					core.OrderAbilityPosition(botBrain, skills.abilR, vecTmp)
				end
			elseif bNeedRange then
				bActionTaken = core.OrderMoveToUnitClamp(botBrain, unitSelf, unitTarget)
			end
		end

		if not bActionTaken and skills.abilQ:CanActivate()
			and nLastHarassUtility > botBrain.nContrpThreshold
		then
			local range = skills.abilQ:GetRange()
			local off = nTargetDistanceSq - (range * range)
			if off <= 24000 then
				bActionTaken = core.OrderAbility(botBrain, skills.abilQ)
			elseif off <= 130000 then	-- just so he does not dive towers
				bActionTaken = core.OrderMoveToUnitClamp(botBrain, unitSelf, unitTarget)
			end
		end
	end

	if not bActionTaken then
		return object.harassExecuteOld(botBrain)
	end

	return bActionTaken
end
-- overload the behaviour stock function with custom 
object.harassExecuteOld = behaviorLib.HarassHeroBehavior["Execute"]
behaviorLib.HarassHeroBehavior["Execute"] = HarassHeroExecuteOverride

BotEcho("Finished loading Doctor Repulsor")
