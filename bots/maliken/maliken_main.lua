--malikenBot v1.0


local _G = getfenv(0)
local object = _G.object

object.myName = object:GetName()

object.bRunLogic   	= true
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

BotEcho('loading maliken_main...')

--------------------------------
-- Lanes
--------------------------------
core.tLanePreferences = {Jungle = 0, Mid = 1, ShortSolo = 5, LongSolo = 4, ShortSupport = 1, LongSupport = 1, ShortCarry = 5, LongCarry = 5}

object.heroName = 'Hero_Maliken'

----------------------------------
--	Maliken' specific harass bonuses
--
--  Abilities off cd increase harass util
--  Ability use increases harass util for a time
----------------------------------

object.nSwordThrowUp = 15
object.nPossessionUp = 25

object.nSwordThrowUse = 20
object.nPossessionUse = 40

object.nSwordThrowThreshold = 35
object.nSwordPortThreshold = 50
object.nPossessionThreshold = 50

object.nSwordThrownTime = 0
object.nSwordProjectileSpeed = 850
object.vecSwordSource = nil
object.vecSwordDestination = nil

--  Use sword to blink home.
local nTimeThrewSwordToRetreat = 0
object.nSwordThrowRetreatThreshold = 55

--------------------------------
-- Skills
--------------------------------
-- Skillbuild table, 0=SwordThrow, 1=SwordOfTheDemand, 2=HellbourneZeal, 3=Possession, 4=attri
object.tSkills = {
	0, 1, 0, 1, 0,
	3, 0, 1, 1, 2,
	3, 2, 2, 2, 4,
	3, 4, 4, 4, 4,
	4, 4, 4, 4, 4
}

function object:SkillBuild()
	local unitSelf = self.core.unitSelf	
	
	if  skills.abilSwordThrow == nil then
		skills.abilSwordThrow		= unitSelf:GetAbility(0)
		skills.abilSwordOfTheDamned	= unitSelf:GetAbility(1)
		skills.abilHellbourneZeal	= unitSelf:GetAbility(2)
		skills.abilPossession		= unitSelf:GetAbility(3)
		skills.abilSwordFlame		= unitSelf:GetAbility(5)
		skills.abilSwordHeal		= unitSelf:GetAbility(6)
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

--melee weight overrides
behaviorLib.nCreepPushbackMul = 0.5
behaviorLib.nTargetPositioningMul = 0.6


local function exterpolate(vecPos1, vecPos2, nDistance) -- this is to lock sword target to the max range
	local nAngle = atan2(vecPos2.y-vecPos1.y, vecPos2.x-vecPos1.x)
	return vecPos1 + Vector3.Create(cos(nAngle) * nDistance, sin(nAngle) * nDistance)
end

local function getSwordPosition() --this may be slightly off if Maliken levels his sword mid-throw, but meh.
	local nTimeSinceThrow = HoN:GetGameTime() - object.nSwordThrownTime
	local nThrowMaxLength = 600 + 150 * skills.abilSwordThrow:GetLevel()
	local nSwordProjectileSpeed = object.nSwordProjectileSpeed
	local nTotalThrowDuration = ((2 * nThrowMaxLength) / nSwordProjectileSpeed) * 1000
	if nTimeSinceThrow > nTotalThrowDuration or nTimeSinceThrow < 0 then
		return nil -- Sword shouldn't still be in the air.. unless we are running, ah well, no point teleporting then.
	end
	local vecSource = object.vecSwordSource or core.unitSelf:GetPosition()
	local vecDestination = object.vecSwordDestination
	local nNewTimeSinceThrow = nTimeSinceThrow
	-- change direction if it should have reached the furtherest point
	if nTimeSinceThrow > nTotalThrowDuration / 2 then
		nNewTimeSinceThrow = nTimeSinceThrow - nTotalThrowDuration / 2
		vecSource = object.vecSwordDestination
		vecDestination = core.unitSelf:GetPosition()
	end
	--core.DrawDebugArrow(vecSource, vecDestination, 'green')
	--core.DrawDebugArrow(vecSource, vecSource + nTimeSinceThrow * 0.850 * Vector3.Normalize(vecDestination - vecSource), 'red')
	
	--							time spent in air   speed  direction
	return vecSource + nNewTimeSinceThrow * nSwordProjectileSpeed / 1000 * Vector3.Normalize(vecDestination - vecSource), nTimeSinceThrow / nTotalThrowDuration
end

object.nSwordType = 0 --0 none, 1 damage, 2 heal
function object:onthinkOverride(tGameVariables)
	self:onthinkOld(tGameVariables)
	
	local unitSelf = core.unitSelf
	-- Change our sword depending on our health TODO: This will likely be changed later, when we want to do more damage.
		
	if unitSelf:IsAlive() then--not dead
		local nHealthPercent = unitSelf:GetHealthPercent()
		if nHealthPercent > 0.85 and object.nSwordType ~= 1 and skills.abilSwordFlame:CanActivate() and core.OrderAbility(self, skills.abilSwordFlame) then
			object.nSwordType = 1 -- DAMAGE
			
		elseif nHealthPercent < 0.85 and object.nSwordType ~= 2 and skills.abilSwordHeal:CanActivate() and core.OrderAbility(self, skills.abilSwordHeal) then
				object.nSwordType = 2 -- HEAL
		end
	else
		object.nSwordType = 0
	end
	
end
object.onthinkOld = object.onthink
object.onthink 	= object.onthinkOverride


--Maliken ability use gives bonus to harass util for a while
function object:oncombateventOverride(EventData)
	self:oncombateventOld(EventData)
	
	local bDebugEchos = false
	local nAddBonus = 0
	
	if EventData.Type == "Ability" then
		if bDebugEchos then BotEcho("  ABILILTY EVENT!  InflictorName: "..EventData.InflictorName) end
		if EventData.InflictorName == "Ability_Maliken1" then
			nAddBonus = nAddBonus + self.nSwordThrowUse
		elseif EventData.InflictorName == "Ability_Maliken4" then
			nAddBonus = nAddBonus + self.nPossessionUse
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

--Utility calc override
local function CustomHarassUtilityFnOverride(hero)
	local nUtility = 0
	
	if skills.abilSwordThrow:CanActivate() then
		nUtility = nUtility + object.nSwordThrowUp
	end
	
	if skills.abilPossession:CanActivate() then
		nUtility = nUtility + object.nPossessionUp
	end	
	return nUtility
end
behaviorLib.CustomHarassUtility = CustomHarassUtilityFnOverride   

----------------------------------
--	Maliken harass actions
----------------------------------

local function HarassHeroExecuteOverride(botBrain)
	local unitSelf = core.unitSelf
	local unitTarget = behaviorLib.heroTarget
	
	local vecMyPosition = unitSelf:GetPosition()
	local vecTargetPosition = unitTarget:GetPosition()
	if not unitTarget or not vecTargetPosition then
		return false
	end
	local nTargetDistanceSq = Vector3.Distance2DSq(vecMyPosition, vecTargetPosition)
	
	local nLastHarassUtility = behaviorLib.lastHarassUtil
	--local bCanSee = core.CanSeeUnit(botBrain, unitTarget)	
		
	local bActionTaken = false
		
	--Sword Throw
	if nLastHarassUtility > botBrain.nSwordThrowThreshold then
		local nNow = HoN:GetGameTime()
		local abilSwordThrow = skills.abilSwordThrow
		if abilSwordThrow:CanActivate() and object.nSwordThrownTime + 5000 < nNow and vecTargetPosition and not unitTarget:isMagicImmune() then
			local vecTargetHeading = unitTarget:GetHeading()
			if vecTargetHeading then
				local nEstimatedPosition = vecTargetPosition + vecTargetHeading * 100 -- this could be precise, however that would require a sqrt. Perhaps I'll make a Lib.
				bActionTaken = core.OrderAbilityPosition(botBrain, abilSwordThrow, nEstimatedPosition)
				if (bActionTaken) then
					object.nSwordThrownTime = nNow + 400
					object.vecSwordSource = vecMyPosition
					object.vecSwordDestination = exterpolate(vecMyPosition, nEstimatedPosition, 600 + 150 * abilSwordThrow:GetLevel())
				end
			end
		end
	end
	
	--Sword Port
	if not bActionTaken and nLastHarassUtility > botBrain.nSwordPortThreshold then -- we want to
		local vecSwordPosition = getSwordPosition()
		local abilSwordThrow = skills.abilSwordThrow
		if abilSwordThrow:CanActivate() and vecSwordPosition then -- we can
			if Vector3.Distance2DSq(vecTargetPosition, vecSwordPosition) < 100 * 100 then -- sword is close to target
				bActionTaken = core.OrderAbility(botBrain, abilSwordThrow)
				if bActionTaken then
					object.nSwordThrownTime = 0
				end
			end
		end
	end
	
	--Possession
	if not bActionTaken and nLastHarassUtility > botBrain.nPossessionThreshold then
		local abilPossession = skills.abilPossession
		if abilPossession:CanActivate() then
			local nRange = 350 --actually 400, but we are using a buffer.
			if (nTargetDistanceSq < nRange * nRange) then
				bActionTaken = core.OrderAbility(botBrain, abilPossession)
			end
		end
	end
		
	if not bActionTaken then
		return object.harassExecuteOld(botBrain)
	end
end
object.harassExecuteOld = behaviorLib.HarassHeroBehavior["Execute"]
behaviorLib.HarassHeroBehavior["Execute"] = HarassHeroExecuteOverride

------------------------------------------------------------------
--Retreat execute
------------------------------------------------------------------
function behaviorLib.CustomRetreatExecute(botBrain)
	local bActionTaken = false
	local vecSwordPosition, nSwordTravelPercent = getSwordPosition()
	local abilSwordThrow = skills.abilSwordThrow
	local unitSelf = core.unitSelf
	local nNow = HoN:GetGameTime()
	if abilSwordThrow:CanActivate() and behaviorLib.lastRetreatUtil > object.nSwordThrowRetreatThreshold and not vecSwordPosition and object.nSwordThrownTime + 5000 < nNow then
		bActionTaken = core.OrderBlinkAbilityToEscape(botBrain, abilSwordThrow)
		if (bActionTaken) then
			object.nSwordThrownTime = nNow + 400
			nTimeThrewSwordToRetreat = nNow + 400
			object.vecSwordSource = unitSelf:GetPosition()
			object.vecSwordDestination = behaviorLib.GetSafeBlinkPosition(core.allyWell:GetPosition(), abilSwordThrow:GetRange())
		end
	end

	if not bActionTaken and nTimeThrewSwordToRetreat + 3000 > nNow and nSwordTravelPercent and nSwordTravelPercent >= 0.45 then
		bActionTaken = core.OrderAbility(botBrain, abilSwordThrow)
		if (bActionTaken) then
			nTimeThrewSwordToRetreat = 0
			object.nSwordThrownTime = 0
		end
	end
	return false
end

----------------------------------
--	Maliken's items
----------------------------------	
behaviorLib.StartingItems = 
  {"Item_LoggersHatchet", "Item_IronBuckler", "Item_RunesOfTheBlight"}
behaviorLib.LaneItems = 
  {"Item_Marchers", "Item_Steamboots", "Item_BloodChalice"}
-- Item_Immunity is shrunken head
behaviorLib.MidItems = 
  {"Item_Insanitarius", "Item_Immunity", "Item_ElderParasite", "Item_SolsBulwark"}
--Item_LifeSteal4 is symbol of rage, Item_Lightning2 is Charged Hammer, Item_Critical1 is Riftshards, Item_Weapon3 is Savage Mace
behaviorLib.LateItems = 
  {"Item_LifeSteal4", "Item_DaemonicBreastplate", "Item_BehemothsHeart", "Item_Lightning2", 'Item_Critical1 4', "Item_Weapon3"}


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

BotEcho('finished loading maliken_main')