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
-- Skelbot v0.0000006
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
runfile "bots/eventslib.lua"
runfile "bots/metadata.lua"
runfile "bots/behaviorlib.lua"

local core, eventsLib, behaviorLib, metadata, skills = object.core, object.eventsLib, object.behaviorLib, object.metadata, object.skills

local print, ipairs, pairs, string, table, next, type, tinsert, tremove, tsort, format, tostring, tonumber, strfind, strsub
	= _G.print, _G.ipairs, _G.pairs, _G.string, _G.table, _G.next, _G.type, _G.table.insert, _G.table.remove, _G.table.sort, _G.string.format, _G.tostring, _G.tonumber, _G.string.find, _G.string.sub
local ceil, floor, pi, tan, atan, atan2, abs, cos, sin, acos, max, random
	= _G.math.ceil, _G.math.floor, _G.math.pi, _G.math.tan, _G.math.atan, _G.math.atan2, _G.math.abs, _G.math.cos, _G.math.sin, _G.math.acos, _G.math.max, _G.math.random

local BotEcho, VerboseLog, BotLog = core.BotEcho, core.VerboseLog, core.BotLog
local Clamp = core.Clamp

BotEcho(object:GetName()..' Monkey King Gokuu Starting Up...')




--####################################################################
--####################################################################
--#                                                                 ##
--#                  bot constant definitions                       ##
--#                                                                 ##
--####################################################################
--####################################################################

-- Hero_<hero>  to reference the internal HoN name of a hero, Hero_Yogi ==Wildsoul
object.heroName = 'Hero_MonkeyKing'


--   Item Buy order. Internal names  
behaviorLib.StartingItems  = { "Item_RunesOfTheBlight", "Item_IronBuckler", "Item_LoggersHatchet"}
behaviorLib.LaneItems  = {"Item_Marchers","Item_ManaBattery"}
behaviorLib.MidItems  = {"Item_EnhancedMarchers","Item_PowerSupply","Item_Regen","Item_Stealth"}
behaviorLib.LateItems  = {"Item_Protect","Item_ManaBurn2","Item_Freeze","Item_Sasuke","Item_DaemonicBreastplate","Item_Damage9"}


-- Skillbuild table, 0=Q, 1=W, 2=E, 3=R, 4=Attri
object.tSkills = {
    0, 1, 2, 1, 1,
    3, 1, 2, 2, 2, 
    3, 0, 0, 0, 4,
    3, 4, 4, 4, 4,
    4, 4, 4, 4, 4,
}

--melee weight overrides
behaviorLib.nCreepPushbackMul = 0.5
behaviorLib.nTargetPositioningMul = 0.6

-- bonus agression points if a skill/item is available for use

object.nIllusiveUp = 20
object.nVaultUp = 30 
object.nSlamUp = 20
object.nStealthUp = 40
object.nIllusionUp = 20

-- bonus agression points that are applied to the bot upon successfully using a skill/item

object.nIllusiveUse = 10
object.nVaultUse = 10 
object.nSlamUse = 10
object.nStealthUse = 40
object.nIllusionUse = 20

--thresholds of aggression the bot must reach to use these abilities

object.nIllusiveThreshold = 40
object.nVaultThreshold = 20 
object.nVault2Threshold = 60 
object.nSlamThreshold = 80
object.nStealthThreshold = 30
object.nIllusionThreshold = 30
object.nTauntThreshold = 50

--retreat thresholds

object.nretreatStealthThreshold = 60


--####################################################################
--####################################################################
--#                                                                 ##
--#                  Kill Chat Override                    ##
--#                                                                 ##
--####################################################################
--####################################################################

object.killMessages = {}
object.killMessages.General = {
	"Didn't even break a sweat!","KA-ME-HA-ME-HA!!!","Wake me up when you're done monkeying around"
	}
object.killMessages.Hero_Accursed = {
	"Such a dull blade won't kill me", "You're just falling apart!"
	}
object.killMessages.Hero_Arachna = {
	"Ewww, I think I stepped on a bug", "That's one pest out of my hair"
	}
object.killMessages.Hero_Chronos = {
	"Bet you didn't see that coming!", "Not even time can stop me!"
	}
object.killMessages.Hero_Defiler = {
	"Ugh, get your slimy hands off me", "From what rock did you crawl out under from?"
	}
object.killMessages.Hero_Engineer = {
	"What the hell are you mumbling about!?", "What a waste of a good drink", "Your turret's your best friend? Forever alone much?", "Get a life basement dweller!"
	}
object.killMessages.Hero_Kunas = {
	"Monkey beats ape anytime!", "Here, have a banana!", "You ain't no King Kong", "Too busy eating lice off your back?"
	}
object.killMessages.Hero_Shaman = {
	"Wow you really must be demented to suck that much", "Keep the mask on, no one wants to see your ugly mug"
	}
object.killMessages.Hero_MonkeyKing = { 
	"I won't lose to my own clone!", "The original is always the best!", "There is only one true Monkey King!" 
	}
object.killMessages.Hero_Frosty = {
	"You don't tell me to chill!", "Let's break the ice shall we?", "Sorry pal, but I'm just cooler than you"
	}
object.killMessages.Hero_Gemini = {
	"Play Dead! Oh wait, you're not playing?", "Never was a dog-person"
	}
object.killMessages.Hero_Scout = {
	"You can't disarm me!", "Scouted and Routed!", "And here I thought I was the only monkey around here"
	}
object.killMessages.Hero_Rocky = {
	"I break rocks in my sleep", "Pebbles? Huh, guess your name speaks for you", "Duuuuuuude it's Stun THEN Chuck!!!"
	}
 
local function ProcessKillChatOverride(unitTarget, sTargetPlayerName)
    local nCurrentTime = HoN.GetGameTime()
    if nCurrentTime < core.nNextChatEventTime then
        return
    end   
     
    local nToSpamOrNotToSpam = random()
         
    if(nToSpamOrNotToSpam < core.nKillChatChance) then
        local nDelay = random(core.nChatDelayMin, core.nChatDelayMax) 
        local tHeroMessages = object.killMessages[unitTarget:GetTypeName()]
	
	local sTargetName = sTargetPlayerName or unitTarget:GetDisplayName()
        if tHeroMessages ~= nil and random() <= 0.7 then
            local nMessage = random(#tHeroMessages)
            core.AllChat(format(tHeroMessages[nMessage], sTargetPlayerName), nDelay)
        else
            local nMessage = random(#object.killMessages.General) 
            core.AllChat(format(object.killMessages.General[nMessage], sTargetPlayerName), nDelay)
        end
    end
     
    core.nNextChatEventTime = nCurrentTime + core.nChatEventInterval
end
core.ProcessKillChat = ProcessKillChatOverride 

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
    core.VerboseLog("SkillBuild()")

-- takes care at load/reload, <name_#> to be replaced by some convinient name.
    local unitSelf = self.core.unitSelf
    if  skills.abilQ == nil then
        skills.abilQ = unitSelf:GetAbility(0)
        skills.abilW = unitSelf:GetAbility(1)
        skills.abilE = unitSelf:GetAbility(2)
        skills.abilR = unitSelf:GetAbility(3)
        skills.abilAttributeBoost = unitSelf:GetAbility(4)
	skills.abilT = unitSelf:GetAbility(8) -- Taunt
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
		if EventData.InflictorName == "Ability_MonkeyKing1" then
		    nAddBonus = nAddBonus + object.nIllusiveUse
		elseif EventData.InflictorName == "Ability_MonkeyKing2" then
		    nAddBonus = nAddBonus + object.nVaultUse
		elseif EventData.InflictorName == "Ability_MonkeyKing3" then
		    nAddBonus = nAddBonus + object.nSlamUse
		end
	elseif EventData.Type == "Item" then
		if core.itemStealth ~= nil and EventData.SourceUnit == core.unitSelf:GetUniqueID() and EventData.InflictorName == core.itemStealth:GetName() then
			addBonus = addBonus + self.nStealthUse
		end
		if core.itemIllusion ~= nil and EventData.SourceUnit == core.unitSelf:GetUniqueID() and EventData.InflictorName == core.itemIllusion:GetName() then
			addBonus = addBonus + self.nIllusion
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

------------------------------
--
------------------------------
function IsEnemyTowerNear(unit)
	-- Initializing the Tower Table
	local uTower = {}
	
	local nTowerRange = 821.6
	local vecMyPosition = unit:GetPosition() 
	local tBuildings = HoN.GetUnitsInRadius(vecMyPosition, nTowerRange, core.UNIT_MASK_ALIVE + core.UNIT_MASK_BUILDING)
	for key, unitBuilding in pairs(tBuildings) do
		if unitBuilding:IsTower() and unitBuilding:GetCanAttack() and (unitBuilding:GetTeam()==unit:GetTeam())==false then
			
			-- Checking if the Tower is Targeting The Unit
			
			local unitAggroTarget = unitBuilding:GetAttackTarget()
			
			if unitAggroTarget ~= nil and unitAggroTarget:GetUniqueID() == unit:GetUniqueID() then
				uTower.bIsTargetingUnit = true
			else
				uTower.bIsTargetingUnit = false
			end
			
			uTower.nLevel = unitBuilding:GetLevel()
			uTower.nDamage = unitBuilding:GetBaseDamage()	
			
			return uTower
		end
	end
	

	
	printTable(uTower)
	
	return false
end

------------------------------------------------------
-- Calculate Possible Damage 
------------------------------------------------------

local function CalcPotentialDamage(unit)
	local unitSelf = core.unitSelf
	
	local abilIllusive = skills.abilQ
	local abilVault = skills.abilW
	local abilSlam = skills.abilE
	
	local potentialDamage = 0
	local pResist = 0
	local mResist = 0
	
	if(unit) then
	
		if( unit:GetPhysicalResistance() and unit:GetMagicResistance()) then
			pResist = unit:GetPhysicalResistance()
			mResist = unit:GetMagicResistance()
		end
		
		if abilIllusive:CanActivate() then
			potentialDamage = potentialDamage + ( ( unitSelf:GetBaseDamage() + (abilIllusive:GetLevel() * 10 ) ) * (1 - pResist) )
			--BotEcho("Illusive Damage With Resist: "..( ( unitSelf:GetBaseDamage() + (abilIllusive:GetLevel() * 10 ) ) * (1 - pResist) ))
		end
		 
		if abilVault:CanActivate() then
			potentialDamage = potentialDamage + ( ( 50 + (abilIllusive:GetLevel() * 50 ) ) * (1 - pResist) )
			--BotEcho("Vault Damage: "..( ( 50 + (abilIllusive:GetLevel() * 50 ) ) * (1 - pResist) ))
		end
		    
		if abilSlam:CanActivate() then
			potentialDamage = potentialDamage + ( ( 30 + (abilIllusive:GetLevel() * 30 ) ) * (1 - mResist) )
			--BotEcho("Slam Damage: "..( ( 30 + (abilIllusive:GetLevel() * 30 ) ) * (1 - mResist) ))
		end
		
		potentialDamage = potentialDamage + unitSelf:GetFinalAttackDamageMax()

	end
	
	return potentialDamage
end

------------------------------------------------------
-- Harass Values Based On Health   --
------------------------------------------------------
local function HarassExtraBonus(hero)
	local unitSelf = core.unitSelf
	local nUtil = 0
	local aggroRange = 500
	
	local vecMyPosition = unitSelf:GetPosition() 
	local nAttackRange = core.GetAbsoluteAttackRangeToUnit(unitSelf, hero)
	local nMyExtraRange = core.GetExtraRange(unitSelf)
	local nMySpeed = unitSelf:GetMoveSpeed()
	    
	local vecTargetPosition = hero:GetPosition()
	local nTargetExtraRange = core.GetExtraRange(hero)
	local nTargetDistanceSq = Vector3.Distance2DSq(vecMyPosition, vecTargetPosition)
	local nTargetSpeed = hero:GetMoveSpeed()
	
	local nPotentialDamage = 0
	if hero then
		nPotentialDamage = CalcPotentialDamage(hero)
	end
	
	-- Health Related Bonuses
	
	if(unitSelf:GetLevel()>1) then
	
		if (unitSelf:GetHealthPercent() <=0.15 and unitSelf:GetAttackType() == "melee") or (unitSelf:GetHealthPercent() <=0.25 and unitSelf:GetAttackType() == "ranged") then
			if hero:GetHealthPercent() >=0.20 then
				nUtil = -200
			else
				nUtil = nUtil + (unitSelf:GetManaPercent() * 100)
			end
		elseif (unitSelf:GetHealthPercent() <=0.25 and unitSelf:GetAttackType() == "melee") or (unitSelf:GetHealthPercent() <=0.40 and unitSelf:GetAttackType() == "ranged") then
			if hero:GetHealthPercent() >=0.8  or (nPotentialDamage - hero:GetHealth() < (nPotentialDamage * -0.5)) then
				nUtil = -100
			elseif hero:GetHealthPercent() >=0.5 or (nPotentialDamage - hero:GetHealth() < (nPotentialDamage * -1)) then
				nUtil = -50
			else
				nUtil = -25
			end
		elseif unitSelf:GetHealthPercent() <=0.50  then
			if hero:GetHealthPercent() >=0.8 or (nPotentialDamage - hero:GetHealth() <= nPotentialDamage * -0.5 ) then
				nUtil = -20
				nUtil = nUtil + (unitSelf:GetManaPercent() * 50)
			elseif hero:GetHealthPercent() >=0.5 then
				nUtil = 0
				nUtil = nUtil + (unitSelf:GetManaPercent() * 25)
			else
				nUtil = 20
			end
		elseif unitSelf:GetHealthPercent() <= 1 then
			if hero:GetHealthPercent() <=0.5 or (nPotentialDamage - hero:GetHealth() >= 0 ) then
				nUtil = 30
			elseif hero:GetHealthPercent() <=0.8 or ( nPotentialDamage - hero:GetHealth() >= nPotentialDamage ) then
				nUtil = 20
			else
				nUtil = 10
			end
		end
		
		--BotEcho ("Base nUtil = ".. nUtil) 
		--BotEcho (format("Potential Damage: %d / Target Health %d",nPotentialDamage,hero:GetHealth()))
		
		-- Mana Related Bonus
		
		--nUtil = nUtil + (unitSelf:GetManaPercent() * 20)
		
		-- Movement and Distance Related Bonus
		
		if (nTargetDistanceSq <= (aggroRange * aggroRange)) and (nMySpeed > nTargetSpeed) then
			nUtil = nUtil + ((nMySpeed/nTargetSpeed) * 10 ) + 10
		elseif (nTargetDistanceSq > (aggroRange * aggroRange)) and (nMySpeed < nTargetSpeed) then
			--nUtil = -5000
			nUtil = nUtil + ((nMySpeed/nTargetSpeed) * 10 )- 10
		end
		
		--BotEcho ("+Movement Util nUtil = ".. nUtil) 
		
	end
	
	-- Debuff Modifiers
	
	if unitSelf:IsDisarmed() then
		nUtil = nUtil - 10
	end
	
	if unitSelf:IsSilenced() then
		nUtil = nUtil - 10
	end
	
	-- NearTower Modifiers
	local uTower = IsEnemyTowerNear(unitSelf)
	local healthDifference = unitSelf:GetHealthPercent() - hero:GetHealthPercent()
	
	if ( uTower ) then
		
		--BotEcho(format("Level: %d / Damage: %d",uTower.nLevel,uTower.nDamage))
		--BotEcho("Enemy Tower Nearby - Lowering Harass")
		nUtil = nUtil + ( healthDifference * 100 ) - 20
		
		if(unitSelf:GetHealthPercent() < 0.25) or ( healthDifference <= -0.3 ) then
			nUtil = nUtil - 50
		elseif(unitSelf:GetHealthPercent() < 0.5) then
			nUtil = nUtil - 25
		end
		
		if (uTower.bIsTargetingUnit) then
			nUtil = nUtil - (uTower.nLevel * 10)
			--BotEcho("Enemy Tower Targetting Me - Lowering Harass")
		end
	
	end
	
	local uTower = IsEnemyTowerNear(hero)
		
	if ( uTower ) then
		--BotEcho("Ally Tower Nearby - Raising Harass")
		nUtil = nUtil + ( healthDifference * 100 ) + 20
		
		if(hero:GetHealthPercent() < 0.25) or ( healthDifference >= 0.3 ) then
			nUtil = nUtil + 50
		elseif(unitSelf:GetHealthPercent() < 0.5) then
			nUtil = nUtil + 25
		end
		
		if (uTower.bIsTargetingUnit) then
			nUtil = nUtil + (uTower.nLevel * 20)
			--BotEcho("Allied Tower Targetting Enemy Hero - Raising Harass")
		end

	end
	
	--BotEcho ("Final Bonus nUtil = ".. nUtil) 
	
	return nUtil
end

------------------------------------------------------
--            customharassutility override          --
-- change utility according to usable spells here   --
------------------------------------------------------
-- @param: iunitentity hero
-- @return: number
local function CustomHarassUtilityFnOverride(hero)
    local nUtil = 0
    local unitSelf = core.unitSelf
    

	nUtil = HarassExtraBonus(hero)

    if skills.abilQ:CanActivate() then
        nUnil = nUtil + object.nIllusiveUp
    end
 
    if skills.abilW:CanActivate() then
        nUtil = nUtil + object.nVaultUp
    end
    
    if skills.abilE:CanActivate() then
        nUtil = nUtil + object.nSlamUp
    end
    
    if object.itemStealth and object.itemStealth:CanActivate() then
        nUtil = nUtil + object.nStealthUp
    end
    
    if object.itemIllusion and object.itemIllusion:CanActivate() then
        nUtil = nUtil + object.nIllusionUp
    end
    
    --BotEcho ("Total nUtil = ".. nUtil) 
 
    return nUtil
end
-- assisgn custom Harrass function to the behaviourLib object
behaviorLib.CustomHarassUtility = CustomHarassUtilityFnOverride  

--------------------------------------------------------------
-- Combos
--------------------------------------------------------------
--object.combos = {}


--Timer Variables
object.nComboPause = 0
object.aLastMove = nil

--------------------------------------------------------------
--                    Harass Behavior                       --
-- All code how to use abilities against enemies goes here  --
--------------------------------------------------------------
-- @param botBrain: CBotBrain
-- @return: none
--
local function HarassHeroExecuteOverride(botBrain)
    local bDebugEchos = false
    
    local unitTarget = behaviorLib.heroTarget
    if unitTarget == nil then
        return object.harassExecuteOld(botBrain) --Target is invalid, move on to the next behavior
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
    
    
    --- Insert abilities code here, set bActionTaken to true 
    --- if an ability command has been given successfully
    
    if bCanSee then
	local bStealth = unitSelf:HasState("State_Item3G") or unitSelf:HasState("State_Sasuke")
	core.FindItems()
        local itemStealth = core.itemStealth
	local itemIllusion = core.itemIllusion
	local itemBattery = core.itemBattery
	local itemGhostMarchers = core.itemGhostMarchers
	local abilTaunt = skills.abilT
	
	local abilIllusive = skills.abilQ
	local abilVault = skills.abilW
	local abilSlam = skills.abilE
	
	--BotEcho("Attacking - ".. nLastHarassUtility)
	
		if unitTarget:GetHealthPercent()<0.15 and abilTaunt:CanActivate() then
			if nTargetDistanceSq <= ( 300 * 300 ) and nLastHarassUtility > botBrain.nTauntThreshold then
				bActionTaken = core.OrderAbilityEntity(botBrain, abilTaunt, unitTarget)
			end
		end
		
		if not bActionTaken and (itemBattery and itemBattery:CanActivate()) and IsInBag(itemBattery) then
			if itemBattery:GetCharges() >= 10 and unitSelf:GetHealthPercent() < 0.8 then
				bActionTaken = core.OrderItemClamp(botBrain, unitSelf, itemBattery)
			elseif itemBattery:GetCharges() >= 1 and unitSelf:GetHealthPercent() < 0.5 then
				bActionTaken = core.OrderItemClamp(botBrain, unitSelf, itemBattery)
			elseif itemBattery:GetCharges() >= 5 and unitSelf:GetManaPercent() < 0.2 then
				bActionTaken = core.OrderItemClamp(botBrain, unitSelf, itemBattery)
			end
		end
	
		if not bActionTaken and (itemIllusion and itemIllusion:CanActivate()) and IsInBag(itemIllusion) then
			if nTargetDistanceSq <= ( 300 * 300 ) then
				bActionTaken = core.OrderItemClamp(botBrain, unitSelf, itemIllusion)
			end
		end
		
		if not bActionTaken and (itemStealth and itemStealth:CanActivate()) and IsInBag(itemStealth) and not bStealth then
			bActionTaken = core.OrderItemClamp(botBrain, unitSelf, itemStealth)
		end
		
		if itemGhostMarchers and itemGhostMarchers:CanActivate() and not bStealth then
			bActionTaken = core.OrderItemClamp(botBrain, unitSelf, itemGhostMarchers)
		end
		
		if not bActionTaken and (object.nComboPause > HoN.GetGameTime()) then
			local myRange = unitSelf:GetAttackRange()
			if itemGhostMarchers and itemGhostMarchers:CanActivate() and not bStealth then 
				bActionTaken = core.OrderItemClamp(botBrain, unitSelf, itemGhostMarchers)
			end
			if nTargetDistanceSq <= ((myRange * myRange)) then
				bActionTaken = core.OrderAttackClamp(botBrain, unitSelf, unitTarget)
			else
				bActionTaken = core.OrderMoveToUnitClamp(botBrain, unitSelf, unitTarget)
			end
		end
		
		if not bActionTaken and not bStealth then
		
			if bDebugEchos then BotEcho("(" .. nLastHarassUtility .. ") Checking Vault") end

			if abilVault:CanActivate() and (nLastHarassUtility > botBrain.nVaultThreshold) and ( object.nComboPause <= HoN.GetGameTime() )  then
				local nRange = abilVault:GetRange() 
				if nTargetDistanceSq <= ((nRange * nRange)) then
					bActionTaken = core.OrderAbilityEntity(botBrain, abilVault, unitTarget)
					if (bActionTaken) then
						object.nComboPause = HoN.GetGameTime() + 1000
						object.aLastMove = abilVault
					end
				end
			end
			
		end
		
		if not bActionTaken and not bStealth then
			if bDebugEchos then BotEcho("(" .. nLastHarassUtility .. ") Checking Illusive") end
			if abilIllusive:CanActivate() and nLastHarassUtility > botBrain.nIllusiveThreshold and ( object.nComboPause <= HoN.GetGameTime() )  then
			    local nRange = abilIllusive:GetRange() 
			    if (nTargetDistanceSq <= ( 300 * 300 )) or ( (nTargetDistanceSq - ( 300 * 300 )) < ( 200 * 200 )  and object.aLastMove == abilVault) then
				bActionTaken = core.OrderAbility(botBrain, abilIllusive)
				if (bActionTaken) then
					object.nComboPause = HoN.GetGameTime() + 500
					object.aLastMove = abilIllusive
				end
			    end
			end
		end
    
		if not bActionTaken and not bStealth then
			if bDebugEchos then BotEcho("(" .. nLastHarassUtility .. ") Checking Slam") end
			if abilSlam:CanActivate() and nLastHarassUtility > botBrain.nSlamThreshold and ( object.nComboPause <= HoN.GetGameTime() ) then
			    if nTargetDistanceSq <= ( 200 * 200 ) then
				bActionTaken = core.OrderAbility(botBrain, abilSlam)
				if (bActionTaken) then
					object.nComboPause = HoN.GetGameTime() + 500
					object.aLastMove = abilSlam
				end
			    end
			end
		end
   
    end
    
    if not bActionTaken then
        return object.harassExecuteOld(botBrain)
    end 
end
-- overload the behaviour stock function with custom 
object.harassExecuteOld = behaviorLib.HarassHeroBehavior["Execute"]
behaviorLib.HarassHeroBehavior["Execute"] = HarassHeroExecuteOverride


----------------------------------------------------
-- function: IsInBag
-- Checks if the IEntityItem is in the Bot's Inventory
-- Takes IEntityItem, Returns Boolean
----------------------------------------------------
function IsInBag(item)
	local unitSelf = core.unitSelf
	local sItemName = item:GetName()
	local unitInventory = unitSelf:GetInventory(false)
	for slot = 1, 6, 1 do
		local curItem = unitInventory[slot]
		if curItem then
			if curItem:GetName() == sItemName and not curItem:IsRecipe() then
				return true
			end
		end
	end
	return false
end
---------------------------------------------
-- Attack Creeps Override
---------------------------------------------

function AttackCreepsExecuteCustom(botBrain)

local unitSelf = core.unitSelf
	local currentTarget = core.unitCreepTarget
	local bActionTaken = false

	if currentTarget and core.CanSeeUnit(botBrain, currentTarget) then		
		local vecTargetPos = currentTarget:GetPosition()
		local nDistSq = Vector3.Distance2DSq(unitSelf:GetPosition(), vecTargetPos)
		local nAttackRangeSq = core.GetAbsoluteAttackRangeToUnit(unitSelf, currentTarget, true)

		if currentTarget ~= nil then			
			
			core.FindItems(botBrain)
			local itemHatchet = core.itemHatchet
			if nDistSq < nAttackRangeSq and unitSelf:IsAttackReady() then
				--BotEcho("Attacking Creep")
				--only attack when in nRange, so not to aggro towers/creeps until necessary, and move forward when attack is on cd
				bActionTaken = core.OrderAttackClamp(botBrain, unitSelf, currentTarget)
			elseif (itemHatchet and itemHatchet:CanActivate() and IsInBag(itemHatchet)) then
				local nHatchRange = itemHatchet:GetRange()
				if nDistSq < ( nHatchRange * nHatchRange ) and currentTarget:GetTeam() ~= unitSelf:GetTeam() then					
					--BotEcho("Attempting Hatchet")
					bActionTaken = core.OrderItemEntityClamp(botBrain, unitSelf, itemHatchet, currentTarget)
				end			
			else
				--BotEcho("MOVIN OUT")
				local vecDesiredPos = core.AdjustMovementForTowerLogic(vecTargetPos)
				bActionTaken = core.OrderMoveToPosClamp(botBrain, unitSelf, vecDesiredPos, false)
			end
		end
	else
		return false
	end
	
	if not bActionTaken then
		return object.AttackCreepsExecuteOld(botBrain)
	end 
end

object.AttackCreepsExecuteOld = behaviorLib.AttackCreepsBehavior["Execute"]
behaviorLib.AttackCreepsBehavior["Execute"] = AttackCreepsExecuteCustom

---------------------------------------------
-- Retreat From Threat Override
---------------------------------------------
local function RetreatFromThreatExecuteOverride(botBrain)
	local bDebugEchos = false
	local bActionTaken = false
	
	local nlastRetreatUtil = behaviorLib.lastRetreatUtil
	
	local unitSelf = core.unitSelf
	local bStealth = unitSelf:HasState("State_Item3G") or unitSelf:HasState("State_Sasuke")
	core.FindItems()
	
	if bDebugEchos then BotEcho("Running - ".. nlastRetreatUtil) end
	
	--Activate battery if we can
	local itemBattery = core.itemBattery
	if not bActionTaken and (itemBattery and itemBattery:CanActivate() and itemBattery:GetCharges() >= 1)  then
			if itemBattery:GetCharges() >= 10 and unitSelf:GetHealthPercent() < 0.8 then
				if bDebugEchos then BotEcho("Running - Using Battery") end
				bActionTaken = core.OrderItemClamp(botBrain, unitSelf, itemBattery)
			elseif itemBattery:GetCharges() >= 1 and unitSelf:GetHealthPercent() < 0.5 then
				bActionTaken = core.OrderItemClamp(botBrain, unitSelf, itemBattery)
			end
	end
		
	if not bActionTaken and nlastRetreatUtil >= botBrain.nretreatStealthThreshold then
	--Activate stealth if we can
		local itemStealth = core.itemStealth
		if itemStealth and itemStealth:CanActivate() then
			if bDebugEchos then BotEcho("Running - Attempting Stealth") end
			bActionTaken = core.OrderItemClamp(botBrain, unitSelf, itemStealth)
		end
	end
		
	if not bActionTaken and not bStealth then
		--Activate ghost marchers if we can
		local itemGhostMarchers = core.itemGhostMarchers
		if behaviorLib.lastRetreatUtil >= behaviorLib.retreatGhostMarchersThreshold and itemGhostMarchers and itemGhostMarchers:CanActivate() then
			if bDebugEchos then BotEcho("Running - Using Ghost Marchers") end
			bActionTaken = core.OrderItemClamp(botBrain, core.unitSelf, itemGhostMarchers)
		end
	end
	
	if not bActionTaken then
		return object.RetreatFromThreatExecuteOld(botBrain)
	end 
	
end

-- override the behaviour
object.RetreatFromThreatExecuteOld = behaviorLib.RetreatFromThreatBehavior["Execute"]
behaviorLib.RetreatFromThreatBehavior["Execute"] = RetreatFromThreatExecuteOverride

----------------------------------
-- HealAtWellSpendGold Override
----------------------------------
function behaviorLib.HealAtWellAndSpendGold(botBrain)
	local hpPercent = core.unitSelf:GetHealthPercent()
	local myGold = botBrain:GetGold()
	local bGotWhatINeed = (behaviorLib.buyState == behaviorLib.BuyStateLateItems and #behaviorLib.curItemList <= 1)
	
	if hpPercent < 0.5 and not bGotWhatINeed then
		if(myGold >= 4000) then
			return 100
		elseif(myGold >= 2000) then
			return 50
		end
	end

	return object.HealAtWellBehaviorUtilityOld(botBrain)
end

object.HealAtWellBehaviorUtilityOld = behaviorLib.HealAtWellBehavior["Utility"]
behaviorLib.HealAtWellBehavior["Utility"] = behaviorLib.HealAtWellAndSpendGold

----------------------------------
--  FindItems Override
----------------------------------
local function funcFindItemsOverride(botBrain)
	local bUpdated = object.FindItemsOld(botBrain)

	if core.itemStealth ~= nil and not core.itemStealth:IsValid() then
		core.itemStealth = nil
	end
	if core.itemIllusion ~= nil and not core.itemIllusion:IsValid() then
		core.itemIllusion = nil
	end
	if core.itemBattery ~= nil and not core.itemBattery:IsValid() then
		core.itemBattery = nil
	end
	
	if bUpdated then
		--only update if we need to
		if core.itemStealth and core.itemIllusion and core.itemBattery then
			return
		end
		
		local inventory = core.unitSelf:GetInventory(true)
		for slot = 1, 12, 1 do
			local curItem = inventory[slot]
			if curItem then
				if core.itemStealth == nil and (curItem:GetName() == "Item_Stealth" or curItem:GetName() == "Item_Sasuke") then
					core.itemStealth = core.WrapInTable(curItem)
				elseif core.itemIllusion == nil and curItem:GetName() == "Item_ManaBurn2" then
					core.itemIllusion = core.WrapInTable(curItem)
				elseif core.itemBattery == nil and (curItem:GetName() == "Item_ManaBattery" or curItem:GetName() == "Item_PowerSupply") then
					core.itemBattery = core.WrapInTable(curItem)
				end
			end
		end
	end
end
object.FindItemsOld = core.FindItems
core.FindItems = funcFindItemsOverride