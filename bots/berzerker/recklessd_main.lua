--------------------------------------------------------------------- -- -- 
--------------------------------------------------------------------- -- -- 
--  ____                      __       ___                              
-- /\  _`\                   /\ \     /\_ \                             
-- \ \ \L\ \      __     ___ \ \ \/'\ \//\ \       __     ____    ____  
--  \ \ ,  /    /'__`\  /'___\\ \ , <   \ \ \    /'__`\  /',__\  /',__\ 
--   \ \ \\ \  /\  __/ /\ \__/ \ \ \\`\  \_\ \_ /\  __/ /\__, `\/\__, `\
--    \ \_\ \_\\ \____\\ \____\ \ \_\ \_\/\____\\ \____\\/\____/\/\____/
--     \/_/\/ / \/____/ \/____/  \/_/\/_/\/____/ \/____/ \/___/  \/___/
--  ____                                     __                    
-- /\  _`\    __                            /\ \__                 
-- \ \ \/\ \ /\_\     ____     __       ____\ \ ,_\     __   _ __  
--  \ \ \ \ \\/\ \   /',__\  /'__`\    /',__\\ \ \/   /'__`\/\`'__\
--   \ \ \_\ \\ \ \ /\__, `\/\ \L\.\_ /\__, `\\ \ \_ /\  __/\ \ \/ 
--    \ \____/ \ \_\\/\____/\ \__/.\_\\/\____/ \ \__\\ \____\\ \_\ 
--     \/___/   \/_/ \/___/  \/__/\/_/ \/___/   \/__/ \/____/ \/_/ 
--                                                                 
--                                                                 
--------------------------------------------------------------------- -- -- 
--------------------------------------------------------------------- -- -- 
-- Reckless Disaster v1.1

--####################################################################
--####################################################################
--#																 ##
--#					   Bot Initiation							##
--#																 ##
--####################################################################
--####################################################################


local _G = getfenv(0)
local object = _G.object

object.myName = object:GetName()

object.bRunLogic		 = true
object.bRunBehaviors	= true
object.bUpdates		 = true
object.bUseShop		 = true

object.bRunCommands	 = true 
object.bMoveCommands	 = true
object.bAttackCommands	 = true
object.bAbilityCommands = true
object.bOtherCommands	 = true

object.bReportBehavior = false
object.bDebugUtility = false

object.logger = {}
object.logger.bWriteLog = false
object.logger.bVerboseLog = false

object.core		 = {}
object.eventsLib	 = {}
object.metadata	 = {}
object.behaviorLib	 = {}
object.skills		 = {}

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

BotEcho(object:GetName()..' loading recklessd_main...')




--####################################################################
--####################################################################
--#																 ##
--#				  Bot Constant Definitions					   ##
--#																 ##
--####################################################################
--####################################################################

-- Hero_<hero>  to reference the internal HoN name of a hero, Hero_Yogi ==Wildsoul
object.heroName = 'Hero_Berzerker'


--   Item Buy order. Internal names  
behaviorLib.StartingItems  = { "Item_RunesOfTheBlight", "Item_IronBuckler", "Item_LoggersHatchet"}
behaviorLib.LaneItems  = {"Item_Strength5","Item_Marchers"}
behaviorLib.MidItems  = {"Item_ElderParasite","Item_Insanitarius","Item_EnhancedMarchers","Item_Brutalizer"}
behaviorLib.LateItems  = {"Item_BehemothsHeart","Item_Critical1"}


-- Skillbuild table, 0=Q, 1=W, 2=E, 3=R, 4=Attri
object.tSkills = {
	0, 1, 0, 2, 0,
	3, 0, 1, 1, 1, 
	3, 2, 2, 2, 4,
	3, 4, 4, 4, 4,
	4, 4, 4, 4, 4,
}

-- bonus agression points if a skill/item is available for use

object.nChainUp = 17
object.nSapUp = 10
object.nMarkUp = 12
object.nCarnageUp = 22
object.nElderParasiteUp = 25 
object.nInsanitariusUp = 25
-- bonus agression points that are applied to the bot upon successfully using a skill/item

object.nChainUse = 20
object.nSapUse = 15 
object.nMarkUse = 20
object.nCarnageUse = 40
object.nElderParasiteUse = 20
object.nInsanitariusUse = 30

--thresholds of aggression the bot must reach to use these abilities

object.nChainThreshold = 25
object.nSapThreshold = 15
object.nDefSapThreshold = 20
object.nMarkThreshold = 75 
object.nCarnageThreshold = 50
object.nElderParasiteThreshold = 70
object.nInsanitariusThreshold = 70
object.nInsanitariusOffThreshold = 60
object.nEnhancedMarchersThreshold = 70
object.nMarkOfDeathAggro = 0.2
object.ChainTimer = nil

behaviorLib.nCreepPushbackMul = 0.5
behaviorLib.nTargetPositioningMul = 0.6

--####################################################################
--####################################################################
--#																 ##
--#   Bot Function Overrides										##
--#																 ##
--####################################################################
--####################################################################

------------------------------
--	 Skills			   --
------------------------------
-- @param: none
-- @return: none
function object:SkillBuild()
	core.VerboseLog("SkillBuild()")

-- takes care at load/reload, <NAME_#> to be replaced by some convinient name.
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
	
   
	local nLev = unitSelf:GetLevel()
	local nLevPts = unitSelf:GetAbilityPointsAvailable()
	for i = nLev, nLev+nLevPts do
		unitSelf:GetAbility( object.tSkills[i] ):LevelUp()
	end
end


------------------------------------------------------
--			onthink override					  --
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
--			oncombatevent override		--
-- use to check for infilictors (fe. buffs) --
----------------------------------------------
-- @param: eventdata
-- @return: none
function object:oncombateventOverride(EventData)
	self:oncombateventOld(EventData)
 
	local nAddBonus = 0
	
	if EventData.Type == "Ability" then
		if EventData.InflictorName == "Ability_Berzerker1" then
			nAddBonus = nAddBonus + object.nChainUse
		elseif EventData.InflictorName == "Ability_Berzerker2" then
			nAddBonus = nAddBonus + object.nSapUse
		elseif EventData.InflictorName == "Ability_Berzerker3" then
			nAddBonus = nAddBonus + object.nMarkUse
		elseif EventData.InflictorName == "Ability_Berzerker4" then
			nAddBonus = nAddBonus + object.nCarnageUse
		end
	elseif EventData.Type == "Item" then
		--eventsLib.printCombatEvent(EventData)
		if core.itemElderParasite ~= nil and EventData.InflictorName == core.itemElderParasite:GetName() then
			nAddBonus = nAddBonus + self.nElderParasiteUse
		elseif core.itemInsanitarius ~= nil and EventData.InflictorName == core.itemInsanitarius:GetName() then
			nAddBonus = nAddBonus + self.nInsanitariusUse
		end
	end
 
	if nAddBonus > 0 then
		core.DecayBonus(self)
		core.nHarassBonus = core.nHarassBonus + nAddBonus
	end
end
-- override combat event trigger function.
object.oncombateventOld = object.oncombatevent
object.oncombatevent	 = object.oncombateventOverride




------------------------------------------------------
--			customharassutility override		  --
-- change utility according to usable spells here   --
------------------------------------------------------
-- @param: iunitentity hero
-- @return: number
local function CustomHarassUtilityFnOverride(hero)
	local nUtil = 0
	 
	if skills.abilQ:CanActivate() then
		nUnil = nUtil + object.nChainUp
	end
 
	if skills.abilW:CanActivate() then
		nUtil = nUtil + object.nSapUp
	end
	
	if skills.abilE:CanActivate() then
		nUtil = nUtil + object.nMarkUp
	end

	if skills.abilR:CanActivate() then
		nUtil = nUtil + object.nCarnageUp
	end
	   
	if object.itemElderParasite and object.itemElderParasite:CanActivate() then
		nUtil = nUtil + object.nElderParasiteUp
	end

	if object.itemInsanitarius and object.itemInsanitarius:CanActivate() then
		nUtil = nUtil + object.nInsanitariusUp
	end

	if object.itemEnhancedMarchers and object.itemEnhancedMarchers:CanActivate() then
		nUtil = nUtil + object.nEnhancedMarchersUp
	end
	
	if hero:HasState("State_Berzerker_Ability3_Debuff") then
		nUtil = nUtil + nUtil * object.nMarkOfDeathAggro
	end
	 
	return nUtil
end
-- assisgn custom Harrass function to the behaviourLib object
behaviorLib.CustomHarassUtility = CustomHarassUtilityFnOverride   


----------------------------------
--  FindItems Override
----------------------------------
local function funcFindItemsOverride(botBrain)
	local bUpdated = object.FindItemsOld(botBrain)

	if core.EnhancedMarchers ~= nil and not core.itemEnhancedMarchers:IsValid() then
		core.EnhancedMarchers = nil
	end
	if core.Insanitarius ~= nil and not core.itemInsanitarius:IsValid() then
		core.Insanitarius = nil
	end
	if core.ElderParasite ~= nil and not core.itemElderParasite:IsValid() then
		core.ElderParasite = nil
	end
	
	if bUpdated then
		--only update if we need to
		if core.itemEnhancedMarchers and core.itemInsanitarius and core.itemElderParasite then
			return
		end
		
		local inventory = core.unitSelf:GetInventory(true)
		for slot = 1, 12, 1 do
			local curItem = inventory[slot]
			if curItem then
				if core.itemEnhancedMarchers == nil and curItem:GetName() == "Item_EnhancedMarchers" then
					core.itemEnhancedMarchers = core.WrapInTable(curItem)
				elseif core.itemInsanitarius == nil and curItem:GetName() == "Item_Insanitarius" then
					core.AllChat("Now, Bow before the RECKLESS DISASTER !!!", 0)
					core.itemInsanitarius = core.WrapInTable(curItem)
				elseif core.itemElderParasite == nil and curItem:GetName() == "Item_ElderParasite" then
					core.AllChat("Come on ! Back Down is for Weaklings ...", 0)
					core.itemElderParasite = core.WrapInTable(curItem)
				end
			end
		end
	end
end

object.FindItemsOld = core.FindItems
core.FindItems = funcFindItemsOverride



--------------------------------------------------------------
--					Harass Behavior					   --
-- All code how to use abilities against enemies goes here  --
--------------------------------------------------------------
-- @param botBrain: CBotBrain
-- @return: none
--
local function HarassHeroExecuteOverride(botBrain)
	local bDebugEchos = true
	
	

	
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
	   
	--- Insert abilities code here, set bActionTaken to true 
	--- if an ability command has been given successfully
	
	 -- Chain Activation
	if core.CanSeeUnit(botBrain, unitTarget) then
		local abilChain = skills.abilQ
		if not bActionTaken then
			if abilChain:CanActivate() and nLastHarassUtility > botBrain.nChainThreshold and not unitSelf:HasState("State_Berzerker_Ability1_Self") then
				local nRange = abilChain:GetRange()
				if nTargetDistanceSq < (nRange * nRange) then 
					bActionTaken = core.OrderAbilityEntity(botBrain, abilChain, unitTarget)
					botBrain.nChainTimer = HoN.GetGameTime()
				end
			end
		end 
	end 

	 -- Chain Desactivation
	 
	if core.CanSeeUnit(botBrain, unitTarget) then
		local abilChain = skills.abilQ
		if not bActionTaken and unitSelf:HasState("State_Berzerker_Ability1_Self") and abilChain:CanActivate() and (nTargetDistanceSq < ( 150 * 150 ) or nTargetDistanceSq >= ( 780 * 780 ) or HoN.GetGameTime() - botBrain.nChainTimer > 4500 ) then
			bActionTaken = core.OrderAbility(botBrain, abilChain)
		end
	end
	 
	 -- Sap Activation
	if core.CanSeeUnit(botBrain, unitTarget) then
		local abilSap = skills.abilW
		if not bActionTaken then --and bTargetVuln then
			if abilSap:CanActivate() and nLastHarassUtility > botBrain.nSapThreshold then
				if nTargetDistanceSq < (400 * 400) then --- distance?
					bActionTaken = core.OrderAbility(botBrain, abilSap)
				end
			end
		end 
	end
	 
	 -- Mark Activation
	if core.CanSeeUnit(botBrain, unitTarget) then
		local abilMark = skills.abilE
		if not bActionTaken then --and bTargetVuln then
			if abilMark:CanActivate() and nLastHarassUtility > botBrain.nMarkThreshold then
				local nRange = abilMark:GetRange()
				if nTargetDistanceSq < (nRange * nRange) then --- distance?
					bActionTaken = core.OrderAbilityEntity(botBrain, abilMark, unitTarget)
					core.OrderAttackClamp(botBrain, unitSelf, unitTarget)
				end
			end
		end 
	end 

	 -- Carnage Activation
	if core.CanSeeUnit(botBrain, unitTarget) then
		local abilCarnage = skills.abilR
		if not bActionTaken then --and bTargetVuln then
			if abilCarnage:CanActivate() and nLastHarassUtility > botBrain.nCarnageThreshold then
				if nTargetDistanceSq < (650 * 650) then --- distance?
					bActionTaken = core.OrderAbility(botBrain, abilCarnage)
				end
			end
		end 
	end

	 -- ElderParasite Activation
	if core.CanSeeUnit(botBrain, unitTarget) then
		core.FindItems()
		local itemElderParasite = core.itemElderParasite -- reel name?
		if not bActionTaken then --and bTargetVuln then
			if itemElderParasite and itemElderParasite:CanActivate() and nLastHarassUtility > botBrain.nElderParasiteThreshold then
				if nTargetDistanceSq < (540 * 540) then --- distance?
					bActionTaken = core.OrderItemClamp(botBrain, unitSelf, itemElderParasite)
				end
			end
		end 
	end

	 -- Insanitarius Activation
	if core.CanSeeUnit(botBrain, unitTarget) then
		core.FindItems()
	local itemInsanitarius = core.itemInsanitarius -- reel name?
		if not bActionTaken then --and bTargetVuln then
			if itemInsanitarius and itemInsanitarius:CanActivate() and nLastHarassUtility > botBrain.nInsanitariusThreshold and not unitSelf:HasState("State_Insanitarius") then
				if nTargetDistanceSq < (200 * 200) then --- distance?
					bActionTaken = core.OrderItemClamp(botBrain, unitSelf, itemInsanitarius)
				end
			end
		end 
	end
			
	 -- Ghost Marchers Offensive Activation
	if core.CanSeeUnit(botBrain, unitTarget) then
		core.FindItems()
	local itemEnhancedMarchers = core.itemEnhancedMarchers -- reel name?
		if not bActionTaken then 
			if itemEnhancedMarchers and itemEnhancedMarchers:CanActivate() and nLastHarassUtility > botBrain.nEnhancedMarchersThreshold then
				if nTargetDistanceSq < (750 * 750) then --- distance?
					bActionTaken = core.OrderItemClamp(botBrain, unitSelf, itemEnhancedMarchers)
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

----------------------------------
-- Retreating tactics as seen in Spennerino's ScoutBot 
-- with variations from Rheged's Emerald Warden Bot
----------------------------------

function funcRetreatFromThreatExecuteOverride(botBrain)
	local bActionTaken = false
	local unitSelf = core.unitSelf
	local vecMyPosition = unitSelf:GetPosition()
	local nlastRetreatUtil = behaviorLib.lastRetreatUtil
	local unitTarget = behaviorLib.heroTarget
	local tEnemies = core.localUnits["EnemyHeroes"]
	local nCount = 0
	
	if unitSelf:GetHealthPercent() < .33 then
		for id, unitEnemy in pairs(tEnemies) do
			if core.CanSeeUnit(botBrain, unitEnemy) then
				nCount = nCount + 1
			end
		end
	
		if nCount > 0 then
			local abilSap = skills.abilW
			if not bActionTaken then --and bTargetVuln then
				if abilSap:CanActivate() and nlastRetreatUtil > botBrain.nDefSapThreshold then
					bActionTaken = core.OrderAbility(botBrain, abilSap)
				end
			end
			
		end
	end
	
	if unitTarget == nil then
     		return object.RetreatFromThreatExecuteOld(botBrain)
	end
	if not bActionTaken then
		return object.RetreatFromThreatExecuteOld(botBrain)
	end
	
end
object.RetreatFromThreatExecuteOld = behaviorLib.RetreatFromThreatExecute
behaviorLib.RetreatFromThreatBehavior["Execute"] = funcRetreatFromThreatExecuteOverride


object.killMessages = {}
object.killMessages.General = {
	"My love for you was like a truck... Berzerkeeer !",
	"Oh you're already dead?! I'm Berzerkeeeeer !",
	"You're Next... yeah you...",
	"Call me Carnage, Disaster, Rampage (oops it's already taken...) I'm just Berzerkeeer !!!",
	"Buy a Behemoth's Heart next time, The Berzeeeerk Mode would last longer...",
	"If your Respawn time was 0.5 second and at the same place, it would be funnier... I'm Berzeeeerker !!!"
	}
object.killMessages.Hero_Xalnyx 		= {	"Controlling chains can't prevent you to die against mine... Berzerkeeers !!!",
											"Chain the Unchained... Berzerkeeer !" }
object.killMessages.Hero_Rampage			= { "Carnage vs Rampage, like in Alphabet, I won...", }
object.killMessages.Hero_Engineer			= {	"When this war is over, I'll be waiting your respawn time, so we go to drink some of your Keg ale, my brother" }


local function ProcessKillChatOverride(unitTarget, sTargetPlayerName)
	local nCurrentTime = HoN.GetGameTime()
	if nCurrentTime < core.nNextChatEventTime then
		return
	end	
	
	local nToSpamOrNotToSpam = random()
	--BotEcho(unitTarget:GetTypeName())
		
	if(nToSpamOrNotToSpam < core.nKillChatChance) then
		local nDelay = random(core.nChatDelayMin, core.nChatDelayMax) 
		local tHeroMessages = object.killMessages[unitTarget:GetTypeName()]
		
		local sMessage = nil
		if tHeroMessages ~= nil and random() <= 0.7 then -- about a third of the time we use hero specific ones (if there are any)
			local nMessage = random(#tHeroMessages)
			--BotEcho('Specific chat')
			sMessage = tHeroMessages[nMessage]
		else
			local nMessage = random(#object.killMessages.General) 
			sMessage = object.killMessages.General[nMessage]
		end
		
		local sTargetName = sTargetPlayerName or unitTarget:GetDisplayName()
		if sTargetName == nil or sTargetName == "" then
			sTargetName = unitTarget:GetTypeName()
		end
		
		core.AllChatLocalizedMessage(sMessage, {target=sTargetName}, nDelay)
	end
	
	core.nNextChatEventTime = nCurrentTime + core.nChatEventInterval
end
core.ProcessKillChat = ProcessKillChatOverride

function behaviorLib.TimeToLiveUtilityFn(unitHero)
	--Increases as your time to live based on your damage velocity decreases
	local nUtility = 0
	local nTimeToLive = 9999

	if unitHero.bIsMemoryUnit then
		local nHealthVelocity = unitHero:GetHealthVelocity()
		local nHealth = unitHero:GetHealth()
		if nHealthVelocity < 0 then
			nTimeToLive = nHealth / (-1 * nHealthVelocity)

			local nYIntercept = 100
			local nXIntercept = 20
			local nOrder = 2
			nUtility = core.ExpDecay(nTimeToLive, nYIntercept, nXIntercept, nOrder)
		end
	end

	nUtility = Clamp(nUtility, 0, 100)

	--BotEcho(format("%d timeToLive: %g  healthVelocity: %g", HoN.GetGameTime(), nTimeToLive, nHealthVelocity))

	return nUtility, nTimeToLive
end

function behaviorLib.InsanitariusAutoOffUtility(botBrain)
	-- Insanitarius Desactivation by Melto
	
	local nUtility = 0
	local unitSelf = core.unitSelf
	if unitSelf:HasState("State_Insanitarius") then
		local DangerOneHealthPoint = 500
		local LowHealthThreshold = 0.25
		local TimeToLiveThreshold = 50
		local tEnemyHeroes = core.localUnits["EnemyHeroes"]
		local tEnemyCreeps = core.localUnits["EnemyCreeps"]
		local nHeroes = core.NumberElements(tEnemyHeroes)
		local nCreeps = core.NumberElements(tEnemyCreeps)
		core.FindItems()
		local itemInsanitarius = core.itemInsanitarius
		local nLastHarassUtility = behaviorLib.lastHarassUtil
		
		local nTimeToLiveUtility = nil
		local nCurrentTimeToLive = nil
		nTimeToLiveUtility, nCurrentTimeToLive = behaviorLib.TimeToLiveUtilityFn(unitSelf)
		if itemInsanitarius and itemInsanitarius:CanActivate() then
			if nHeroes == 0 and (nCreeps == 0 or (nCreeps > 0 and unitSelf:GetHealth() > DangerOneHealthPoint)) then
				return 999
			end

			if nLastHarassUtility < botBrain.nInsanitariusOffThreshold and unitSelf:GetHealth() > DangerOneHealthPoint then
				return 999
			end

			if unitSelf:GetHealthPercent() < LowHealthThreshold and nCurrentTimeToLive > TimeToLiveThreshold and unitSelf:GetHealth() < DangerOneHealthPoint then
				return 999
			end

			if unitSelf:GetHealthPercent() < LowHealthThreshold and unitSelf:GetHealth() > DangerOneHealthPoint then
				return 999
			end
		end
	end
	return 0
end

function behaviorLib.InsanitariusAutoOffExecute(botBrain)

	local unitSelf = core.unitSelf
	core.FindItems()
	local itemInsanitarius = core.itemInsanitarius

	if itemInsanitarius and itemInsanitarius:CanActivate() then
		core.OrderItemClamp(botBrain, unitSelf, itemInsanitarius)
		return true 
	end
	
	return false
end

behaviorLib.InsanitariusAutoOff = {}
behaviorLib.InsanitariusAutoOff["Utility"] = behaviorLib.InsanitariusAutoOffUtility
behaviorLib.InsanitariusAutoOff["Execute"] = behaviorLib.InsanitariusAutoOffExecute
behaviorLib.InsanitariusAutoOff["Name"] = "InsanitariusAutoOff"
tinsert(behaviorLib.tBehaviors, behaviorLib.InsanitariusAutoOff)
