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


BotEcho(object:GetName()..' loading plaguerider_main...')




--####################################################################
--####################################################################
--#                                                                 ##
--#                  bot constant definitions                       ##
--#                                                                 ##
--####################################################################
--####################################################################

-- hero_<hero>  to reference the internal hon name of a hero, Hero_Yogi ==wildsoul
object.heroName = 'Hero_DiseasedRider'


behaviorLib.StartingItems = {"Item_PretendersCrown", "2 Item_MinorTotem", "Item_HealthPotion", "Item_RunesOfTheBlight"}
behaviorLib.LaneItems = {"Item_Marchers", "Item_Strength5", "Item_Striders"}
behaviorLib.MidItems = {"Item_MightyBlade", "Item_NeophytesBook", "Item_Glowstone", "Item_Intelligence7"} --Purchases precursor items before fullying buying SoTM Intelligence7 is Staff of the Master
behaviorLib.LateItems = {"Item_Intelligence7"} --Weapon3 is Savage Mace. Item_Damage9 is Doombringer


-- skillbuild table, 0=q, 1=w, 2=e, 3=r, 4=attri
object.tSkills = {
    2, 0, 0, 2, 0, --Levels 1-5 skills
    3, 0, 2, 1, 1, --Levels 6-10 skills
    3, 1, 1, 2, 4, --levels 11-15 skills
    3, 4, 4, 4, 4, --Levels 16-20
    4, 4, 4, 4, 4, --Levels 21-25
}

-- bonus agression points if a skill/item is available for use


-- bonus agression points that are applied to the bot upon successfully using a skill/item


--thresholds of aggression the bot must reach to use these abilities





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
end
local unitSelf = core.unitSelf
object.onthinkOld = object.onthink
object.onthink 	= object.onthinkOverride

-- These are bonus agression points if a skill/item is available for use
object.nNukeUp = 17
object.nArmorUp = 0
object.nManaUp = 35
object.nUltUp = 36
 
-- These are bonus agression points that are applied to the bot upon successfully using a skill/item
object.nNukeUse = 35
object.nArmorUse = 0
object.nManaUse = 3
object.nUltUse = 50
 
 
--These are thresholds of aggression the bot must reach to use these abilities

object.nNukeThreshold = 15
object.nArmorThreshold = 35
object.nManaThreshold = 12
object.nUltThreshold = 55




----------------------------------------------
--            oncombatevent override        --
-- use to check for inflictors (fe. buffs) --
----------------------------------------------
-- @param: EventData
-- @return: none 
function object:oncombateventOverride(EventData)
    self:oncombateventOld(EventData)

    local nAddBonus = 0

    if EventData.Type == "Ability" then
        if EventData.InflictorName == "Ability_DiseasedRider1" then
            nAddBonus = nAddBonus + object.nNukeUse
        elseif EventData.InflictorName == "Ability_DiseasedRider4" then
            nAddBonus = nAddBonus + object.nUltUse
        elseif EventData.InflictorName == "Ability_DiseasedRider2" then
            nAddBonus = nAddBonus + object.nArmorUse
		elseif EventData.InflictorName == "Ability_DiseasedRider3" then
            nAddBonus = nAddBonus + object.nManaUse
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
    local nUtil = 40
    
    if skills.abilQ:CanActivate() then
        nUtil = nUtil + object.nNukeUp
    end

    if skills.abilW:CanActivate() then
        nUtil = nUtil + object.nArmorUp
    end

	if skills.abilE:CanActiate()then
		nUtil = nUtil + object.nManaUp
	end
	
    if skills.abilR:CanActivate() then
        nUtil = nUtil + object.nUltUp
    end



    return nUtil
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
local function HarassHeroExecuteOverride(botBrain)
    local unitTarget = behaviorLib.heroTarget
    if unitTarget == nil then
        return object.harassExecuteOld(botBrain)  --Target is invalid, move on to the next behavior
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
	
	--since we are using an old pointer, ensure we can still see the target for entity targeting
	if core.CanSeeUnit(botBrain, unitTarget) then
		local bTargetVuln = unitTarget:IsStunned() or unitTarget:IsImmobilized() or unitTarget:IsPerplexed()
		local abilArmor = skills.abilW
		local abilMana = skills.abilE
        local abilNuke = skills.abilQ
        local abilUlt = skills.abilR

   
        -- Contagion
        if not bActionTaken then            
            local nRange = abilNuke:GetRange()
                if abilNuke:CanActivate() and nLastHarassUtility > botBrain.nNukeThreshold then
                    if nTargetDistanceSq < (nRange*nRange) then
                        bActionTaken = core.OrderAbilityEntity(botBrain, abilNuke, unitTarget)
                    else
						bActionTaken = core.OrderMoveToUnitClamp(botBrain, unitSelf, unitTarget)
					end
                end 
            end
   
            if abilUlt:CanActivate() and nLastHarassUtility > botBrain.nUltThreshold then
                local nRange = abilUlt:GetRange()
                if nTargetDistanceSq < (nRange * nRange) then
                    bActionTaken = core.OrderAbilityEntity(botBrain, abilUlt, unitTarget)
                end           
            end 
        end
    


     -- Plague Shield
    if not bActionTaken then
        local abilArmor = skills.abilW
        if abilArmor:CanActivate() and nLastHarassUtility > botBrain.nArmorThreshold then
            local nRange = abilArmor:GetRange()
            if(unitSelf:GetHealth()<900) then
			bActionTaken = core.OrderAbility(botBrain, abilArmor, unitSelf)
        end
    end 

     -- Plague Carrier
    if core.CanSeeUnit(botBrain, unitTarget) then
        local abilUlt = skills.abilR
        if not bActionTaken then --and bTargetVuln then
            if abilUlt:CanActivate() and nLastHarassUtility > botBrain.nUltThreshold then
                local nRange = abilUlt:GetRange()
                if nTargetDistanceSq < (nRange * nRange) then
        		    bActionTaken = core.OrderAbilityEntity(botBrain, abilUlt, unitTarget)
                else
                    bActionTaken = core.OrderMoveToUnitClamp(botBrain, unitSelf, unitTarget)
                end
            end
        end  
    end
	
	-- Extinguish
	if core.CanSeeUnit(botBrain, unitTarget) and (unitTarget:GetHealth()>549)then
		local abilMana = skills.abilE
		if not bActionTaken then
			if abilMana:CanActivate() and nLastHarassUtility > botBrain.nManaThreshold then
				bActionTaken = core.OrderAbilityEntity(botBrain, abilMana, unitTarget)
				end
				
		end
	end
	
				

    
    if not bActionTaken then
        return object.harassExecuteOld(botBrain) 
    end 
end
end
    --- Insert abilities code here, set bActionTaken to true 
	
	--Checks to see if an enemy is within Nuke range for harassing while having enough mana to use Extinguish afterwards
	--if core.CanSeeUnit(botBrain, unitTarget) then
		--if not bActionTaken then
			--if (nTargetDistance < 600) and abilNuke:CanActivate() and abilMana:CanActivate() and unitSelf:GetMana()>235 then
			--bActionTaken = core.OrderAbilityEntity(botBrain, abilNuke, unitTarget, true)
			--need to put in action here to use Extinguish!!!!!!!!!!
			--!!!!!!!!!!!!!!!!!!!!!1
			--!!!!!!!!!!!!!!!!!!!!!!!
    --- if an ability command has been given successfully
			--end
		--end
	--end
	
	
	
	
    
    
    
    

-- overload the behaviour stock function with custom 
object.harassExecuteOld = behaviorLib.HarassHeroBehavior["Execute"]
behaviorLib.HarassHeroBehavior["Execute"] = HarassHeroExecuteOverride






