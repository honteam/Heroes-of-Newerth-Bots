--Created by SPENNERINO
--TrembleBot v0.1

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

BotEcho('loading tremble_main...')

object.heroName = 'Hero_Tremble'

--------------------------------
-- Skills
--------------------------------
function object:SkillBuild()
	core.VerboseLog("SkillBuild()")

	local unitSelf = self.core.unitSelf	
	
	if  skills.abilDarkSwarm == nil then
		skills.abilDarkSwarm		= unitSelf:GetAbility(0)
		skills.abilTerrorform		= unitSelf:GetAbility(1)
		skills.abilImpalers			= unitSelf:GetAbility(2)
		skills.abilHiveMind			= unitSelf:GetAbility(3)
		skills.abilAttributeBoost	= unitSelf:GetAbility(4)
		skills.abilTerrorMound		= unitSelf:GetAbility(5)
		skills.abilTerrorPort		= unitSelf:GetAbility(6)
		skills.abilTaunt			= unitSelf:GetAbility(8)
	end
	
	if unitSelf:GetAbilityPointsAvailable() <= 0 then
		return
	end
	
	object.tSkills = {
	    1, 2, 2, 0, 1,
	    3, 2, 2, 0, 0, 
	    3, 0, 1, 1, 4,
	    3, 4, 4, 4, 4,
	    4, 4, 4, 4, 4,
	}
	
	local nLev = unitSelf:GetLevel()
    local nLevPts = unitSelf:GetAbilityPointsAvailable()
    for i = nLev, nLev+nLevPts do
        unitSelf:GetAbility( object.tSkills[i] ):LevelUp()
    end
end

---------------------------------------------------
--                Local Functions                --
---------------------------------------------------

local function GetTerrorMoundRadius()
	return 450
end

local function IsOnTerrorMound(unitSelf)	
	if unitSelf:HasState("State_Tremble_Ability2") or unitSelf:IsStealth() then
		return true
	else
		return false
	end
end

local function CanTerrorPort(unitSelf)
	if unitSelf:HasState("State_Tremble_Ability2_Teleport") then
		return true
	else
		return false
	end
end

local function IsLowHealth()
	local nMaxHealth = core.unitSelf:GetMaxHealth()
	local nHealth = core.unitSelf:GetHealth()
	
	if nHealth < (nMaxHealth * 0.1) or nHealth < 150 then
		return true
	else
		return false
	end
end

local function IsLowMana()
	local nMaxMana = core.unitSelf:GetMaxMana()
	local nMana = core.unitSelf:GetMana()
	
	if nMana < (nMaxMana * 0.3) then
		return true
	else
		return false
	end
end

---------------------------------------------------
--                   Overrides                   --
---------------------------------------------------

--melee weight overrides
behaviorLib.nCreepPushbackMul = 0.5
behaviorLib.nTargetPositioningMul = 0.6

----------------------------------
--	Tremble' specific harass bonuses
--
--  Abilities off cd increase harass util
--  Ability use increases harass util for a time
----------------------------------

object.nDarkSwarmUp =  10
object.nTerrorMoundUp = 0
object.nTerrorPortUp = 0
object.nImpalersUp = 10
object.nHiveMindUp = 40

object.nDarkSwarmUse = 5
object.nImpalersUse = 5

object.nDarkSwarmThreshold = 40 
object.nTerrorMoundThreshold = 60
object.nHiveMindThreshold = 60

local function AbilitiesUpUtility(hero)
	local bDebugLines = false
	local bDebugEchos = false
	
	local nUtility = 0
	local nLowHealthBonusDown = 20
	local nLowManaBonusDown = 5
	
	if skills.abilDarkSwarm:CanActivate() then
		nUtility = nUtility + object.nDarkSwarmUp
	end
	
	if skills.abilImpalers:GetLevel() > 0 then
		nUtility = nUtility + (object.nImpalersUp * skills.abilImpalers:GetLevel())
	end
	
	if skills.abilHiveMind:CanActivate() then
		nUtility = nUtility + object.nHiveMindUp
	end
	
	--Is On Mound
	--Can Port
	
	--Find Borus
	
	if IsLowHealth() then
		nUtility = core.Clamp(nUtility - nLowHealthBonusDown,0,100)
	end
	
	if IsLowMana() then
		nUtility = core.Clamp(nUtility - nLowManaBonusDown,0,100)
	end
	
	--BotEcho(nUtility)
	
	if bDebugLines then
		local lineLen = 150
		local myPos = core.unitSelf:GetPosition()
		local vTowards = Vector3.Normalize(hero:GetPosition() - myPos)
		local vOrtho = Vector3.Create(-vTowards.y, vTowards.x) --quick 90 rotate z
		core.DrawDebugArrow(myPos - vOrtho * lineLen * 1.4, (myPos - vOrtho * lineLen * 1.4 ) + vTowards * nUtility * (lineLen/100), 'cyan')
	end
	
	return nUtility
end

--Tremble ability use gives bonus to harass util for a while
function object:oncombateventOverride(EventData)
	self:oncombateventOld(EventData)
	
	local bDebugEchos = false
	local nAddBonus = 0
	
	if EventData.Type == "Attack" and EventData.TargetUnit:IsHero() then
		--BotEcho("ABILILTY EVENT!  InflictorName: "..EventData.InflictorName)
		BotEcho("IMPALERS")		
		nAddBonus = nAddBonus + object.nImpalersUse
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
	local nUtility = AbilitiesUpUtility(hero)
	return nUtility
end
behaviorLib.CustomHarassUtility = CustomHarassUtilityFnOverride   

----------------------------------
--	Tremble harass actions
----------------------------------

local function HarassHeroExecuteOverride(botBrain)
	local bDebugEchos = false
	
	local unitTarget = behaviorLib.heroTarget
	if unitTarget == nil then
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
	
	local nLastHarassUtility = behaviorLib.lastHarassUtil	
	local bActionTaken = false
	
	--unitTarget property helpers
	local bTargetRooted = unitTarget:IsStunned() or unitTarget:IsImmobilized() or unitTarget:GetMoveSpeed() < 200
	local bTargetVuln = unitTarget:IsStunned() or unitTarget:IsImmobilized()
	local bCanSee = core.CanSeeUnit(botBrain, unitTarget)

	--Ability and Item Pointers
	local abilDarkSwarm = skills.abilDarkSwarm
	local abilImpalers = skills.abilImpalers
	local abilHiveMind = skills.abilHiveMind
	local abilTerrorMound = skills.abilTerrorMound
	local abilTerrorPort = skills.abilTerrorPort
	local abilTaunt = skills.abilTaunt
	
	core.FindItems()
	local itemImmunity = core.itemImmunity
	local itemSolsBulwark = core.itemSolsBulwark

	if not bActionTaken then
		if abilHiveMind:CanActivate() then
			if bDebugEchos then BotEcho("Casting Hive Mind") end
			BotEcho("Casting Hive Mind")
			--core.OrderAbility(botBrain, abilHiveMind)
		end
	end
	
	if bCanSee then
		if not bActionTaken then
			if abilDarkSwarm:CanActivate() and nLastHarassUtility > botBrain.nDarkSwarmThreshold then
				if bDebugEchos then BotEcho("Casting Dark Swarm") end
				
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
--  FindItems Override
----------------------------------
local function funcFindItemsOverride(botBrain)
	local bUpdated = object.FindItemsOld(botBrain)

	if bUpdated then
		--only update if we need to
		if core.itemImmunity and core.itemSolsBulwark and core.itemPierce then
			return
		end

		local inventory = core.unitSelf:GetInventory(true)
		for slot = 1, 12, 1 do
			local curItem = inventory[slot]
			if curItem then
				if core.itemImmunity == nil and curItem:GetName() == "Item_Immunity" then
					core.itemImmunity = core.WrapInTable(curItem) 
				elseif core.itemSolsBulwark == nil and curItem:GetName() == "Item_SolsBulwark" then
					core.itemSolsBulwark = core.WrapInTable(curItem)
				elseif core.itemPierce == nil and curItem:GetName() == "Item_Pierce" then
					core.itemPierce = core.WrapInTable(curItem)
				end
			end
		end
	end
end
object.FindItemsOld = core.FindItems
core.FindItems = funcFindItemsOverride

----------------------------------
--  RetreatFromThreat Override
----------------------------------
object.nRetreatThreshold = 35

--Unfortunately this utility is kind of volatile, so we basically have to deal with util spikes
function funcRetreatFromThreatExecuteOverride(botBrain)
	local bDebugEchos = false
	
	local bActionTaken = false
	local unitSelf = core.unitSelf
	
	--Shrunken ?
	--Mound ?
	--Both ?
	--Re Hive Mind?
	
	if not bActionTaken then
		return object.RetreatFromThreatExecuteOld(botBrain)
	end
end
object.RetreatFromThreatExecuteOld = behaviorLib.RetreatFromThreatExecute
behaviorLib.RetreatFromThreatBehavior["Execute"] = funcRetreatFromThreatExecuteOverride

function funcHealAtWellExecuteOverride(botBrain)
	local bDebugEchos = false
	
	local bActionTaken = false
	local unitSelf = core.unitSelf
	
	--Can Terror Port Home?
	
	if not bActionTaken then
		return object.HealAtWellExecuteOld(botBrain)
	end
end
object.HealAtWellExecuteOld = behaviorLib.HealAtWellExecute
behaviorLib.HealAtWellBehavior["Execute"] = funcHealAtWellExecuteOverride

----------------------------------
--	Tremble items
----------------------------------
--[[ list code:
	"# Item" is "get # of these"
	"Item #" is "get this level of the item" --]]
	
behaviorLib.StartingItems = 
	{"Item_LoggersHatchet", "Item_IronBuckler", "Item_RunesOfTheBlight"}
behaviorLib.LaneItems = 
	{"Item_Marchers", "Item_EnhancedMarchers", "Item_Lifetube"}
behaviorLib.MidItems = 
	{"Item_Shield2", "Item_MysticVestments", "Item_Immunity", "Item_SolsBulwark", "Item_Pierce 1"}
behaviorLib.LateItems =
	{"Item_Shield2", "Item_Immunity", "Item_DaemonicBreastplate", "Item_Pierce 3", "Item_BehemothsHeart"} 
 
----------------------------------
--	Custom Behaviors
----------------------------------
local vecMoundFountain = nil
local vecMoundMidTower = nil
local vecMoundMidRiver = nil
local nMaxMounds = 0
 
local function GetUnits(position, radius, sorted)  
	return HoN.GetUnitsInRadius(position, radius, core.UNIT_MASK_ALIVE + core.UNIT_MASK_GADGET + core.UNIT_MASK_CORPSE + core.UNIT_MASK_UNIT, sorted or false)
end 
 
local function GetMounds(unitSelf)  
	local allUnits = GetUnits(Vector3.Create(), 99999)  
	
	--core.printGetNameTable(allUnits)
	--core.printGetTypeNameTable(allUnits)
	
	local tMounds = {}
	for key, unit in pairs(allUnits) do    
		local typeName = unit:GetTypeName()    
		if unit:GetTeam() == unitSelf:GetTeam() and 
		(typeName == "Gadget_Tremble_Ability2") then   
			tMounds[key] = unit
		end
	end

	if core.IsTableEmpty(tMounds) then
		return nil
	end
	
	return tMounds
end

local function GetMoundCount(unitSelf)
	tMounds = GetMounds(unitSelf)
	return core.NumberElements(tMounds)
end 

local function GetFountainMound(unitSelf)
	tMounds = GetMounds(unitSelf)
	if tMounds ~= null then
		for key, unit in pairs(tMounds) do
			vecPosition = unit:GetPosition()
			if vecPosition.x == vecMoundFountain.x and vecPosition.y == vecMoundFountain.y then
				return unit
			end
		end	
	end
	
	return nil
end
 
function behaviorLib.TerrorformUtility(botBrain)    
	local nUtility = 0    
	local unitSelf = core.unitSelf  
	
	if unitSelf:GetTeam() == 1 then
		vecMoundFountain = Vector3.Create(1728, 1120)
		vecMoundMidTower = Vector3.Create(7100, 6895)
		vecMoundMidRiver = Vector3.Create(7330, 7380)
	else
		vecMoundFountain = Vector3.Create(13977, 13462)
		vecMoundMidTower = Vector3.Create(8650, 7950)
		vecMoundMidRiver = Vector3.Create(7900, 7780)
	end

	nLevel = skills.abilTerrorform:GetLevel()
	nMaxMounds = 0
	if nLevel == 1 then
		nMaxMounds = 3
	elseif nLevel == 2 then
		nMaxMounds = 5
	elseif nLevel == 3 then
		nMaxMounds = 7
	elseif nLevel == 4 then
		nMaxMounds = 9
	end
	
	local nTime = HoN.GetMatchTime()  
	local abilTerrorMound = skills.abilTerrorMound
	local nDistanceSq = Vector3.Distance2DSq(unitSelf:GetPosition(), vecMoundFountain)
	
	if GetMoundCount(unitSelf) < 2 or (nTime == 0
	and nDistanceSq > (abilTerrorMound:GetRange() * abilTerrorMound:GetRange())) then
		nUtility = 100
	elseif GetMoundCount(unitSelf) < nMaxMounds then  
		--[[	
		if not HoN.CanSeePosition(vecWardSpot1) then          
			nUtility = nUtility + 10 
		end 
		if not HoN.CanSeePosition(vecWardSpot2) then            
			nUtility = nUtility + 10            
		end       
		]]		
	end
	
	return nUtility
end 
	
function behaviorLib.TerrorformExecute(botBrain)
	local bDebugEchos = false
	local unitSelf = core.unitSelf    
	
	if vecMoundFountain ~= nil then 
		local abilTerrorMound = skills.abilTerrorMound
		local abilTerrorPort = skills.abilTerrorPort
		local nTime = HoN.GetMatchTime() 

		if GetMoundCount(unitSelf) == 0 then        
			local nDistanceSq = Vector3.Distance2DSq(unitSelf:GetPosition(), vecMoundFountain)
			
			if abilTerrorMound:CanActivate() 
			and nDistanceSq < (abilTerrorMound:GetRange() * abilTerrorMound:GetRange()) then            
				core.OrderAbilityPosition(botBrain, abilTerrorMound, vecMoundFountain)
				if bDebugEchos then BotEcho("TerrorMound Fountain") end				
			end
		elseif GetMoundCount(unitSelf) == 1 then
			local nDistanceSq = Vector3.Distance2DSq(unitSelf:GetPosition(), vecMoundMidTower) 
			
			if abilTerrorMound:CanActivate() 
			and nDistanceSq < (abilTerrorMound:GetRange() * abilTerrorMound:GetRange()) then            
				core.OrderAbilityPosition(botBrain, abilTerrorMound, vecMoundMidTower)
				if bDebugEchos then BotEcho("TerrorMound Mid Tower") end
			elseif unitSelf:GetManaPercent() > 0.9 then     
				core.OrderMoveToPosClamp(botBrain, unitSelf, vecMoundMidTower, false)    
				if bDebugEchos then BotEcho("Move to Mid Tower") end				
			end
		elseif abilTerrorPort:CanActivate()
		and GetMoundCount(unitSelf) == 2 then
			unitFountainMound = GetFountainMound(unitSelf)
			if unitFountainMound ~= nil then			
				core.OrderAbilityPosition(botBrain, abilTerrorPort, unitFountainMound:GetPosition())
				if bDebugEchos then BotEcho("TerrorPort to Fountain") end
			end
		end
	else        
		return false    
	end         
	
	return true
end 

behaviorLib.TerrorformBehavior = {}
behaviorLib.TerrorformBehavior["Utility"] = behaviorLib.TerrorformUtility
behaviorLib.TerrorformBehavior["Execute"] = behaviorLib.TerrorformExecute
behaviorLib.TerrorformBehavior["Name"] = "Terrorform"
tinsert(behaviorLib.tBehaviors, behaviorLib.TerrorformBehavior)
 
BotEcho('finished loading tremble_main')