-------------------------------------------------------------------
-------------------------------------------------------------------
--   ____     __               ___    ____             __        --
--  /\  _`\  /\ \             /\_ \  /\  _`\          /\ \__     --
--  \ \,\L\_\\ \ \/'\       __\//\ \ \ \ \L\ \    ___ \ \ ,_\    --
--   \/_\__ \ \ \ , <     /'__`\\ \ \ \ \  _ <'  / __`\\ \ \/    --
--     /\ \L\ \\ \ \\`\  /\  __/ \_\ \_\ \ \L\ \/\ \L\ \\ \ \_   --
--     \ `\____\\ \_\ \_\\ \____\/\____\\ \____/\ \____/ \ \__\  --
--      \/_____/ \/_/\/_/ \/____/\/____/ \/___/  \/___/   \/__/  --
-------------------------------------------------------------------
-------------------------------------------------------------------
-- Skelbot v0.0000008
-- This bot represent the BARE minimum required for HoN to spawn a bot
-- and contains some very basic overrides you can fill in
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
local ceil, floor, pi, tan, atan, atan2, abs, cos, sin, acos, max, random
    = _G.math.ceil, _G.math.floor, _G.math.pi, _G.math.tan, _G.math.atan, _G.math.atan2, _G.math.abs, _G.math.cos, _G.math.sin, _G.math.acos, _G.math.max, _G.math.random

local BotEcho, VerboseLog, BotLog = core.BotEcho, core.VerboseLog, core.BotLog
local Clamp = core.Clamp


BotEcho(object:GetName()..' loading cd_main...')

local nChargeTime = 0
local bChargeTimer = false
local bChargeCountdown = false

--####################################################################
--####################################################################
--#                                                                 ##
--#                  bot constant definitions                       ##
--#                                                                 ##
--####################################################################
--####################################################################

-- hero_<hero>  to reference the internal hon name of a hero, Hero_Yogi ==wildsoul
object.heroName = 'Hero_CorruptedDisciple'

--   item buy order. internal names  
behaviorLib.StartingItems  = {}
behaviorLib.LaneItems  = {}
behaviorLib.MidItems  = {}
behaviorLib.LateItems  = {}

-- skillbuild table, 0=q, 1=w, 2=e, 3=r, 4=attri
object.tSkills = {
    0, 1, 0, 1, 0,
    3, 0, 1, 1, 2, 
    3, 2, 2, 2, 4,
    3, 4, 4, 4, 4,
    4, 4, 4, 4, 4,
}

-- Bonus aggression if skills are up
object.nElectricTideUp = 15
object.nConduitUp = 15
object.nUltUp = 25

-- Bonus aggression if skills are used
object.nElectricTideUse = 5
object.nConduitUse = 10
object.nUltUse = 25

-- Thresholds for skills to be used
object.nElectricTideThreshold = 35
object.nConduitThreshold = 55
object.nUltThreshold = 65

local nMoveSpeedAggression = 0
local nConduitAggression = 2





--####################################################################
--####################################################################
--#                                                                 ##
--#   bot function overrides                                        ##
--#                                                                 ##
--####################################################################
--####################################################################

------------------------------
--     Skills               --
------------------------------
-- @param: none
-- @return: none
function object:SkillBuild()
    core.VerboseLog("skillbuild()")

-- takes care at load/reload, <name_#> to be replaced by some convinient name.
    local unitSelf = self.core.unitSelf
    if  skills.abilQ == nil then
        skills.abilQ = unitSelf:GetAbility(0)
        skills.abilW = unitSelf:GetAbility(1)
        skills.abilE = unitSelf:GetAbility(2)
        skills.abilR = unitSelf:GetAbility(3)
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
	if bChargeTimer then
		nChargeTime = nChargeTime + 50
		--BotEcho("Time:"..nChargeTime)
	end
	if bChargeCountdown then
		nChargeTime = nChargeTime - 50
		--BotEcho("Time:"..nChargeTime)
		
		if nChargeTime <= 0 then
			bChargeCountdown = false
			nChargeTime = 0
		end
	end
end
object.onthinkOld = object.onthink
object.onthink 	= object.onthinkOverride




----------------------------------------------
--            oncombatevent override        --
-- use to check for infilictors (fe. buffs) --
----------------------------------------------
-- @param: eventdata
-- @return: none
function object:oncombateventOverride(EventData)
	self:oncombateventOld(EventData)

	local bDebugEchos = false
	local nAddBonus = 0
	
	if EventData.Type == "Ability" then
		--BotEcho("  ABILILTY EVENT!  InflictorName: "..EventData.InflictorName)
		if EventData.InflictorName == "Ability_CorruptedDisciple1" then
			nAddBonus = nAddBonus + object.nElectricTideUse
		elseif EventData.InflictorName == "Ability_CorruptedDisciple2" then
			nAddBonus = nAddBonus + object.nConduitUse
		elseif EventData.InflictorName == "Ability_CorruptedDisciple4" then
			nAddBonus = nAddBonus + object.nUltUse
		end
	end
	
	if nAddBonus > 0 then
		core.DecayBonus(self)
		core.nHarassBonus = core.nHarassBonus + nAddBonus
	end
	
end
-- override combat event trigger function.
object.oncombateventOld = object.oncombatevent
object.oncombatevent     = object.oncombateventOverride


------------------------------------------------------
--            customharassutility override          --
-- change utility according to usable spells here   --
------------------------------------------------------
-- @param: iunitentity hero
-- @return: number
local function CustomHarassUtilityFnOverride(hero)
    local bDebugEchos = false
	
	local val = 0
	
	if skills.abilQ:CanActivate() then
		val = val + object.nElectricTideUp
	end
	
	if skills.abilW:CanActivate() then
		val = val + object.nConduitUp
	end

	if skills.abilR:CanActivate() then
		val = val + object.nUltUp
	end
	
	if bDebugEchos then BotEcho(" HARASS - abilitiesUp: "..val) end

    return val
end
-- assisgn custom Harrass function to the behaviourLib object
behaviorLib.CustomHarassUtilityFn = CustomHarassUtilityFnOverride   




--------------------------------------------------------------
--                    Harass Behavior                       --
-- All code how to use abilities against enemies goes here  --
--------------------------------------------------------------
-- @param botBrain: CBotBrain
-- @return: none
--

local function GetBestConduitTarget()
	local unitSelf = core.unitSelf
    local vecMyPosition = unitSelf:GetPosition() 
	local bestTarget = nil
	local damage = 0
	local nRange = skills.abilW:GetRange()

	local tTargets = HoN.GetUnitsInRadius(vecMyPosition, nRange, core.UNIT_MASK_ALIVE + core.UNIT_MASK_HERO)
	for i, hero in pairs(tTargets) do
		if (hero:GetTeam() ~= unitSelf:GetTeam()) then
			if(hero:GetFinalAttackDamageMax() > damage) then
				damage = hero:GetFinalAttackDamageMax()
				bestTarget = hero
			end
		end
	end

	return bestTarget
end

local function HarassHeroExecuteOverride(botBrain)
	local bDebugEchos = false
	
    local unitTarget = behaviorLib.heroTarget
    if unitTarget == nil then
        return object.harassExecuteOld(botBrain) --Target is invalid, move on to the next behavior
    end
    
    
	-- Corrupted Disciple variables (unitSelf)
    local unitSelf = core.unitSelf
    local vecMyPosition = unitSelf:GetPosition() 
    local nAttackRange = core.GetAbsoluteAttackRangeToUnit(unitSelf, unitTarget)
    local nMyExtraRange = core.GetExtraRange(unitSelf)
	
	local nMoveSpeed = unitSelf:GetMoveSpeed()
    
    local nLastHarassUtility = behaviorLib.lastHarassUtil
    local bCanSee = core.CanSeeUnit(botBrain, unitTarget)    
	
    local bActionTaken = false
	
	-- Target variables
    local vecTargetPosition = unitTarget:GetPosition()
    local nTargetExtraRange = core.GetExtraRange(unitTarget)
    local nTargetDistanceSq = Vector3.Distance2DSq(vecMyPosition, vecTargetPosition)
	
	local nTargetMagicResist = unitTarget:GetMagicResistance()
	local nTargetHealth = unitTarget:GetHealth()
	local nTargetMoveSpeed = unitTarget:GetMoveSpeed()
	
	-- Ability variables
	local abilElectricTide= skills.abilQ
	local levelQ = skills.abilQ:GetLevel()
	
	local abilConduit = skills.abilW
	local nChargesW = abilConduit:GetCharges()
	local levelW = skills.abilW:GetLevel()
	local nConduitRange = abilConduit:GetRange()
	local nConduitPerCharge = 2
	
	local abilUlt = skills.abilR
	local levelR = skills.abilR:GetLevel()
	
	-- Add aggression based on movespeed difference
	if nMoveSpeed > nTargetMoveSpeed then
		nMoveSpeedAggression = (((nMoveSpeed/nTargetMoveSpeed)*4)*3)
	else
		nMoveSpeedAggression = 0
	end
	
	nLastHarassUtility = (nLastHarassUtility + nMoveSpeedAggression)
	
	--BotEcho("Movespeedaggression:"..nMoveSpeedAggression)

	-- | Electric Tide (Q) |----------------------------------------
	local nTideRange = abilElectricTide:GetTargetRadius()
	local nTideMaxDamage = 140
	local nTideMinDamage = 80
	
	if levelQ == 2 then
		nTideMaxDamage = 210
		nTideMinDamage = 120
	elseif levelQ == 3 then
		nTideMaxDamage = 280
		nTideMinDamage = 160
	elseif levelQ == 4 then
		nTideMaxDamage = 350
		nTideMinDamage = 200
	end
	
	if nTargetMagicResist == nil then
		nTargetMagicResist = 0.248
	end
	
	local nMaxTrueDamageQ = (nTideMaxDamage * (1 - nTargetMagicResist))
	local nMinTrueDamageQ = (nTideMinDamage * (1 - nTargetMagicResist))
	
	--BotEcho("TrueDMGQ:"..nMaxTrueDamageQ)
	
		-- Use if visible, aggression is high enough, can be activated and in range
		if bCanSee then
			if not bActionTaken and nLastHarassUtility > object.nElectricTideThreshold then
				if abilElectricTide:CanActivate() then
					--BotEcho('Checking Electric Tide')
					if nTargetDistanceSq < (nTideRange * nTideRange) then
						--BotEcho('Electric Tide activated')
						bActionTaken = core.OrderAbility(botBrain, abilElectricTide)
					end
				end
			end
		end
		
		-- Use if visible, in range and target has less health than the total damage of Electric Tide (will kill)
		if bCanSee then
			if abilElectricTide:CanActivate() and nTargetDistanceSq < (nTideRange * nTideRange) and nTargetHealth < nMaxTrueDamageQ then
				bActionTaken = core.OrderAbility(botBrain, abilElectricTide)
			end
		end
	
		

	-- | Corrupted Conduit (W) | --------------------------------------------------------------
	
	-- If the timer has started, check if the target has the Conduit state, if it has: add aggression every second (every charge). If target doesnt have state: disable chargetimer and start countdown (13 seconds until the state dissappears).
	if bChargeTimer then
		if unitTarget:HasState("State_CorruptedDisciple_Ability2_Enemy") then
			--BotEcho("TRUE")
			if nChargeTime >= 1000 then
				nConduitAggression = (nConduitAggression + nConduitPerCharge)
				nChargeTime = 0
				nLastHarassUtility = (nLastHarassUtility + nConduitAggression)
			end
		else 
			bChargeTimer = false
			nChargeTime = 12750
			bChargeCountdown = true
		end
	end
	
	if not bChargeCountdown and not bChargeTimer then -- If the timers arent on, reset Conduit Aggression to 2
		nConduitAggression = 2
	end
	
	-- Use if visible, aggression is high enough, in range (a range between attack and conduit)
	-- Starts the timer for the charges (bChargeTimer)
	if bCanSee then
		if not bActionTaken and nLastHarassUtility > object.nConduitThreshold then
			if abilConduit:CanActivate() then
				--BotEcho('Checking Conduit')
				if nTargetDistanceSq < (nConduitRange * nAttackRange) then
					--BotEcho('Conduit activated')
					unitTarget = GetBestConduitTarget()
					bActionTaken = core.OrderAbilityEntity(botBrain, abilConduit, unitTarget)
					bChargeTimer = true
				end
			end
		end
	end
			

	-- | Overload (R) | -------------------------------------------------------------------------
	if bCanSee then
		if not bActionTaken and nLastHarassUtility > object.nUltThreshold then
			if abilUlt:CanActivate() then
				local nRange = abilUlt:GetRange()
				if nTargetDistanceSq < (nAttackRange * nAttackRange) then
					--BotEcho('Overload activated')
					bActionTaken = core.OrderAbility(botBrain, abilUlt)
				end
			end
		end
	end
    
    
    	--BotEcho("CDAgg: "..nConduitAggression.." Harass: "..nLastHarassUtility.." Time: "..nChargeTime)
    
    if not bActionTaken then
		if bDebugEchos then BotEcho("  No action yet, proceeding with normal harass execute.") end
        return object.harassExecuteOld(botBrain)
    end 
end
-- overload the behaviour stock function with custom 
object.harassExecuteOld = behaviorLib.HarassHeroBehavior["Execute"]
behaviorLib.HarassHeroBehavior["Execute"] = HarassHeroExecuteOverride


behaviorLib.StartingItems = {"Item_DuckBoots", "4 Item_MinorTotem", "Item_HealthPotion", "Item_RunesOfTheBlight"}
behaviorLib.LaneItems = {"Item_Marchers", "Item_Shield2", "Item_EnhancedMarchers", "Item_MysticVestments"} --Item_Shield2 = Helm of the black legion
behaviorLib.MidItems = {"Item_Sicarius", "Item_Strength6", "Item_Dawnbringer", "Item_MagicArmor2"} -- Item_Sicarius = Firebrand, Item_Strength6 = Icebrand, Item_MagicArmo2 = Shaman's Headdress
behaviorLib.LateItems = {"Item_Weapon3", "Item_Lightning2", "Item_Evasion" } --Weapon3 is Savage Mace. Item_Lightning2 = Charged Hammer, Item_Evasion = Wingbow

BotEcho('finished loading cd_main')



