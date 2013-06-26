--TeamBot v1.0


local _G = getfenv(0)
local object = _G.object

object.teamID = object:GetTeam()
object.myName = ('Team '..(object.teamID or 'nil'))

object.bRunLogic   	= true
object.bGroupAndPush	= true
object.bDefense			= true

object.bUseRealtimePositions = false

object.logger = {}
object.logger.bWriteLog = false
object.logger.bVerboseLog = false


object.core 		= {}
object.metadata 	= {}

runfile "bots/core.lua"
runfile "bots/metadata.lua"

local core, metadata = object.core, object.metadata

local print, ipairs, pairs, string, table, next, type, tinsert, tremove, tsort, format, tostring, tonumber, strfind, strsub
	= _G.print, _G.ipairs, _G.pairs, _G.string, _G.table, _G.next, _G.type, _G.table.insert, _G.table.remove, _G.table.sort, _G.string.format, _G.tostring, _G.tonumber, _G.string.find, _G.string.sub
local ceil, floor, pi, tan, atan, atan2, abs, cos, sin, acos, max, random
	= _G.math.ceil, _G.math.floor, _G.math.pi, _G.math.tan, _G.math.atan, _G.math.atan2, _G.math.abs, _G.math.cos, _G.math.sin, _G.math.acos, _G.math.max, _G.math.random

local BotEcho, VerboseLog, BotLog = core.BotEcho, core.VerboseLog, core.BotLog
local Clamp = core.Clamp

BotEcho('Loading teambotbrain...')

object.tAllyHeroes = {}
object.tEnemyHeroes = {}
object.tAllyHumanHeroes = {}
object.tAllyBotHeroes = {}

object.tTopLane = {}
object.tMiddleLane = {}
object.tBottomLane = {}
object.tJungle = {}

object.teamBotBrainInitialized = false
function object:TeamBotBrainInitialize()
	BotEcho('TeamBotBrainInitializing')
	
	local bDebugEchos = false

	--collect all heroes
	self.tAllyHeroes = HoN.GetHeroes(core.myTeam)
	self.tEnemyHeroes = HoN.GetHeroes(core.enemyTeam)
	
	for _, hero in pairs(self.tAllyHeroes) do
		if hero:IsBotControlled() then
			self.tAllyBotHeroes[hero:GetUniqueID()] = hero
		else
			self.tAllyHumanHeroes[hero:GetUniqueID()] = hero
		end
	end
	
 	if bDebugEchos then
		BotEcho('tAllyHeroes')
		core.printGetTypeNameTable(self.tAllyHeroes)
		BotEcho('allyHumanHeroes')
		core.printGetTypeNameTable(self.tAllyHumanHeroes)
		BotEcho('allyBotHeroes')
		core.printGetTypeNameTable(self.tAllyBotHeroes)
		BotEcho('enemyHeroes')
		core.printGetTypeNameTable(self.tEnemyHeroes)		
	end
	
	object.teamBotBrainInitialized = true
end

--Time left before the match starts when the bots should move to lane
object.nInitialBotMove = 15000

object.bLanesBuilt = false
object.laneDoubleCheckTime = 17000 --time after start to double check our lane decisions
object.bLanesDoubleChecked = false
object.laneReassessTime = 0
object.laneReassessInterval = core.MinToMS(3) --regular interval to check for player lane switches

local STATE_IDLE		= 0
local STATE_GROUPING	= 1
local STATE_PUSHING		= 2
object.nPushState = STATE_IDLE

--Called every frame the engine gives us during the actual match
function object:onthink(tGameVariables)
	StartProfile('onthink')
	if core.coreInitialized == false or core.coreInitialized == nil then
		core.CoreInitialize(self)
	end	
	if self.teamBotBrainInitialized == false then
		self:TeamBotBrainInitialize()
	end
	if metadata.bInitialized == false then
		metadata.Initialize()
	end	
	if core.tGameVariables == nil then
		if tGameVariables == nil then
			BotEcho("TGAMEVARIABLES IS NIL OH GOD OH GOD WHYYYYYYYY!??!?!!?")
		else
			core.tGameVariables = tGameVariables
			core.bIsTutorial = core.tGameVariables.sMapName == 'tutorial'
			core.nDifficulty = core.tGameVariables.nDifficulty or core.nEASY_DIFFICULTY
			
			--[Tutorial] Hellbourne heroes don't group up to push and Legion waits longer to push
			if core.bIsTutorial then
				if core.myTeam == HoN.GetHellbourneTeam() then
					self.bGroupAndPush = false
				else
					object.nNextPushTime = core.MinToMS(12)
				end
			end
			
			--[Difficulty: Easy] Bots don't defend
			if core.nDifficulty == core.nEASY_DIFFICULTY or core.bIsTutorial then
				object.bDefense = false
				-- don't reset this when the tutorial switches Legion to medium
			end
		end
	end

	if self.bRunLogic == false then 
		return
	end
	
	self.bPurchasedThisFrame = false
	
	StartProfile('Validation')
		core.ValidateReferenceTable(self.tMemoryUnits)
		core.ValidateUnitReferences()
	StopProfile()
	
	StartProfile('UpdateMemoryUnits')
		self:UpdateAllMemoryUnits()
	StopProfile()	
	
	StartProfile('UpdateTeleportBuildings')
		self:UpdateTeleportBuildings()
	StopProfile()
	
	StartProfile('LethalityCalculations')
		self:LethalityCalculations()
	StopProfile()
	
	StartProfile('Lane Building')
		--build lanes as the match starts, and reassess lanes every few minutes to cater to players
		local curTime = HoN.GetGameTime()

		if HoN.GetRemainingPreMatchTime() <= self.nInitialBotMove then
			if curTime > self.laneReassessTime and self.nPushState == STATE_IDLE then
				--TODO: defense lanes integration
				self:BuildLanes()
				
				if self.bLanesDoubleChecked then
					self.laneReassessTime = curTime + self.laneReassessInterval
				else
					self.laneReassessTime = curTime + self.laneDoubleCheckTime
					self.bLanesDoubleChecked = true
				end
			end
		end
	StopProfile()
	
	StartProfile('Group and Push Logic')
	if self.bGroupAndPush ~= false then
		self:GroupAndPushLogic()
	end
	StopProfile()
	
	StartProfile('Defense Logic')
	if self.bDefense ~= false then
		self:DefenseLogic()
	end
	StopProfile()
end

function object:PrintLanes(tTop, tMid, tBot)
	if not tTop then
		tTop = self.tTopLane
	end
	if not tMid then
		tMid = self.tMiddleLane
	end
	if not tBot then
		tBot = self.tBottomLane
	end
	
	print('    top: ')
	for nUID, unit in pairs(tTop) do
		print('['..nUID..']'..unit:GetTypeName())
		print(', ')
	end
	print('\n    mid: ')
	for nUID, unit in pairs(tMid) do
		print('['..nUID..']'..unit:GetTypeName())
		print(', ')
	end
	print('\n    bot: ')
	for nUID, unit in pairs(tBot) do
		print('['..nUID..']'..unit:GetTypeName())
		print(', ')
	end
	print('\n')
end

object.tTeleportBuildings = {}
function object:UpdateTeleportBuildings()
	if core.allyTowers then
		local tTeleportBuildings = core.CopyTable(core.allyTowers)
		
		local tRax = core.allyRax
		for k,v in pairs(tRax) do
			tTeleportBuildings[k] = v
		end

		tTeleportBuildings[core.allyMainBaseStructure:GetUniqueID()] = core.allyMainBaseStructure
		tTeleportBuildings[core.allyWell:GetUniqueID()] = core.allyWell
		
		self.tTeleportBuildings = tTeleportBuildings
	end
end

function object:GetTeleportBuildings()
	return self.tTeleportBuildings
end

---- Memory units ----
object.tMemoryUnits = {}

object.nMemoryUnitHealthIntervalMS = 3000
function object:CreateMemoryUnit(unit)	
	StartProfile('CreateMemoryUnit')
	
	if unit == nil then
		BotEcho("CreateMemoryUnit - unit is nil")
		StopProfile()
		return nil
	end
	
	local nID = unit:GetUniqueID()
	local tMemoryUnits = self.tMemoryUnits
	if tMemoryUnits and tMemoryUnits[nID] ~= nil then
		--BotEcho(tostring(unit).." is already a memory unit; returning it")
		StopProfile()
		return tMemoryUnits[nID]
	end
		
	local tWrapped = core.WrapInTable(unit)
	
	if tWrapped then		
		--add to our list
		if tMemoryUnits then
			tMemoryUnits[nID] = tWrapped
		end
	
		local tMetatable = getmetatable(tWrapped)
		local tFunctionObject = tMetatable.__index
		
		--Echo("tFunctionObject")
		--core.printTable(tFunctionObject)
		
		--store some data
		tWrapped.bIsMemoryUnit		= true
		tWrapped.storedTime			= HoN.GetGameTime()
		tWrapped.storedHealth 		= tWrapped:GetHealth()
		tWrapped.storedMaxHealth 	= tWrapped:GetMaxHealth()
		tWrapped.storedMana			= tWrapped:GetMana()
		tWrapped.storedMaxMana		= tWrapped:GetMaxMana()
		tWrapped.storedPosition		= tWrapped:GetPosition()
		tWrapped.storedMoveSpeed	= tWrapped:GetMoveSpeed()
		tWrapped.storedAttackRange	= tWrapped:GetAttackRange()
		tWrapped.lastStoredPosition	= nil
		tWrapped.lastStoredTime  	= nil
		
		tWrapped.tStoredHealths 	= {}
		tWrapped.nHealthVelocity	= nil
		
		--tWrapped.nAverageHealthVelocity		= nil
		--tWrapped.nAverageHealthVelocityTime	= nil
		
		tWrapped.debugPosition		= false
		tWrapped.debugPositionSent	= false
		
		--tWrapped.storedPositions 	= {}
		--tWrapped.storedPositions[tWrapped.storedTime] = tWrapped:GetPosition()
		
		local funcNewGetHealth = nil
		local funcNewGetMaxHealth = nil
		local funcNewGetHealthPercent = nil
		local funcNewGetMana = nil
		local funcNewGetMaxMana = nil
		local funcNewGetPosition = nil
		local funcNewGetMoveSpeed = nil
		local funcNewGetAttackRange = nil
		
		local funcGetHealthVelocity = nil
		
		
		--GetHealth
		funcNewGetHealth = function(tThis)
			return tThis.storedHealth
		end
		
		--GetMaxHealth
		funcNewGetMaxHealth = function(tThis)
			return tThis.storedMaxHealth
		end
		
		--GetHealthPercent
		funcNewGetHealthPercent = function(tThis)
			return tThis.storedHealth/tThis.storedMaxHealth
		end
					
		--GetMana
		funcNewGetMana = function(tThis)
			return tThis.storedMana
		end
		
		--GetMaxMana
		funcNewGetMaxMana = function(tThis)
			return tThis.storedMaxMana
		end
		
		--GetPosition
		funcNewGetPosition = function(tThis)
			local vecReturn = tThis.storedPosition
			local bPredicted = false
			
			if object.bUseRealtimePositions and core.CanSeeUnit(object, tThis) then
				vecReturn = tThis.object:GetPosition()
			end
			
			local nCurrentTime = HoN.GetGameTime()
			if tThis.storedTime ~= nCurrentTime and not core.CanSeeUnit(object, tThis) then --object reference feels hacky, probably because it is
				--prediction and shit
				bPredicted = true
				--core.UpdateMemoryAveragePositions(tThis)
				if tThis.storedPosition and tThis.lastStoredPosition and tThis.storedMoveSpeed then
					local vecLastDirection = Vector3.Normalize(tThis.storedPosition - tThis.lastStoredPosition)
					vecReturn = tThis.storedPosition + vecLastDirection * tThis.storedMoveSpeed * core.MSToS(nCurrentTime - tThis.storedTime)
					
					if tThis.debugPosition then core.DrawArrowLine(tThis.storedPosition, tThis.storedPosition + vecLastDirection * 150, 'teal') end				
				else
					vecReturn = tThis.storedPosition
				end
			end
			
			if tThis.debugPosition and not tThis.debugPositionSent then
				if tThis.lastStoredPosition then 	core.DrawXPosition(tThis.lastStoredPosition, 'teal') end
				if tThis.storedPosition then 		core.DrawXPosition(tThis.storedPosition, 'blue') end
				if vecReturn then 				core.DrawXPosition(vecReturn, 'red') end
				tThis.debugPositionSent = true
			end
			
			return vecReturn, bPredicted
		end
		
		--GetMoveSpeed
		funcNewGetMoveSpeed = function(tThis)
			return tThis.storedMoveSpeed
		end
		
		--GetAttackRange
		funcNewGetAttackRange = function(tThis)
			return tThis.storedAttackRange
		end
		
		--GetHealthVelocity
		funcGetHealthVelocity = function(tThis)
			return tThis.nHealthVelocity or 0
		end
		
		--GetAverageHealthVelocity
		--[[
		local function GetAverageHealthVelocityFn(t)
			local nAverageHealthVelocityTime = t.nAverageHealthVelocityTime
			if nAverageHealthVelocityTime == nil or nAverageHealthVelocityTime < t.storedTime then
				core.UpdateAverageHealthVelocity(t)
			end
			
			return t.nAverageHealthVelocity or 0
		end
		tFunctionObject.GetAverageHealthVelocity = GetAverageHealthVelocityFn
		--]]	
		
		tFunctionObject.GetHealth			= funcNewGetHealth
		tFunctionObject.GetMaxHealth		= funcNewGetMaxHealth
		tFunctionObject.GetHealthPercent	= funcNewGetHealthPercent
		tFunctionObject.GetMana				= funcNewGetMana
		tFunctionObject.GetMaxMana			= funcNewGetMaxMana
		tFunctionObject.GetPosition			= funcNewGetPosition
		tFunctionObject.GetMoveSpeed		= funcNewGetMoveSpeed
		tFunctionObject.GetAttackRange		= funcNewGetAttackRange
		
		tFunctionObject.GetHealthVelocity	= funcGetHealthVelocity
	end
	
	StopProfile()
	return tWrapped
end

--[[
function core.UpdateAverageHealthVelocity(tUnit)
	local tPairs = {}
	for nTime, nHealth in pairs(tUnit.tStoredHealths) do
		tinsert(tPairs, {nTime, nHealth})
	end
	
	tsort(tPairs, function(a,b) return a[1] < b[1] end)
	
	local nAverageHealthVelocity = 0
	local nLastTime = nil
	local nLastHealth = nil	
	for i, tPair in ipairs(tPairs) do
		local nTime =	tPair[1]
		local nHealth = tPair[2]
		if nLastTime then
			nAverageHealthVelocity = nAverageHealthVelocity + (((nHealth - nLastHealth) / (nTime - nLastTime)) * 1000)
		end
		nLastTime = nTime
		nLastHealth = nHealth
	end
	tUnit.nAverageHealthVelocity = nAverageHealthVelocity / (#tPairs - 1)
	tUnit.nAverageHealthVelocityTime = tUnit.storedTime	
end
--]]

--[[
core.memoryUnitAverageVelocityTime = 2000
function core.UpdateMemoryPredictedVelocity(memoryUnit)
	local finalTime = HoN.GetGameTime()
	
	local sumVelocity = Vector3.Create()
	
	local currentTime = nil
	local currentPosition = nil
	local bFirstTime = true
	for nextTime, nextPosition in pairs(memoryUnit.storedPositions) do
		if not bFirstTime then
			local deltaTime = nextTime - currentTime
			
			sumVelocity = sumVelocity + (nextPosition - currentPosition) * deltaTime
		end
		
		bFristTime = false
		currentTime = nextTime
		currentPosition = nextPosition
	end	
	
	memoryUnit.predictedVelocityTime = finalTime
	memoryUnit.predictedVelocity = sumVelocity
end
--]]
--[[
function core.DrawMemoryPredictedVelocity(memoryUnit)
	local currentTime = nil
	local currentPosition = nil
	local bFirstTime = true
	for nextTime, nextPosition in pairs(memoryUnit.storedPositions) do
		if not bFirstTime then
			local deltaTime = nextTime - currentTime			
			local curVelocity = (nextPosition - currentPosition)
			
			core.DrawDebugArrow(currentPosition, currentPosition + curVelocity * core.MSToS(deltaTime), 'blue')
		end
		
		core.DrawXPosition(nextPosition, 'teal')
		
		bFristTime = false
		currentTime = nextTime
		currentPosition = nextPosition
	end
	
	local finalPosition = currentPosition
end
--]]

function object:UpdateMemoryUnit(unit)
	if not unit then
		return
	end
	
	if unit.bIsMemoryUnit then
		local nCurrentTime = HoN.GetGameTime()
		
		if core.CanSeeUnit(self, unit) then
			--BotEcho('Updating '..unit:GetTypeName())
			unit.lastStoredPosition	= unit.storedPosition
			unit.lastStoredTime  	= unit.storedTime
			
			unit.storedTime 		= nCurrentTime
			unit.storedHealth 		= unit.object:GetHealth()
			unit.storedMaxHealth 	= unit.object:GetMaxHealth()
			unit.storedMana			= unit.object:GetMana()
			unit.storedMaxMana		= unit.object:GetMaxMana()
			unit.storedPosition		= unit.object:GetPosition()
			unit.storedMoveSpeed	= unit.object:GetMoveSpeed()
			unit.storedAttackRange 	= unit.object:GetAttackRange()
			
			unit.tStoredHealths[nCurrentTime] = unit.storedHealth
		end
		
		unit.debugPositionSent			= false
		
		local nEarliestTime = 99999999	
		local nEarliestHealth = nil
		local tPairs = {}
		local nCutoffTime = nCurrentTime - self.nMemoryUnitHealthIntervalMS
		for nTime, nHealth in pairs(unit.tStoredHealths) do
			if nTime < nCutoffTime then
				--BotEcho(format("%d - %d < %d, removing", nTime, self.nMemoryUnitHealthIntervalMS, nCutoffTime))
				unit.tStoredHealths[nTime] = nil
			else
				if nTime < nEarliestTime then
					nEarliestTime = nTime
					nEarliestHealth = nHealth
				end
			end
		end
		
		if nEarliestHealth then
			unit.nHealthVelocity = ((unit:GetHealth() - nEarliestHealth) / self.nMemoryUnitHealthIntervalMS) * 1000
		end
		
		
		--unit.storedPositions[unit.storedTime] = unit:GetPosition()		
		--self:UpdateMemoryAveragePositions(memoryUnit)
	end
end

object.memoryUnitInterval = 200
object.memoryUnitTimeout = 3500
object.nMemoryUnitsNextUpdate = 0
function object:UpdateAllMemoryUnits()
	local bDebugEchos = false
	local currentTime = HoN.GetGameTime()
	
	if self.nMemoryUnitsNextUpdate > currentTime then
		return
	end
	
	local tMemoryUnits = self.tMemoryUnits
	local nMyTeam = core.myTeam
	
	for id, unit in pairs(tMemoryUnits) do
		if unit.bIsMemoryUnit then		
			self:UpdateMemoryUnit(unit)
			
			local pos, bPredicted = unit:GetPosition()
			local bHaveWaited = unit.storedTime + self.memoryUnitInterval > currentTime --give it a brief moment
			if unit:IsAlive() == false and unit:GetTeam() ~= nMyTeam then --bit hacky
				if bDebugEchos then BotEcho('Removing '..unit:GetTypeName()..' since it is dead') end
				tMemoryUnits[id] = nil			
			elseif bPredicted and bHaveWaited and HoN.CanSeePosition(pos) and not core.CanSeeUnit(self, unit) then
				--we have mispredicted, rm
				if bDebugEchos then BotEcho('Mispredicted position! removing') end
				tMemoryUnits[id] = nil
			elseif unit.storedTime + self.memoryUnitTimeout < currentTime then
				if bDebugEchos then BotEcho('Removing '..unit:GetTypeName()..' since it timedout') end
				tMemoryUnits[id] = nil
			end
		else
			if bDebugEchos then BotEcho('Removing '..(unit and unit:GetTypeName() or '"nil unit"')..' since it is not an actual memory unit') end
			tMemoryUnits[id] = nil --this is not an actual memoryUnit
		end
	end
	
	self.nMemoryUnitsNextUpdate = currentTime + self.memoryUnitInterval
end

function object:AddMemoryUnitsToTable(tInput, nTeamFilter, vecPos, nRadius, fnFilter)
	StartProfile('AddMemoryUnitsToTable')
	
	local bDebugEchos = false
	
	if tInput ~= nil then
		
		local bIgnoreDistance = false
		if vecPos and not nRadius then
			nRadius = nRadius or core.localCreepRange
		elseif not vecPos and not nRadius then
			bIgnoreDistance = true
		end
		
		if bDebugEchos then BotEcho(format("AddMemoryUnitsToTable - nTeamFilter: %s  bIgnoreDistance: %s", tostring(nTeamFilter), tostring(bIgnoreDistance))) end
		
		local tMemoryUnits = self.tMemoryUnits
		local nRadiusSq = (nRadius and nRadius * nRadius) or 0
		for nUID, unit in pairs(tMemoryUnits) do
			if (nTeamFilter == nil or unit:GetTeam() == nTeamFilter) and unit.bIsMemoryUnit then 
				if fnFilter == nil or fnFilter(unit) then
					local nUID = unit:GetUniqueID()
					if bIgnoreDistance or Vector3.Distance2DSq(unit:GetPosition(), vecPos) <= nRadiusSq then
						if bDebugEchos then BotEcho(format("  adding %d: %s", nUID, unit:GetTypeName())) end
						tInput[nUID] = unit
					end
				end
			end
		end
	end
	
	StopProfile()
end


---- Threat + Defense Calculations ----
object.nLethalityCalcInterval = 200

object.tStoredThreats = {}
object.tStoredDefenses = {}

function object:LethalityCalculations()
	bDebugEchos = false
	
	if bDebugEchos then BotEcho("LethalityCalculations()") end
	
	local tAllyHeroes = self.tAllyHeroes
	local tEnemyHeroes = self.tEnemyHeroes
	local tStoredThreats = object.tStoredThreats
	local tStoredDefenses = object.tStoredDefenses
	
	for nUID, unitHero in pairs(tAllyHeroes) do
		tStoredThreats[nUID]  = self.CalculateThreat(unitHero)
		tStoredDefenses[nUID] = self.CalculateDefense(unitHero)
		
		if bDebugEchos then BotEcho(format("%s  threat: %d  defense: %d", unitHero:GetTypeName(), tStoredThreats[nUID], tStoredDefenses[nUID])) end
	end
	
	for nUID, unitHero in pairs(tEnemyHeroes) do
		if core.CanSeeUnit(self, unitHero) then
			tStoredThreats[nUID]  = self.CalculateThreat(unitHero)
			tStoredDefenses[nUID] = self.CalculateDefense(unitHero)
			if bDebugEchos then BotEcho(format("%s  threat: %d  defense: %d", unitHero:GetTypeName(), tStoredThreats[nUID], tStoredDefenses[nUID])) end
		elseif bDebugEchos then
			BotEcho("Not updating "..unitHero:GetTypeName())
		end
	end	
end


function object.CalculateThreat(unitHero)
	local nDPSThreat = object.DPSThreat(unitHero)
	
	local nMoveSpeedThreat = unitHero:GetMoveSpeed() * 0.50
	local nRangeThreat = unitHero:GetAttackRange() * 0.50
	
	local nThreat = nDPSThreat + nMoveSpeedThreat + nRangeThreat -- + nCustomThreat
		
	return nThreat
end

function object.CalculateDefense(unitHero)
	local bDebugEchos = false

	--Health
	local nHealth = unitHero:GetHealth()
	local nMagicReduction = unitHero:GetMagicResistance()
	local nPhysicalReduction = unitHero:GetPhysicalResistance()
	
	--This is obviously not strictly accurate, but this will be effective for our utility calculations
	local nHealthDefense = nHealth + (nHealth * nMagicReduction) + (nHealth * nPhysicalReduction)
	nHealthDefense = nHealthDefense * 1.20
	
	if bDebugEchos then 
		BotEcho(format("HealthDefense: %d  nHealth: %d  nMagicR: %g  nPhysicalR: %g",
			nHealthDefense, nHealth, nMagicReduction, nPhysicalReduction)
		)
	end
	
	--MS and Range
	local nMoveSpeedDefense = unitHero:GetMoveSpeed() * 0.50
	local nRangeDefense = unitHero:GetAttackRange() * 0.50
		
	--local nRegen = unitHero:GetHealthRegen()
	--local nLifesteal = unitHero:GetLifeSteal()
	--local nLifeStealDefense = 0
	--if nLifesteal > 0 then
	--	local nDamage = core.GetFinalAttackDamageAverage(unitHero)
	--	local nAttacksPerSecond = core.GetAttacksPerSecond()
	--	local nDPS = nDamage * nAttacksPerSecond
	--	nLifeStealDefense = nDPS * nLifeSteal
	--end
	--
	--local nSustainabilityDefense = 0
	--
	--local nStayingPowerDefense = 
	--
	--local bStunned = unitHero:IsStunned()
	--local bImmobilized = unitHero:IsImmobilized()
	--
	--local nStunnedUtility = 0
	--local nImmobilizedUtility = 0
	
	local nDefense = nHealthDefense + nMoveSpeedDefense + nRangeDefense -- + other stuffs
	
	return nDefense
end

function object.DPSThreat(unitHero)
	local nDamage = core.GetFinalAttackDamageAverage(unitHero)
	local nAttacksPerSecond = core.GetAttacksPerSecond(unitHero)
	local nDPS = nDamage * nAttacksPerSecond
	
	--BotEcho(format("%s dps: %d  aps: %g  dmg: %d", unitHero:GetTypeName(), nDPS, nAttacksPerSecond, nDamage))
	
	return nDPS * 25
end


function object:GetThreat(unitHero)
	return self.tStoredThreats[unitHero:GetUniqueID()] or 0
end

function object:GetTotalThreat(tUnits)
	local nThreat = 0
	if tUnits then
		for _, unit in pairs(tUnits) do
			nThreat = nThreat + self:GetThreat(unit)
		end
	end
	return nThreat
end

function object:GetDefense(unitHero)
	return self.tStoredDefenses[unitHero:GetUniqueID()] or 0
end

function object:GetTotalDefense(tUnits)
	local nDefense = 0
	if tUnits then
		for _, unit in pairs(tUnits) do
			nDefense = nDefense + self:GetDefense(unit)
		end
	end
	return nDefense
end

---- Group-and-push logic ----
--Note: all times in match time
object.nPushIntervalMin = core.MinToMS(3)
object.nPushIntervalMax = core.MinToMS(6)

-- Time until the first push
object.nNextPushTime = core.MinToMS(7) + core.RandomReal(0, object.nPushIntervalMax - object.nPushIntervalMin) 

object.nPushStartTime = 0
object.unitPushTarget = nil
object.unitRallyBuilding = nil

object.tArrivalEstimatePairs = {}
object.nGroupUpRadius = 800
object.nGroupUpRadiusSq = object.nGroupUpRadius * object.nGroupUpRadius
object.nGroupEstimateMul = 1.5
object.nMaxGroupWaitTime = core.SToMS(25)
object.nGroupWaitTime = nil

function object:GroupAndPushLogic()
	local bDebugEchos = false
	local bDebugLines = false
	
	local nCurrentMatchTime = HoN.GetMatchTime()
	local nCurrentGameTime = HoN.GetGameTime()
	
	if bDebugEchos then BotEcho('GroupAndPushLogic: ') end
	
	if self.nPushState == STATE_IDLE then
		if bDebugEchos then BotEcho(format('IDLE - nCurrentMatchTime: %d  nNextPushTime: %d', nCurrentMatchTime, self.nNextPushTime)) end
		
		if nCurrentMatchTime > self.nNextPushTime then
			--determine target lane
			local nLane = random(3)
			local tLaneUnits = nil
			local tLaneNodes = nil
			
			--put everyone in the target's lane
			self.tTopLane = {}
			self.tBottomLane = {}
			self.tMiddleLane = {}
			self.tJungle = {}
			if nLane == 1 then
				self.tTopLane = core.CopyTable(self.tAllyHeroes)
				tLaneUnits = self.tTopLane
				tLaneNodes = metadata.GetTopLane()
			elseif nLane == 2 then
				self.tMiddleLane = core.CopyTable(self.tAllyHeroes)
				tLaneUnits = self.tMiddleLane
				tLaneNodes = metadata.GetMiddleLane()
			else
				self.tBottomLane = core.CopyTable(self.tAllyHeroes)
				tLaneUnits = self.tBottomLane
				tLaneNodes = metadata.GetBottomLane()
			end
			
			local unitTarget = core.GetClosestLaneTower(tLaneNodes, core.bTraverseForward, core.enemyTeam)
			if unitTarget == nil then
				unitTarget = core.enemyMainBaseStructure
			end
			self.unitPushTarget = unitTarget
			
			--calculate estimated time to arrive
			local unitRallyBuilding = core.GetFurthestLaneTower(tLaneNodes, core.bTraverseForward, core.myTeam)
			if unitRallyBuilding == nil then
				unitRallyBuilding = core.allyMainBaseStructure
			end
			self.unitRallyBuilding = unitRallyBuilding
			
			--invalidate our wait timeout
			self.nGroupWaitTime = nil
			
			local vecTargetPos = unitRallyBuilding:GetPosition()
			for key, hero in pairs(tLaneUnits) do
				if hero:IsBotControlled() then
					local nWalkTime = core.TimeToPosition(vecTargetPos, hero:GetPosition(), hero:GetMoveSpeed())
					local nRespawnTime = (not hero:IsAlive() and hero:GetRemainingRespawnTime()) or 0
					local nTotalTime = nWalkTime * self.nGroupEstimateMul + nRespawnTime
					tinsert(self.tArrivalEstimatePairs, {hero, nTotalTime})
				end
			end
			
			if bDebugEchos then 
				BotEcho(format('IDLE - switching!  randLane: %d  target: %s at %s', nLane, unitTarget:GetTypeName(), tostring(unitTarget:GetPosition())))
				BotEcho("ArrivalEstimatePairs:")
				core.printTableTable(self.tArrivalEstimatePairs)
			end
			
			self.nPushStartTime = nCurrentMatchTime
			self.nPushState = STATE_GROUPING
			if bDebugEchos then BotEcho("PUSHING - Grouping up!") end
		end
	elseif self.nPushState == STATE_GROUPING then
		if not self.unitRallyBuilding or not self.unitRallyBuilding:IsValid() then
			self.nNextPushTime = nCurrentMatchTime
			self.nPushState = STATE_IDLE
		elseif self.nGroupWaitTime ~= nil and nCurrentGameTime >= self.nGroupWaitTime then
			if bDebugEchos then BotEcho("GROUPING - We've waited long enough... Time to push!") end
			self.nPushState = STATE_PUSHING
		else
			if bDebugEchos then BotEcho('GROUPING - checking if everyone is at the '..self.unitRallyBuilding:GetTypeName()) end
			local bAllHere = true
			local bAnyHere = false
			local vecRallyPosition = self.unitRallyBuilding:GetPosition()
			for key, tPair in pairs(self.tArrivalEstimatePairs) do
				local unit = tPair[1]
				local nTime = tPair[2]
				if not unit or not nTime then 
					BotEcho('GroupAndPushLogic - ERROR - malformed arrival esimate pair!')
				end
				
				if Vector3.Distance2DSq(unit:GetPosition(), vecRallyPosition) > self.nGroupUpRadiusSq then
					if bDebugEchos then BotEcho(format('%s should arrive in less than %ds', unit:GetTypeName(), (self.nPushStartTime + nTime - nCurrentTime)/1000)) end
				
					if nCurrentMatchTime > self.nPushStartTime + nTime then
						self.tArrivalEstimatePairs[key] = nil
						if bDebugEchos then 
							BotEcho(format('GROUPING - dropping %s due to taking too long %d > %d + (%d * %g)', 
								unit:GetTypeName(), nCurrentMatchTime, self.nPushStartTime, nTime, self.nGroupEstimateMul
							))
						end
					else
						bAllHere = false
					end
				else
					bAnyHere = true
					if bDebugEchos then BotEcho(unit:GetTypeName().." has arrived!") end
				end
			end
			
			if bAllHere then
				if bDebugEchos then BotEcho("GROUPING - everyone is here! Time to push!") end
				self.nPushState = STATE_PUSHING
			elseif bAnyHere and self.nGroupWaitTime == nil then
				self.nGroupWaitTime = nCurrentGameTime + self.nMaxGroupWaitTime
			end
		end
	elseif self.nPushState == STATE_PUSHING then
		local bEnd = not self.unitPushTarget:IsAlive()
		if bDebugEchos then BotEcho(format("PUSHING - target: %s  alive: %s", self.unitPushTarget:GetTypeName(), tostring(self.unitPushTarget:IsAlive()))) end
		
		if bEnd == false then
			--if we don't want to end already, see if we have wiped
			local nAllyHeroes = core.NumberElements(self.tAllyHeroes)
			local nHeroesAlive = 0
			for _, hero in pairs(self.tAllyHeroes) do
				if hero:IsAlive() then
					nHeroesAlive = nHeroesAlive + 1
				end
			end
			
			bEnd = nHeroesAlive <= nAllyHeroes / 2
			if bDebugEchos then BotEcho("PUSHING - have wiped: "..tostring(nHeroesAlive <= nAllyHeroes / 2)) end
		end
		
		if bEnd == true then
			if bDebugEchos then BotEcho("PUSHING - done pushing") end
			self:BuildLanes()
			self.nPushState = STATE_IDLE
			self.nNextPushTime = nCurrentMatchTime + core.RandomReal(self.nPushIntervalMin, self.nPushIntervalMax)
		end
	end
	
	if bDebugLines then
		if self.unitRallyBuilding then
			core.DrawXPosition(self.unitRallyBuilding:GetPosition(), 'yellow')
		end
		if self.unitPushTarget then
			core.DrawXPosition(self.unitPushTarget:GetPosition(), 'red')
		end
	end
end

function object:GroupUtility()
	local nUtility = 0
	
	if self.nPushState == STATE_GROUPING then
		nUtility = 100
	end
	
	return nUtility
end

function object:PushUtility()
	local nUtility = 0
	
	if self.nPushState == STATE_PUSHING then
		nUtility = 100
	end
	
	return nUtility
end

function object:GetGroupRallyPoint()
	return self.unitRallyBuilding:GetPosition()
end


---- Lane building ----

--[[
Add custom code to lane building function which takes into account each bot's preference to be in a given lane.
This will allow teambotbrain to intelligently set up lanes and resolve competing preferences.
If only pubs cooperated like this in TMM games!

These are *optional* preferences which each individual bot can configure to reflect its code.

Note:
	"Jungle" is considered a lane.
	"Short" = bot lane solo for legion, top for hellbourne
	"Long" = top lane solo for legion, bot for hellbourne
	Trilanes and dual mid lanes are not currently supported, but could be implemented in the future?

Each bot can specify a preference for the following 8 lanes+role combinations:
	Jungle (allied jungle only, I assume?)
	Mid (solo?)
	Short solo
	Long solo
	Short support (dual lane)
	Short carry (dual lane)
	Long support (dual lane)
	Long carry (dual lane)

Preference for the above lanes/roles can be ranked by a bot using the following scoring system:
0 = impossible (only use if no code written to support it!)
1 = bad
2 = ok
3 = decent
4 = good
5 = awesome
5+= guess overflow'd awesome (mid can do this, for example. [1+[2+2+1] = 6])

Rough psuedo code ideas for calculating initial lane assignment:

Method 2 (bot preference based):
1) Scan team and import tables of bot preferences.  (If no table exists for a bot, fill it with default values).
2) Scan all possible combinations of lanes and find the highest sum of the preferences. On easy mode, these values should randomely get
	numbers added/subttracted to them, for odd laning combinations.
3) Decide tie-breakers via: 2-1-1 w/jungle then 2-1-2, then splitting ranged, then longest range mid, then random between remaining combos.
4) Echo back to bots their lane assignments (purely to give bots a chance to select an item build appropriate for their lane)

--]]

object.nLaneProximityThreshold = 0.60 --how close you need to be (percentage-wise) to be "in" a lane

object.lanePreferences = {
--	{ Jungle = 0, Mid = 1, ShortSolo = 1, LongSolo = 1, ShortSupport = 5, LongSupport = 5, ShortCarry = 1, LongCarry = 1 , hero = nil },
--	{ Jungle = 0, Mid = 5, ShortSolo = 2, LongSolo = 1, ShortSupport = 1, LongSupport = 1, ShortCarry = 3, LongCarry = 3 , hero = nil },
--	{ Jungle = 5, Mid = 2, ShortSolo = 2, LongSolo = 1, ShortSupport = 1, LongSupport = 1, ShortCarry = 2, LongCarry = 2 , hero = nil },
--	{ Jungle = 0, Mid = 2, ShortSolo = 4, LongSolo = 5, ShortSupport = 3, LongSupport = 4, ShortCarry = 2, LongCarry = 2 , hero = nil },
--	{ Jungle = 0, Mid = 5, ShortSolo = 4, LongSolo = 1, ShortSupport = 1, LongSupport = 1, ShortCarry = 4, LongCarry = 3 , hero = nil }
}

local nHighestCombo = -500
object.tCombinations = {}

-- This is to make sure that a terrible lane for a bot won't be forced onto it unless absolutely necessary.
local tValueMultipliers = {-3, -1, 1, 2, 3, 5, 5}


local function validLanes(tNewCurrentLanes)	
	local nLong=0
	local nMid=0
	local nShort=0
	local nJungle=0
	for key, value in pairs(tNewCurrentLanes) do
		local hero = object.lanePreferences[key].hero
		if string.find(value, "Short") then
			nShort=nShort+1
		elseif string.find(value, "Long") then
			nLong=nLong+1
		elseif string.find(value, "Mid") then
			nMid=nMid+1
		else
			nJungle=nJungle+1
		end
	end
	
	--too many players to a lane check
	local tLongLane = nil
	local tShortLane = nil
	if core.myTeam == HoN.GetLegionTeam() then
		tLongLane = object.tTopLane
		tShortLane = object.tBottomLane
	else
		tLongLane = object.tBottomLane
		tShortLane = object.tTopLane
	end
	if ((core.NumberElements(object.tJungle)+nJungle>1 and nJungle~=0) or (core.NumberElements(object.tMiddleLane)+nMid>1 and nMid~=0) or (core.NumberElements(tLongLane)+nLong>2 and nLong~=0) or (core.NumberElements(tShortLane)+nShort>2 and nShort~=0)) then -- too many players in lanes!
		--BotEcho("Too many players in lanes.")
		return false
	end
	
	if #tNewCurrentLanes>2 and (core.NumberElements(tLongLane)+nLong==0 or core.NumberElements(object.tMiddleLane)+nMid==0 or core.NumberElements(tShortLane)+nShort==0) then --lane empty for no reason.. silly junglers up to no good.
		--BotEcho("silly junglers")
		return false
	elseif (core.NumberElements(object.tMiddleLane)+nMid==0) then -- no-one in mid! NO! INVALID! STAMP IT WITH LOTS OF RED AND HURL IT AWAY!
		--BotEcho("NO MID")
		return false
	end
	if core.tableContains(tNewCurrentLanes, "ShortSupport") and not core.tableContains(tNewCurrentLanes, "ShortCarry") or
		core.tableContains(tNewCurrentLanes, "ShortCarry") and not core.tableContains(tNewCurrentLanes, "ShortSupport") or
		core.tableContains(tNewCurrentLanes, "LongSupport") and not core.tableContains(tNewCurrentLanes, "LongCarry") or
		core.tableContains(tNewCurrentLanes, "LongCarry") and not core.tableContains(tNewCurrentLanes, "LongSupport") then --Dependent roles failing.
		--BotEcho("bad dependencies")
		return false
	end
	
	return true
end

-- Recurrsive function to Loop through all possible bot combinations and add the sums
local function sumPreferences(tPossibleLanes, nIndex, nSum, tCurrentLanes)
	local nOrigSum = nSum
	for i = 1, #tPossibleLanes do 
		-- Iterate over the remaining lanes
		--             /   multiplier  /  look into bots table  /  get bot     /get lane
		nSum = nOrigSum + tValueMultipliers[object.lanePreferences[nIndex][tPossibleLanes[i]] + 1]-- +1 as lanePreferences starts at 0
		if nIndex == core.NumberElements(object.tBotsLeft) then 
			-- Last unit, no need to search deeper.
			local tNewCurrentLanes = core.CopyTable(tCurrentLanes)
			tinsert(tNewCurrentLanes, tPossibleLanes[i])
			if nSum > nHighestCombo and validLanes(tNewCurrentLanes) then
				nHighestCombo = nSum
				object.tCombinations = {}
				tinsert(object.tCombinations, tNewCurrentLanes)
			--elseif nSum == nHighestCombo and validLanes(tNewCurrentLanes) then -- we are only going to choose the first one.
				--tinsert(object.tCombinations, tNewCurrentLanes)
			end
		elseif nSum + ((core.NumberElements(object.tBotsLeft) - nIndex) * tValueMultipliers[#tValueMultipliers]) >= nHighestCombo then 
			-- Stop looking through this branch if there is no way we could compete with the current highest score
			local tNewCurrentLanes = core.CopyTable(tCurrentLanes)
			tinsert(tNewCurrentLanes, tPossibleLanes[i])
			local tNewPossibleLanes = core.CopyTable(tPossibleLanes)
			tremove(tNewPossibleLanes, i)
			-- The following are clashes between laneing types.
			if tPossibleLanes[i] == "ShortSolo" then
				core.RemoveByValue(tNewPossibleLanes, "ShortSupport")
				core.RemoveByValue(tNewPossibleLanes, "ShortCarry")
			elseif tPossibleLanes[i] == "ShortSupport" then
				core.RemoveByValue(tNewPossibleLanes, "ShortSolo")
			elseif tPossibleLanes[i] == "ShortCarry" then
				core.RemoveByValue(tNewPossibleLanes, "ShortSolo")
			elseif tPossibleLanes[i] == "LongSolo" then
				core.RemoveByValue(tNewPossibleLanes, "LongSupport")
				core.RemoveByValue(tNewPossibleLanes, "LongCarry")
			elseif tPossibleLanes[i] == "LongSupport" then
				core.RemoveByValue(tNewPossibleLanes, "LongSolo")
			elseif tPossibleLanes[i] == "LongCarry" then
				core.RemoveByValue(tNewPossibleLanes, "LongSolo")
			end
			
			-- Recurrsively run the function for the next bot
			sumPreferences(tNewPossibleLanes, nIndex + 1, nSum, tNewCurrentLanes)
		end
	end
end

object.tAlreadyLoadedPrefs = {}
function object:SetLanePreferences(tPrefs)
	if tPrefs then
		BotEcho("^yLoading Lane Preferences for: "..tPrefs.hero:GetTypeName())
		if not object.tAlreadyLoadedPrefs[tPrefs.hero:GetUniqueID()] then
			object.tAlreadyLoadedPrefs[tPrefs.hero:GetUniqueID()] = tPrefs
		end
	else
		BotEcho("TPREFS IS NIL!")
	end
end

function guessLanePreference(unitHero)
	local tPreferences = {Jungle = 0, Mid = 1, ShortSolo = 1, LongSolo = 1, ShortSupport = 1, LongSupport = 1, ShortCarry = 1, LongCarry = 1, hero = unitHero}

	local sPrimaryAttribute = unitHero:GetPrimaryAttribute()
	
	if (unitHero:GetAttackType() ~= "melee") then
		local nAttackRange = unitHero:GetAttackRange()
		if sPrimaryAttribute == "agi" then
			if nAttackRange > 500 then --long range, most likely a carry, ex: Flint, Emerald Warden, Valkyrie
				tPreferences.ShortCarry = tPreferences.ShortCarry + 2
				tPreferences.LongCarry = tPreferences.LongCarry + 2
				tPreferences.Mid = tPreferences.Mid + 2
				tPreferences.ShortSolo = tPreferences.ShortSolo + 1
				tPreferences.LongSolo = tPreferences.LongSolo + 1
			else --shorter range, engi, andro, MQ, CD
				tPreferences.ShortCarry = tPreferences.ShortCarry + 1
				tPreferences.LongCarry = tPreferences.LongCarry + 1
			end
		elseif sPrimaryAttribute == "int" then
			tPreferences.ShortSupport = tPreferences.ShortSupport + 1
			tPreferences.LongSupport = tPreferences.LongSupport + 1
			if nAttackRange >= 450 then --long range int, most likely a semi-carry, pyro, aluna, rhaps, myrm, 
				tPreferences.Mid = tPreferences.Mid + 1
				tPreferences.ShortSolo = tPreferences.ShortSolo + 1
				tPreferences.LongSolo = tPreferences.LongSolo + 1
			end
		else -- str, flux or midas atm
			tPreferences.ShortCarry = tPreferences.ShortCarry + 1
			tPreferences.LongCarry = tPreferences.LongCarry + 1
		end
	else --melee
		if sPrimaryAttribute == "agi" then
			tPreferences.ShortCarry = tPreferences.ShortCarry + 3
			tPreferences.LongCarry = tPreferences.LongCarry + 2
			tPreferences.ShortSolo = tPreferences.ShortSolo + 2
			tPreferences.LongSolo = tPreferences.LongSolo + 1
		elseif sPrimaryAttribute == "int" then
			tPreferences.ShortSupport = tPreferences.ShortSupport + 1
			tPreferences.LongSupport = tPreferences.LongSupport + 1
		else -- str
			tPreferences.ShortCarry = tPreferences.ShortCarry + 1
			tPreferences.LongCarry = tPreferences.LongCarry + 1
			tPreferences.ShortSupport = tPreferences.ShortSupport + 1
			tPreferences.LongSupport = tPreferences.LongSupport + 1
		end
	end
	
	local nAvgDamage = (unitHero:GetFinalAttackDamageMax() + unitHero:GetFinalAttackDamageMin()) / 2
	if nAvgDamage > 55 then
		tPreferences.Mid = tPreferences.Mid + 2
		tPreferences.ShortSolo = tPreferences.ShortSolo + 2
		tPreferences.ShortCarry = tPreferences.ShortCarry + 1
		tPreferences.LongCarry = tPreferences.LongCarry + 1
	else
		tPreferences.ShortSupport = tPreferences.ShortSupport + 1
		tPreferences.LongSupport = tPreferences.LongSupport + 1
	end
	
	local nHealth = unitHero:GetHealth()
	local nAvgEHP = ((nHealth / (1 - unitHero:GetPhysicalResistance())) + (nHealth / (1 - unitHero:GetMagicResistance()))) / 2
	if nAvgEHP > 850 then
		tPreferences.Mid = tPreferences.Mid + 1
		tPreferences.ShortSolo = tPreferences.ShortSolo + 1
		tPreferences.LongSolo = tPreferences.LongSolo + 1
	end
	
	return tPreferences
end

function object:BuildLanes()
	local bDebugEchos = false

	local tTopLane = {}
	local tMiddleLane = {}
	local tBottomLane = {}
	local tJungle = {}
	
	local tPossibleLanes = {"Jungle", "Mid", "ShortSolo", "LongSolo", "ShortSupport", "LongSupport", "ShortCarry", "LongCarry"}

	-- Check for players already in lane
	for nID, unitHero in pairs(self.tAllyHumanHeroes) do
		local vecPosition = unitHero:GetPosition()
		local nDistToWellSq = Vector3.Distance2DSq(vecPosition, core.allyWell:GetPosition())
		if nDistToWellSq > (1200 * 1200) then
			local tLaneBreakdown = core.GetLaneBreakdown(unitHero)
			if tLaneBreakdown["mid"] >= self.nLaneProximityThreshold then
				tMiddleLane[nID] = unitHero
			elseif tLaneBreakdown["top"] >= self.nLaneProximityThreshold  then
				tTopLane[nID] = unitHero
			elseif tLaneBreakdown["bot"] >= self.nLaneProximityThreshold then
				tBottomLane[nID] = unitHero
			elseif (tLaneBreakdown["bot"]+tLaneBreakdown["top"]+tLaneBreakdown["mid"]==0) then --too far (>1200) from any lane, not in base, must be jungle.
				tJungle[nID] = unitHero
			end
		end
	end
	
	--save current values so we can reference them later in validLanes
	self.tTopLane = tTopLane
	self.tMiddleLane = tMiddleLane
	self.tBottomLane = tBottomLane
	self.tJungle = tJungle
	
	object.tBotsLeft = core.CopyTable(self.tAllyBotHeroes)

	-- Tutorial
	if core.bIsTutorial and core.myTeam == HoN.GetLegionTeam() then
		if bDebugEchos then BotEcho("BuildLanes - Tutorial!") end
		local unitSpecialBot = nil
		local tPlayerLane = nil
		local sName = "Hero_Shaman"

		--find the player's lane
		local tLanes = {tTopLane, tMiddleLane, tBottomLane}
		for _, t in pairs(tLanes) do
			if not core.IsTableEmpty(t) then
				if bDebugEchos then BotEcho("Found the player!") end
				tPlayerLane = t
			end
		end			

		if tPlayerLane ~= nil then
			for nUID, unit in pairs(self.tAllyBotHeroes) do
				if sName and unit:GetTypeName() == sName then
					if bDebugEchos then BotEcho("FoundShaman!") end
					tPlayerLane[nUID] = unit
					unitSpecialBot = unit
				end
			end

			for nUID, unit in pairs(object.tBotsLeft) do
				if unit == unitSpecialBot then
					object.tBotsLeft[nUID] = nil
					break
				end
			end	
		end
	end	
	-- /Tutorial

	object.lanePreferences={}
	nHighestCombo=0
	-- Get preferences from bots.
	if core.NumberElements(object.lanePreferences) < core.NumberElements(object.tBotsLeft) then
		for _, unitHero in pairs(object.tBotsLeft) do
			if object.tAlreadyLoadedPrefs[unitHero:GetUniqueID()] then
				tinsert(object.lanePreferences, object.tAlreadyLoadedPrefs[unitHero:GetUniqueID()])
			else
				local tGuessedLanePreference = guessLanePreference(unitHero)
				tinsert(object.lanePreferences, tGuessedLanePreference)
			end
		end
	end
	
	local tLongLane = nil
	local tShortLane = nil
	if core.myTeam == HoN.GetLegionTeam() then
		tLongLane = tTopLane
		tShortLane = tBottomLane
	else
		tLongLane = tBottomLane
		tShortLane = tTopLane
	end
	
	--Omit certain lane roles due to where human players are. *This will be handled in validLanes later, but this is for better processing time.
	if (#tLongLane>0) then
		tremove(tPossibleLanes,"LongSolo")
		if (#tLongLane>1) then
			tremove(tPossibleLanes,"LongCarry")
			tremove(tPossibleLanes,"LongSupport")
		end
	end
	if (#tShortLane>0) then
		tremove(tPossibleLanes,"ShortSolo")
		if (#tShortLane>1) then
			tremove(tPossibleLanes,"ShortCarry")
			tremove(tPossibleLanes,"ShortSupport")
		end
	end
	if (#tMiddleLane>0) then
		tremove(tPossibleLanes,"Mid")
	end
	if (#tJungle>0) then
		tremove(tPossibleLanes,"Jungle")
	end
	
	object.tCombinations = {}
	-- Sort our best combinations into object.tCombinations
	sumPreferences(tPossibleLanes, 1, 0, {})
	--BotEcho("highest combination was with "..nHighestCombo.." and there was "..#object.tCombinations)
	
	
	--Assign bots to lane.
	for key, value in pairs(object.tCombinations[1]) do
		local hero = object.lanePreferences[key].hero
		--BotEcho(hero:GetTypeName().."("..hero:GetUniqueID()..")'s role is "..value)
		if string.find(value, "Short") then
			tShortLane[hero:GetUniqueID()] = hero
		elseif string.find(value, "Long") then
			tLongLane[hero:GetUniqueID()] = hero
		elseif string.find(value, "Mid") then
			tMiddleLane[hero:GetUniqueID()] = hero
		elseif string.find(value, "Jungle") then
			tJungle[hero:GetUniqueID()] = hero
		end
	end

	self.tTopLane = tTopLane
	self.tMiddleLane = tMiddleLane
	self.tBottomLane = tBottomLane
	self.tJungle = tJungle
end

function object:GetDesiredLane(unitAsking)
	if unitAsking then
		local nUniqueID = unitAsking:GetUniqueID()
		
		if self.tTopLane[nUniqueID] then
			return metadata.GetTopLane()
		elseif self.tMiddleLane[nUniqueID] then
			return metadata.GetMiddleLane()
		elseif self.tBottomLane[nUniqueID] then
			return metadata.GetBottomLane()
		elseif self.tJungle[nUniqueID] then
			--Jungle doesn't have a lane, but to stop other parts of the code failing, use a dummy lane.
			--With the lane name 'jungle', so we can use core.tMyLane.sLaneName=='jungle' to know whether we are jungle or not.	
			local jungleLane=core.CopyTable(metadata.GetMiddleLane())
			jungleLane.sLaneName='jungle'
			return jungleLane
		end
		
		BotEcho("Couldn't find a lane for unit: "..tostring(unitAsking)..'  name: '..unitAsking:GetTypeName()..'  id: '..nUniqueID)
		self.teamBotBrainInitialized = false	
	else
		BotEcho("Couldn't find a lane for unit: nil")
	end	
	
	return nil
end

function object:ChangeLane(unitHero, tLane)
	if unitHero and tLane then
		local nUniqueID = unitHero:GetUniqueID()
		if nUniqueID and (tLane == self.tTopLane or tLane == self.tMiddleLane or tLane == self.tBottomLane) then
			self.tTopLane[nUniqueID] =    nil
			self.tMiddleLane[nUniqueID] = nil
			self.tBottomLane[nUniqueID] = nil	
			tLane[nUniqueID] = unitHero
		end
	end
end

---- Defense Logic ----
object.nDefenseLogicTime = 0
object.nDefenseLogicInterval = 1000
object.nDefenseInRangeRadius = 1200
object.nDefenseCloseRadius = 3000
object.tDefenseInfos = {}		--Our collection of Defense targets that contains its defense team and the attackers
object.tHeroDefenseTargets = {}	--A quick reference for bot queries
function object:DefenseLogic()
	local bDebugEchos = false

	local nCurrentTime = HoN.GetGameTime()
	if nCurrentTime < self.nDefenseLogicTime then
		return
	end
	self.nDefenseLogicTime = nCurrentTime + self.nDefenseLogicInterval
	
	self.tHeroDefenseTargets = {}
	
	local tDefenseInfos = self.tDefenseInfos		
	local bDefendingBefore = not core.IsTableEmpty(tDefenseInfos)
	local nMask = core.UNIT_MASK_HERO + core.UNIT_MASK_UNIT + core.UNIT_MASK_ALIVE
	
	StartProfile('Detection')
	--Iterate through buildings and determine if they need defense
	local tBuildings = self:GetDefenseBuildings()	--this ignores ranged rax
	for nBuildingID, unitBuilding in pairs(tBuildings) do
		local tLocalUnits, tSortedUnits = 
			HoN.GetUnitsInRadius(unitBuilding:GetPosition(), self.nDefenseInRangeRadius, nMask, true)
		
		local nHealthPercent = unitBuilding:GetHealthPercent()
		local nEnemyHeroesPresent = core.NumberElements(tSortedUnits.EnemyHeroes)
		local bAllyCreepsPresent = not core.IsTableEmpty(tSortedUnits.AllyCreeps)
		local bEnemyCreepsPresent = not core.IsTableEmpty(tSortedUnits.EnemyCreeps)
		
		if bDebugEchos then BotEcho(format(
			"Checking if %d %s needs defense!  %%: %d  enemyHeroes: %s  enemyCreeps: %s  allyCreeps: %s", nBuildingID, unitBuilding:GetTypeName(), 
			nHealthPercent * 100, tostring(nEnemyHeroesPresent), tostring(bEnemyCreepsPresent), tostring(bAllyCreepsPresent))) 
		end
		
		local bImportantBuilding = nHealthPercent < 0.5 or unitBuilding:IsRax() or unitBuilding:IsBase()
		local bWeakBuildingIsUndefended = nHealthPercent < 0.25 and not bAllyCreepsPresent and bEnemyCreepsPresent
		
		if (nEnemyHeroesPresent > 0 and bImportantBuilding) or bWeakBuildingIsUndefended or nEnemyHeroesPresent >= 3 then
			--Defend this!
			local tEnemies = tSortedUnits.EnemyHeroes
			local tAllies = tSortedUnits.AllyHeroes
				
			--Remove our bots so that we can assign them to go defend the targets we decide
			for nID, unitHero in pairs(tAllies) do
				if unitHero:IsBotControlled() then --TODO: only remove bot heroes that will listen to us
					tAllies[nID] = nil
				end
			end			
							
			if bDebugEchos then BotEcho(format("%d %s requires a defense with nEnemyThreats: %d  nAlreadyDefending: %d", 					
				nBuildingID, unitBuilding:GetTypeName(), core.NumberElements(tSortedUnits.EnemyHeroes), core.NumberElements(tSortedUnits.AllyHeroes)))
			end
			
			--Add to our collection of targets
			tDefenseInfos[nBuildingID] = {unitBuilding, tAllies, tEnemies}
		else
			--Target has been defended/doesn't need defense
			if bDebugEchos and tDefenseInfos[nBuildingID] ~= nil then BotEcho(nBuildingID..unitBuilding:GetTypeName().." has been properly defended, removing from the list") end
							
			--TODO: delayed removal to ensure enemy didn't just duck out of range?
			
			tDefenseInfos[nBuildingID] = nil
			
			if bDebugEchos then BotEcho("["..nBuildingID.."] "..unitBuilding:GetTypeName().." has been properly defended, removing") end
		end
	end
	StopProfile()
	
	--Prioritize targets, and cull old but invalid targets (and count the valid ones)
	--  Priority is currently type only (5 for base, 4 for rax, 3, 2, 1 for towers (by tier))
	local tPriorityPairs = {}
	
	local nDefenseTargets = 0
	for nTargetID, tCurrentInfo in pairs(tDefenseInfos) do
		local unitTarget = tCurrentInfo[1]
		if unitTarget then
			if unitTarget:IsAlive() and unitTarget:IsValid() then
				nDefenseTargets = nDefenseTargets + 1
				
				local nValue = 0
				if unitTarget:IsBase() then
					nValue = 5
				elseif unitTarget:IsRax() then
					nValue = 4
				elseif unitTarget:IsTower() then
					nValue = unitTarget:GetLevel()
				end
				
				tinsert(tPriorityPairs, {nValue, nTargetID})
				
				if bDebugEchos then BotEcho("Adding ["..nTargetID.."] "..unitTarget:GetTypeName().." at priorityValue "..nValue) end
			else
				tDefenseInfos[nTargetID] = nil
				
				if bDebugEchos then BotEcho("Removing invalid ["..nTargetID.."] "..unitTarget:GetTypeName()) end
			end
		end
	end
	
	--Exit if we're all done defending and rebuild lanes
	if nDefenseTargets <= 0 then
		if bDefendingBefore then
			self.laneReassessTime = 0
		end
		return
	end
	
	--TODO: Reconcile conflicts with push in a meaningful way
	
	--Sort targets by priority
	tsort(tPriorityPairs, function(a,b) return (a[1] > b[1]) end)

	if bDebugEchos then 
		print("tDefenseInfos {\n") for i,v in pairs(tDefenseInfos) do print(' '..tostring(i)..', '.. tostring(v[1]:GetTypeName())..'\n') end print('}\n')
		print("tPriorityPairs  {\n") for i,v in ipairs(tPriorityPairs) do print(' '..tostring(i)..', '.. tostring(v[2])..'\n') end print('}\n')
	end
	
	--Build a defense team to defend our defense targets
	StartProfile("BuildTeams")
		self:BuildDefenseTeams(tDefenseInfos, tPriorityPairs)
	StopProfile()
	
	--Update the lane info and hero defense target info with this
	for nTargetID, tCurrentInfo in pairs(tDefenseInfos) do
		local unitTarget = tCurrentInfo[1]
		
		--determine the defense target's lane
		local tLane = nil
		local tLaneBreakdown = core.GetLaneBreakdown(unitTarget)		
		if tLaneBreakdown["mid"] >= self.nLaneProximityThreshold then
			tLane = self.tMiddleLane
		elseif tLaneBreakdown["top"] >= self.nLaneProximityThreshold  then
			tLane = self.tTopLane
		elseif tLaneBreakdown["bot"] >= self.nLaneProximityThreshold then
			tLane = self.tBottomLane
		end
		
		local tAlliesDefending = tCurrentInfo[2]
		for nHeroID, unitHero in pairs(tAlliesDefending) do
			--add heroes to a table to keep track of who is defending and what for faster queries
			self.tHeroDefenseTargets[nHeroID] = unitTarget
			self:ChangeLane(unitHero, tLane)
		end		
	end
	
	if bDebugEchos and core.NumberElements(tDefenseInfos) > 0 then BotEcho("Lanes After:") self:PrintLanes() end
end

function object:BuildDefenseTeams(tDefenseInfos, tPriorityPairs)
	local bDebugEchos = false
	local bRebuildEchos = false
	
	--[[Algorithm:
		0. Add all in range and close human players ( already in tDefenseInfos[###][2] )
		Add units until our Lethality > their Lethality
		Do each pass for each defense target:
			1. Add heroes that are in range (nDefenseInRangeRadius)
			2. Add heroes that are "close" (nDefenseCloseRadius)
			3. Add heroes that can TP in
			4. Add the closest remaining heroes
	--]]
	
	--Schema:
	-- tDefenseInfos[nUniqueID] = {unitTower, tAllyHeroes tEnemyHeroes}
	-- tPriorityPairs[i] = {nValue, nUniqueID} --sorted from highest to lowest
	
	--TODO:Defense method for coordination (port, walk, etc)
	
	local tHeroesLeft = core.CopyTable(self.tAllyBotHeroes)
	
	--remove dead heroes
	for nID, unit in pairs(tHeroesLeft) do
		if not unit:IsAlive() then
			tHeroesLeft[nID] = nil
		end
	end
	
	local nHeroesLeft = core.NumberElements(tHeroesLeft)
	
	if bDebugEchos then
		BotEcho("Assigning "..nHeroesLeft.." heroes to defense targets")
		BotEcho("Lanes Pre:")
		self:PrintLanes()
	end
	
	if nHeroesLeft <= 0 then
		return
	end
	
	local tRemainingPriorityPairs = core.CopyTable(tPriorityPairs)
	
	--cached data for performance
	local funcGetThreat = self.GetThreat
	local funcGetTotalThreat = self.GetTotalThreat
	local funcGetDefense = self.GetDefense
	local funcGetTotalDefense = self.GetTotalDefense
	
	local nInRangeSq = object.nDefenseInRangeRadius * object.nDefenseInRangeRadius
	local nCloseSq = object.nDefenseCloseRadius * object.nDefenseCloseRadius
	
	local tDefenseData = {}
	
	--1. Add heroes that are in range (nDefenseInRangeRadius)
	local i = 1
	while true do
		if i > #tRemainingPriorityPairs then
			break
		end
	
		local tPair = tRemainingPriorityPairs[i]
		
		local bDefended = false
		local tAllyDistancePairs = {}
		
		local nTargetID = tPair[2]
		local tCurrentStruct = tDefenseInfos[nTargetID]
		local vecBuildingPos = tCurrentStruct[1]:GetPosition()			
		local tAlliesDefending = tCurrentStruct[2]
		local tEnemiesAttacking = tCurrentStruct[3]
		
		if bDebugEchos then
			print("CurrentStruct: ") core.printTable(tCurrentStruct)
			print("AlliesDefending ") core.printGetTypeNameTable(tAlliesDefending)
			print("EnemiesAttacking ") core.printGetTypeNameTable(tEnemiesAttacking)
		end		
		
		local nAlliesDefending = core.NumberElements(tAlliesDefending)
		
		--Calculate Lethalities
		local nAllyThreat	= funcGetTotalThreat (self, tAlliesDefending)
		local nAllyDefense	= funcGetTotalDefense(self, tAlliesDefending)
		local nEnemyThreat	= funcGetTotalThreat (self, tEnemiesAttacking)
		local nEnemyDefense	= funcGetTotalDefense(self, tEnemiesAttacking)
		
		local nAllyLethatlity = nAllyThreat - nEnemyDefense
		local nEnemyLethality = nEnemyThreat - nAllyDefense
	
		if bDebugEchos then BotEcho(format("[%d]%s - allyThreat: %d  allyDefense: %d  enemyThreat: %d  enemyDefense: %d",
			nTargetID, tCurrentStruct[1]:GetTypeName(), nAllyThreat, nAllyDefense, nEnemyThreat, nEnemyDefense)) end
				
		if nAllyLethatlity < nEnemyLethality or nAlliesDefending <= 0 then
			
			--determine our distances from this target and sort
			for nID, unit in pairs(tHeroesLeft) do
				local nDistanceSq = Vector3.Distance2DSq(vecBuildingPos, unit:GetPosition())
				tinsert(tAllyDistancePairs, {nDistanceSq, unit})
			end
			tsort(tAllyDistancePairs, function(a,b) return (a[1] < b[1]) end)					
			
			--Find heroes who are already here
			for i, tPair in ipairs(tAllyDistancePairs) do
				--add in-range heroes only for this pass
				if tPair[1] > nInRangeSq then
					--move on to the next pass
					break
				end
				
				local unit = tPair[2]				
				local nUniqueID = unit:GetUniqueID()
				tAlliesDefending[nUniqueID] = unit
				tHeroesLeft[nUniqueID] = nil
				tremove(tAllyDistancePairs, i)
				
				if bDebugEchos then BotEcho(unit:GetTypeName().." added to defend at "..tPair[1].." unitsSq away, which is in range") end
								
				--Check Lethality
				nAllyThreat	= nAllyThreat + funcGetThreat(self, unit)
				nAllyDefense = nAllyDefense + funcGetDefense(self, unit)

				local nAllyLethatlity = nAllyThreat - nEnemyDefense
				local nEnemyLethality = nEnemyThreat - nAllyDefense
	
				if nAllyLethatlity >= nEnemyLethality then
					--the team is strong enough to defend
					if bDebugEchos then BotEcho("We can win the fight! "..nAllyLethatlity.." >= "..nEnemyLethality) end
					bDefended = true
					break
				end
			end
		else
			--the team is strong enough to defend
			bDefended = true
		end
		
		if bDefended then
			tremove(tRemainingPriorityPairs, i)
		else 
			--store off our local vars so we don't have to recalculate them on the next pass
			tDefenseData[nTargetID] = {tAllyDistancePairs, nAllyThreat, nAllyDefense, nEnemyThreat, nEnemyDefense}
			i = i + 1
		end
	end --first pass
	
	--2. Add heroes that are "close" (nDefenseCloseRadius)
	i = 1
	while true do
		if i > #tRemainingPriorityPairs then
			break
		end	
	
		local tPair = tRemainingPriorityPairs[i]
		
		local bDefended = false
			
		local nTargetID = tPair[2]
		local tCurrentStruct = tDefenseInfos[nTargetID]
		local tAlliesDefending = tCurrentStruct[2]
		
		--Get stored vars
		local tTargetData = tDefenseData[nTargetID]
		local tAllyDistancePairs = tTargetData[1] 
		local nAllyThreat	= tTargetData[2]
		local nAllyDefense	= tTargetData[3]
		local nEnemyThreat	= tTargetData[4]
		local nEnemyDefense	= tTargetData[5]
	
		--Find "close" heroes
		for i, tPair in ipairs(tAllyDistancePairs) do
			--add in-range heroes only for this pass
			if tPair[1] > nCloseSq then
				--move on to the next pass
				break
			end
			
			local unit = tPair[2]				
			local nUniqueID = unit:GetUniqueID()
			tAlliesDefending[nUniqueID] = unit
			tHeroesLeft[nUniqueID] = nil
			tremove(tAllyDistancePairs, i)
			
			if bDebugEchos then BotEcho(unit:GetTypeName().." added to defend at "..tPair[1].." unitsSq away, which is close") end
							
			--Check Lethality
			nAllyThreat = nAllyThreat + funcGetThreat(self, unit)
			nAllyDefense = nAllyDefense + funcGetDefense(self, unit)

			local nAllyLethatlity = nAllyThreat - nEnemyDefense
			local nEnemyLethality = nEnemyThreat - nAllyDefense

			if nAllyLethatlity >= nEnemyLethality then
				--the team is strong enough to defend
				if bDebugEchos then BotEcho("We can win the fight! "..nAllyLethatlity.." >= "..nEnemyLethality) end
				bDefended = true
				break
			end
		end
		
		if bDefended then
			tremove(tRemainingPriorityPairs, i)
		else 
			--store off our local vars so we don't have to recalculate them on the next pass
			tDefenseData[nTargetID] = {tAllyDistancePairs, nAllyThreat, nAllyDefense, nEnemyThreat, nEnemyDefense}
			i = i + 1
		end
	end --second pass
	
	--3. Add heroes that can TP in
	i = 1
	while true do
		if i > #tRemainingPriorityPairs then
			break
		end
		
		local tPair = tRemainingPriorityPairs[i]
		
		local bDefended = false
			
		local nTargetID = tPair[2]
		local tCurrentStruct = tDefenseInfos[nTargetID]
		local tAlliesDefending = tCurrentStruct[2]
		
		--Get stored vars
		local tTargetData = tDefenseData[nTargetID]
		local tAllyDistancePairs = tTargetData[1] 
		local nAllyThreat	= tTargetData[2]
		local nAllyDefense	= tTargetData[3]
		local nEnemyThreat	= tTargetData[4]
		local nEnemyDefense	= tTargetData[5]
	
		local sTeleportName = core.idefHomecomingStone:GetName()
		
		--Find heroes who can TP
		for i, tPair in ipairs(tAllyDistancePairs) do
			local unit = tPair[2]				
			
			local tInventory = unit:GetInventory()
			local tTPStones = core.InventoryContains(tInventory, sTeleportName)
					
			if tTPStones[1] then
				local nUniqueID = unit:GetUniqueID()
				tAlliesDefending[nUniqueID] = unit
				tHeroesLeft[nUniqueID] = nil
				tremove(tAllyDistancePairs, i)
				
				if bDebugEchos then BotEcho(unit:GetTypeName().." added to defend by teleporting in") end
								
				--Check Lethality
				nAllyThreat = nAllyThreat + funcGetThreat(self, unit)
				nAllyDefense = nAllyDefense + funcGetDefense(self, unit)

				local nAllyLethatlity = nAllyThreat - nEnemyDefense
				local nEnemyLethality = nEnemyThreat - nAllyDefense

				if nAllyLethatlity >= nEnemyLethality then
					--the team is strong enough to defend
					if bDebugEchos then BotEcho("We can win the fight! "..nAllyLethatlity.." >= "..nEnemyLethality) end
					bDefended = true
					break
				end
			end
		end
		
		if bDefended then
			tremove(tRemainingPriorityPairs, i)
		else 
			--store off our local vars so we don't have to recalculate them on the next pass
			tDefenseData[nTargetID] = {tAllyDistancePairs, nAllyThreat, nAllyDefense, nEnemyThreat, nEnemyDefense}
			i = i + 1
		end
	end --third pass
	
	--4. Add the closest remaining heroes
	i = 1
	while true do
		if i > #tRemainingPriorityPairs then
			break
		end
	
		local tPair = tRemainingPriorityPairs[i]
		
		local bDefended = false
			
		local nTargetID = tPair[2]
		local tCurrentStruct = tDefenseInfos[nTargetID]
		local tAlliesDefending = tCurrentStruct[2]
		
		--Get stored vars
		local tTargetData = tDefenseData[nTargetID]
		local tAllyDistancePairs = tTargetData[1] 
		local nAllyThreat	= tTargetData[2]
		local nAllyDefense	= tTargetData[3]
		local nEnemyThreat	= tTargetData[4]
		local nEnemyDefense	= tTargetData[5]
	
		--Find any hero left
		for i, tPair in ipairs(tAllyDistancePairs) do			
			local unit = tPair[2]			
			local nUniqueID = unit:GetUniqueID()
			
			tAlliesDefending[nUniqueID] = unit
			tHeroesLeft[nUniqueID] = nil
			tremove(tAllyDistancePairs, i)
			
			if bDebugEchos then BotEcho(unit:GetTypeName().." added to defend at "..tPair[1].." unitsSq away") end
							
			--Check Lethality
			nAllyThreat = nAllyThreat + funcGetThreat(self, unit)
			nAllyDefense = nAllyDefense + funcGetDefense(self, unit)

			local nAllyLethatlity = nAllyThreat - nEnemyDefense
			local nEnemyLethality = nEnemyThreat - nAllyDefense

			if nAllyLethatlity >= nEnemyLethality then
				--the team is strong enough to defend
				if bDebugEchos then BotEcho("We can win the fight! "..nAllyLethatlity.." >= "..nEnemyLethality) end
				bDefended = true
				break
			end
		end
		
		if bDefended then
			tremove(tRemainingPriorityPairs, i)
		else 
			i = i + 1
		end
	end --fourth pass
	
	--If there are any targets left in tRemainingPriorityPairs, they aren't able to be properly defended.
	--	We must then remove them from our defense targeting and reallocate any of their alocated bots elsewehere
	--	(unless we're trying to defend only one thing, which would mean that even though we can't properly defend,
	--	we need everyone at that one target, so don't remove it)
	
	--Remove the failed defense from tPriorityPairs and recurse if it frees up bots
	local nFailedDefenses = #tRemainingPriorityPairs
	if core.NumberElements(tDefenseInfos) > 1 and nFailedDefenses > 0 then
		local bRecursed = false
		
		if bDebugEchos then print("tRemainingPriorityPairs  {\n") for i,v in pairs(tRemainingPriorityPairs) do print(' '..tostring(i)..', '.. tostring(v[2])..'\n') end print('}\n') end
		
		StartProfile("FailedDefenses")
		for i=nFailedDefenses, 1, -1 do
			if bRebuildEchos then BotEcho("Failed Defenses ("..nFailedDefenses.."), i = "..i) end
			local tLowestPriorityPair = tRemainingPriorityPairs[i]
			
			local nTargetID = tLowestPriorityPair[2]
			local sBuilding = (tDefenseInfos[nTargetID] and tDefenseInfos[nTargetID][1] and tDefenseInfos[nTargetID][1]:GetTypeName()) or "nil"
				
			if bRebuildEchos then BotEcho("Removing failed defense target ["..nTargetID.."] "..sBuilding) end
			
			--Remove by value
			local bSuccess = false
			for i, tPair in ipairs(tPriorityPairs) do
				if tPair[2] == nTargetID then
					tremove(tPriorityPairs, i)
					bSuccess = true
					break
				end
			end
			
			local bFreedUsableResources = false
		
			--Rebuild teams only if we freed up bot defenders and we can apply them to another failed defense
			if bSuccess then
				if nFailedDefenses > 1 then
					local tLowestPriorityDefenseStruct = tDefenseInfos[nTargetID]
					local tAlliesDefending = tLowestPriorityDefenseStruct[2]
					for nID, unit in pairs(tAlliesDefending) do
						if unit:IsBotControlled() then
							if bRebuildEchos then BotEcho("  This freed up some bots, that can be used for our "..(nFailedDefenses - 1).." other failed defenses") end
							bFreedUsableResources = true
							break
						end
					end
				end
			else
				--Error
				BotEcho("Tried to remove ["..nTargetID.."] "..sBuilding.." from the priority list, but it wasn't there??")
			end
			
			if bSuccess and bFreedUsableResources then
				bRecurse = true
				break
			end
		end
		StopProfile()
		
		StartProfile("Recursion")
		if bRecurse then
			if bRebuildEchos then BotEcho("recursing BuildDefenseTeams") end
			self:BuildDefenseTeams(tDefenseInfos, tPriorityPairs)
		end
		StopProfile()
	end
end

object.bDamageableDefenseOnly = true
function object:GetDefenseBuildings()
	local tBuildings = {}
	local bDamageableOnly = self.bDamageableDefenseOnly
	
	--Towers
	local tTowers = core.allyTowers
	for nID, unitTower in pairs(tTowers) do
		if unitTower:IsAlive() and (not bDamageableOnly or not unitTower:IsInvulnerable()) then
			tBuildings[nID] = unitTower
		end
	end
	
	--Main base structure
	local unitMainBase = core.allyMainBaseStructure
	if (not bDamageableOnly or not unitMainBase:IsInvulnerable()) then
		tBuildings[unitMainBase:GetUniqueID()] = unitMainBase
	end

	--Rax (ignore ranged)
	local tRax = core.allyRax
	for nID, unitRax in pairs(tRax) do
		if unitRax:IsAlive() and (not bDamageableOnly or not unitRax:IsInvulnerable()) and unitRax:IsUnitType("MeleeRax") then
			tBuildings[nID] = unitRax
		end
	end

	return tBuildings
end

function object:GetDefenseTarget(unitAsking)
	if unitAsking then
		local nUniqueID = unitAsking:GetUniqueID()
		if nUniqueID then
			return self.tHeroDefenseTargets[nUniqueID]
		end
	end
	return nil
end


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

BotEcho('Finished loading teambotbrain')

