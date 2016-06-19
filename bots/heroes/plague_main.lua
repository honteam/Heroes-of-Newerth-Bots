--[[

	PlagueBot v1.1
	by CASHBALLER 

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

BotEcho('loading plague_main...')

---------------------------------------------------
--                  Constants
---------------------------------------------------

object.heroName = 'Hero_DiseasedRider'

-- Lanes
core.tLanePreferences = {Jungle = 0, ShortCarry = 1, LongCarry = 1, Mid = 2, ShortSolo = 2, LongSolo = 3, ShortSupport = 5, LongSupport = 5}

-- Skillbuild table, 0 = q, 1 = w, 2 = e, 3 = r, 4 = attri
object.tSkills = {
	0, 2, 0, 2, 0,
	3, 0, 2, 2, 1,
	3, 1, 1, 1, 4,
	3, 4, 4, 4, 4,
	4, 4, 4, 4, 4
}

----------------------------------
--	Plague items
----------------------------------
behaviorLib.StartingItems = {"Item_PretendersCrown", "2 Item_MinorTotem", "Item_HealthPotion", "2 Item_RunesOfTheBlight"}
behaviorLib.LaneItems = 
	{"Item_Strength5", "Item_Marchers", "Item_Striders", "Item_MysticPotpourri", "Item_MysticVestments"} -- Strength5 is Fortified Bracer and Potpourri is Refreshing Ornament
behaviorLib.MidItems = 
	{"Item_Astrolabe", "Item_Glowstone", "Item_MightyBlade", "Item_NeophytesBook", "Item_Intelligence7", "Item_PostHaste"} -- Intelligence7 is SotM and Protect is Null Stone
behaviorLib.LateItems = 
	{"Item_Glowstone", "Item_Lifetube", "Item_Protect", "Item_AcolytesStaff", "Item_Morph", "Item_BehemothsHeart", "Item_Immunity"} -- Morph is Sheepstick

--------------------------------
-- Skills
--------------------------------
local bSkillsValid = false
function object:SkillBuild()

	local unitSelf = self.core.unitSelf
	if not bSkillsValid then
		skills.abilNuke = unitSelf:GetAbility(0)
		skills.abilShield = unitSelf:GetAbility(1)
		skills.abilMana = unitSelf:GetAbility(2)
		skills.abilUltimate = unitSelf:GetAbility(3)
		
		if (skills.abilNuke and skills.abilShield and skills.abilMana and skills.abilUltimate) then
			bSkillsValid = true
		else
			return
		end		
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

---------------------------------------------------
--                   Utilities                   --
---------------------------------------------------

-- bonus aggression points if a skill/item is available for use
object.nNukeUp = 18
object.nUltimateUp = 7
-- bonus aggression points that are applied to the bot upon successfully using a skill/item
object.nNukeUse = 24
object.nShieldUse = 5
object.nUltimateUse = 28
--thresholds of aggression the bot must reach to use these abilities
object.nUltimateThreshold = 50
----------------------------------------------
--  		  oncombatevent override		--
----------------------------------------------
local function AbilitiesUpUtilityFn()
	local val = 0

	if skills.abilNuke:CanActivate() then
		val = val + object.nNukeUp
	end
	
	if skills.abilUltimate:CanActivate() then
		val = val + object.nUltimateUp
	end
	
	return val
end

function object:oncombateventOverride(EventData)
self:oncombateventOld(EventData)
	local addBonus = 0

	if EventData.Type == "Ability" then
		if EventData.InflictorName == "Ability_DiseasedRider1" then
			addBonus = addBonus + object.nNukeUse
		end

		if EventData.InflictorName == "Ability_DiseasedRider2" then
			addBonus = addBonus + object.nShieldUse
		end

		if EventData.InflictorName == "Ability_DiseasedRider4" then
			addBonus = addBonus + self.nUltimateUse
		end
	end

	if addBonus > 0 then
		--decay before we add
		core.DecayBonus(self)
		core.nHarassBonus = core.nHarassBonus + addBonus
	end
end
object.oncombateventOld = object.oncombatevent
object.oncombatevent = object.oncombateventOverride

----------------------------------
-- Use Shield
----------------------------------
local function UseShield(botBrain, bCheckNearAllies)
	local nManaThresholdAlone = 0.90
	local nManaThresholdNearAllies = 0.50
	local nNumAlliesRequired = 2
	local abilShield = skills.abilShield
	if abilShield:CanActivate() then
		local unitSelf = core.unitSelf
		local tLocalAllyHeroes = core.localUnits["AllyHeroes"]
		-- Assess if shield is worth casting
		if ( unitSelf:GetManaPercent() > nManaThresholdAlone) or ( bCheckNearAllies and
				unitSelf:GetManaPercent() > nManaThresholdNearAllies and core.NumberElements(tLocalAllyHeroes) > nNumAlliesRequired )  then
			-- Order shield cast
			return core.OrderAbilityEntity(botBrain, abilShield, unitSelf)
		end
	end
	return false
end

----------------------------------
-- Use Extinguish
----------------------------------
local function UseExtinguish(botBrain, nManaThreshold)
	local abilMana = skills.abilMana
	local unitSelf = core.unitSelf
	local vecMyPosition = unitSelf:GetPosition()
	local tLocalAllyCreeps = core.localUnits["AllyCreeps"]
	
	-- Assess if Extinguish is worth casting
	if abilMana:CanActivate() and unitSelf:GetManaPercent() < nManaThreshold and core.NumberElements(tLocalAllyCreeps) > 0 then
		for nUID,unitAlly in pairs(tLocalAllyCreeps) do
			local sName = unitAlly:GetTypeName()
			-- Find appropriate creep to deny
			if (string.find(sName, "Legion") or string.find(sName, "Hellbourne")) and not string.find(sName, "Siege") then
				local vecUnitPosition = unitAlly:GetPosition()
				local nUnitDistanceSq = Vector3.Distance2DSq(vecMyPosition, vecUnitPosition)
				local nRange = abilMana:GetRange()
				if (nUnitDistanceSq < (nRange * nRange)) then
					-- Order cast
					return core.OrderAbilityEntity(botBrain, abilMana, unitAlly)
				end
			end
		end
	end
	return false
end

----------------------------------
--	Plague harass actions
----------------------------------
local function HarassHeroExecuteOverride(botBrain)
	local unitTarget = behaviorLib.heroTarget
	if unitTarget == nil or not unitTarget:IsValid() then
		return false --can not execute, move on to the next behavior
	end
	
	local unitSelf = core.unitSelf
	local vecMyPosition = unitSelf:GetPosition()
	local vecTargetPosition = unitTarget:GetPosition()
	local nTargetDistanceSq = Vector3.Distance2DSq(vecMyPosition, vecTargetPosition)
	local nLastHarassUtility = behaviorLib.lastHarassUtil
	local bActionTaken = false
	local abilNuke = skills.abilNuke
	local abilUltimate = skills.abilUltimate
	local tLocalEnemyHeroes = core.localUnits["EnemyHeroes"]
	local tLocalAllyHeroes = core.localUnits["AllyHeroes"]
		
	--Nuke
	if abilNuke:CanActivate() and core.CanSeeUnit(botBrain, unitTarget) then
		local nRange = abilNuke:GetRange()
		if nTargetDistanceSq < (nRange * nRange) then
			-- Highest priority, not much reason to NOT cast this spell. If we have high mana, target has low health, or a gank/fight is happening, cast it.
			if (unitTarget:GetHealthPercent() < (unitSelf:GetManaPercent() + 0.15)) or (core.NumberElements(tLocalAllyHeroes) > 2) or (core.NumberElements(tLocalEnemyHeroes) > 2) then
				bActionTaken = core.OrderAbilityEntity(botBrain, abilNuke, unitTarget)
			end
		end
	end
	
	--Ultimate
	if not bActionTaken and abilUltimate:CanActivate() and core.CanSeeUnit(botBrain, unitTarget) then
		local nRange = abilUltimate:GetRange()
		if nTargetDistanceSq < (nRange * nRange) then
			-- Cast ultimate if high aggression, target is low and you are alone, or if there are many nearby opponents.
			if ( nLastHarassUtility > botBrain.nUltimateThreshold ) or ( unitTarget:GetHealthPercent() < 0.35 and core.NumberElements(tLocalAllyHeroes) < 1 ) or (core.NumberElements(tLocalEnemyHeroes) > 2) then
				bActionTaken = core.OrderAbilityEntity(botBrain, abilUltimate, unitTarget)
			end
		end
	end
	
	if not bActionTaken then
		return object.harassExecuteOld(botBrain)
	end
	
	return bActionTaken
end
object.harassExecuteOld = behaviorLib.HarassHeroBehavior["Execute"]
behaviorLib.HarassHeroBehavior["Execute"] = HarassHeroExecuteOverride

----------------------------------
--	    Farming a lane
----------------------------------
local function AttackCreepsExecuteOverride(botBrain)
	local bActionTaken = false
	
	--Extinguish
	bActionTaken = UseExtinguish(botBrain, 0.90)
	
	--Shield
	if not bActionTaken then
		-- Don't bother checking support utility if we're just hitting creeps
		bActionTaken = UseShield(botBrain, false)
	end
	
	if not bActionTaken then
		return object.attackCreepsOld(botBrain)
	end
	
	return bActionTaken
end
object.attackCreepsOld = behaviorLib.AttackCreepsBehavior["Execute"]
behaviorLib.AttackCreepsBehavior["Execute"] = AttackCreepsExecuteOverride

--------------------------------------------------------------
--                 	Pushing
--------------------------------------------------------------
function behaviorLib.customPushExecute(botBrain)
	local bSuccess = false
	
	--Shield
	bSuccess = UseShield(botBrain, true)
	
	--Extinguish
	if not bSuccess then
		-- Only deny during push if low mana
		bSuccess = UseExtinguish(botBrain, 0.40)
	end
	
	return bSuccess
end

--------------------------------------------------------------
--               	Retreat
--------------------------------------------------------------
function behaviorLib.CustomRetreatExecute(botBrain)
	local bSuccess = false
	local unitSelf = core.unitSelf
	local vecMyPosition = unitSelf:GetPosition()
	local abilNuke = skills.abilNuke
	local tLocalEnemyHeroes = core.localUnits["EnemyHeroes"]
		
	--Nuke
	if abilNuke:CanActivate() and unitSelf:GetManaPercent() > 0.70 then
		local nRange = abilNuke:GetRange()
		for nUID,unitEnemy in pairs(tLocalEnemyHeroes) do
			local vecUnitPosition = unitEnemy:GetPosition()
			local nUnitDistanceSq = Vector3.Distance2DSq(vecMyPosition, vecUnitPosition)
			local nRange = abilNuke:GetRange()
			-- If there are any nearby heroes while retreating, nuke them for the slow
			if (core.CanSeeUnit(botBrain, unitEnemy) and nUnitDistanceSq < (nRange * nRange)) then
				bSuccess = core.OrderAbilityEntity(botBrain, abilNuke, unitEnemy)
				break
			end
		end
	end
	
	--Shield
	if not bSuccess then
		-- Might as well throw up a defensive shield if we have high mana or teammates nearby
		bSuccess = UseShield(botBrain, true)
	end
	
	return bSuccess
end

--------------------------------------------------------------
--                	Return to Well
--------------------------------------------------------------
function behaviorLib.CustomReturnToWellExecute(botBrain)
	local bSuccess = false
	
	-- Extinguish on the way back to well (deny and/or restore mana so we don't have to heal)
	bSuccess = UseExtinguish(botBrain, 0.95)
	
	return bSuccess
end

BotEcho('finished loading plague_main')