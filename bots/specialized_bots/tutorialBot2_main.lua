-- TutorialBot1 v1.0

------------------------------------------
--  	Bot Initialization  	--
------------------------------------------
local _G = getfenv(0)
local object = _G.object
object.myName = object:GetName()
object.bRunLogic, object.bRunBehaviors, object.bUpdates, object.bUseShop, object.bRunCommands, object.bMoveCommands, object.bAttackCommands, object.bAbilityCommands, object.bOtherCommands = true
object.logger = {}
object.bReportBehavior, object.bDebugUtility, object.logger.bWriteLog, object.logger.bVerboseLog = false
object.core 		= {}
object.eventsLib	= {}
object.metadata 	= {}
object.behaviorLib  	= {}
object.skills   	= {}
runfile "bots/core.lua"
runfile "bots/botbraincore.lua"
runfile "bots/eventslib.lua"
runfile "bots/metadata.lua"
runfile "bots/behaviorlib.lua"
runfile "bots/shoppingLib.lua"

local itemHandler = object.itemHandler
local shoppingLib = object.shoppingLib
--Implement changes to default settings
local tSetupOptions = {
	bCourierCare = false,
	bWaitForLaneDecision = false, --don't wait for lane decision before shopping
	tConsumableOptions = true
}
--call setup function
shoppingLib.Setup(tSetupOptions)
--object.shoppingLib.setup({bReserveItems=true, bWaitForLaneDecision=false, tConsumableOptions=true, bCourierCare=false})

local core, eventsLib, behaviorLib, metadata, skills = object.core, object.eventsLib, object.behaviorLib, object.metadata, object.skills
local print, ipairs, pairs, string, table, next, type, tinsert, tremove, tsort, format, tostring, tonumber, strfind, strsub 	= _G.print, _G.ipairs, _G.pairs, _G.string, _G.table, _G.next, _G.type, _G.table.insert, _G.table.remove, _G.table.sort, _G.string.format, _G.tostring, _G.tonumber, _G.string.find, _G.string.sub
local ceil, floor, pi, tan, atan, atan2, abs, cos, sin, acos, max, random, sqrt = _G.math.ceil, _G.math.floor, _G.math.pi, _G.math.tan, _G.math.atan, _G.math.atan2, _G.math.abs, _G.math.cos, _G.math.sin, _G.math.acos, _G.math.max, _G.math.random, _G.math.sqrt
local BotEcho, VerboseLog, BotLog = core.BotEcho, core.VerboseLog, core.BotLog
local Clamp = core.Clamp

BotEcho('loading tutorialBot2...')

--------------------------------
-- Skills - level stats
--------------------------------
function object:SkillBuild()
	local unitSelf = self.core.unitSelf	
	
	if  skills.abilAttributeBoost == nil then
		skills.abilAttributeBoost	= unitSelf:GetAbility(4)
	end
	
	if unitSelf:GetAbilityPointsAvailable() <= 0 then
		return
	end
	
	if skills.abilAttributeBoost:CanLevelUp() then
		skills.abilAttributeBoost:LevelUp()
	end
end


--------------------------------
-- Skills
--------------------------------
function object:SkillBuild()
	local unitSelf = self.core.unitSelf

	if  skills.abilHammerThrow == nil then
		skills.abilHammerThrow = unitSelf:GetAbility(0)
		skills.abilMightySwing = unitSelf:GetAbility(1)
		skills.abilGalvanize = unitSelf:GetAbility(2)
		skills.abilBruteStrength = unitSelf:GetAbility(3)
		skills.abilAttributeBoost = unitSelf:GetAbility(4)
	end
	
	if unitSelf:GetAbilityPointsAvailable() <= 0 then
		return
	end
	
	--Ult, HammerThrow, 2 in stats, Galvanzie, Mighty Swing, Stats
	if skills.abilBruteStrength:CanLevelUp() then
		skills.abilBruteStrength:LevelUp()
	elseif skills.abilHammerThrow:CanLevelUp() then
		skills.abilHammerThrow:LevelUp()
	elseif skills.abilAttributeBoost:GetLevel() < 1 then
		skills.abilAttributeBoost:LevelUp()
	elseif skills.abilGalvanize:CanLevelUp() then
		skills.abilGalvanize:LevelUp()
	elseif skills.abilMightySwing:CanLevelUp() then
		skills.abilMightySwing:LevelUp()
	else
		skills.abilAttributeBoost:LevelUp()
	end
end

---------------------------------------------------
--                   Overrides                   --
---------------------------------------------------

behaviorLib.nCreepPushbackMul = 0.5
behaviorLib.nTargetPositioningMul = 0.6

----------------------------------
--	Hammerstorm specific harass bonuses
--
--  Abilities off cd increase harass util
--  Ability use increases harass util for a time
----------------------------------

object.nHammerThrowUp = 13
object.nBruteStrengthUp = 17

object.nHammerThrowUse = 25
object.nGalvanizeActive = 5
object.nBruteStrengthActive = 25
object.nPortalKeyUse = 20

object.nGalvanizeExpireTime = 0
object.sGalvanizeStateName = "State_Hammerstorm_Ability3"
object.nBruteStrengthExpireTime = 0
object.sBruteStrengthStateName = "State_Hammerstorm_Ability4"

object.nPortalKeyThreshold = 45
object.nHammerThrowThreshold = 33
object.nGalvanizeThreshold = 45

--Hammerstorm ability use gives bonus to harass util for a while
function object:oncombateventOverride(EventData)
	self:oncombateventOld(EventData)
	
	local bDebugEchos = false
	local nAddBonus = 0
	
	if EventData.Type == "Ability" then
		if bDebugEchos then BotEcho("  ABILILTY EVENT!  InflictorName: "..EventData.InflictorName) end
		if EventData.InflictorName == "Ability_Hammerstorm1" then
			nAddBonus = nAddBonus + object.nHammerThrowUse
		end		
	elseif EventData.Type == "State" or EventData.Type == "Buff" then
		if EventData.StateName == object.sGalvanizeStateName then
			if bDebugEchos then BotEcho(format("Galvanize applied for %d at %d", EventData.StateDuration, EventData.TimeStamp)) end
			object.nGalvanizeExpireTime = EventData.TimeStamp + EventData.StateDuration
		elseif EventData.StateName == object.sBruteStrengthStateName then
			if bDebugEchos then BotEcho(format("Brute Strength applied for %d at %d", EventData.StateDuration, EventData.TimeStamp)) end
			object.nBruteStrengthExpireTime = EventData.TimeStamp + EventData.StateDuration
		end
	elseif EventData.Type == "Item" then
		--eventsLib.printCombatEvent(EventData)
		if core.itemPortalKey ~= nil and EventData.InflictorName == core.itemPortalKey:GetName() then
			nAddBonus = nAddBonus + self.nPortalKeyUse
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

--Util calc override
function behaviorLib.CustomHarassUtility(hero)
	local val = 0
	if skills.abilHammerThrow:CanActivate() then
		val = val + object.nHammerThrowUp
	end
	if skills.abilBruteStrength:CanActivate() then
		val = val + object.nBruteStrengthUp
	end
	if object.nBruteStrengthExpireTime > HoN.GetGameTime() then
		val = val + object.nBruteStrengthActive
	end
	return val
end 

----------------------------------
--	Hammer harass actions
----------------------------------

local function HarassHeroExecuteOverride(botBrain)

	local unitTarget = behaviorLib.heroTarget
	if unitTarget == nil or not unitTarget:IsValid() then
		return false --can not execute, move on to the next behavior
	end
	
	local unitSelf = core.unitSelf
	local vecMyPosition = unitSelf:GetPosition()
	local nAttackRangeSq = core.GetAbsoluteAttackRangeToUnit(unitSelf, unitTarget)
	nAttackRangeSq = nAttackRangeSq * nAttackRangeSq
	
	local vecTargetPosition = unitTarget:GetPosition()
	local nTargetDistanceSq = Vector3.Distance2DSq(vecMyPosition, vecTargetPosition)
	local bTargetRooted = unitTarget:IsStunned() or unitTarget:IsImmobilized() or unitTarget:GetMoveSpeed() < 200
	
	local nLastHarassUtility = behaviorLib.lastHarassUtil
	local bCanSee = core.CanSeeUnit(botBrain, unitTarget)	
	
	local bActionTaken = false
	local bMoveIn = false
	
	--portalkey
	local itemPortalKey = core.itemPortalKey
	if itemPortalKey then
		local nPortalKeyRange = itemPortalKey:GetRange()
		local nHammerRange = skills.abilHammerThrow:GetRange()
		if itemPortalKey:CanActivate() and behaviorLib.lastHarassUtil > object.nPortalKeyThreshold then
			if nTargetDistanceSq > (nHammerRange * nHammerRange) and nTargetDistanceSq < (nPortalKeyRange*nPortalKeyRange + nHammerRange*nHammerRange) then
				vecCenter = core.GetGroupCenter(core.localUnits["EnemyHeroes"])
				if vecCenter then
					bActionTaken = core.OrderItemPosition(botBrain, unitSelf, itemPortalKey, vecCenter)
				end
			end
		end
	end
	
	--hammer throw
	local nHammerThrowAoERadius = 300
	if not bActionTaken and bCanSee and not bTargetRooted and nLastHarassUtility > botBrain.nHammerThrowThreshold then
		local abilHammerThrow = skills.abilHammerThrow
		if abilHammerThrow:CanActivate() then
			local nRange = abilHammerThrow:GetRange()
			if nTargetDistanceSq < (nRange * nRange) then
				bActionTaken = core.OrderAbilityEntity(botBrain, abilHammerThrow, unitTarget)
			else
				bMoveIn = true
			end
		end
	end
	
	--brute strength
	if not bActionTaken then
		local abilBruteStrength = skills.abilBruteStrength
		--activate when just out of melee range of target
		if abilBruteStrength:CanActivate() and nTargetDistanceSq < nAttackRangeSq * (1.25 * 1.25) then
			bActionTaken = core.OrderAbility(botBrain, abilBruteStrength)
		end
	end

	--galvanize
	if not bActionTaken and (bMoveIn or nLastHarassUtility > botBrain.nGalvanizeThreshold) then
		local abilGalvanize = skills.abilGalvanize
		if abilGalvanize:CanActivate() then
			bActionTaken = core.OrderAbility(botBrain, abilGalvanize)
		end
	end
	
	if not bActionTaken then
		return object.harassExecuteOld(botBrain)
	end
end
object.harassExecuteOld = behaviorLib.HarassHeroBehavior["Execute"]
behaviorLib.HarassHeroBehavior["Execute"] = HarassHeroExecuteOverride




---------------------------------------------------
--				  Behavior changes				 --
---------------------------------------------------
-- We don't want anything running other than last hitting and positioning.
behaviorLib.tBehaviors = {}
tinsert(behaviorLib.tBehaviors, behaviorLib.AttackCreepsBehavior)
tinsert(behaviorLib.tBehaviors, behaviorLib.attackEnemyMinionsBehavior)
tinsert(behaviorLib.tBehaviors, behaviorLib.DontBreakChannelBehavior)
tinsert(behaviorLib.tBehaviors, behaviorLib.PositionSelfBehavior)
tinsert(behaviorLib.tBehaviors, behaviorLib.RetreatFromThreatBehavior)
tinsert(behaviorLib.tBehaviors, behaviorLib.PreGameBehavior)
tinsert(behaviorLib.tBehaviors, behaviorLib.ShopBehavior) -- This has courier included.
tinsert(behaviorLib.tBehaviors, behaviorLib.StashBehavior)
tinsert(behaviorLib.tBehaviors, behaviorLib.HarassHeroBehavior) -- Added - for harder bots.


----------------------------------
--	Hammerstorm items
----------------------------------
behaviorLib.StartingItems = {"Item_CrushingClaws", "Item_MarkOfTheNovice", "2 Item_RunesOfTheBlight", "2 Item_ManaPotion"}
behaviorLib.LaneItems = {"Item_BloodChalice", "Item_Marchers", "Item_Strength5", "Item_Steamboots"} --Item_Strength5 is Fortified Bracelet
behaviorLib.MidItems = {"Item_PortalKey", "Item_Insanitarius", "Item_Immunity", "Item_Critical1 4"} --Immunity is Shrunken Head, Item_Critical1 is Riftshards
behaviorLib.LateItems = {"Item_Warpcleft", "Item_SolsBulwark", "Item_DaemonicBreastplate", "Item_BehemothsHeart", "Item_Damage9"} --Item_Damage9 is doombringer

BotEcho('finished loading tutorialBot2')
