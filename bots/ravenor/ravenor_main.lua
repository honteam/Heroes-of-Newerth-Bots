-------------------------------------------------------------------
-------------------------------------------------------------------
--   ____    ______  __  __  ____    __  __  _____   ____        --
--  /\  _`\ /\  _  \/\ \/\ \/\  _`\ /\ \/\ \/\  __`\/\  _`\      --
--  \ \ \L\ \ \ \L\ \ \ \ \ \ \ \L\_\ \ `\\ \ \ \/\ \ \ \L\ \    --
--   \ \ ,  /\ \  __ \ \ \ \ \ \  _\L\ \ , ` \ \ \ \ \ \ ,  /    --
--    \ \ \\ \\ \ \/\ \ \ \_/ \ \ \L\ \ \ \`\ \ \ \_\ \ \ \\ \   --
--     \ \_\ \_\ \_\ \_\ `\___/\ \____/\ \_\ \_\ \_____\ \_\ \_\ --
--      \/_/\/ /\/_/\/_/`\/__/  \/___/  \/_/\/_/\/_____/\/_/\/ / --
-------------------------------------------------------------------
-------------------------------------------------------------------
-- RavenorBot v1.1
-- based on Skelbot v0.0000008
--

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
local ceil, floor, pi, tan, atan, atan2, abs, cos, sin, acos, max, min, random
	= _G.math.ceil, _G.math.floor, _G.math.pi, _G.math.tan, _G.math.atan, _G.math.atan2, _G.math.abs, _G.math.cos, _G.math.sin, _G.math.acos, _G.math.max, _G.math.min, _G.math.random

local BotEcho, VerboseLog, BotLog = core.BotEcho, core.VerboseLog, core.BotLog
local Clamp = core.Clamp

local ravenor = {}


BotEcho(object:GetName()..' RavenorBor is starting up ...')




--####################################################################
--####################################################################
--#                                                                 ##
--#                  bot constant definitions                       ##
--#                                                                 ##
--####################################################################
--####################################################################

-- hero_<hero>  to reference the internal hon name of a hero, Hero_Yogi ==wildsoul
object.heroName = 'Hero_Ravenor'


--   item buy order. internal names  
behaviorLib.StartingItems  = {"Item_LoggersHatchet", "Item_RunesOfTheBlight", "Item_IronBuckler"}
behaviorLib.LaneItems  = {"Item_Marchers", "Item_BloodChalice", "Item_Lifetube"}
behaviorLib.MidItems  = {"Item_Steamboots", "Item_Shield2", "Item_MagicArmor2"} -- Item_Shield2 is Helm of the black legion, Item_LifeSteal5 is Abyssal Skull, Item_MagicArmor2 is Shamans Headdress
behaviorLib.LateItems  = {"Item_Immunity", "Item_Freeze", "Item_Lightning2"} -- Item_Freeze is Frostwolf Skull


-- skillbuild table, 0=q, 1=w, 2=e, 3=r, 4=attri
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
object.nImmunityUse = 12
object.nChargedUse = 10

-- thresholds of aggression the bot must reach to use these abilities

object.nLightningThreshold = 33
object.nLightningPortThreshold = 41
object.nBladesThreshold = 38 
object.nFeedbackThreshold = 20


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
-- @param: none
-- @return: none
function object:SkillBuild()
	core.VerboseLog("skillbuild()")

-- takes care at load/reload, <name_#> to be replaced by some convinient name.
	local unitSelf = self.core.unitSelf
	if  skills.abilLightning == nil then
		skills.abilLightning = unitSelf:GetAbility(0)
		skills.abilBlades = unitSelf:GetAbility(1)
		skills.abilFeedback = unitSelf:GetAbility(2)
		skills.abilPower = unitSelf:GetAbility(3)
		skills.abilAttributeBoost = unitSelf:GetAbility(4)
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

------------------------------------------------------
--            onthink override                      --
-- Called every bot tick, custom onthink code here  --
------------------------------------------------------
-- @param: tGameVariables
-- @return: none
function object:onthinkOverride(tGameVariables)
	self:onthinkOld(tGameVariables)

	-- custom code here
end
object.onthinkOld = object.onthink
object.onthink 	= object.onthinkOverride

object.unitBallLightningTarget = nil
object.nLastBallLighningHit = 0
object.nBallLightningDuration = 4000

----------------------------------------------
--            oncombatevent override        --
-- use to check for infilictors (fe. buffs) --
----------------------------------------------
-- @param: eventdata
-- @return: none
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
	elseif EventData.Type == "Attack" then
		if EventData.InflictorName == "Projectile_Ravenor_Ability1" then
			-- Save time of impact and impact target, so we know which hero we can teleport to
			object.nLastBallLighningHit = HoN.GetGameTime()
			object.unitBallLightningTarget = EventData.TargetUnit
		end
	elseif EventData.Type == "Item" then
		core.FindItems()
        if core.itemImmunity ~= nil and EventData.SourceUnit == core.unitSelf:GetUniqueID() and EventData.InflictorName == core.itemImmunity:GetName() then
            nAddBonus = nAddBonus + self.nImmunityUse
		end
		if core.itemChargedHammer ~= nil and EventData.SourceUnit == core.unitSelf:GetUniqueID() and EventData.InflictorName == core.itemChargedHammer:GetName() then
			addBonus = addBonus + self.nChargedUse
	    end
	end
 
	if nAddBonus > 0 then
		-- BotEcho ("Total nAddBonus = ".. nAddBonus) 
		core.DecayBonus(self)
		core.nHarassBonus = core.nHarassBonus + nAddBonus
	end
end
-- override combat event trigger function.
object.oncombateventOld = object.oncombatevent
object.oncombatevent     = object.oncombateventOverride

------------------------------------------------------
--            calculate utility Values              --
-- change utility according to usable spells here   --
------------------------------------------------------
-- @tparam IUnitEntity hero
-- @treturn number
local function AbilitiesUpUtilityFn(hero)
	local bDebugEchos = false
	
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
	
	if bDebugEchos then BotEcho(" HARASS - abilitiesUp: "..nUtil) end
	
	return nUtil
end

object.tPosition = {}
object.nPositionRefreshInterval = 200

------------------------------------------------------
--            EnemyToAllyRatioUtility               --
--   supposed to determine if we want to teleport   --
--        to a target hero. Currently unused        --
------------------------------------------------------
-- @tparam IUnitEntity target
-- @treturn number
local function EnemyToAllyRatioUtility(unitTarget)
	-- only update the heroes in the target area on an interval, so we dont spam this
	local nLastUpdate = 0
	if object.tPosition[unitTarget] ~= nil then 
		nLastUpdate = object.tPosition[unitTarget].nNextPositionRefresh 
	else 
		object.tPosition[unitTarget] = {}
		nLastUpdate = 0 
	end

	if nLastUpdate < HoN.GetGameTime() then
		local unitSelf = core.unitSelf
		local vecCenter = unitTarget:GetPosition()
		local nRadius = 800
		local nMask = core.UNIT_MASK_ALIVE + core.UNIT_MASK_HERO
		local tHeroes = HoN.GetUnitsInRadius(vecCenter, nRadius, nMask)

		local nEnemyHeroes = 0
		local nAllyHeroes = 0

		for k,hero in pairs(tHeroes) do
			if hero:GetUniqueID() == unitSelf:GetUniqueID() then BotEcho("Target is current Hero: "..unitSelf:GetUniqueID()) end
			if hero:GetTeam() == unitSelf:GetTeam() then
				nAllyHeroes = nAllyHeroes + 1
			else
				nEnemyHeroes = nEnemyHeroes + 1
			end
		end

		object.tPosition[unitTarget].nEnemyHeroes = nEnemyHeroes
		object.tPosition[unitTarget].nAllyHeroes = nAllyHeroes
		object.tPosition[unitTarget].nNextPositionRefresh = HoN.GetGameTime() + object.nPositionRefreshInterval
	end

	local tPosition = object.tPosition[unitTarget]
	local nEnemyHeroes = tPosition.nEnemyHeroes
	local nAllyHeroes = tPosition.nAllyHeroes
	local nUtil = 10 + (5 * nAllyHeroes - 5 * nEnemyHeroes)
	BotEcho("Last EnemyToAllyRatioUtility: "..nUtil)
	return nUtil
end

------------------------------------------------------
--            ShouldUseBallLightning                --
-- determines if we want to use ball lighning       --
-- currently only checks if we're atleast level 2   --
-- more advanced checks to come                     --
------------------------------------------------------
local function ShouldUseBallLightning(botBrain, unitTarget, unitSelf)
	-- body
	--[[local nManaSelf = unitSelf:GetMana()
	local nTargetHealth = unitTarget:GetHealth()

	local vecMyPosition = unitSelf:GetPosition()
	local vecTargetPosition = unitTarget:GetPosition()
	local nAttackRangeSq = core.GetAbsoluteAttackRangeToUnit(unitSelf, unitTarget, true)
	local nTargetDistanceSq = Vector3.Distance2DSq(vecMyPosition, vecTargetPosition)
	local nPotentialTotalDamage = CalcPotentialDamage(unitTarget)
	]]--

	local abilLightning = skills.abilLightning
	local abilBlades = skills.abilBlades

	local bShouldUseBallLightning = false

	if unitSelf:GetLevel() > 1 then
		-- we dont want to use the spell when we're level 1
		bShouldUseBallLightning = true
	end

	return bShouldUseBallLightning
end

------------------------------------------------------
--            customharassutility override          --
-- change utility according to usable spells here   --
------------------------------------------------------
-- @tparam IUnitEntity hero
-- @treturn number
local function CustomHarassUtilityOverride(hero)
	local nUtility = AbilitiesUpUtilityFn(hero)
	--return 0
	return nUtility
end
behaviorLib.CustomHarassUtility = CustomHarassUtilityOverride     

--------------------------------------------------------------
--                    Harass Behavior                       --
-- All code how to use abilities against enemies goes here  --
--------------------------------------------------------------
-- @param botBrain: CBotBrain
-- @return: none
--

object.nLightningRangeBuffer = -100

local function HarassHeroExecuteOverride(botBrain)
	local bDebugEchos = false
	local bUseOldHarass = false

	if bDebugEchos then BotEcho("Executing custom harras behavior") end
	
	local unitTarget = behaviorLib.heroTarget
	local unitSelf = core.unitSelf

	if unitTarget == nil then
		return object.harassExecuteOld(botBrain) --Target is invalid, move on to the next behavior
	end

	if bUseOldHarass then
		return object.harassExecuteOld(botBrain)
	end
	
	local vecMyPosition = unitSelf:GetPosition() 
	local nAttackRange = core.GetAbsoluteAttackRangeToUnit(unitSelf, unitTarget)
	local nMyExtraRange = core.GetExtraRange(unitSelf)
	
	local vecTargetPosition = unitTarget:GetPosition()
	local nTargetExtraRange = core.GetExtraRange(unitTarget)
	local nTargetDistanceSq = Vector3.Distance2DSq(vecMyPosition, vecTargetPosition)   
	local bTargetRooted = unitTarget:IsStunned() or unitTarget:IsImmobilized() or unitTarget:GetMoveSpeed() < 200
	local nAttackRangeSq = core.GetAbsoluteAttackRangeToUnit(unitSelf, unitTarget, true)
	
	local nLastHarassUtility = behaviorLib.lastHarassUtil
	local bCanSee = core.CanSeeUnit(botBrain, unitTarget)    
	local bActionTaken = false
	
	
	--- Insert abilities code here, set bActionTaken to true 
	--- if an ability command has been given successfully
	
	--since we are using an old pointer, ensure we can still see the target for entity targeting
	if core.CanSeeUnit(botBrain, unitTarget) then
		local vecToward = Vector3.Normalize(vecTargetPosition - vecMyPosition)
		local vecAbilityTarget = vecMyPosition + vecToward * 250

		core.FindItems()
		local itemImmunity = core.itemImmunity
		if not bActionTaken and (itemImmunity and itemImmunity:CanActivate()) then
			if nTargetDistanceSq <= ( 500 * 500 ) then
				bActionTaken = core.OrderItemClamp(botBrain, unitSelf, itemImmunity)
			end
		end	

		local itemChargedHammer = core.itemChargedHammer
		if not bActionTaken and (itemChargedHammer and itemChargedHammer:CanActivate()) then
			local tAllyHeroes = core.localUnits["AllyHeroes"]
			local unitWeakest = unitSelf
			local nRange = itemChargedHammer:GetRange()

			for i,hero in ipairs(tAllyHeroes) do
				local nDistanceSq = Vector3.Distance2DSq(vecMyPosition, hero:GetPosition())
				if unitWeakest:GetHealthPercent() < hero:GetHealthPercent() and nDistanceSq < nRange * nRange then
					unitWeakest = hero
				end
			end

			if unitWeakest ~= nil then
				bActionTaken = core.OrderItemEntityClamp(botBrain, unitSelf, itemChargedHammer, unitWeakest, false)
			end
		end	

		--core.DrawDebugArrow(vecMyPosition, vecMyPosition + vecToward * 250, 'green')
		--core.DrawDebugArrow(vecMyPosition, vecMyPosition + vecToward, 'red')

		-- Ball Lightning
		if not bActionTaken and not bTargetRooted and nLastHarassUtility > botBrain.nLightningThreshold then
			if bDebugEchos then BotEcho("  No action yet, checking ball lightning") end
			local abilLightning = skills.abilLightning
			if abilLightning:CanActivate() then
				local bCanTeleport = (abilLightning:GetManaCost() == 0) and unitSelf:HasState("State_Ravenor_Ability1")
				if not bCanTeleport then
					if ShouldUseBallLightning(botBrain, unitSelf, unitTarget) then
						local nRange = 1400 + botBrain.nLightningRangeBuffer
						if nTargetDistanceSq < (nRange * nRange) then
							--calculate a target since our range doesn't match the ability effective range
							--local vecToward = Vector3.Normalize(vecTargetPosition - vecMyPosition)
							--local vecAbilityTarget = vecMyPosition + vecToward * 250
							bActionTaken = core.OrderAbilityPosition(botBrain, abilLightning, vecAbilityTarget)
						end
					end
				end
			end
		end
	end

	-- Blades
	if not bActionTaken and nLastHarassUtility > botBrain.nBladesThreshold then
		if bDebugEchos then BotEcho("No action yet, checking blades") end
		local abilBlades = skills.abilBlades
		if abilBlades:CanActivate() then
			if nTargetDistanceSq < nAttackRangeSq then
				-- only activate if we are close to the target
				bActionTaken = core.OrderAbility(botBrain, abilBlades)
			end
		end
	end
	
	if not bActionTaken then
		if bDebugEchos then BotEcho("No action taken, fall back to default harras execute") end
		return object.harassExecuteOld(botBrain)
	end 
end
-- overload the behaviour stock function with custom 
object.harassExecuteOld = behaviorLib.HarassHeroBehavior["Execute"]
behaviorLib.HarassHeroBehavior["Execute"] = HarassHeroExecuteOverride


----------------------------------------------------
-- function: ElectricFeecbackUtilityFn
-- Checks if there has been damage from a hero in the last second
-- @treturn Number number from 0-100 indicating if we want activate electric feedback
----------------------------------------------------
function behaviorLib.ElectricFeecbackUtilityFn(botBrain)
	local nLastSecondHeroDamage = eventsLib.recentHeroDamageSec

	local nUtil = 0

	if behaviorLib.lastHarassUtil > botBrain.nFeedbackThreshold then
		if skills.abilFeedback:CanActivate() and nLastSecondHeroDamage > 0 then
			nUtil = nUtil + behaviorLib.lastRetreatUtil + behaviorLib.lastHarassUtil + 10
		end
	end

	return nUtil
end

function behaviorLib.ElectricFeecbackExecuteFn(botBrain)
	local unitSelf = core.unitSelf
	
	local nLastHarassUtility = behaviorLib.lastHarassUtil
	local bActionTaken = false

	if nLastHarassUtility > botBrain.nFeedbackThreshold then
		local abilFeedback = skills.abilFeedback
		if abilFeedback:CanActivate() then
			bActionTaken = core.OrderAbility(botBrain, abilFeedback)
		end
	end

	return bActionTaken
end

behaviorLib.FeedbackBehavior = {}
behaviorLib.FeedbackBehavior["Utility"] = behaviorLib.ElectricFeecbackUtilityFn
behaviorLib.FeedbackBehavior["Execute"] = behaviorLib.ElectricFeecbackExecuteFn
behaviorLib.FeedbackBehavior["Name"] = "Feedback"
tinsert(behaviorLib.tBehaviors, behaviorLib.FeedbackBehavior)

----------------------------------------------------
-- function: BallLightningTeleportUtility
-- TODO: check the number of enemy heroes around the target so we dont suicide
-- @treturn Number number from 0-100 indicating if we want activate the ball lightning teleport
----------------------------------------------------
function behaviorLib.BallLightningTeleportUtility(botBrain)
	local nUtil = 0
	if object.nLastBallLighningHit + object.nBallLightningDuration > HoN.GetGameTime() then
		local unitTarget = object.unitBallLightningTarget
		local unitSelf = core.unitSelf

		if unitTarget ~= nil and core.CanSeeUnit(botBrain, unitTarget) then
			local vecMyPosition = unitSelf:GetPosition() 
			local vecTargetPosition = unitTarget:GetPosition()
			local nTargetDistanceSq = Vector3.Distance2DSq(vecMyPosition, vecTargetPosition)
			local nAttackRangeSq = core.GetAbsoluteAttackRangeToUnit(unitSelf, unitTarget, true)

			local bTargetRooted = unitTarget:IsStunned() or unitTarget:IsImmobilized() or unitTarget:GetMoveSpeed() < 200

			local nLastHarassUtility = behaviorLib.lastHarassUtil

			if unitTarget:HasState("State_Enemy_Ravenor_Ability1") then
				if nLastHarassUtility >= object.nLightningPortThreshold then
					-- We're either out of range, or the target is not stunned
					if (nTargetDistanceSq > nAttackRangeSq) or (nTargetDistanceSq <= nAttackRangeSq and not bTargetRooted) then
						nUtil = nUtil + nLastHarassUtility + object.nLightningPortUp
					-- Out port chance is about to expire, so we want to use port to get the extra damage
					elseif HoN.GetGameTime() > object.nLastBallLighningHit + object.nBallLightningDuration - 500 then
						nUtil = nUtil + nLastHarassUtility + EnemyToAllyRatioUtility(unitTarget)
					else
						nUtil = 0
					end
				end
			end
		end
	end

	--BotEcho("Last BallLightningTeleportUtility: "..nUtil)

	return nUtil
end

----------------------------------------------------
-- function: BallLightningTeleportExecute
-- TODO: check the number of enemy heroes around the target so we dont suicide
----------------------------------------------------
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
-- function: IsInBag
-- Checks if the IEntityItem is in the Bot's Inventory
-- Takes IEntityItem, Returns Boolean
----------------------------------------------------
local function IsInBag(item)
	local unitSelf = core.unitSelf
	local sItemName = item:GetName()
	if unitSelf then
		local unitInventory = unitSelf:GetInventory(true)
		if unitInventory then
			for slot = 1, 6, 1 do
				local curItem = unitInventory[slot]
				if curItem then
					if curItem:GetName() == sItemName and not curItem:IsRecipe() then
						return true
					end
				end
			end
		end
	end
	return false
end

----------------------------------------------------
-- function: BloodChaliceUtility
-- @treturn Number number from 0-100 indicating if we want to use blood chalice
----------------------------------------------------
function behaviorLib.BloodChaliceUtility(botBrain)
	local nUtil = 0

	core.FindItems(botBrain)
	local itemChalice = core.itemChalice

	if itemChalice and itemChalice:CanActivate() and IsInBag(itemChalice) then
		local unitSelf = core.unitSelf
		local nHealth = unitSelf:GetHealth()
		local nHealthPercent = unitSelf:GetHealthPercent()
		local nManaPercent = unitSelf:GetManaPercent()
		local nMissingMana = unitSelf:GetMaxMana() - unitSelf:GetMana()

		if nHealthPercent > nManaPercent and nMissingMana > 85 and nHealth > 300 then
			nUtil = nUtil + 100
		end
	end

	return nUtil
end

----------------------------------------------------
-- function: BloodChaliceExecute
----------------------------------------------------
function behaviorLib.BloodChaliceExecute(botBrain)
	local unitSelf = core.unitSelf

	local bActionTaken = false

	core.FindItems(botBrain)
	local itemChalice = core.itemChalice

	if itemChalice and itemChalice:CanActivate() and IsInBag(itemChalice) then
		local unitSelf = core.unitSelf
		local nHealth = unitSelf:GetHealth()
		local nHealthPercent = unitSelf:GetHealthPercent()
		local nManaPercent = unitSelf:GetManaPercent()
		local nMissingMana = unitSelf:GetMaxMana() - unitSelf:GetMana()

		if nHealthPercent > nManaPercent and nMissingMana > 85 and nHealth > 300 then
			bActionTaken = core.OrderItemClamp(botBrain, unitSelf, itemChalice, false)
		end
	end

	return bActionTaken
end

behaviorLib.BloodChaliceBehavior = {}
behaviorLib.BloodChaliceBehavior["Utility"] = behaviorLib.BloodChaliceUtility
behaviorLib.BloodChaliceBehavior["Execute"] = behaviorLib.BloodChaliceExecute
behaviorLib.BloodChaliceBehavior["Name"] = "BloodChaliceBehavior"
tinsert(behaviorLib.tBehaviors, behaviorLib.BloodChaliceBehavior)

----------------------------------
--  AttackCreeps behavior
--
--  Utility: 21 if deny, 24 if ck, only if it predicts it can kill in one hit
--  Execute: Attacks target
----------------------------------

function behaviorLib.GetCreepAttackTarget(botBrain, unitEnemyCreep, unitAllyCreep)
	local bDebugEchos = false
	-- no predictive last hitting, just wait and react when they have 1 hit left
	-- prefers LH over deny

	local unitSelf = core.unitSelf
	local nDamageMin = unitSelf:GetFinalAttackDamageMin()
	local vecSelfPosition = unitSelf:GetPosition()
	local nMoveSpeed = unitSelf:GetMoveSpeed()
	--local nDamageAverage = core.GetFinalAttackDamageAverage(unitSelf)
	
	core.FindItems(botBrain)
	if core.itemHatchet then
		nDamageMin = nDamageMin * core.itemHatchet.creepDamageMul
	end 
	
	-- [Difficulty: Easy] Make bots worse at last hitting
	if core.nDifficulty == core.nEASY_DIFFICULTY then
		nDamageMin = nDamageMin * 1.35
	end

	local nDamageHatchet = nDamageMin

	if unitEnemyCreep and core.CanSeeUnit(botBrain, unitEnemyCreep) then
		local abilPower = skills.abilPower
		local abilBlades = skills.abilBlades

		local nTargetHealth = unitEnemyCreep:GetHealth()
		local tNearbyAllyCreeps = core.localUnits['AllyCreeps']
		local tNearbyAllyTowers = core.localUnits['AllyTowers']
		local nExpectedCreepDamage = 0
		local nExpectedTowerDamage = 0

		local vecTargetPos = unitEnemyCreep:GetPosition()

		-- Calculate our travel time to the creep
		local nTravelTime = core.TimeToPosition(vecSelfPosition, vecTargetPos, nMoveSpeed)
		local nTimeToAttack = (nTravelTime + unitSelf:GetAdjustedAttackActionTime()) / 1000
		if bDebugEchos then BotEcho ("Time to attack: " .. nTimeToAttack ) end 

		--Determine the damage expected on the creep by other creeps
		for i, unitCreep in pairs(tNearbyAllyCreeps) do
			if unitCreep:GetAttackTarget() == unitEnemyCreep then
				local nCreepAttacks = math.floor(nTimeToAttack / unitCreep:GetAttackSpeed())
				if not unitCreep:IsAttackReady() and nCreepAttacks > 0 then nCreepAttacks = nCreepAttacks - 1 end
				nExpectedCreepDamage = nExpectedCreepDamage + unitCreep:GetFinalAttackDamageMin() * nCreepAttacks
			end
		end

		--Determine the damage expected on the creep by towers
		for i, unitTower in pairs(tNearbyAllyTowers) do
			if unitTower:GetAttackTarget() == unitEnemyCreep then
				local nTowerAttacks = math.floor(nTimeToAttack / unitTower:GetAttackSpeed())
				if not unitTower:IsAttackReady() and nTowerAttacks > 0 then nTowerAttacks = nTowerAttacks - 1 end
				nExpectedTowerDamage = nExpectedTowerDamage + unitTower:GetFinalAttackDamageMin() * nTowerAttacks
			end
		end

		local pResist = 0
		local mResist = 0
		
		if( unitEnemyCreep:GetPhysicalResistance() and unitEnemyCreep:GetMagicResistance()) then
			pResist = unitEnemyCreep:GetPhysicalResistance()
			mResist = unitEnemyCreep:GetMagicResistance()
		end

		-- Factor in the extra damage from our ultimate
		if abilPower:GetLevel() > 0 then
			nDamageMin = nDamageMin + ( abilPower:GetCharges() * (1 - mResist) )
		end

		-- Factor in the damage from our second skill
		if unitSelf:HasState("State_Ravenor_Ability2") then
			nDamageMin = nDamageMin + (( 25 + (abilBlades:GetLevel() * 25)) * (1 - mResist))
		end
		
		-- Only attack if, by the time our attack reaches the target
		-- the damage done by other sources brings the target's health
		-- below our minimum damage
		if nDamageMin >= (nTargetHealth - nExpectedCreepDamage - nExpectedTowerDamage) then
			if bDebugEchos then BotEcho("Returning an enemy") end
			return unitEnemyCreep
		else
			-- Check if we can kill the target with loggers hatchet
			core.FindItems(botBrain)
			local itemHatchet = core.itemHatchet
			if (itemHatchet and itemHatchet:CanActivate() and IsInBag(itemHatchet)) then
				-- Loggers Hatchet can be used. Since we are a melee hero this might be the safer choice
				local nProjectileSpeed = 900
				local nProjectileTravelTime = Vector3.Distance2D(vecSelfPosition, vecTargetPos) / nProjectileSpeed
				if bDebugEchos then BotEcho ("Hatchet projectile travel time: " .. nProjectileTravelTime ) end 
				
				--Determine the damage expected on the creep by other creeps
				for i, unitCreep in pairs(tNearbyAllyCreeps) do
					if unitCreep:GetAttackTarget() == unitEnemyCreep then
						local nCreepAttacks = math.floor(nProjectileTravelTime / unitCreep:GetAttackSpeed())
						if not unitCreep:IsAttackReady() and nCreepAttacks > 0 then nCreepAttacks = nCreepAttacks - 1 end
						nExpectedCreepDamage = nExpectedCreepDamage + unitCreep:GetFinalAttackDamageMin() * nCreepAttacks
					end
				end

				--Determine the damage expected on the creep by towers
				for i, unitTower in pairs(tNearbyAllyTowers) do
					if unitTower:GetAttackTarget() == unitEnemyCreep then
						local nTowerAttacks = math.floor(nProjectileTravelTime / unitTower:GetAttackSpeed())
						if not unitTower:IsAttackReady() and nTowerAttacks > 0 then nTowerAttacks = nTowerAttacks - 1 end
						nExpectedTowerDamage = nExpectedTowerDamage + unitTower:GetFinalAttackDamageMin() * nTowerAttacks
					end
				end
				
				--Only attack if, by the time our attack reaches the target
				-- the damage done by other sources brings the target's health
				-- below our minimum damage
				if nDamageHatchet >= (nTargetHealth - nExpectedCreepDamage - nExpectedTowerDamage) then
					if bDebugEchos then BotEcho("Returning an enemy") end
					return unitEnemyCreep
				end
			end
		end        
	end

	if unitAllyCreep then
		local nTargetHealth = unitAllyCreep:GetHealth()
		local tNearbyEnemyCreeps = core.localUnits['EnemyCreeps']
		local tNearbyEnemyTowers = core.localUnits['EnemyTowers']
		local nExpectedCreepDamage = 0
		local nExpectedTowerDamage = 0

		local sName = core.GetCurrentBehaviorName(botBrain)
		if core.teamBotBrain.nPushState == 2 then
			return nil
		end

		local vecTargetPos = unitAllyCreep:GetPosition()
		local nTravelTime = core.TimeToPosition(vecSelfPosition, vecTargetPos, nMoveSpeed)
		local nTimeToAttack = (nTravelTime + unitSelf:GetAdjustedAttackActionTime()) / 1000
		if bDebugEchos then BotEcho ("Time to attack: " .. nTimeToAttack ) end 
		
		--Determine the damage expected on the creep by other creeps
		for i, unitCreep in pairs(tNearbyEnemyCreeps) do
			if unitCreep:GetAttackTarget() == unitAllyCreep then
				local nCreepAttacks = math.floor(nTimeToAttack / unitCreep:GetAttackSpeed())
				if not unitCreep:IsAttackReady() and nCreepAttacks > 0 then nCreepAttacks = nCreepAttacks - 1 end
				nExpectedCreepDamage = nExpectedCreepDamage + unitCreep:GetFinalAttackDamageMin() * nCreepAttacks
			end
		end

		--Determine the damage expected on the creep by towers
		for i, unitTower in pairs(tNearbyEnemyTowers) do
			if unitTower:GetAttackTarget() == unitAllyCreep then
				local nTowerAttacks = math.floor(nTimeToAttack / unitTower:GetAttackSpeed())
				if not unitTower:IsAttackReady() and nTowerAttacks > 0 then nTowerAttacks = nTowerAttacks - 1 end
				nExpectedTowerDamage = nExpectedTowerDamage + unitTower:GetFinalAttackDamageMin() * nTowerAttacks
			end
		end
		
		--Only attack if, by the time our attack reaches the target
		-- the damage done by other sources brings the target's health
		-- below our minimum damage
		if nDamageMin >= (nTargetHealth - nExpectedCreepDamage - nExpectedTowerDamage) then
			local bActuallyDeny = true
			
			--[Difficulty: Easy] Don't deny
			if core.nDifficulty == core.nEASY_DIFFICULTY then
				bActuallyDeny = false
			end         
			
			-- [Tutorial] Hellbourne *will* deny creeps after shit gets real
			if core.bIsTutorial and core.bTutorialBehaviorReset == true and core.myTeam == HoN.GetHellbourneTeam() then
				bActuallyDeny = true
			end
			
			if bActuallyDeny then
				if bDebugEchos then BotEcho("Returning an ally") end
				return unitAllyCreep
			end
		end
	end

	return nil
end

---------------------------------------------
-- Attack Creeps Override
---------------------------------------------

local function AttackCreepsExecuteCustom(botBrain)
	local bDebugEchos = false

	local unitSelf = core.unitSelf
	local unitCreepTarget = core.unitCreepTarget
	local bActionTaken = false
	local nMoveSpeed = unitSelf:GetMoveSpeed()
	local bActionTaken = false

	if unitCreepTarget and core.CanSeeUnit(botBrain, unitCreepTarget) then      
		--Get info about the target we are about to attack
		local bIsAlliedCreep = unitCreepTarget:GetTeam() == unitSelf:GetTeam()

		local vecSelfPos = unitSelf:GetPosition()
		local vecTargetPos = unitCreepTarget:GetPosition()
		local nDistSq = Vector3.Distance2DSq(vecSelfPos, vecTargetPos)
		local nAttackRangeSq = core.GetAbsoluteAttackRangeToUnit(unitSelf, currentTarget, true)       
		local nTargetHealth = unitCreepTarget:GetHealth()
		local nDamageMin = unitSelf:GetFinalAttackDamageMin()
		local bUseHatchet = false

		local sName = core.GetCurrentBehaviorName(botBrain)
		local bIsPushing = false

		if core.teamBotBrain.nPushState == 2 then
			bIsPushing = true
			nDamageMin = nDamageMin * 3
		end

		core.FindItems(botBrain)
		local itemHatchet = core.itemHatchet
		if core.itemHatchet then
			nDamageMin = nDamageMin * core.itemHatchet.creepDamageMul
		end 
		local nDamageHatchet = nDamageMin

		local nProjectileTravelTime = 0
		local nTravelTime = core.TimeToPosition(vecSelfPos, vecTargetPos, nMoveSpeed)
		nProjectileTravelTime = (nTravelTime + unitSelf:GetAdjustedAttackActionTime()) / 1000

		if not bIsAlliedCreep then
			-- If its not an allied creep we can add aditional damage from our spells
			local abilPower = skills.abilPower
			local abilBlades = skills.abilBlades

			local pResist = 0
			local mResist = 0
			
			if( unitCreepTarget:GetPhysicalResistance() and unitCreepTarget:GetMagicResistance()) then
				pResist = unitCreepTarget:GetPhysicalResistance()
				mResist = unitCreepTarget:GetMagicResistance()
			end

			if abilPower:GetLevel() > 0 then
				nDamageMin = nDamageMin + ( abilPower:GetCharges() * (1 - mResist) )
			end

			if unitSelf:HasState("State_Ravenor_Ability2") then
				nDamageMin = nDamageMin + (( 25 + (abilBlades:GetLevel() * 25)) * (1 - mResist))
			end
		end

		--Get projectile info
		if bDebugEchos then BotEcho ("Time to attack: " .. nProjectileTravelTime ) end 
		
		local nExpectedCreepDamage = 0
		local nExpectedTowerDamage = 0
		local tNearbyAttackingCreeps = nil
		local tNearbyAttackingTowers = nil

		--Get the creeps and towers on the opposite team
		-- of our target
		if unitCreepTarget:GetTeam() == unitSelf:GetTeam() then
			tNearbyAttackingCreeps = core.localUnits['EnemyCreeps']
			tNearbyAttackingTowers = core.localUnits['EnemyTowers']
		else
			tNearbyAttackingCreeps = core.localUnits['AllyCreeps']
			tNearbyAttackingTowers = core.localUnits['AllyTowers']
		end
	
		--Determine the damage expected on the creep by other creeps
		for i, unitCreep in pairs(tNearbyAttackingCreeps) do
			if unitCreep:GetAttackTarget() == unitCreepTarget then
				local nCreepAttacks = math.floor(nProjectileTravelTime / unitCreep:GetAttackSpeed())
				if not unitCreep:IsAttackReady() and nCreepAttacks > 0 then nCreepAttacks = nCreepAttacks - 1 end
				nExpectedCreepDamage = nExpectedCreepDamage + unitCreep:GetFinalAttackDamageMin() * nCreepAttacks
			end
		end
	
		--Determine the damage expected on the creep by other towers
		for i, unitTower in pairs(tNearbyAttackingTowers) do
			if unitTower:GetAttackTarget() == unitCreepTarget then
				local nTowerAttacks = math.floor(nProjectileTravelTime / unitTower:GetAttackSpeed())
					if not unitTower:IsAttackReady() and nTowerAttacks > 0 then nTowerAttacks = nTowerAttacks - 1 end
				nExpectedTowerDamage = nExpectedTowerDamage + unitTower:GetFinalAttackDamageMin() * nTowerAttacks
			end
		end

		--BotEcho(format("nExpectedCreepDamage: %i - nExpectedTowerDamage: %i", nExpectedCreepDamage, nExpectedTowerDamage))
	
		-- Only attack if, by the time our attack reaches the target
		-- the damage done by other sources brings the target's health
		-- below our minimum damage, and we are in range and can attack right now
		if nDistSq < nAttackRangeSq and unitSelf:IsAttackReady() and (nDamageMin >= (nTargetHealth - nExpectedCreepDamage - nExpectedTowerDamage) or bIsPushing) then
			if bDebugEchos then BotEcho ("Attacking target") end
			bActionTaken = core.OrderAttackClamp(botBrain, unitSelf, unitCreepTarget)
		elseif (itemHatchet and itemHatchet:CanActivate() and IsInBag(itemHatchet)) then
			-- maybe we can kill the target with hatchet
			local nProjectileSpeed = 900
			nProjectileTravelTime = Vector3.Distance2D(vecSelfPos, vecTargetPos) / nProjectileSpeed

			--Get projectile info
			if bDebugEchos then BotEcho ("Hatchet Projectile travel time: " .. nProjectileTravelTime ) end 
			
			local nExpectedCreepDamage = 0
			local nExpectedTowerDamage = 0
			local tNearbyAttackingCreeps = nil
			local tNearbyAttackingTowers = nil

			--Get the creeps and towers on the opposite team
			-- of our target
			if unitCreepTarget:GetTeam() == unitSelf:GetTeam() then
				tNearbyAttackingCreeps = core.localUnits['EnemyCreeps']
				tNearbyAttackingTowers = core.localUnits['EnemyTowers']
			else
				tNearbyAttackingCreeps = core.localUnits['AllyCreeps']
				tNearbyAttackingTowers = core.localUnits['AllyTowers']
			end
		
			--Determine the damage expected on the creep by other creeps
			for i, unitCreep in pairs(tNearbyAttackingCreeps) do
				if unitCreep:GetAttackTarget() == unitCreepTarget then
					local nCreepAttacks = math.floor(nProjectileTravelTime / unitCreep:GetAttackSpeed())
					if not unitCreep:IsAttackReady() and nCreepAttacks > 0 then nCreepAttacks = nCreepAttacks - 1 end
					nExpectedCreepDamage = nExpectedCreepDamage + unitCreep:GetFinalAttackDamageMin() * nCreepAttacks
				end
			end
		
			--Determine the damage expected on the creep by other towers
			for i, unitTower in pairs(tNearbyAttackingTowers) do
				if unitTower:GetAttackTarget() == unitCreepTarget then
					local nTowerAttacks = math.floor(nProjectileTravelTime / unitTower:GetAttackSpeed())
					if not unitTower:IsAttackReady() and nTowerAttacks > 0 then nTowerAttacks = nTowerAttacks - 1 end
					nExpectedTowerDamage = nExpectedTowerDamage + unitTower:GetFinalAttackDamageMin() * nTowerAttacks
				end
			end

			nAttackRangeSq = 600 * 600

			-- Only attack if, by the time our attack reaches the target
			-- the damage done by other sources brings the target's health
			-- below our minimum damage, and we are in range and can attack right now
			if nDistSq < nAttackRangeSq and unitSelf:IsAttackReady() and (nDamageHatchet >= (nTargetHealth - nExpectedCreepDamage - nExpectedTowerDamage) or bIsPushing) then
				if bDebugEchos then BotEcho ("Attacking target with hatchet") end
				bActionTaken = core.OrderItemEntityClamp(botBrain, unitSelf, itemHatchet, unitCreepTarget)
			end
		else
			--BotEcho("MOVIN OUT")
			local vecDesiredPos = core.AdjustMovementForTowerLogic(vecTargetPos)
			bActionTaken = core.OrderMoveToPosAndHoldClamp(botBrain, unitSelf, vecDesiredPos, false)
		end
	else
		return false
	end

	if not bActionTaken then
		--BotEcho("No action yet, trying old behavior")
		return object.AttackCreepsExecuteOld(botBrain)
	end 
end

object.AttackCreepsExecuteOld = behaviorLib.AttackCreepsBehavior["Execute"]
behaviorLib.AttackCreepsBehavior["Execute"] = AttackCreepsExecuteCustom


-- This function allowes soul reaper to use his ability while pushing
-- Has prediction, however it might need some repositioning so he is in correct range more often
local function abilityPush(botBrain, unitSelf)
	local debugAbilityPush = false
	local bDontPush = false
	if bDontPush then
		return false
	end

	local abilBlades = skills.abilBlades
	local abilLightning = skills.abilLightning

	local tNearbyEnemyCreeps = core.localUnits["EnemyCreeps"]
	
	-- Be conservative with mana, so we can cast our combo afterwards
	if  abilBlades:CanActivate() and unitSelf:GetMana() > (abilBlades:GetManaCost() * 2 + abilLightning:GetManaCost()) then 
		--Get judgement info
		local nBladesRangeSq = 300 * 300

		--Get info about surroundings
		local myPos = unitSelf:GetPosition()
		local tNearbyEnemyTowers = core.localUnits["EnemyTowers"]

		--Determine information about nearby creeps
		local nCreepsInRange = 0
		for i, unitCreep in pairs(tNearbyEnemyCreeps) do
			nTargetDistanceSq = Vector3.Distance2DSq(myPos, unitCreep:GetPosition())
			if nTargetDistanceSq < nBladesRangeSq then
				nCreepsInRange = nCreepsInRange + 1
			end
		end
		
		--Check for nearby towers
		local bNearTower = false
		for i, unitTower in pairs(tNearbyEnemyTowers) do
			if unitTower then
				bNearTower = true
			end
		end

		--Only cast if one of these conditions is met
		local bShouldCast = nCreepsInRange >= 2 or (nCreepsInRange >= 1 and bNearTower)

		--Cast judgement if a condition is met
		if bShouldCast then
			return core.OrderAbility(botBrain, abilBlades)
		end
	end

	if unitSelf:IsAttackReady() then
        if #tNearbyEnemyCreeps > 0 then
            local unitClosestCreep = nil
            local nClosestDistanceSq = 99999 * 99999
            local vecMyPosition = unitSelf:GetPosition()
            for i,creep in pairs(tNearbyEnemyCreeps) do
                local nDistanceSq = Vector3.Distance2DSq(vecMyPosition. creep:GetPosition())
                if nDistanceSq > nClosestDistanceSq then
                    unitClosestCreep = creep
                end
            end

            if unitClosestCreep ~= nil then
                local nAttackRangeSq = core.GetAbsoluteAttackRangeToUnit(unitSelf, unitClosestCreep, true)

                if nClosestDistanceSq < nAttackRangeSq and unitSelf:IsAttackReady() then
                    if bDebugEchos then BotEcho ("Attacking target") end
                    bActionTaken = core.OrderAttackClamp(botBrain, unitSelf, unitCreepTarget)
                else  
                    --BotEcho("MOVIN OUT")
                    local vecDesiredPos = core.AdjustMovementForTowerLogic(unitClosestCreep:GetPosition())
                    bActionTaken = core.OrderMoveToPosAndHoldClamp(botBrain, unitSelf, vecDesiredPos, false)
                end
            end
        end
    end
	
	return false
end


function object.CreepPush(botBrain)
	local debugPushLines = false
	
	local bSuccess = false
		
	local unitSelf = core.unitSelf
	if unitSelf:IsChanneling() then 
		return
	end

	local unitTarget = core.unitEnemyCreepTarget
	if unitTarget then
		bSuccess = abilityPush(botBrain, unitSelf)
	end
	
	return bSuccess
end

-- both functions below call for the creep push, however 
function object.PushExecuteOverride(botBrain)
	if not object.CreepPush(botBrain) then 
		object.PushExecuteOld(botBrain)
	end
end
object.PushExecuteOld = behaviorLib.PushBehavior["Execute"]
behaviorLib.PushBehavior["Execute"] = object.PushExecuteOverride


local function TeamGroupBehaviorOverride(botBrain)
	object.TeamGroupBehaviorOld(botBrain)
	object.CreepPush(botBrain)
end
object.TeamGroupBehaviorOld = behaviorLib.TeamGroupBehavior["Execute"]
behaviorLib.TeamGroupBehavior["Execute"] = TeamGroupBehaviorOverride

----------------------------------
--  FindItems Override
----------------------------------
local function funcFindItemsOverride(botBrain)
	local bUpdated = object.FindItemsOld(botBrain)

	if core.itemChalice ~= nil and not core.itemChalice:IsValid() then
		core.itemChalice = nil
	end

	if core.itemImmunity ~= nil and not core.itemImmunity:IsValid() then
		core.itemImmunity = nil
	end

	if core.itemChargedHammer ~= nil and not core.itemChargedHammer:IsValid() then
		core.itemChargedHammer = nil
	end
	
	if bUpdated then
		--only update if we need to
		if core.itemChalice and core.itemImmunity and core.itemChargedHammer then
			return
		end
		
		local inventory = core.unitSelf:GetInventory(true)
		for slot = 1, 12, 1 do
			local curItem = inventory[slot]
			if curItem then
				if core.itemChargedHammer == nil and curItem:GetName() == "Item_Lightning2" then
					core.itemChargedHammer = core.WrapInTable(curItem)
				end
				if core.itemImmunity == nil and curItem:GetName() == "Item_Immunity" then
					core.itemImmunity = core.WrapInTable(curItem)
				end
				if core.itemChalice == nil and (curItem:GetName() == "Item_BloodChalice") then
					core.itemChalice = core.WrapInTable(curItem)
				end
			end
		end
	end
end
object.FindItemsOld = core.FindItems
core.FindItems = funcFindItemsOverride
