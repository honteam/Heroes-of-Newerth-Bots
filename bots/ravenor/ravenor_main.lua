-------------------------------------------------------------------
-------------------------------------------------------------------
--   ____    ______  __  __  ____    __  __  _____   ____   	 --
--  /\  _`\ /\  _  \/\ \/\ \/\  _`\ /\ \/\ \/\  __`\/\  _`\ 	 --
--  \ \ \L\ \ \ \L\ \ \ \ \ \ \ \L\_\ \ `\\ \ \ \/\ \ \ \L\ \    --
--   \ \ ,  /\ \  __ \ \ \ \ \ \  _\L\ \ , ` \ \ \ \ \ \ ,  /    --
--    \ \ \\ \\ \ \/\ \ \ \_/ \ \ \L\ \ \ \`\ \ \ \_\ \ \ \\ \   --
--     \ \_\ \_\ \_\ \_\ `\___/\ \____/\ \_\ \_\ \_____\ \_\ \_\ --
--  	\/_/\/ /\/_/\/_/`\/__/  \/___/  \/_/\/_/\/_____/\/_/\/ / --
-------------------------------------------------------------------
-------------------------------------------------------------------
-- RavenorBot v1.1
-------------------------------------------------------------------

local _G = getfenv(0)
local object = _G.object

object.myName = object:GetName()

object.bRunLogic		 = true
object.bRunBehaviors	= true
object.bUpdates 		= true
object.bUseShop 		= true

object.bRunCommands 	= true 
object.bMoveCommands	 = true
object.bAttackCommands     = true
object.bAbilityCommands = true
object.bOtherCommands     = true

object.bReportBehavior = false
object.bDebugUtility = false

object.logger = {}
object.logger.bWriteLog = false
object.logger.bVerboseLog = false

object.core			= {}
object.eventsLib	 = {}
object.metadata		= {}
object.behaviorLib	 = {}
object.skills		= {}

runfile "bots/core.lua"
runfile "bots/botbraincore.lua"
runfile "bots/eventsLib.lua"
runfile "bots/metadata.lua"
runfile "bots/behaviorLib.lua"

local core, eventsLib, behaviorLib, metadata, skills = object.core, object.eventsLib, object.behaviorLib, object.metadata, object.skills

local print, ipairs, pairs, string, table, next, type, tinsert, tremove, tsort, format, tostring, tonumber, strfind, strsub
	 = _G.print, _G.ipairs, _G.pairs, _G.string, _G.table, _G.next, _G.type, _G.table.insert, _G.table.remove, _G.table.sort, _G.string.format, _G.tostring, _G.tonumber, _G.string.find, _G.string.sub
local ceil, floor, pi, tan, atan, atan2, abs, cos, sin, acos, max, min, random
	 = _G.math.ceil, _G.math.floor, _G.math.pi, _G.math.tan, _G.math.atan, _G.math.atan2, _G.math.abs, _G.math.cos, _G.math.sin, _G.math.acos, _G.math.max, _G.math.min, _G.math.random

local BotEcho, VerboseLog, BotLog = core.BotEcho, core.VerboseLog, core.BotLog
local Clamp = core.Clamp

-- hero_ < hero >  to reference the internal hon name of a hero, Hero_Ravenor == Ravenor
object.heroName = 'Hero_Ravenor'

--   item buy order. internal names  
behaviorLib.StartingItems  = {"Item_LoggersHatchet", "Item_RunesOfTheBlight", "Item_IronBuckler"}
behaviorLib.LaneItems  = {"Item_Marchers", "Item_BloodChalice", "Item_Steamboots"}
behaviorLib.MidItems  = {"Item_MysticVestments","Item_ElderParasite"} -- Item_Shield2 is Helm of the black legion, Item_MagicArmor2 is Shamans Headdress
behaviorLib.LateItems  = {"Item_PortalKey", "Item_Insanitarius", "Item_Dawnbringer", "Item_BehemothsHeart"} -- Item_Freeze is Frostwolf Skull, Item_Lightning2 is charged hammer, Item_Immunity is shrunken head

-- skillbuild table, 0 = ballLightening, 1 = stormBlades, 2 = electricalFeedback, 3 = powerOverwhelming, 4 = attri
object.tSkills = {
	0, 1, 1, 0, 1, 
	3, 1, 0, 0, 2, 
	3, 2, 2, 2, 4, 
	3, 4, 4, 4, 4, 
	4, 4, 4, 4, 4, 
}

--melee weight overrides
behaviorLib.nCreepPushbackMul = 0.5
behaviorLib.nTargetPositioningMul = 0.6

-- bonus agression points if a skill/item is available for use
object.nLightningUp = 18
object.nLightningPortUp = 30
object.nBladesUp = 25 
object.nBladesActive = 40 
object.nFeedbackUp = 12
object.nPowerMul = 0.40

-- bonus agression points that are applied to the bot upon successfully using a skill/item
object.nLightningUse = 15
object.nBladesUse = 20 
object.nFeedbackUse = 5

-- thresholds of aggression the bot must reach to use these abilities
object.nLightningThreshold = 33
object.nLightningPortThreshold = 41
object.nBladesThreshold = 38 
--raises utility, if retreat or harass above 20
object.nFeedbackThreshold = 20

--item thresholds
object.nPortalKeyThreshold = 50

------------------------------
--     skills   			--
------------------------------
local bSkillsValid = false
function object:SkillBuild()
	core.VerboseLog("skillbuild()")

	local unitSelf = self.core.unitSelf
	if not bSkillsValid then
		skills.abilLightning	= unitSelf:GetAbility(0)
		skills.abilBlades		= unitSelf:GetAbility(1)
		skills.abilFeedback		= unitSelf:GetAbility(2)
		skills.abilPower		= unitSelf:GetAbility(3)
		
		if skills.abilLightning and skills.abilBlades and skills.abilFeedback and skills.abilPower then
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
	for i = nlev, nlev + nlevpts do
		unitSelf:GetAbility( object.tSkills[i] ):LevelUp()
	end
end

----------------------------------------------
--  		  oncombatevent override		--
-- use to check for infilictors (fe. buffs) --
----------------------------------------------
object.unitBallLightningTarget = nil
object.nLastBallLighningHit = 0
function object:oncombateventOverride(EventData)
	self:oncombateventOld(EventData)
	local nAddBonus = 0
	
	if EventData.Type == "Ability" then
		if EventData.InflictorName == "Ability_Ravenor1" then
			nAddBonus = nAddBonus + object.nLightningUse
		elseif EventData.InflictorName == "Ability_Ravenor2" then
			nAddBonus = nAddBonus + object.nBladesUse
		elseif EventData.InflictorName == "Ability_Ravenor3" then
			nAddBonus = nAddBonus + object.nFeedbackUse
		end
	elseif EventData.Type == "Attack" and  EventData.InflictorName == "Projectile_Ravenor_Ability1" then
		-- Save time of impact and impact target, so we know which hero we can teleport to
		object.nLastBallLighningHit = HoN.GetGameTime()
		object.unitBallLightningTarget = EventData.TargetUnit
	end
	if nAddBonus > 0 then
		core.DecayBonus(self)
		core.nHarassBonus = core.nHarassBonus + nAddBonus
	end
end
object.oncombateventOld = object.oncombatevent
object.oncombatevent	= object.oncombateventOverride

------------------------------------------------------
--  		customharassutility override	   	 --
-- change utility according to usable spells here   --
------------------------------------------------------
local function CustomHarassUtilityOverride(hero)
	local nUtil = 0
	local unitSelf = core.unitSelf

	if skills.abilLightning:CanActivate() and skills.abilLightning:GetManaCost() > 0 then
		nUtil = nUtil + object.nLightningUp
	elseif skills.abilLightning:CanActivate() and unitSelf:HasState("State_Ravenor_Ability1") then
		nUtil = nUtil + object.nLightningPortUp
	end
	if skills.abilBlades:CanActivate() then
		nUtil = nUtil + object.nBladesUp
	elseif unitSelf:HasState("State_Ravenor_Ability2") then
		nUtil = nUtil + object.nBladesActive
	end
	if skills.abilFeedback:CanActivate() then
		nUtil = nUtil + object.nFeedbackUp
	end
	if skills.abilPower:GetLevel() > 0 then
		nUtil = nUtil + (skills.abilPower:GetCharges() * object.nPowerMul)
	end
	
	return nUtil
end
behaviorLib.CustomHarassUtility = CustomHarassUtilityOverride

--------------------------------------------------------------
--  				  Harass Behavior   					--
-- All code how to use abilities against enemies goes here  --
--------------------------------------------------------------
object.nLightningRangeBuffer = -100
local function HarassHeroExecuteOverride(botBrain)
	local unitTarget = behaviorLib.heroTarget
	local unitSelf = core.unitSelf
	if unitTarget == nil then
		return object.harassExecuteOld(botBrain)
	end
	local vecMyPosition = unitSelf:GetPosition()
	local vecTargetPosition = unitTarget:GetPosition()
	local nTargetDistanceSq = Vector3.Distance2DSq(vecMyPosition, vecTargetPosition)
	local bTargetRooted = unitTarget:IsStunned() or unitTarget:IsImmobilized() or unitTarget:GetMoveSpeed() < 200
	local nAttackRangeSq = core.GetAbsoluteAttackRangeToUnit(unitSelf, unitTarget, true)
	local nLastHarassUtility = behaviorLib.lastHarassUtil 
	local bActionTaken = false
		
	--Ensure we can still see the target for entity targeting
	if core.CanSeeUnit(botBrain, unitTarget) then
	
		--Portal Key
		local itemPortalKey = core.GetItem("Item_PortalKey")
		if itemPortalKey then
			local nPortalKeyRange = itemPortalKey:GetRange()
			if itemPortalKey:CanActivate() and nLastHarassUtility > object.nPortalKeyThreshold then
				if nTargetDistanceSq > (300*300) and nTargetDistanceSq < (nPortalKeyRange * nPortalKeyRange) then
					bActionTaken = core.OrderItemPosition(botBrain, unitSelf, itemPortalKey, vecTargetPosition)
				end
			end
		end
	
		-- Ball Lightning
		if not bActionTaken and not bTargetRooted and nLastHarassUtility > botBrain.nLightningThreshold and not unitTarget:isMagicImmune() then
			local abilLightning = skills.abilLightning
			if abilLightning:CanActivate() then
				local bCanTeleport = (abilLightning:GetManaCost() == 0) and unitSelf:HasState("State_Ravenor_Ability1")
				if not bCanTeleport and unitSelf:GetLevel() > 1 then
					local nRange = 1400 + botBrain.nLightningRangeBuffer
					if nTargetDistanceSq < (nRange * nRange) then
						bActionTaken = core.OrderAbilityPosition(botBrain, abilLightning, vecTargetPosition)
					end
				end
			end
		end
	end

	-- Blades
	if not bActionTaken and nLastHarassUtility > botBrain.nBladesThreshold and not unitTarget:isMagicImmune() then
		local abilBlades = skills.abilBlades
		if abilBlades:CanActivate() and nTargetDistanceSq < nAttackRangeSq then
			-- only activate if we are close to the target
			bActionTaken = core.OrderAbility(botBrain, abilBlades) --no clamp means that we can perform more actions in 50ms time.
		end
	end
	
	if not bActionTaken then
		return object.harassExecuteOld(botBrain)
	end 
end
object.harassExecuteOld = behaviorLib.HarassHeroBehavior["Execute"]
behaviorLib.HarassHeroBehavior["Execute"] = HarassHeroExecuteOverride

----------------------------------------------------
-- ELECTRIC FEEDBACK (E)
----------------------------------------------------
function behaviorLib.ElectricFeecbackUtilityFn(botBrain)
	local nLastSecondHeroDamage = eventsLib.recentHeroDamageSec
	local nUtil = max(behaviorLib.lastRetreatUtil, behaviorLib.lastHarassUtil)
	if nUtil > botBrain.nFeedbackThreshold and skills.abilFeedback:CanActivate() and nLastSecondHeroDamage > 0 then
		-- Base returned value on lastRetreatUtil and lastHarassUtil since we want to be higher
		nUtil = nUtil + 10
	end
	
	return nUtil
end

function behaviorLib.ElectricFeecbackExecuteFn(botBrain)
	local bActionTaken = false

	local abilFeedback = skills.abilFeedback
	if abilFeedback:CanActivate() then
		bActionTaken = core.OrderAbility(botBrain, abilFeedback)
	end

	return bActionTaken
end
behaviorLib.FeedbackBehavior = {}
behaviorLib.FeedbackBehavior["Utility"] = behaviorLib.ElectricFeecbackUtilityFn
behaviorLib.FeedbackBehavior["Execute"] = behaviorLib.ElectricFeecbackExecuteFn
behaviorLib.FeedbackBehavior["Name"] = "Feedback"
tinsert(behaviorLib.tBehaviors, behaviorLib.FeedbackBehavior)

----------------------------------------------------
--	BALL LIGHTENING TELEPORT (W)
----------------------------------------------------
object.nBallLightningDuration = 4000
function behaviorLib.BallLightningTeleportUtility(botBrain)
	if object.nLastBallLighningHit + object.nBallLightningDuration > HoN.GetGameTime() then
		local unitTarget = object.unitBallLightningTarget
		local unitSelf = core.unitSelf

		if unitTarget then
			local vecMyPosition = unitSelf:GetPosition() 
			local vecTargetPosition = unitTarget:GetPosition()
			local nTargetDistanceSq = vecTargetPosition and Vector3.Distance2DSq(vecMyPosition, vecTargetPosition) or 360000 --just a high number
			local nAttackRangeSq = core.GetAbsoluteAttackRangeToUnit(unitSelf, unitTarget, true)
	
			local nMoveSpeed = unitTarget:GetMoveSpeed() or 350
			local bTargetRooted = unitTarget:IsStunned() or unitTarget:IsImmobilized() or nMoveSpeed < 200

			local nLastHarassUtility = behaviorLib.lastHarassUtil

			if unitTarget:HasState("State_Enemy_Ravenor_Ability1") and nLastHarassUtility >= object.nLightningPortThreshold then
				-- We're either out of range, or the target is not stunned
				if (nTargetDistanceSq > nAttackRangeSq) or (nTargetDistanceSq <= nAttackRangeSq and not bTargetRooted) then
					return nLastHarassUtility + object.nLightningPortUp
				-- Out port chance is about to expire, so we want to use port to get the extra damage
				elseif HoN.GetGameTime() > object.nLastBallLighningHit + object.nBallLightningDuration - 500 then
					return nLastHarassUtility
				else
					return 0
				end
			end
		end
	end
	return 0
end

function behaviorLib.BallLightningTeleportExecute(botBrain)
	local unitTarget = object.unitBallLightningTarget
	local unitSelf = core.unitSelf

	local bActionTaken = false

	if unitSelf:HasState("State_Ravenor_Ability1") and unitTarget:HasState("State_Enemy_Ravenor_Ability1") then
		local abilLightning = skills.abilLightning
		if abilLightning:CanActivate() and abilLightning:GetManaCost() <= 0 then
			--BotEcho("Teleporting to Target")
			bActionTaken = core.OrderAbility(botBrain, abilLightning)
		end
	end

	return bActionTaken
end
behaviorLib.TeleportBehavior = {}
behaviorLib.TeleportBehavior["Utility"] = behaviorLib.BallLightningTeleportUtility
behaviorLib.TeleportBehavior["Execute"] = behaviorLib.BallLightningTeleportExecute
behaviorLib.TeleportBehavior["Name"] = "Teleport"
tinsert(behaviorLib.tBehaviors, behaviorLib.TeleportBehavior)

----------------------------------------------------
--	PUSHING
----------------------------------------------------
-- Use Lightning blades while pushing if we have enough mana
function behaviorLib.customPushExecute(botBrain) --this had much more to it, which I removed.
	local unitSelf = core.unitSelf
	if unitSelf:IsChanneling() then 
		return
	end
	local unitTarget = core.unitEnemyCreepTarget
	if unitTarget then
		local abilBlades = skills.abilBlades
		local abilLightning = skills.abilLightning
		-- Be conservative with mana, so we can cast our combo afterwards
		if  abilBlades:CanActivate() and unitSelf:GetMana() > (abilBlades:GetManaCost() * 2 + abilLightning:GetManaCost()) then 
			return core.OrderAbility(botBrain, abilBlades)
		end
	end
	return false
end

--[[for testing
runfile "bots/miscTestCode.lua"
function object:onthinkOverride(tGameVariables)
	self:onthinkOld(tGameVariables)
	
	core.unitSelf:TeamShare()
	
	core.DrawXPosition(core.unitSelf:GetPosition(), "teal", 150)

	if self.testDisplayAllNodes == nil then
		Echo("derp")
	else
		self.testDisplayAllNodes()
	end
end
object.onthinkOld = object.onthink
object.onthink 	= object.onthinkOverride
--]]




