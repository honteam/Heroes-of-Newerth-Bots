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
	bCourierCare = true,
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

BotEcho('loading tutorialBot3...')


--------------------------------
-- Skills
--------------------------------
function object:SkillBuild()
	local unitSelf = self.core.unitSelf	
	
	if  skills.abilGraveyard == nil then
		skills.abilGraveyard		= unitSelf:GetAbility(0)
		skills.abilMiniaturization	= unitSelf:GetAbility(1)
		skills.abilPowerDrain		= unitSelf:GetAbility(2)
		skills.abilSilverBullet		= unitSelf:GetAbility(3)
		skills.abilAttributeBoost	= unitSelf:GetAbility(4)
	end
	if unitSelf:GetAbilityPointsAvailable() <= 0 then
		return
	end
	
	-- automatically levels stats in the end
	-- stats have to be leveld manually if needed inbetween
	tSkills ={
		0, 1, 0, 2, 0, 3, 
		0, 1, 1, 1, 3, 
		2, 2, 2, 4,
		3
	}
	
	local nLev = unitSelf:GetLevel()
    local nLevPts = unitSelf:GetAbilityPointsAvailable()
    --BotEcho(tostring(nLev + nLevPts))
    for i = nLev, nLev+nLevPts do
		local nSkill = tSkills[i]
		if nSkill == nil then nSkill = 4 end
		
        unitSelf:GetAbility(nSkill):LevelUp()
    end
end

----------------------------------
--	Witch Slayer's specific harass bonuses
--
--  Abilities off cd increase harass util
--  Ability use increases harass util for a time
----------------------------------

object.nGraveyardUp = 12
object.nMiniaturizationUp = 8
object.nSilverBulletUp = 35
object.nSheepstickUp = 12

object.nGraveyardUse = 16
object.nMiniaturizationUse = 15
object.nSilverBulletUse = 55
object.nSheepstickUse = 16

object.nGraveyardThreshold = 45
object.nMiniaturizationThreshold = 40
object.nPowerDrainThreshold = 25
object.nSilverBulletThreshold = 60
object.nSheepstickThreshold = 30


object.nPowerDrainExpireTime = 0

local function AbilitiesUpUtility(hero)
	local nUtility = 0
	
	if skills.abilGraveyard:CanActivate() then
		nUtility = nUtility + object.nGraveyardUp
	end
	
	if skills.abilMiniaturization:CanActivate() then
		nUtility = nUtility + object.nMiniaturizationUp
	end
	
	if skills.abilSilverBullet:CanActivate() then
		nUtility = nUtility + object.nSilverBulletUp
	end
	
	if object.itemSheepstick and object.itemSheepstick:CanActivate() then
		nUtility = nUtility + object.nSheepstickUp
	end
	
	return nUtility
end

--Witch Slayer ability use gives bonus to harass util for a while
object.nGraveyardUseTime = 0
function object:oncombateventOverride(EventData)
	self:oncombateventOld(EventData)
	
	local bDebugEchos = false
	local nAddBonus = 0
	
	if EventData.Type == "Ability" then
		if bDebugEchos then BotEcho("  ABILILTY EVENT!  InflictorName: "..EventData.InflictorName) end
		if EventData.InflictorName == "Ability_WitchSlayer1" then
			nAddBonus = nAddBonus + object.nGraveyardUse
			object.nGraveyardUseTime = EventData.TimeStamp
		elseif EventData.InflictorName == "Ability_WitchSlayer2" then
			nAddBonus = nAddBonus + object.nMiniaturizationUse
		elseif EventData.InflictorName == "Ability_WitchSlayer4" then
			nAddBonus = nAddBonus + object.nSilverBulletUse
		end
	elseif EventData.Type == "Item" then
		if core.itemSheepstick ~= nil and EventData.SourceUnit == core.unitSelf:GetUniqueID() and EventData.InflictorName == core.itemSheepstick:GetName() then
			nAddBonus = nAddBonus + self.nSheepstickUse
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
local function CustomHarassUtilityFnOverride(hero)
	local nUtility = AbilitiesUpUtility(hero)
	
	return nUtility
end
behaviorLib.CustomHarassUtility = CustomHarassUtilityFnOverride   

----------------------------------
--	Witch Slayer harass actions
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
	local bTargetRooted = unitTarget:IsStunned() or unitTarget:IsImmobilized() or unitTarget:GetMoveSpeed() < 200
	
	local nLastHarassUtility = behaviorLib.lastHarassUtil
	local bCanSee = core.CanSeeUnit(botBrain, unitTarget)
	
	-- Don't stop power drain early for no reason
	local bShouldUsePowerDrain = (bTargetRooted or nTargetDistanceSq < (450 * 450))
	local bHealthHighEnough = unitSelf:GetHealthPercent() > 0.6
	local bManaHighEnough = unitSelf:GetManaPercent() > 0.1 and unitSelf:GetMana() > 50
	if not bShouldUsePowerDrain or not bHealthHighEnough or not bManaHighEnough then
		object.nPowerDrainExpireTime = 0 -- Stop draining.
	end
	if object.nPowerDrainExpireTime > HoN.GetGameTime() then
		return
	end
	
	local bActionTaken = false
	
	--Graveyard
	if not bTargetRooted and nLastHarassUtility > object.nGraveyardThreshold then
		local abilGraveyard = skills.abilGraveyard
		if abilGraveyard:CanActivate() then
			local nRange = 850
			if nTargetDistanceSq < (nRange * nRange) then
				--calculate a target since our range doesn't match the ability effective range
				local vecToward = Vector3.Normalize(vecTargetPosition - vecMyPosition)
				local vecAbilityTarget = vecMyPosition + vecToward * 250
				bActionTaken = core.OrderAbilityPosition(botBrain, abilGraveyard, vecAbilityTarget)
			end
		end
	end
	
	--since we are using an old pointer, ensure we can still see the target for entity targeting	
	if bCanSee then		
		--Miniaturization
		if not bActionTaken and nLastHarassUtility > object.nMiniaturizationThreshold then
			--graveyard could take up to 500ms after it is cast to stun, so wait at least that long if we just cast it
			if not bTargetRooted and HoN.GetGameTime() > object.nGraveyardUseTime + 600 then
				local abilMiniaturization = skills.abilMiniaturization
				if abilMiniaturization:CanActivate() then
					local nRange = abilMiniaturization:GetRange()
					if nTargetDistanceSq < (nRange * nRange) then
						bActionTaken = core.OrderAbilityEntity(botBrain, abilMiniaturization, unitTarget)
					end
				end
			end
		end
	
		--Silver Bullet
		if not bActionTaken and nLastHarassUtility > object.nSilverBulletThreshold then
			local abilSilverBullet = skills.abilSilverBullet
			local nDamage = 500
			if nLevel == 2 then
				nDamage = 650
			elseif nLevel == 3 then
				nDamage = 850
			end
			
			local nMaxHealth = unitTarget:GetMaxHealth()
			local nHealth = unitTarget:GetHealth()
			local nDamageMultiplier = 1 - unitTarget:GetMagicResistance()
			local nTrueDamage = nDamage * nDamageMultiplier
			local bUseBullet = (core.nDifficulty ~= core.nEASY_DIFFCULTY) or unitTarget:IsBotControlled() or (nHealth - nTrueDamage >= nMaxHealth * 0.12)
			if abilSilverBullet:CanActivate() and bUseBullet then
				local nRange = abilSilverBullet:GetRange()
				if nTargetDistanceSq < (nRange * nRange) then
					bActionTaken = core.OrderAbilityEntity(botBrain, abilSilverBullet, unitTarget)
				end
			end
		end
		
		--Power Drain
		if not bActionTaken and nLastHarassUtility > object.nPowerDrainThreshold then
			local abilPowerDrain = skills.abilPowerDrain
			if abilPowerDrain:CanActivate() and bShouldUsePowerDrain and bHealthHighEnough and bManaHighEnough then
				local nRange = abilPowerDrain:GetRange()
				if nTargetDistanceSq < (nRange * nRange) then
					bActionTaken = core.OrderAbilityEntity(botBrain, abilPowerDrain, unitTarget)
					if bActionTaken then
						object.nPowerDrainExpireTime = HoN.GetGameTime() + 4000
					end
				end
			end
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
--	Witch Slayer items
----------------------------------
behaviorLib.StartingItems = 
	{"Item_GuardianRing", "Item_PretendersCrown", "Item_MinorTotem", "2 Item_ManaPotion", "Item_RunesOfTheBlight"}
behaviorLib.LaneItems = 
	{"Item_ManaRegen3", "Item_Marchers", "Item_Striders", "Item_GraveLocket"} --ManaRegen3 is Ring of the Teacher
behaviorLib.MidItems = 
	{"Item_SacrificialStone", "Item_NomesWisdom", "Item_Astrolabe", "Item_Intelligence7"} --Intelligence7 is Staff of the Master
behaviorLib.LateItems = 
	{"Item_Morph", "Item_BehemothsHeart", 'Item_Damage9'} --Morph is Sheepstick. Item_Damage9 is Doombringer

BotEcho('finished loading tutorialBot3')
