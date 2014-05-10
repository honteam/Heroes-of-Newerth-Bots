----------------------------------------------------------------------
----------------------------------------------------------------------
--   ____    _	     _____   _____   _____     ____    ________  -----
--  |    \  | |	    /	  \ /     \ |	  \   /	   \  |  _  _  | -----
--  | Ѻ _|  | |___  |  Ѻ  | |  Ѻ  | |  ѻ__/  |   _  | |__    __| -----
--  |   \   |  _  \ |  _  | |  ___/ 3      \ |  (Ѻ) |    |  |    -----
--  | |\ \  | |	| | | | | | | |     |  Ѻ   | |	 ¯  |    |  |	 -----
--  |_| \_\ |_| |_| |_| |_| |_,     |______,  \____,     |__|	 -----
----------------------------------------------------------------------
----------------------------------------------------------------------
-- Rhapbot v1.1 

-- By community member fane_maciuca

--[[ Change Log: 
(v1.1)	Changed the call to GroupCenter to use the faster, engine-side call
--]]

-- Note from fane_maciuca:
-- I have a new respect for ASCII artists (a damn pain do the header here)
-- Special thanks to: Zerotorescue, spennerino, fahna, etc , etc
-- BIG thanks to Stolen_ID for being an integral part of rhapbot's birth
-- And great big bags of beer to [s2]malloc for being awesome

--####################################################################
--####################################################################
--#                                                                 ##
--#                       Bot Initiation                            ##
--#                                                                 ##
--####################################################################
--####################################################################


local _G = getfenv(0)
local object = _G.object

object.myName = object:GetName()

object.bRunLogic        = true
object.bRunBehaviors    = true
object.bUpdates         = true
object.bUseShop         = true

object.bRunCommands     = true 
object.bMoveCommands    = true
object.bAttackCommands  = true
object.bAbilityCommands = true
object.bOtherCommands   = true

object.bReportBehavior = false
object.bDebugUtility   = false
object.bDebugExecute = false


object.logger = {}
object.logger.bWriteLog   = false
object.logger.bVerboseLog = false

object.core          = {}
object.eventsLib     = {}
object.metadata      = {}
object.behaviorLib   = {}
object.skills        = {}

--runfile "bots/Libraries/LibWarding/LibWarding.lua"
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


BotEcho(' loading rhapsody_main...')

--------------------------------
-- Lanes
--------------------------------
core.tLanePreferences = {Jungle = 0, Mid = 3, ShortSolo = 2, LongSolo = 1, ShortSupport = 5, LongSupport = 4, ShortCarry = 3, LongCarry = 2}

--[[for testing
function object:onthinkOverride(tGameVariables)
	self:onthinkOld(tGameVariables)
	
	core.unitSelf:TeamShare()
	
	-- Insert code here
end
object.onthinkOld = object.onthink
object.onthink 	= object.onthinkOverride
--]]


--####################################################################
--####################################################################
--#                                                                 ##
--#                  bot constant definitions                       ##
--#                                                                 ##
--####################################################################
--####################################################################

object.heroName = 'Hero_Rhapsody'


--   item buy order. this uses internal names  
behaviorLib.StartingItems  = {"Item_MinorTotem", "Item_HealthPotion", "Item_RunesOfTheBlight", "Item_PretendersCrown"}
behaviorLib.LaneItems  = {"Item_Marchers", "Item_Striders", "Item_Astrolabe"}
behaviorLib.MidItems  = {"Item_Immunity" }
behaviorLib.LateItems  = {"Item_BehemothsHeart", "Item_Damage9"}


-- skillbuild table, 0=q, 1=w, 2=e, 3=r, 4=attributeBoost
object.tSkills = {
	0, 1, 0, 1, 0, 
	3, 0, 1, 1, 2, 
	2, 2, 2, 3, 4, 
	3, 4, 4, 4, 4, 
	4, 4, 4, 4, 4
}

-- These are bonus agression points if a skill/item is available for use
object.nStaccatoUp = 12
object.nDanceInfernoUp = 8


-- These are bonus agression points that are applied to the bot upon successfully using a skill/item
object.nStaccatoUse = 13
object.nDanceInfernoUse = 10

--These are thresholds of aggression the bot must reach to use these abilities
object.nStaccatoThreshold = 47
object.nDanceInfernoThreshold = 54

--Other constants used through the code
object.nStaccatoTime = 0				--used for staccato timings / stagger
object.nStaccatoChargeThreshold = 250	--the stagger interval in ms
object.nRetreatStunThreshold = 43		--used for the defensive stunning

--####################################################################
--####################################################################
--#                                                                 ##
--#   bot function overrides                                        ##
--#                                                                 ##
--####################################################################
--####################################################################

------------------------------
--     skills               --
------------------------------

function object:SkillBuild()
	local unitSelf = self.core.unitSelf
	if  skills.abilStaccato == nil then
		skills.abilStaccato = unitSelf:GetAbility(0)
		skills.abilDanceInferno = unitSelf:GetAbility(1)
		skills.abilHymn = unitSelf:GetAbility(2)
		skills.abilProtectiveMelody = unitSelf:GetAbility(3)
		skills.abilAttributeBoost = unitSelf:GetAbility(4)
	end
	
	local nPoints = unitSelf:GetAbilityPointsAvailable()
	if nPoints <= 0 then
		return
	end
	
	local nLevel = unitSelf:GetLevel()
	for i = nLevel, (nLevel + nPoints) do
		unitSelf:GetAbility( self.tSkills[i] ):LevelUp()
	end
end

----------------------------------------------
--          oncombatevent override          --
-- use to check for infilictors (fe. buffs) --
----------------------------------------------
function object:oncombateventOverride(EventData)
	self:oncombateventOld(EventData)
 
	local nAddBonus = 0
 
	if EventData.Type == "Ability" then
		if EventData.InflictorName == "Ability_Rhapsody1" then
			nAddBonus = nAddBonus + object.nStaccatoUse
		elseif EventData.InflictorName == "Ability_Rhapsody2" then
			nAddBonus = nAddBonus + object.nDanceInfernoUse
		end
	end
 
   if nAddBonus > 0 then
		core.DecayBonus(self)
		core.nHarassBonus = core.nHarassBonus + nAddBonus
	end
	--BotEcho(nAddBonus..' naddbonus')
end
-- override combat event trigger function.
object.oncombateventOld = object.oncombatevent
object.oncombatevent    = object.oncombateventOverride

------------------------------------------------------
--            customharassutility override          --
-- change utility according to usable spells here   --
------------------------------------------------------
local function CustomHarassUtilityFnOverride(hero)
   local nUtility = 0
	 
	if skills.abilStaccato:CanActivate() then
		nUtility = nUtility + object.nStaccatoUp
	end
 
	if skills.abilDanceInferno:CanActivate() then
		nUtility = nUtility + object.nDanceInfernoUp
	end
 --BotEcho(nUtil..' nutil')
	return nUtility
end
-- assisgn custom Harrass function to the behaviourLib object
behaviorLib.CustomHarassUtility = CustomHarassUtilityFnOverride   

--------------------------------------------------------------
--                    Harass Behavior                       --
--                                                          --
--------------------------------------------------------------
local function HarassHeroExecuteOverride(botBrain)
	
	local unitTarget = behaviorLib.heroTarget
	if unitTarget == nil or not unitTarget:IsValid() then
		return false --Target is invalid, move on to the next behavior
	end
	
	if core.unitSelf:IsChanneling() then
		--dooo it, the ultimate is called someplace else, but this is 
		--here in case behaviors change during channel time for some reason
		return true
	end
	
	local unitSelf = core.unitSelf
	local vecMyPosition = unitSelf:GetPosition() 
	local nAttackRange = core.GetAbsoluteAttackRangeToUnit(unitSelf, unitTarget)
	local nMyExtraRange = core.GetExtraRange(unitSelf)
	
	local vecTargetPosition = unitTarget:GetPosition()
	local nTargetExtraRange = core.GetExtraRange(unitTarget)
	local nTargetDistanceSq = Vector3.Distance2DSq(vecMyPosition, vecTargetPosition)
	
	local nLastHarassUtility = behaviorLib.lastHarassUtil
	local bCanSee = core.CanSeeUnit(botBrain, unitTarget)	
	local bActionTaken = false
	local bTargetVuln = unitTarget:IsStunned() or unitTarget:IsImmobilized()

   
	local abilStun = skills.abilStaccato
	local abilDance = skills.abilDanceInferno
	
	--BotEcho (nLastHarassUtility..' lastharassutil')
	----------------------------------------------------- Staccato / Stun
	if core.CanSeeUnit(botBrain, unitTarget) then
		if not bActionTaken then
			if abilStun:CanActivate() and nLastHarassUtility > botBrain.nStaccatoThreshold and not unitSelf:HasState("State_Rhapsody_Ability1_Self") then
				-- state_rhapsody_ability1_self means that rhapsody has staccato charges
				local nRange = abilStun:GetRange()								
				if nTargetDistanceSq < (nRange * nRange) then
					bActionTaken = core.OrderAbilityEntity(botBrain, abilStun, unitTarget)
					object.nStaccatoTime = HoN.GetGameTime() --the moment in the game that rhapsody used the orginal stun (used for staccato stagger)
				else
					bActionTaken = core.OrderMoveToUnitClamp(botBrain, unitSelf, unitTarget)
				end
			end
		end 
	end 
	----------------------------------------------------- Dance dance 
	if not bActionTaken then
		if abilDance:CanActivate() and unitTarget:GetHealthPercent() > 0.1 then --not gonna use this on a sure kill, won't waste
			if nLastHarassUtility > botBrain.nDanceInfernoThreshold or bTargetVuln then --hey malloc would this if statement just override the dance threshold if i add bTargetVuln ?
				local nRange = abilDance:GetRange()										--just delete if you deem necesarry, same with this comment
				if nTargetDistanceSq < (nRange * nRange) then
					bActionTaken = core.OrderAbilityPosition(botBrain, abilDance, vecTargetPosition)
				end
			end
		end
	end
	----------------------------------------------------- Staccato charges stagger
	if not bActionTaken then
		if unitSelf:HasState("State_Rhapsody_Ability1_Self") and not bTargetVuln then --to avoid stacking stuns
			local nCurTime = HoN.GetGameTime()
			if nCurTime - object.nStaccatoTime >= object.nStaccatoChargeThreshold then --if current time 250ms after last stun, do another stun!
				core.OrderAbility(botBrain, abilStun)
				object.nStaccatoTime = nCurTime
			end
		end  	  
	end
	
	
	if not bActionTaken then
		return object.harassExecuteOld(botBrain)
	end 
end
object.harassExecuteOld = behaviorLib.HarassHeroBehavior["Execute"]
behaviorLib.HarassHeroBehavior["Execute"] = HarassHeroExecuteOverride

--------------------------------------------------------------
--                RetreatFromThreat Override                --
--               --Use staccato defensively--               --
--------------------------------------------------------------
--Unfortunately this utility is kind of volatile, so we basically have to deal with util spikes
function funcRetreatFromThreatExecuteOverride(botBrain)
	local bDebugEchos = false
	
	local bActionTaken = false
	local unitSelf = core.unitSelf
	local abilStun = skills.abilStaccato

	--BotEcho("Checkin defensive Stun")
	if not bActionTaken then
		--Stun use		
		if abilStun:CanActivate() and not unitSelf:HasState("State_Rhapsody_Ability1_Self") then
			--BotEcho("CanActivate!  nRetreatUtil: "..behaviorLib.lastRetreatUtil.."  thresh: "..object.nRetreatStunThreshold)
			local tTargets = core.localUnits["EnemyHeroes"]
			if behaviorLib.lastRetreatUtil >= object.nRetreatStunThreshold and tTargets then
				local vecMyPosition = unitSelf:GetPosition() 
				local nRange = abilStun:GetRange()					
				for key, hero in pairs(tTargets) do
					local heroPos = hero:GetPosition()
					local nTargetDistanceSq = Vector3.Distance2DSq(vecMyPosition, heroPos)
					if nTargetDistanceSq < (nRange * nRange) then
						-- will only attempt to stun if he is in range, no turning back!
						bActionTaken = core.OrderAbilityEntity(botBrain, abilStun, hero) 
						object.nStaccatoTime = HoN.GetGameTime()
					end
				end
			end
		end
	end
	
	--Staccato charges stagger
	if not bActionTaken then
		if unitSelf:HasState("State_Rhapsody_Ability1_Self") and not bTargetVuln then 
			local nCurTime = HoN.GetGameTime()
			if nCurTime - object.nStaccatoTime >= object.nStaccatoChargeThreshold then 
				--if current time X ms after last stun, do another stun!
				core.OrderAbility(botBrain, abilStun)
				object.nStaccatoTime = nCurTime
			end
		end  	  
	end
	

	if not bActionTaken then
		return object.RetreatFromThreatExecuteOld(botBrain)
	end
end
object.RetreatFromThreatExecuteOld = behaviorLib.RetreatFromThreatExecute
behaviorLib.RetreatFromThreatBehavior["Execute"] = funcRetreatFromThreatExecuteOverride


--------------------------------------------------------------
--                   		Pushing		                    --
--    needed to make rhapbot use dance inferno on pushes    --
--------------------------------------------------------------
function behaviorLib.customPushExecute(botBrain)
	local bSuccess = false
	local abilDance = skills.abilDanceInferno
	local unitSelf = core.unitSelf
	local nMinimumCreeps = 3

	local vecCreepCenter, nCreeps = core.GetGroupCenter(core.localUnits["EnemyCreeps"])
	
	if vecCreepCenter == nil or nCreeps == nil or nCreeps < nMinimumCreeps then 
		return false
	end
	
	--don't use dance inferno if it gets our mana too low
	if abilDance:CanActivate() and vecCreepCenter and unitSelf:GetManaPercent() > 0.20 then 
		bSuccess = core.OrderAbilityPosition(botBrain, abilDance, vecCreepCenter)
	end
	
	return bSuccess
end


--####################################################################
--####################################################################
--#                                                                 ##
--#   bot added behaviors                                           ##
--#                                                                 ##
--####################################################################
--####################################################################
------------------------------------------------------------
--	Rhapsody Help behavior
--	
--	Execute: Use Protective Melody
--  The following few functions are a necesary 
--  copy pasta from GlaciusBot(with adaptaions for rhapsody's skills, ofc)
------------------------------------------------------------
behaviorLib.nHealUtilityMul = 0.8
behaviorLib.nHealHealthUtilityMul = 1.0
behaviorLib.nHealTimeToLiveUtilityMul = 0.5
-------------------------------------Ultimate Execution 
-------------------------------------Rhapsody's ult can be activated for just 1 teammate
-------------------------------------but she will attemt to move to center of group before popping
-------------------------------------Also pops Shrunken, if available
function ProtectiveMelodyExecute(botBrain)
	local unitSelf = core.unitSelf
	local tTargets = core.CopyTable(core.localUnits["AllyHeroes"])
	local nMyID    = unitSelf:GetUniqueID()
	tTargets[nMyID] = nil
	
	local vecAlliesCenter = core.GetGroupCenter(tTargets)
	local vecMyPosition = unitSelf:GetPosition()
	local abilUlt = skills.abilProtectiveMelody

	if vecAlliesCenter ~= nil then
		local nTargetDistanceSq = Vector3.Distance2DSq(vecMyPosition, vecAlliesCenter)
					
		local nRadius = abilUlt:GetTargetRadius()
		local nHalfRadiusSq = nRadius * nRadius * 0.25
		if nTargetDistanceSq <= nHalfRadiusSq then
			local itemShrunkenHead = core.GetItem("Item_Immunity")
			if itemShrunkenHead and itemShrunkenHead:CanActivate() then		--see if Shrunken can pop, then pop it
				local bSuccess = core.OrderItemClamp(botBrain, unitSelf, itemShrunkenHead)
				if bSuccess then
					return
				end
			end
			core.OrderAbility(botBrain, abilUlt)		
		else 
			core.OrderMoveToPosClamp(botBrain, unitSelf, vecAlliesCenter)
		end
	else
		return false
	end
end
tinsert(behaviorLib.tDontUseDefaultItemBehavior, "Item_Immunity")


function object.GetUltimateTimeToLiveThreshold () 
-- todo: modify according to ult level? 
-- trial and error convinced me not to do so
	return 4
end

function behaviorLib.HealHealthUtilityFn(unitHerox)
	local nUtility = 0
	
	local nYIntercept = 100
	local nXIntercept = 100
	local nOrder = 2

	nUtility = core.ExpDecay(unitHerox:GetHealthPercent() * 100, nYIntercept, nXIntercept, nOrder)
	
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
	
	if bDebugEchos then BotEcho("HealUtility") end
	
	local nUtility = 0

	local unitSelf = core.unitSelf
	behaviorLib.unitHealTarget = nil
	
	local abilMelody = skills.abilProtectiveMelody
	local nUltimateTTL = object.GetUltimateTimeToLiveThreshold() 
	
	local nHighestUtility = 0
	local unitTarget = nil
	local nTargetTimeToLive = nil
	local sAbilName = ""
	
	if abilMelody:CanActivate() then
		local tTargets = core.CopyTable(core.localUnits["AllyHeroes"])
		tTargets[unitSelf:GetUniqueID()] = unitSelf --I am also a target
		local nMyID = unitSelf:GetUniqueID()
		for key, hero in pairs(tTargets) do
			--Don't heal yourself if we are going to head back to the well anyway, 
			--	as it could cause us to retrace half a walkback
			if hero:GetUniqueID() ~= nMyID or core.GetCurrentBehaviorName(botBrain) ~= "HealAtWell" then
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
			if abilMelody:CanActivate() and unitTarget:GetUniqueID() ~= nMyID and nTargetTimeToLive <= nUltimateTTL then
				local nCostBonus = behaviorLib.AbilityCostBonusFn(unitSelf, abilMelody)
				nUtility = nHighestUtility + nCostBonus
				sAbilName = "Protective Melody"
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

function behaviorLib.HealExecute(botBrain) -- this is used for Ultimate triggering
	local abilMelody = skills.abilProtectiveMelody
	
	local nUltimateTTL = object.GetUltimateTimeToLiveThreshold () 
	local unitHealTarget = behaviorLib.unitHealTarget
	local nHealTimeToLive = behaviorLib.nHealTimeToLive
	local unitSelf = core.unitSelf
	
	if unitSelf:IsChanneling() then
		--nothing to see here, just passing through
		return
	end
	
	--Priority order is Ultimate
	if unitHealTarget then 
		if nHealTimeToLive <= nUltimateTTL and abilMelody:CanActivate() and unitHealTarget ~= unitSelf  then  --only attempt ult for other players (not for self, lol)
			ProtectiveMelodyExecute(botBrain)
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

--####################################################################
--####################################################################
--#                                                                 ##
--#   CHAT FUNCTIONSS                                               ##
--#                                                                 ##
--####################################################################
--####################################################################

object.tCustomKillKeys = {
	"fane_maciuca_rhapsody_kill1",
	"fane_maciuca_rhapsody_kill2",
	"fane_maciuca_rhapsody_kill3",
	"fane_maciuca_rhapsody_kill4",
	"fane_maciuca_rhapsody_kill5",
	"fane_maciuca_rhapsody_kill6",
	"fane_maciuca_rhapsody_kill7"	}

local function GetKillKeysOverride(unitTarget)
	local tChatKeys = object.funcGetKillKeysOld(unitTarget)
	core.InsertToTable(tChatKeys, object.tCustomKillKeys)
	return tChatKeys
end
object.funcGetKillKeysOld = core.GetKillKeys
core.GetKillKeys = GetKillKeysOverride


object.tCustomRespawnKeys = {
	"fane_maciuca_rhapsody_respawn1",
	"fane_maciuca_rhapsody_respawn2",
	"fane_maciuca_rhapsody_respawn3",
	"fane_maciuca_rhapsody_respawn4",
	"fane_maciuca_rhapsody_respawn5"	}

local function GetRespawnKeysOverride()
	local tChatKeys = object.funcGetRespawnKeysOld()
	core.InsertToTable(tChatKeys, object.tCustomRespawnKeys)
	return tChatKeys
end
object.funcGetRespawnKeysOld = core.GetRespawnKeys
core.GetRespawnKeys = GetRespawnKeysOverride


object.tCustomDeathKeys = {
	"fane_maciuca_rhapsody_death1",
	"fane_maciuca_rhapsody_death2",
	"fane_maciuca_rhapsody_death3",
	"fane_maciuca_rhapsody_death4",
	"fane_maciuca_rhapsody_death5",
	"fane_maciuca_rhapsody_death6"	}
	
local function GetDeathKeysOverride(unitSource)
	local tChatKeys = object.funcGetDeathKeysOld(unitSource)
	core.InsertToTable(tChatKeys, object.tCustomDeathKeys)
	return tChatKeys
end
object.funcGetDeathKeysOld = core.GetDeathKeys
core.GetDeathKeys = GetDeathKeysOverride


BotEcho ('success')