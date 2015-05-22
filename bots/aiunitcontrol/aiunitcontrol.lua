--AI Unit Control bot v1.0

local _G = getfenv(0)
local object = _G.object

local print, ipairs, pairs, string, table, next, type, tinsert, tremove, tsort, format, tostring, tonumber, strfind, strsub
	= _G.print, _G.ipairs, _G.pairs, _G.string, _G.table, _G.next, _G.type, _G.table.insert, _G.table.remove, _G.table.sort, _G.string.format, _G.tostring, _G.tonumber, _G.string.find, _G.string.sub
local ceil, floor, pi, tan, atan, atan2, abs, cos, sin, acos, max, random
	= _G.math.ceil, _G.math.floor, _G.math.pi, _G.math.tan, _G.math.atan, _G.math.atan2, _G.math.abs, _G.math.cos, _G.math.sin, _G.math.acos, _G.math.max, _G.math.random

--runfile "bots/core.lua"

local bInitialized = false

local nNextBehaviorTime = nil

local nMyPlayerID = nil


-- Both checked every frame
local tUnitsToCommand = {}
local unitHero = nil


--[[
	Creep type name => boolean function(botBrain, unit, unitTarget)
	returns true if the creep used its abilities to attack, false if the creep should attack normaly
]]--
local tCustomAttackBehaviors = {}


local function printDebug(string)
	print("Multiunit debug: " .. string .. "\n")

end
local function RotateVec2DRad(vector, radians)
	local x = vector.x * cos(radians) - vector.y * sin(radians)
	local y = vector.x * sin(radians) + vector.y * cos(radians)
	
	return Vector3.Create(x, y)
end
local function AngleBetween(vec1, vec2)
	local radians = acos(Vector3.Dot(Vector3.Normalize(vec1), Vector3.Normalize(vec2)))
	return radians
end
local function NumberElements(theTable)
	if not theTable then
		return 0
	end

	local count = 0
	for key, value in pairs(theTable) do
		count = count + 1
	end
	return count
end
local function printGetTypeNameTable (printThatTable) 
	print('{\n')
	if printThatTable then    
		for i,v in pairs(printThatTable) do
			print(' '..tostring(i)..', '..v:GetTypeName()..'\n')
		end
	end
	print('}\n')
end
local function printVargs(...)
	local args = {...}
	local str = ""
	for _, arg in pairs(args) do
		str = str..tostring(arg).." "
	end
	return str
end

local nOrderFrequency = 250
local tNextOrderTime = {}
local function SendOrderUnitClamp(botBrain, func, unit, ...)
	if unit == nil or unit:GetUniqueID() == nil then
		return
	end

	--Stagger orders so we don't spam the server
	local nGameTime = HoN.GetGameTime()
	local nNextOrderTime = tNextOrderTime[unit:GetUniqueID()] or 0
	
	if nGameTime >= nNextOrderTime then
		tNextOrderTime[unit:GetUniqueID()] = nGameTime + nOrderFrequency
		if func ~= nil then 
			return func(botBrain, unit, ...)
		end
	end
end 
local function SendOrderToolClamp(botBrain, func, tool, ...)
	--Stagger orders so we don't spam the server
	local nGameTime = HoN.GetGameTime()
	local unit = (tool ~= nil and tool:GetOwnerUnit()) or nil
	local nNextOrderTime = (unit ~= nil and tNextOrderTime[unit:GetUniqueID()]) or 0	
	
	--printDebug(tostring(botBrain).." "..tostring(func).." "..(unit and unit:GetTypeName() or "nil").." "..printVargs(...))
	--printDebug("    "..nGameTime.."  "..nNextOrderTime)	
	
	if nGameTime >= nNextOrderTime then
		tNextOrderTime[unit:GetUniqueID()] = nGameTime + nOrderFrequency
		if func ~= nil then
			return func(botBrain, tool, ...)
		end
	end
end 

local nLeashRange = 650			-- "Too far"
local nHeelRange = 200			-- "By my side"
local nSeparationRange = 100	-- "Too close"
local function positionUnit(botBrain, unit, index, heroBehavior, vecHeroPosition, vecHeroHeading)
	if unit == nil then
		return
	end
		
	local vecUnitPosition = unit:GetPosition()
	if vecUnitPosition == nil then
		return
	end
	
	if heroBehavior == nil then
		return
	end
	
	local behavior = unit:GetBehavior()
	if behavior == nil then	
		return
	end
	
	local sHeroBehavior = heroBehavior:GetType()
	local sMyBehavior = behavior:GetType()
	local nDistanceSQ = Vector3.Distance2DSq(vecUnitPosition, vecHeroPosition)
	
	if sHeroBehavior == "GiveItem" and heroBehavior:GetTarget():GetUniqueID() == unit:GetUniqueID() then
		SendOrderUnitClamp(botBrain, botBrain.OrderEntity, unit, "Touch", unitHero)
		return
	end
	
	-- Check Leash
	if nDistanceSQ > (nLeashRange * nLeashRange) or nDistanceSQ < (nSeparationRange * nSeparationRange) then
		local vecDesiredPosition = Vector3.Normalize(vecUnitPosition - vecHeroPosition) * nHeelRange + vecHeroPosition
		SendOrderUnitClamp(botBrain, botBrain.OrderPosition, unit, "Move", vecDesiredPosition, nil)
		return
	end	
	
	if sMyBehavior == "Attack" then
		if sHeroBehavior == "Hold" or sHeroBehavior == "Stop" then
			SendOrderUnitClamp(botBrain, botBrain.Order, unit, "Hold", nil)
			return
		else
			-- continue attacking until you leash
			return
		end
	end
	
	if sHeroBehavior == "Hold" or sHeroBehavior == "Stop" then
		SendOrderUnitClamp(botBrain, botBrain.Order, unit, "Hold", nil) 
	elseif sHeroBehavior == "Move" or sHeroBehavior == "AttackMove" then
		local vecTargetPosition = heroBehavior:GetGoalPosition()
		if Vector3.Distance2DSq(vecTargetPosition, vecUnitPosition) > nLeashRange then
			local vecDesiredPosition = nil
			if #tUnitsToCommand > 1 then
				-- printDebug(tostring(index-1) .. "/" .. tostring(#tUnitsToCommand - 1))
				vecDesiredPosition = RotateVec2DRad(vecHeroHeading, pi/4 + (index - 1)/(#tUnitsToCommand - 1) * (3/2)*pi) * nHeelRange + vecHeroPosition
			else
				vecDesiredPosition = RotateVec2DRad(vecHeroHeading, pi/4) * nHeelRange + vecHeroPosition
				-- TODO: select closest between left and right side?
			end
			
			SendOrderUnitClamp(botBrain, botBrain.OrderPosition, unit, "Move", vecDesiredPosition, nil)
			return
		end
	end	
	
	if sMyBehavior == "Aggro" or sMyBehavior == "Guard" then
		SendOrderUnitClamp(botBrain, botBrain.Order, unit, "Hold", nil)
	end	
end 

local function positionUnits(botBrain)
	local vecHeroPosition = unitHero:GetPosition()

	if vecHeroPosition == nil then
		return
	end

	local heroBehavior = unitHero:GetBehavior()
	local vecHeroHeading = unitHero:GetHeading()

	for index, unit in pairs(tUnitsToCommand) do
		if unit ~= nil and unit:IsValid() then
			positionUnit(botBrain, unit, index, heroBehavior, vecHeroPosition, vecHeroHeading)
		end
	end
end

local nShiverLeashSq = 1000 * 1000
local nShiverArriveSq = 100 * 100
local vecShiverDesiredPos = nil
local function orderShiver(botBrain, unit)
	local bDebugEchos = false

	if bDebugEchos then printDebug("ordering shiver") end
	
	local abilInvis = unit:GetAbility(0)
	if abilInvis ~= nil and abilInvis:CanActivate() then
		SendOrderToolClamp(botBrain, botBrain.OrderAbility, abilInvis)
	end

	local vecHeroPosition = unitHero:GetPosition()
	local vecShiverPosition = unit:GetPosition()
	
	local bLeashed = Vector3.Distance2DSq(vecHeroPosition, unit:GetPosition()) > nShiverLeashSq 
	local bArrived = vecShiverDesiredPos ~= nil and Vector3.Distance2DSq(vecShiverPosition, vecShiverDesiredPos) < nShiverArriveSq or false
	if bLeashed or bArrived then
		vecShiverDesiredPos = nil
		if bDebugEchos then printDebug("shiver reordered: "..(bLeashed and "Leashed" or "Arrived")) end
	end
	
	if vecShiverDesiredPos == nil then
		local nAngle = random(0, 360) / 180 * pi
		vecShiverDesiredPos = RotateVec2DRad(Vector3.Create(1, 0, 0), nAngle) * 1000 + vecHeroPosition
	end
	
	SendOrderUnitClamp(botBrain, botBrain.OrderPosition, unit, "Move", vecShiverDesiredPos, nil)
end

local sBehavior = ""
local myBehavior = nil	
local unitShiver = nil

function object:onthink(tGameVariables)
	local bDebugEchos = false

	if bInitialized == false or unitHero == nil then
		bInitialized = true
		unitHero = self:GetHeroUnit()

		nMyPlayerID = unitHero:GetOwnerPlayerID()
	end
	
	if unitHero == nil or not unitHero:IsValid() then
		return
	end

	if tGameVariables.bAIUnitControlActive ~= true then
		if bDebugEchos then printDebug("unit control OFF") end
		return
	end
	
	
	local nGameTime = HoN.GetGameTime()

	unitShiver = nil
	
	if nNextBehaviorTime == nil or nGameTime > nNextBehaviorTime then
		nNextBehaviorTime = nGameTime + 200
		
		tUnitsToCommand = {}
		
		--TODO: better way to do this?
		local tControllableUnits = self:GetControllableUnits();
		if NumberElements(tControllableUnits) <= 0 then
			if bDebugEchos then printDebug("no units") end
			return
		end
		
		tControllableUnits = tControllableUnits.AllUnits
		if NumberElements(tControllableUnits) <= 0 then
			if bDebugEchos then printDebug("no units in all units") end
			return
		end
		local nUnits = 0
		
		--Count Units and bookmark Shiver
		for _, unit in pairs(tControllableUnits) do
			if nMyPlayerID == unit:GetOwnerPlayerID() and unit:IsValid() and not unit:IsHero() then
				local sType = unit:GetTypeName()
				
				if bDebugEchos then printDebug("Condisering "..sType) end
				
				-- filter certain units from the list: couriers, gemini, parasite, moira and shiver
				if strfind(sType, "Pet_Tundra_Ability2_Flying") ~= nil then
					if bDebugEchos then printDebug("Found Shiver!") end
					unitShiver = unit
					nUnits = nUnits + 1
				elseif sType ~= "Pet_GroundFamiliar" and sType ~= "Pet_FlyngCourier" and sType ~= "Heropet_Gemini_Ability4_Fire" and sType ~= "Heropet_Gemini_Ability4_Ice" and sType ~= "Pet_Turretman_Ability2" then
					if not unit:HasState("State_Parasite_Ability2_Target") and not unit:HasState("State_Moira_Ability3_Self") then
						tinsert(tUnitsToCommand, unit)
						nUnits = nUnits + 1
					--else
						--unit:TeamShare()
					end
				end
			end
		end
	end

	--Control Units
	if unitShiver ~= nil then
		orderShiver(self, unitShiver)
	end
	
	myBehavior = unitHero:GetBehavior()
	
	if myBehavior ~= nil and myBehavior:IsValid() then		
		sBehavior = myBehavior:GetType() -- Aggro Guard Move Attack Ability AttackMove Touch GiveItem
	
		if sBehavior == "Attack" then
			unitTarget = myBehavior:GetAttackTarget()
			for id, unit in pairs(tUnitsToCommand) do
				if unit ~= nil and unit:IsValid() then
					local sTypeName = unit:GetTypeName()
					if tCustomAttackBehaviors[sTypeName] and tCustomAttackBehaviors[sTypeName](self, unit, unitTarget) then
						--continue
					else
						SendOrderUnitClamp(self, self.OrderEntity, unit, "Attack", unitTarget, nil)
					end
				end
			end
		elseif sBehavior == "Aggro" or sBehavior == "AttackMove" or sBehavior == "Ability" then
			unitTarget = myBehavior:GetAttackTarget() or myBehavior:GetTarget()
			if unitTarget ~= nil then
				for id, unit in pairs(tUnitsToCommand) do
					if unit ~= nil and unit:IsValid() then
						SendOrderUnitClamp(self, self.OrderEntity, unit, "Attack", unitTarget, nil)
					end
				end
			else
				positionUnits(self)
			end
		elseif sBehavior == "Move" or sBehavior == "Touch" or sBehavior == "Hold" or sBehavior == "FollowGuard" then
			positionUnits(self)
		else
			if bDebugEchos then printDebug("Unknown behavior: " .. sBehavior) end
			positionUnits(self)
		end
	end
end

---------------------------------

tCustomAttackBehaviors.Neutral_Minotaur = function(botBrain, unit, unitTarget)
	if unitTarget:IsHero() then
		local abilStun = unit:GetAbility(0)
		if abilStun:CanActivate() then
			if Vector3.Distance2DSq(unit:GetPosition(), unitTarget:GetPosition()) < (200 * 200) then --real radius is 250
				SendOrderToolClamp(botBrain, botBrain.OrderAbility, abilStun)
				return true
			end
		end
	end
	return false
end

tCustomAttackBehaviors.Neutral_Catman_leader = function(botBrain, unit, unitTarget)
	if unitTarget:IsHero() then
		local abilSlow = unit:GetAbility(0)
		if abilSlow:CanActivate() then
			if Vector3.Distance2DSq(unit:GetPosition(), unitTarget:GetPosition()) < (200 * 200) then --real radius is 200
				SendOrderToolClamp(botBrain, botBrain.OrderAbility, abilSlow)
				return true
			end
		end
	end
	return false
end

tCustomAttackBehaviors.Neutral_SkeletonBoss = function(botBrain, unit, unitTarget)
	if unitTarget:IsHero() then
		local abilSnare = unit:GetAbility(0)
		if abilSnare:CanActivate() then
			if Vector3.Distance2DSq(unit:GetPosition(), unitTarget:GetPosition()) < (550 * 550) then
				SendOrderToolClamp(botBrain, botBrain.OrderAbilityEntity, abilSnare, unitTarget)
				return true 
			end
		end
	end
	return false
end

tCustomAttackBehaviors.Neutral_Crazy_Alchemist = function(botBrain, unit, unitTarget)
	if not unitTarget:IsHero() then
		local abilTransmute = unit:GetAbility(0)
		if abilTransmute:CanActivate() then
			if Vector3.Distance2DSq(unit:GetPosition(), unitTarget:GetPosition()) < (600 * 600) then
				SendOrderToolClamp(botBrain, botBrain.OrderAbilityEntity, abilTransmute, unitTarget)
				return true
			end
		end
	end
	return false
end

tCustomAttackBehaviors.Neutral_VagabondLeader = function(botBrain, unit, unitTarget)
	if unitTarget:IsHero() then
		local abilNuke = unit:GetAbility(0)
		if abilNuke:CanActivate() then
			if Vector3.Distance2DSq(unit:GetPosition(), unitTarget:GetPosition()) < (500 * 500) then --real range 700
				SendOrderToolClamp(botBrain, botBrain.OrderAbilityPosition, abilNuke, unitTarget:GetPosition())
				return true
			end
		end
	end
	return false
end

tCustomAttackBehaviors.Neutral_VagabondAssassin = function(botBrain, unit, unitTarget)
	if unitTarget:IsHero() then
		local abilSlow = unit:GetAbility(0)
		if abilSlow:CanActivate() then
			if Vector3.Distance2DSq(unit:GetPosition(), unitTarget:GetPosition()) < (200 * 200) then
				SendOrderToolClamp(botBrain, botBrain.OrderAbilityEntity, abilSlow, unitTarget)
				return true
			end
		end
	end
	return false
end

tCustomAttackBehaviors.Neutral_Vagabond = function(botBrain, unit, unitTarget)
	if unitTarget:IsHero() then
		local abilManaBurn = unit:GetAbility(0)
		if abilManaBurn:CanActivate() then
			if Vector3.Distance2DSq(unit:GetPosition(), unitTarget:GetPosition()) < (600 * 600) then
				SendOrderToolClamp(botBrain, botBrain.OrderAbilityEntity, abilManaBurn, unitTarget)
				return true
			end
		end
	end
	return false
end

tCustomAttackBehaviors.Pet_NecroRanged = function(botBrain, unit, unitTarget)
	if unitTarget:IsHero() then
		local abilManaBurn = unit:GetAbility(0)
		if abilManaBurn:CanActivate() then -- 250 range
			SendOrderToolClamp(botBrain, botBrain.OrderAbilityEntity, abilManaBurn, unitTarget)
			return true
		end
	end
	return false
end

tCustomAttackBehaviors.Pet_Tremble_Ability4 = function(botBrain, unit, unitTarget)
	if unitTarget:IsHero() then
		local abilEnsnare = unit:GetAbility(0)
		if abilEnsnare:CanActivate() then
			if Vector3.Distance2DSq(unit:GetPosition(), unitTarget:GetPosition()) < (600 * 600) then
				if Vector3.Distance2DSq(unitHero:GetPosition(), unitTarget:GetPosition()) > (150 * 150) then
					SendOrderToolClamp(botBrain, botBrain.OrderAbilityEntity, abilEnsnare, unitTarget)				
					return true
				end
			end
		end
	end
	return false
end

