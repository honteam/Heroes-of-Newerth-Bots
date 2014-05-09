--MagmusBot v1.0


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

BotEcho('loading magmus_main...')

--------------------------------
-- Lanes
--------------------------------
core.tLanePreferences = {Jungle = 0, Mid = 1, ShortSolo = 3, LongSolo = 2, ShortSupport = 4, LongSupport = 4, ShortCarry = 4, LongCarry = 4}

object.heroName = 'Hero_Magmar'


--------------------------------
-- Skills
--------------------------------
function object:SkillBuild()
	local unitSelf = self.core.unitSelf

	if  skills.abilLavaSurge == nil then
		skills.abilLavaSurge		= unitSelf:GetAbility(0)
		skills.abilSteamBath		= unitSelf:GetAbility(1)
		skills.abilVolcanicTouch	= unitSelf:GetAbility(2)
		skills.abilEruption			= unitSelf:GetAbility(3)
		skills.abilAttributeBoost	= unitSelf:GetAbility(4)
	end
	
	if unitSelf:GetAbilityPointsAvailable() <= 0 then
		return
	end
	
	--Ult, Lava Surge, 1 in Steam Bath, 1 in stats, Volcanic Touch, Steam Bath, Stats
	if skills.abilEruption:CanLevelUp() then
		skills.abilEruption:LevelUp()
	elseif skills.abilLavaSurge:CanLevelUp() then
		skills.abilLavaSurge:LevelUp()
	elseif skills.abilSteamBath:GetLevel() < 1 then
		skills.abilSteamBath:LevelUp()		
	elseif skills.abilAttributeBoost:GetLevel() < 1 then
		skills.abilAttributeBoost:LevelUp()
	elseif skills.abilVolcanicTouch:CanLevelUp() then
		skills.abilVolcanicTouch:LevelUp()
	elseif skills.abilSteamBath:CanLevelUp() then
		skills.abilSteamBath:LevelUp()
	else
		skills.abilAttributeBoost:LevelUp()
	end
end

---------------------------------------------------
--                   Overrides                   --
---------------------------------------------------

----------------------------------
--  FindItems Override
----------------------------------
local function funcFindItemsOverride(botBrain)
	object.FindItemsOld(botBrain)

	core.ValidateItem(core.itemPortalKey)
	core.ValidateItem(core.itemFrostfieldPlate)
	
	if core.itemPortalKey and core.itemFrostFieldPlate then
		return
	end

	local inventory = core.unitSelf:GetInventory(false)
	for slot = 1, 6, 1 do
		local curItem = inventory[slot]
		if curItem and not curItem:IsRecipe() then
			if core.itemPortalKey == nil and curItem:GetName() == "Item_PortalKey" then
				core.itemPortalKey = core.WrapInTable(curItem)
			elseif core.itemFrostfieldPlate == nil and curItem:GetName() == "Item_FrostfieldPlate" then
				core.itemFrostfieldPlate = core.WrapInTable(curItem)
			end
		end
	end
end
object.FindItemsOld = core.FindItems
core.FindItems = funcFindItemsOverride


--[[for testing
function object:onthinkOverride(tGameVariables)
	self:onthinkOld(tGameVariables)
	
	-- Insert code here
end
object.onthinkOld = object.onthink
object.onthink 	= object.onthinkOverride
--]]

behaviorLib.nCreepPushbackMul = 0.5
behaviorLib.nTargetPositioningMul = 0.6

----------------------------------
--	Magmus specific harass bonuses
--
--  Abilities off cd increase harass util
--  Ability use increases harass util for a time
----------------------------------

object.nLavaSurgeUp = 13
object.nEruptionUp = 18
object.nFrostfieldUp = 12

object.nPortalKeyUse = 20
object.nLavaSurgeUse = 30
object.nEruptionUse = 70
object.nFrostfieldUse = 10

object.nPortalKeyThreshold = 45
object.nLavaSurgeThreshold = 35
object.nEruptionThreshold = 55
object.nFrostfieldThreshold = 12

local function AbilitiesUpUtilityFn(hero)
	local bDebugLines = false
	local bDebugEchos = false
	
	local val = 0
	
	if skills.abilLavaSurge:CanActivate() then
		val = val + object.nLavaSurgeUp
	end
	
	if skills.abilEruption:CanActivate() then
		val = val + object.nEruptionUp
	end
	
	if object.itemFrostfieldPlate and object.itemFrostfieldPlate:CanActivate() then
		nUtility = nUtility + object.nFrostfieldUp
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

--Magmus ability use gives bonus to harass util for a while
function object:oncombateventOverride(EventData)
	self:oncombateventOld(EventData)
	
	local bDebugEchos = false
	local nAddBonus = 0
	
	if EventData.Type == "Ability" then
		if bDebugEchos then BotEcho("  ABILILTY EVENT!  InflictorName: "..EventData.InflictorName) end
		if EventData.InflictorName == "Ability_Magmar1" then
			nAddBonus = nAddBonus + object.nLavaSurgeUse
		elseif EventData.InflictorName == "Ability_Magmar4" then
			nAddBonus = nAddBonus + object.nEruptionUse
		end
	elseif EventData.Type == "Item" then
		--eventsLib.printCombatEvent(EventData)
		if core.itemPortalKey ~= nil and EventData.InflictorName == core.itemPortalKey:GetName() then
			nAddBonus = nAddBonus + self.nPortalKeyUse
		end
		if core.itemFrostfieldPlate ~= nil and EventData.SourceUnit == nSelfUniqueId and EventData.InflictorName == core.itemFrostfieldPlate:GetName() then
			nAddBonus = nAddBonus + self.nFrostfieldUse
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
local function CustomHarassUtilityOverride(hero)
	local nUtility = AbilitiesUpUtilityFn(hero)
	
	return nUtility
end
behaviorLib.CustomHarassUtility = CustomHarassUtilityOverride   

----------------------------------
--	Magmus harass actions
----------------------------------
object.nEruptionCloseDistanceSq = 300*300

local function HarassHeroExecuteOverride(botBrain)
	local bDebugEchos = false
	
	local unitTarget = behaviorLib.heroTarget
	if unitTarget == nil or not unitTarget:IsValid() then
		return false --can not execute, move on to the next behavior
	end
	
	local unitSelf = core.unitSelf
	
	if unitSelf:IsChanneling() then
		--continue to do so
		return
	end
	
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
	
	if bDebugEchos then BotEcho("Magmus HarassHero at "..nLastHarassUtility) end
	local bActionTaken = false
	
	--portalkey
	if not bActionTaken then
		if bDebugEchos then BotEcho("  No action yet, checking portal key") end
		local itemPortalKey = core.itemPortalKey
		if itemPortalKey then
			local nPortalKeyRange = itemPortalKey:GetRange()
			local nRangeLavaSurge = skills.abilLavaSurge:GetRange()
			if itemPortalKey:CanActivate() and behaviorLib.lastHarassUtil > object.nPortalKeyThreshold then
				if nTargetDistanceSq > (nRangeLavaSurge * nRangeLavaSurge) and nTargetDistanceSq < (nPortalKeyRange*nPortalKeyRange + nRangeLavaSurge*nRangeLavaSurge) then
					if bDebugEchos then BotEcho("PortKey!") end
					vecCenter = core.GetGroupCenter(core.localUnits["EnemyHeroes"])
					if vecCenter then
						bActionTaken = core.OrderItemPosition(botBrain, unitSelf, itemPortalKey, vecCenter)
					end
				end
			end
		end
	end
	
	--lava surge
	if not bActionTaken and not bTargetRooted and nLastHarassUtility > botBrain.nLavaSurgeThreshold then
		if bDebugEchos then BotEcho("  No action yet, checking lava surge") end
		local abilLavaSurge = skills.abilLavaSurge
		if abilLavaSurge:CanActivate() then
			local nRange = abilLavaSurge:GetRange()
			if nTargetDistanceSq < (nRange * nRange) then
				bActionTaken = core.OrderAbilityPosition(botBrain, abilLavaSurge, vecTargetPosition)
			end
		end 
	end
	
	--Frostfield
	if not bActionTaken and not bTargetVuln then 
		local itemFrostfieldPlate = core.itemFrostfieldPlate
		if itemFrostfieldPlate then
			if itemFrostfieldPlate:CanActivate() and nLastHarassUtility > botBrain.nFrostfieldThreshold then
				local nRange = itemFrostfieldPlate:GetTargetRadius()
				if nTargetDistanceSq < (nRange * nRange) * 0.9 then
					if bDebugEchos then BotEcho("Using frostfield") end
					bActionTaken = core.OrderItemClamp(botBrain, unitSelf, itemFrostfieldPlate, false)
				end
			end
		end
	end
	
	--eruption
	if not bActionTaken and nLastHarassUtility > botBrain.nEruptionThreshold then
		if bDebugEchos then BotEcho("  No action yet, checking eruption") end
		local abilEruption = skills.abilEruption
		--activate if we are close to the target AND they are stunned OR our pkey is up AND they're in pkey range
		if abilEruption:CanActivate() then
			--TODO: pkey
			if bTargetRooted and nTargetDistanceSq < botBrain.nEruptionCloseDistanceSq then
				bActionTaken = core.OrderAbility(botBrain, abilEruption)
			end
		end
	end
	
	if not bActionTaken then
		if bDebugEchos then BotEcho("  No action yet, proceeding with normal harass execute.") end
		return object.harassExecuteOld(botBrain)
	end
end
object.harassExecuteOld = behaviorLib.HarassHeroBehavior["Execute"]
behaviorLib.HarassHeroBehavior["Execute"] = HarassHeroExecuteOverride


----------------------------------
--	Magmus specific push
----------------------------------

object.nVolcanicTouchPushWeight = 0.7

--magmus' volcanic touch is {90,130,170,210} magic damage in 400 radius
local function VolcanicTouchPushUtility()
	local nLevel = skills.abilVolcanicTouch:GetLevel()
	local m = 25 --(100/4)
	
	local nUtility = m * nLevel
	
	return nUtility
end

local function PushingStrengthUtilityOverride(myHero)
	local nUtility = object.funcPushUtilityOld(myHero)
	
	local nVolcanicTouchUtility = VolcanicTouchPushUtility() * object.nVolcanicTouchPushWeight
	
	nUtility = nUtility + nVolcanicTouchUtility
	nUtility = Clamp(nUtility, 0, 100)

	return nUtility
end
object.funcPushUtilityOld = behaviorLib.PushingStrengthUtility
behaviorLib.PushingStrengthUtility = PushingStrengthUtilityOverride

-----------------------
-- Return to well
-----------------------
--this is a great function to override with using retreating skills, such as blinks, travels, stuns or slows.
function behaviorLib.CustomReturnToWellExecute(botBrain)
	return core.OrderBlinkItemToEscape(botBrain, core.unitSelf, core.itemPortalKey, true) or core.OrderBlinkAbilityToEscape(botBrain, skills.abilLavaSurge, true)
end

----------------------------------
--	Magmus items
----------------------------------
--[[ list code:
	"# Item" is "get # of these"
	"Item #" is "get this level of the item" --]]
behaviorLib.StartingItems = {"Item_CrushingClaws", "Item_MarkOfTheNovice", "2 Item_RunesOfTheBlight", "2 Item_ManaPotion"}
behaviorLib.LaneItems = {"Item_BloodChalice", "Item_Marchers", "Item_Striders", "Item_Strength5"} --Item_Strength5 is Fortified Bracelet
behaviorLib.MidItems = {"Item_PortalKey", "Item_Immunity", "Item_FrostfieldPlate"} --Immunity is Shrunken Head
behaviorLib.LateItems = {"Item_SpellShards 3", "Item_SolsBulwark", "Item_DaemonicBreastplate", "Item_BehemothsHeart", "Item_Damage9"} --Item_Damage9 is doombringer



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

BotEcho('finished loading magmus_main')

