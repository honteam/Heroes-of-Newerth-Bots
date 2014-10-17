--WitchSlayerBot v1.0


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

BotEcho('loading witchslayer_main...')

object.heroName = 'Hero_WitchSlayer'

--------------------------------
-- Lanes
--------------------------------
core.tLanePreferences = {Jungle = 0, Mid = 2, ShortSolo = 2, LongSolo = 1, ShortSupport = 5, LongSupport = 5, ShortCarry = 2, LongCarry = 1}

--------------------------------
-- Skills
--------------------------------
local bSkillsValid = false
function object:SkillBuild()
	local unitSelf = self.core.unitSelf	
	
	if not bSkillsValid then
		skills.abilGraveyard		= unitSelf:GetAbility(0)
		skills.abilMiniaturization	= unitSelf:GetAbility(1)
		skills.abilPowerDrain		= unitSelf:GetAbility(2)
		skills.abilSilverBullet		= unitSelf:GetAbility(3)
		skills.abilAttributeBoost	= unitSelf:GetAbility(4)
		
		if skills.abilGraveyard and skills.abilMiniaturization and skills.abilPowerDrain and skills.abilSilverBullet and skills.abilAttributeBoost then
			bSkillsValid = true
		else
			return
		end
	end
	
	if unitSelf:GetAbilityPointsAvailable() <= 0 then
		return
	end
	
	if skills.abilSilverBullet:CanLevelUp() then
		skills.abilSilverBullet:LevelUp()
	elseif skills.abilGraveyard:CanLevelUp() then
		skills.abilGraveyard:LevelUp()
	elseif skills.abilPowerDrain:GetLevel() < 1 then
		skills.abilPowerDrain:LevelUp()
	elseif skills.abilMiniaturization:CanLevelUp() then
		skills.abilMiniaturization:LevelUp()
	elseif skills.abilPowerDrain:CanLevelUp() then
		skills.abilPowerDrain:LevelUp()
	else
		skills.abilAttributeBoost:LevelUp()
	end
end

---------------------------------------------------
--                   Overrides                   --
---------------------------------------------------

--[[for testing
function object:onthinkOverride(tGameVariables)
	self:onthinkOld(tGameVariables)
	
	core.unitSelf:TeamShare()
	
	-- Insert code here
end
object.onthinkOld = object.onthink
object.onthink 	= object.onthinkOverride
--]]


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
object.nSilverBulletThreshold = 60
object.nSheepstickThreshold = 30

local function AbilitiesUpUtility(hero)
	local bDebugLines = false
	local bDebugEchos = false
	
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
object.nGraveyardRangeBuffer = -100 --since our stun isn't instant, subtract some padding

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
	local bCanSee = core.CanSeeUnit(botBrain, unitTarget)	
	
	if bDebugEchos then BotEcho("Witch Slayer HarassHero at "..nLastHarassUtility) end
	local bActionTaken = false

	--since we are using an old pointer, ensure we can still see the target for entity targeting
	if core.CanSeeUnit(botBrain, unitTarget) then
		local bTargetVuln = unitTarget:IsStunned() or unitTarget:IsImmobilized()

		--Sheepstick
		if not bActionTaken and not bTargetVuln then
			local itemSheepstick = core.itemSheepstick
			if itemSheepstick then
				local nRange = itemSheepstick:GetRange()
				if itemSheepstick:CanActivate() and nLastHarassUtility > botBrain.nSheepstickThreshold then
					if nTargetDistanceSq < (nRange * nRange) then
						bActionTaken = core.OrderItemEntityClamp(botBrain, unitSelf, itemSheepstick, unitTarget)
					end
				end
			end
		end
	end
	
	--Graveyard
	if not bActionTaken and not bTargetRooted and nLastHarassUtility > botBrain.nGraveyardThreshold then
		if bDebugEchos then BotEcho("  No action yet, checking graveyard") end
		local abilGraveyard = skills.abilGraveyard
		if abilGraveyard:CanActivate() then
			local nRange = 950 --[[abilGraveyard:GetRange()]] + botBrain.nGraveyardRangeBuffer
			if nTargetDistanceSq < (nRange * nRange) then
				--calculate a target since our range doesn't match the ability effective range
				local vecToward = Vector3.Normalize(vecTargetPosition - vecMyPosition)
				local vecAbilityTarget = vecMyPosition + vecToward * 250
				bActionTaken = core.OrderAbilityPosition(botBrain, abilGraveyard, vecAbilityTarget)
			end
		end
	end
	
	--since we are using an old pointer, ensure we can still see the target for entity targeting	
	if core.CanSeeUnit(botBrain, unitTarget) then		
		--Miniaturization
		if not bActionTaken and nLastHarassUtility > botBrain.nMiniaturizationThreshold then
			--graveyard could take up to 500ms after it is cast to stun, so wait at least that long if we just cast it
			if not bTargetRooted and HoN.GetGameTime() > object.nGraveyardUseTime + 600 then
				if bDebugEchos then BotEcho("  No action yet, checking miniaturization") end
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
		if not bActionTaken and nLastHarassUtility > botBrain.nSilverBulletThreshold then
			if bDebugEchos then BotEcho("  No action yet, checking silver bullet") end
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
	end
	
	--aggressive Power Drain?
	
	if not bActionTaken then
		if bDebugEchos then BotEcho("  No action yet, proceeding with normal harass execute.") end
		return object.harassExecuteOld(botBrain)
	end
end
object.harassExecuteOld = behaviorLib.HarassHeroBehavior["Execute"]
behaviorLib.HarassHeroBehavior["Execute"] = HarassHeroExecuteOverride


--TODO: Power Drain

----------------------------------
--  FindItems Override
----------------------------------
local function funcFindItemsOverride(botBrain)
	object.FindItemsOld(botBrain)

	core.ValidateItem(core.itemSheepstick)
	
	--only update if we need to
	if core.itemSheepstick then
		return
	end

	local inventory = core.unitSelf:GetInventory(false)
	for slot = 1, 6, 1 do
		local curItem = inventory[slot]
		if curItem and not curItem:IsRecipe() then
			if core.itemSheepstick == nil and curItem:GetName() == "Item_Morph" then
				core.itemSheepstick = core.WrapInTable(curItem)
			end
		end
	end
end
object.FindItemsOld = core.FindItems
core.FindItems = funcFindItemsOverride

----------------------------------
--	Witch Slayer items
----------------------------------
--[[ list code:
	"# Item" is "get # of these"
	"Item #" is "get this level of the item" --]]
behaviorLib.StartingItems = 
	{"Item_GuardianRing", "Item_PretendersCrown", "Item_MinorTotem", "Item_HealthPotion", "Item_RunesOfTheBlight"}
behaviorLib.LaneItems = 
	{"Item_ManaRegen3", "Item_Marchers", "Item_Striders", "Item_GraveLocket"} --ManaRegen3 is Ring of the Teacher
behaviorLib.MidItems = 
	{"Item_SacrificialStone", "Item_NomesWisdom", "Item_Astrolabe", "Item_Intelligence7"} --Intelligence7 is Staff of the Master
behaviorLib.LateItems = 
	{"Item_Morph", "Item_BehemothsHeart", 'Item_Damage9'} --Morph is Sheepstick. Item_Damage9 is Doombringer



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

BotEcho('finished loading witchslayer_main')
