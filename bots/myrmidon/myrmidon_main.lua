---------------------------------------------------
-- ___  ___                    ______       _    --
-- |  \/  |                    | ___ \     | |   --
-- | .  . |_   _ _ __ _ __ ___ | |_/ / ___ | |_  --
-- | |\/| | | | | '__| '_ ` _ \| ___ \/ _ \| __| --
-- | |  | | |_| | |  | | | | | | |_/ / (_) | |_  --
-- \_|  |_/\__, |_|  |_| |_| |_\____/ \___/ \__| --
--          __/ |                                --
--         |___/                                 --
---------------------------------------------------
--          A HoN Community Bot Project          --
---------------------------------------------------
--                  Created by:                  --
--       DarkFire       VHD       Kairus101      --
---------------------------------------------------

--BUG: Myrm stalled out - no movement, sitting in lane safe away from any units.  Yellow arrow to jungle camps still toggling.  Courier was dead...
--		Perhaps trying to buy on non-existant courier??

-- NOTE: bCanSeeTarget in HarassHeroExecute only needs to be checked if we are using OrderAbilityEntity or OrderItemEntity
-- Note2: I reverted the Steamboots change because the well provides 4% of your max mana/health per second so switching to agi has no effect

--Proposed TO-DO list
--	Items:
--		Refine item choices
--  		Need to decide on gank/support/tank/nuke build (or variable build?)
--			I propose adding Lex Talionis after red boots and chalice. Provides magic armor and nice damage amp to burst skills
--			Consider adding grimoire/lightbrand for boosted magic dmg?  Maybe insanitarious for stronger attacks in ult form?
--			Add BKB for late game so we can fight in ult form up close without getting stunned/nuked?
--		Chalice, use whenever we have > 80%(?) hp but < 60%(?) mana.

--  Retreat behavior
--		Ult if about to die (for +hp)
--		Waveform away (pick node nearest max range wave away from threat).
--			Can we detect incoming damage sources before they hit (MOA nuke, hammer stun, ellonia ult) and wave away?
--		Weed/carp to slow down pursuer?

--  Harass behavior
--		Weed:
--			Test/refine target's location prediction?  Currently using Stolen's RA meteor code, but only tracks current target...
--			If carp active, track target and carp locations.  Estimate intercept and cast weed field so that it triggers at time/location of carp intercept?
--			If target is stunned/slowed/snared/etc, boost aggression on weed?  Easy to land if target not moving!
--		Carp:
--			Cast on targets out of attack range that have HP pot on
--			Set up thresholds/sequence to cast before weed when possible (allow setup synergy for better chance of landing weed field)
--		Wave:
--			For far off targets with low hp, use to close distance in order to get nukes off?
--			For close targets, use in a way to pass through enemy target (to slow target)
--		Ult:
--			Turn on when target is slow/immobalized and we are in close/melee range?


------------------------------------------
--          Bot Initialization          --
------------------------------------------

local _G = getfenv(0)
local object = _G.object

object.myName = object:GetName()

object.bRunLogic = true
object.bRunBehaviors = true
object.bUpdates = true
object.bUseShop = true

object.bRunCommands = true
object.bMoveCommands = true
object.bAttackCommands = true
object.bAbilityCommands = true
object.bOtherCommands = true

object.bReportBehavior = false
object.bDebugUtility = false
object.bDebugExecute = false

object.logger = {}
object.logger.bWriteLog = false
object.logger.bVerboseLog = false

object.core = {}
object.eventsLib = {}
object.metadata = {}
object.behaviorLib = {}
object.skills = {}

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

BotEcho('loading myrmidon_main...')

---------------------------------
--          Constants          --
---------------------------------

core.tLanePreferences = {Jungle = 0, Mid = 3, ShortSolo = 3, LongSolo = 2, ShortSupport = 5, LongSupport = 5, ShortCarry = 2, LongCarry = 2}

-- Myrmidon
object.heroName = 'Hero_Hydromancer'

-- Item buy order. internal names
behaviorLib.StartingItems =
	{"Item_RunesOfTheBlight", "2 Item_MinorTotem", "Item_ManaBattery", "Item_HealthPotion"}
behaviorLib.LaneItems =
	{"Item_Steamboots", "Item_BloodChalice"} --, "Item_Gloves3"}
	--chalice on a bot will be crazy. Just time it before each kill, as you would a taunt.
	--Gloves3 is alchemists bones, faster attack speed + extra gold from jungle creeps. May as well impliment it as the first of it's type.
behaviorLib.MidItems =
	{"Item_ElderParasite", "Item_Platemail"}
behaviorLib.LateItems =
	{"Item_SpellShards", "Item_Lightning2", "Item_Intelligence7", "Item_FrostfieldPlate", "Item_BehemothsHeart"}
	--spellshards, because damage is important.
	--"Lightning2 is charged hammer. More attack speed, right?
	--heart, because we need tankyness now.

-- Skillbuild. 0 is Weed Field, 1 is Magic Carp, 2 is Wave Form, 3 is Forced Evolution, 4 is Attributes
object.tSkills = {
	0, 2, 1, 0, 0,
	3, 0, 1, 1, 2,
	3, 1, 2, 2, 4,
	3, 4, 4, 4, 4,
	4, 4, 4, 4, 4
}

-- Bonus agression points if a skill/item is available for use
object.nWeedFieldUp = 5
object.nMagicCarpUp = 3
object.nWaveFormUp = 2
object.nForcedEvolutionUp = 4

-- Bonus agression points that are applied to the bot upon successfully using a skill/item
object.nWeedFieldUse = 4
object.nMagicCarpUse = 4
object.nWaveFormUse = 2
object.nForcedEvolutionUse = 20

-- Thresholds of aggression the bot must reach to use these abilities
object.nWeedFieldThreshold = 45
object.nWaveFormThreshold = 70 -- was 100
object.nWaveFormRetreatThreshold = 50
object.nForcedEvolutionThreshold = 60

-- Other variables

object.nWeedFieldDelay = 1100 -- nCastTime = 1000 --can we extract this from ability/affector? casttime="500" and castactiontime="100" and impactdelay="1000"

------------------------------
--          Skills          --
------------------------------

function object:SkillBuild()
	core.VerboseLog("SkillBuild()")

	local unitSelf = self.core.unitSelf
	if  skills.abilWeedField == nil then
		skills.abilWeedField = unitSelf:GetAbility(0)
		skills.abilMagicCarp = unitSelf:GetAbility(1)
		skills.abilWaveForm = unitSelf:GetAbility(2)
		skills.abilForcedEvolution = unitSelf:GetAbility(3)
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


----------------------------------------
--          OnThink Override          --
----------------------------------------

local bTrackingCarp=false
local unitCarpTarget

function object:onthinkOverride(tGameVariables)
	self:onthinkOld(tGameVariables)

	local bDebugGadgets=false
	local unitSelf=core.unitSelf

	if (bDebugGadgets or bTrackingCarp) then
		local tUnits = HoN.GetUnitsInRadius(unitSelf:GetPosition(), 2000, core.UNIT_MASK_ALIVE + core.UNIT_MASK_GADGET)
		if tUnits then
			for _, unit in pairs(tUnits) do

				-- CARP
				--Carp speed is 600.
				--Carp gadget is "Gadget_Hydromancer_Ability2_Reveal", and it is at the position of the carp itself.

				if (bTrackingCarp and unit:GetTypeName()=="Gadget_Hydromancer_Ability2_Reveal_Linger") then -- carp is now dead
					bTrackingCarp=false
				end

				if (bDebugGadgets) then
					core.DrawDebugArrow(unitSelf:GetPosition(), unit:GetPosition(), 'yellow') --flint q/r, fairy port, antipull, homecoming, kongor, chronos ult
					BotEcho(unit:GetTypeName())
				end
			end
		end
	end

	-- Toggle Steamboots for more Health/Mana
	local itemSteamboots = core.GetItem("Item_Steamboots")
	if itemSteamboots and itemSteamboots:CanActivate() then
		local unitSelf = core.unitSelf
		local sKey = itemSteamboots:GetActiveModifierKey()
		local sCurrentBehavior = core.GetCurrentBehaviorName(self)
		if sKey == "str" then
			-- Toggle away from STR if health is high enough
			if unitSelf:GetHealthPercent() > .65 or sCurrentBehavior == "UseHealthPot" or sCurrentBehavior == "UseRunesOfTheBlight" then
				self:OrderItem(itemSteamboots.object, false)
			end
		elseif sKey == "agi" then
			-- Toggle away from AGI when we're not using Regen items or at well
			if not unitSelf:HasState("State_ManaPotion") and not unitSelf:HasState("State_RunesOfTheBlight") and not unitSelf:HasState("State_HealthPotion") then
				self:OrderItem(itemSteamboots.object, false)
			end
		elseif sKey == "int" then
			-- Toggle away from INT if health gets too low
			if unitSelf:GetHealthPercent() < .45 or sCurrentBehavior == "UseManaPot" then
				self:OrderItem(itemSteamboots.object, false)
			end
		end
	end
end

object.onthinkOld = object.onthink
object.onthink = object.onthinkOverride

----------------------------------------------
--          OnCombatEvent Override          --
----------------------------------------------

function object:oncombateventOverride(EventData)
	self:oncombateventOld(EventData)

	local nAddBonus = 0

	if EventData.Type == "Ability" then
		if EventData.InflictorName == "Ability_Myrmidon1" then
			nAddBonus = nAddBonus + object.nWeedFieldUse
		elseif EventData.InflictorName == "Ability_Myrmidon2" then
			nAddBonus = nAddBonus + object.nMagicCarpUse
		elseif EventData.InflictorName == "Ability_Myrmidon3" then
			nAddBonus = nAddBonus + object.nWaveFormUse
		elseif EventData.InflictorName == "Ability_Myrmidon4" then
			nAddBonus = nAddBonus + object.nForcedEvolutionUse
		end
	end

	if nAddBonus > 0 then
		core.DecayBonus(self)
		core.nHarassBonus = core.nHarassBonus + nAddBonus
	end
end

object.oncombateventOld = object.oncombatevent
object.oncombatevent = object.oncombateventOverride

----------------------------------------------------
--          CustomHarassUtility Override          --
----------------------------------------------------

local function CustomHarassUtilityFnOverride(hero)
	local nUtility = 0

	if skills.abilWeedField:CanActivate() then
		nUtility = nUtility + object.nWeedFieldUp
	end

	if skills.abilMagicCarp:CanActivate() then
		nUtility = nUtility + object.nMagicCarpUp
	end

	if skills.abilWaveForm:CanActivate() then
		nUtility = nUtility + object.nWaveFormUp
	end

	if skills.abilForcedEvolution:CanActivate() then
		nUtility = nUtility + object.nForcedEvolutionUp
	end

	return nUtility
end

behaviorLib.CustomHarassUtility = CustomHarassUtilityFnOverride

----------------------------------------
--          Weed Field Logic          --
----------------------------------------

-- A fixed list seems to be better then to check on each cycle if its  exist
-- so we create it here
local tRelativeMovements = {}
local function createRelativeMovementTable(sKey)
	--BotEcho('Created a relative movement table for: '..key)
	tRelativeMovements[sKey] = {
		vecLastPos = Vector3.Create(),
		vecRelMov = Vector3.Create(),
		nTimestamp = 0
	}
--	BotEcho('Created a relative movement table for: '..tRelativeMovements[sKey].nTimestamp)
end

createRelativeMovementTable("MyrmField") -- for landing Weed Field

-- tracks movement for targets based on a list, so its reusable
-- sKey is the identifier for different uses (fe. RaMeteor for his path of destruction)
-- vecTargetPos should be passed the targets position of the moment
-- to use this for prediction add the vector to a units position and multiply it
-- the function checks for 100ms cycles so one second should be multiplied by 20
local function relativeMovement(sKey, vecTargetPos)
	local bDebugEchoes = false

	local nGameTime = HoN.GetGameTime()
	local vecLastPos = tRelativeMovements[sKey].vecLastPos
	local nTS = tRelativeMovements[sKey].nTimestamp
	local nTimeDiff = nGameTime - nTS

	if bDebugEchoes then
		BotEcho('Updating relative movement for key: '..sKey)
		BotEcho('Relative Movement position: '..vecTargetPos.x..' | '..vecTargetPos.y..' at timestamp: '..nTS)
		BotEcho('Relative lastPosition is this: '..vecLastPos.x)
	end

	if nTimeDiff >= 90 and nTimeDiff <= 140 then -- 100 should be enough (every second cycle)
		local vecRelativeMov = vecTargetPos-vecLastPos

		if vecTargetPos.LengthSq > vecLastPos.LengthSq	then
			vecRelativeMov =  vecRelativeMov*-1
		end

		tRelativeMovements[sKey].vecRelMov = vecRelativeMov
		tRelativeMovements[sKey].vecLastPos = vecTargetPos
		tRelativeMovements[sKey].nTimestamp = nGameTime


		if bDebugEchoes then
			BotEcho('Relative movement -- x: '..vecRelativeMov.x..' y: '..vecRelativeMov.y)
			BotEcho('^r---------------Return new-'..tRelativeMovements[sKey].vecRelMov.x)
		end

		return vecRelativeMov
	elseif nTimeDiff >= 150 then
		tRelativeMovements[sKey].vecRelMov =  Vector3.Create(0,0)
		tRelativeMovements[sKey].vecLastPos = vecTargetPos
		tRelativeMovements[sKey].nTimestamp = nGameTime
	end

	if bDebugEchoes then BotEcho('^g---------------Return old-'..tRelativeMovements[sKey].vecRelMov.x) end
	return tRelativeMovements[sKey].vecRelMov
end

---------------------------------------
--          Harass Behavior          --
---------------------------------------

local function HarassHeroExecuteOverride(botBrain)

	local unitTarget = behaviorLib.heroTarget
	if unitTarget == nil then
		return object.harassExecuteOld(botBrain)
	end

	local unitSelf = core.unitSelf
	local vecMyPosition = unitSelf:GetPosition()

	local vecTargetPosition = unitTarget:GetPosition()
	local nTargetDistanceSq = Vector3.Distance2DSq(vecMyPosition, vecTargetPosition)
	local bCanSeeTarget = core.CanSeeUnit(botBrain, unitTarget)
	local bMagicImmune = unitTarget:isMagicImmune()

	local nWeedFieldDelay = object.nWeedFieldDelay
	local vecRelativeMov = relativeMovement("MyrmField", vecTargetPosition) * (nWeedFieldDelay / 100) --updating every 100ms

	local nLastHarassUtility = behaviorLib.lastHarassUtil
	local bActionTaken = false


	--Magic Carp
	if not bMagicImmune then
		local abilMagicCarp = skills.abilMagicCarp
		if abilMagicCarp:CanActivate() and bCanSeeTarget then
			local nRange = abilMagicCarp:GetRange()
			if nTargetDistanceSq < (nRange * nRange) then
				bActionTaken = core.OrderAbilityEntity(botBrain, abilMagicCarp, unitTarget)
				if bActionTaken then
					unitCarpTarget = unitTarget
					bTrackingCarp = true
				end
			end
		end
	end

	--Weed Field
	--Currently trying to use Stolen's Ra prediction code.  Consider reworking and track all old hero positions?
	if not bActionTaken then
		local abilWeedField = skills.abilWeedField
		local bDebugEchoes = false
		if not bMagicImmune and abilWeedField:CanActivate() and nLastHarassUtility > object.nWeedFieldThreshold then
			local nRange = abilWeedField:GetRange()
			local vecTargetPredictPosition = vecTargetPosition + vecRelativeMov
			if Vector3.Distance2DSq(vecMyPosition, vecTargetPredictPosition) < nRange * nRange then
				local nCarpMovespeedSq = 600 * 600
				if not bTrackingCarp then
					bActionTaken = core.OrderAbilityPosition(botBrain, abilWeedField, vecTargetPredictPosition)
					if bDebugEchoes then
						BotEcho("Casting weed field!")
					end
				-- If carp homing on target, wait till it gets close?
				elseif ((nWeedFieldDelay * nWeedFieldDelay) / (1000 * 1000)) < (Vector3.Distance2DSq(unitCarpTarget:GetPosition(), vecTargetPredictPosition) / nCarpMovespeedSq) then --perfect time to cast weed field!
					bActionTaken = core.OrderAbilityPosition(botBrain, skills.abilWeedField, vecTargetPredictPosition)
				end
			end
		end

		if bDebugEchoes then
			local nRange = abilWeedField:GetRange()
			core.DrawXPosition(vecTargetPosition + vecRelativeMov, 'red', 100) --vecTargetPredictPosition
			core.DrawDebugArrow(vecTargetPosition, vecTargetPosition + vecRelativeMov, 'red') --predicted target movement path
			core.DrawDebugArrow(vecMyPosition, vecMyPosition + (Vector3.Normalize((vecTargetPosition + vecRelativeMov) - vecMyPosition)) * nRange, 'green') --weed field range aimed at predicted position
		end
	end

	--Wave Form
	if not bActionTaken then
		local bDebugEchoes = false
		local abilWaveForm = skills.abilWaveForm
		if abilWaveForm:CanActivate() and nLastHarassUtility > object.nWaveFormThreshold then
			local nRange = abilWaveForm:GetRange()
			local nWaveOvershoot = 128 --try to get this many units past target to guarantee slow and position nicely to ult or block
			local vecWaveFormTarget = vecTargetPosition + nWaveOvershoot * Vector3.Normalize(vecTargetPosition - vecMyPosition)
			if Vector3.Distance2DSq(vecMyPosition, vecWaveFormTarget) < (nRange * nRange) then
				bActionTaken = core.OrderAbilityPosition(botBrain, abilWaveForm, vecWaveFormTarget)
			else
				bActionTaken = core.OrderAbilityPosition(botBrain, abilWaveForm, vecTargetPosition)
			end
		end

		if bDebugEchoes then
			local nRange = abilWaveForm:GetRange()
			local nWaveOvershoot = 128
			local vecWaveFormTarget = vecTargetPosition + nWaveOvershoot * Vector3.Normalize(vecTargetPosition - vecMyPosition)
			if Vector3.Distance2DSq(vecMyPosition, vecWaveFormTarget) < (nRange * nRange) then
				core.DrawXPosition(vecWaveFormTarget, 'blue', 100)
			else
				core.DrawXPosition(vecMyPosition + Vector3.Normalize(vecTargetPosition - vecMyPosition) * nRange, 'blue', 100)
			end
		end
	end

	--ForcedEvolution
	--Need to check that target is not magic immune or our melee attack will not be effective?
	if not bActionTaken and bCanSeeTarget then
		local abilForcedEvolution = skills.abilForcedEvolution
		if abilForcedEvolution:CanActivate() and nLastHarassUtility > object.nForcedEvolutionThreshold and nTargetDistanceSq < (200 * 200) then
			bActionTaken = core.OrderAbility(botBrain, abilForcedEvolution)
		end
	end

	if not bActionTaken then
		bActionTaken = object.harassExecuteOld(botBrain)
	end

	return bActionTaken
end

object.harassExecuteOld = behaviorLib.HarassHeroBehavior["Execute"]
behaviorLib.HarassHeroBehavior["Execute"] = HarassHeroExecuteOverride

local function funcCustomRetreatFromThreatExecuteOverride(botBrain)

	local unitTarget = behaviorLib.heroTarget
	if unitTarget and core.CanSeeUnit(botBrain, unitTarget) then

		local unitSelf = core.unitSelf

		--Counting the enemies
		local tEnemies = core.localUnits["EnemyHeroes"]
		local nCount = 0
		for _, unitEnemy in pairs(tEnemies) do
			nCount = nCount + 1
		end

		if (nCount > 1 or unitSelf:GetHealthPercent() < .4) then -- More enemies or low on life
			local vecMyPosition = unitSelf:GetPosition()
			local vecTargetPosition = unitTarget:GetPosition()
			local nTargetDistanceSq = Vector3.Distance2DSq(vecMyPosition, vecTargetPosition)

			--WeedField
			local abilWeedField = skills.abilWeedField
			if abilWeedField:CanActivate() then
				local nRange = abilWeedField:GetRange()
				if nTargetDistanceSq < (nRange * nRange) then
					return core.OrderAbilityPosition(botBrain, abilWeedField, vecTargetPosition)
				end
			end

			--Todo? Activate ult if HP < ??% and retreating

			--waveform
			if behaviorLib.lastRetreatUtil> object.nWaveFormRetreatThreshold and core.OrderBlinkAbilityToEscape(botBrain, skills.abilWaveForm) then
				return true
			end
		end
	end
end
behaviorLib.CustomRetreatExecute = funcCustomRetreatFromThreatExecuteOverride

--------------------------------------------------
--             HealAtWell Override              --
--------------------------------------------------

--return to well more often. --2000 gold adds 8 to return utility, 0% mana also adds 8.
--When returning to well, use skills and items.
local function HealAtWellUtilityOverride(botBrain)
	return object.HealAtWellUtilityOld(botBrain)*1.75+(botBrain:GetGold()*8/2000)+ 8-(core.unitSelf:GetManaPercent()*8) --couragously flee back to base.
end

local function CustomReturnToBase(botBrain)
	return 	core.OrderBlinkAbilityToEscape(botBrain, skills.abilWaveForm)
end

object.HealAtWellUtilityOld = behaviorLib.HealAtWellBehavior["Utility"]
behaviorLib.HealAtWellBehavior["Utility"] = HealAtWellUtilityOverride
behaviorLib.CustomReturnToWellExecute = CustomReturnToBase

--------------------------------------------
--          PushExecute Override          --
--------------------------------------------
local function CustomPushExecuteFnOverride(botBrain)
	local bActionTaken = false
	local nMinimumCreeps = 3

	local abilWeedField = skills.abilWeedField
	if abilWeedField:CanActivate() and core.unitSelf:GetManaPercent() > 0.4 then
		local tCreeps = core.localUnits["EnemyCreeps"]
		local nNumberCreeps =  core.NumberElements(tCreeps)
		if nNumberCreeps >= nMinimumCreeps then
			local vecTarget = core.GetGroupCenter(tCreeps)
			bActionTaken = core.OrderAbilityPosition(botBrain, abilWeedField, vecTarget)
		end
	end

	return bActionTaken
end
behaviorLib.customPushExecute = CustomPushExecuteFnOverride

local function TeamGroupBehaviorOverride(botBrain)
	if not CustomPushExecuteFnOverride(botBrain) then
		return object.TeamGroupBehaviorOld(botBrain)
	end
end

object.TeamGroupBehaviorOld = behaviorLib.TeamGroupBehavior["Execute"]
behaviorLib.TeamGroupBehavior["Execute"] = TeamGroupBehaviorOverride

BotEcho(object:GetName()..' finished loading myrmidon_main')