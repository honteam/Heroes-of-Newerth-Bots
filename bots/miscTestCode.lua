local _G = getfenv(0)
local object = _G.object

local core, eventsLib, behaviorLib, metadata, skills = object.core, object.eventsLib, object.behaviorLib, object.metadata, object.skills

local print, ipairs, pairs, string, table, next, type, tinsert, tremove, tsort, format, tostring, tonumber, strfind, strsub
	 = _G.print, _G.ipairs, _G.pairs, _G.string, _G.table, _G.next, _G.type, _G.table.insert, _G.table.remove, _G.table.sort, _G.string.format, _G.tostring, _G.tonumber, _G.string.find, _G.string.sub
local ceil, floor, pi, tan, atan, atan2, abs, cos, sin, acos, max, min, random
	 = _G.math.ceil, _G.math.floor, _G.math.pi, _G.math.tan, _G.math.atan, _G.math.atan2, _G.math.abs, _G.math.cos, _G.math.sin, _G.math.acos, _G.math.max, _G.math.min, _G.math.random

local BotEcho, VerboseLog, BotLog = core.BotEcho, core.VerboseLog, core.BotLog
local Clamp = core.Clamp


-- Sell all items
if false then
	behaviorLib.SellLowestItems(self, 12)
end

-- Should port test
if false then
	--local vecDesiredPos = behaviorLib.PositionSelfTraverseLane(self)
	local unitHero = core.teamBotBrain.allyHumanHeroes[1]
	if unitHero then
		local vecDesiredPos = unitHero:GetPosition()
		local bShouldPort, unitTower, itemTPStone = behaviorLib.ShouldPort(vecDesiredPos)
	end
end

-- Attack speed test
if false then
	local unitSelf = core.unitSelf
	local nAttackSpeed = unitSelf:GetAttackSpeed()
	local nAdjustedAttackCD = unitSelf:GetAdjustedAttackCooldown() / 1000
	BotEcho(format(
		"AS: %g  Adusted Attack CD: %g  AttacksPerSecond: %g", nAttackSpeed, nAdjustedAttackCD, 1/nAdjustedAttackCD
		)
	)
end

-- Ability property test
if false then	
	local abil = skills.flare
	if abil then
		core.BotEcho(format("range: %g  manaCost: %g  canActivate: %s  isReady: %s  cooldownTime: %g  remainingCooldownTime: %g", 
		abil:GetRange(), abil:GetManaCost(), tostring(abil:CanActivate()), tostring(abil:IsReady()), abil:GetCooldownTime(), abil:GetRemainingCooldownTime()
		))
	end
end

-- Port target position noise test
if false then
	local unitTarget = nil
	for i,unit in pairs(core.localUnits["AllyTowers"]) do unitTarget = unit break end
	
	if unitTarget then
		--Add noise to the position to prevent clustering on mass ports
		local nX = core.RandomReal(-1, 1)
		local nY = core.RandomReal(-1, 1)
		local vecDirection = Vector3.Normalize(Vector3.Create(nX, nY))
		local nDistance = random(100, 400)
		
		local vecTarget = unitTarget:GetPosition() + vecDirection * nDistance
		
		core.DrawXPosition(vecTarget, "red", 125)
		core.DrawXPosition(unitTarget:GetPosition(), "teal")
	end
end

-- Group Center test
if false then
	local tUnits = core.localUnits["EnemyUnits"]
	
	for nID, unit in pairs(tUnits) do
		core.DrawXPosition(unit:GetPosition(), 'yellow')
	end		

	local vecCenter, nCount = core.GetGroupCenter(tUnits)

	if vecCenter and nCount >= 3 then
		core.DrawXPosition(vecCenter, 'red')
	end	
end

if false then
	behaviorLib.SellLowestItems(self, 12)
end

-- tControllableUnits test
if false then
	--Buy a WhisperingHelm if we don't have it
	local itemWHelm = core.itemWHelm
	if not itemWHelm then
		core.unitSelf:PurchaseRemaining(HoN.GetItemDefinition("Item_WhisperingHelm"))
	end
	
	if core.tControllableUnits then
		for key, unit in pairs(core.tControllableUnits.AllUnits) do
			unit:TeamShare()
		end
	end		
end

-- Well attacker test
if false then
	--BotEcho(tostring(core.enemyWellAttacker))
	if core.enemyWellAttacker then
		core.DrawXPosition(core.enemyWellAttacker:GetPosition(), 'blue')
	end
	
	local vecMyPos = core.unitSelf:GetPosition()
	local vecEWellPos = core.enemyWellAttacker:GetPosition()
	local vToMe = Vector3.Normalize(vecMyPos - vecEWellPos)
	core.AdjustMovementForTowerLogic(vecEWellPos + vToMe * 250, true)
end

-- Path to player test
if false then
	if self.unitPlayer == nil then
		local t = HoN.GetHeroes(core.myTeam)
		for _, hero in pairs(t) do
			if not hero:IsBotControlled() then
				self.unitPlayer = hero
				break
			end
		end
	end
	
	local function funcGoToPlayer(botBrain)
		if self.unitPlayer then
			return self.unitPlayer:GetPosition()
		else
			BotEcho("No Player you idiot!")
		end
	end
	
	local funcOld = behaviorLib.PositionSelfTraverseLane
	behaviorLib.PositionSelfTraverseLane = funcGoToPlayer
	
	behaviorLib.PositionSelfExecute(self)
	
	behaviorLib.PositionSelfTraverseLane = funcOld
end

-- Neutral detection test
if false then
	local tLocalUnits = core.localUnits
	local tEnemyUnits = core.localUnits["EnemyUnits"]
	local tNeutrals = core.localUnits["Neutrals"]
	--BotEcho(#core.localUnits)
	
	BotEcho("tLocalUnits:")
	for key, value in pairs(tLocalUnits) do
		BotEcho(tostring(key))
	end
	
	for nID, unit in pairs(tEnemyUnits) do
		core.DrawXPosition(unit:GetPosition(), 'red')
	end
	
	if tNeutrals then
		for nID, unit in pairs(tNeutrals) do
			core.DrawXPosition(unit:GetPosition(), 'yellow')
		end
	else
		BotEcho("no tNeutrals")
	end
end

-- Rotating vector test (also displayed updates)
if false then
	if self.nDeg == nil then
		self.nDeg = 0
	end

	local unitSelf = core.unitSelf
	local myPos = unitSelf:GetPosition()
	
	local vec = Vector3.Create(1, 0)
	vec = core.RotateVec2D(vec, self.nDeg)
	core.DrawDebugArrow(myPos, myPos + vec * 150, 'yellow')
	self.nDeg = (self.nDeg + 20) % 360
end

-- Tower dive test
if false then
	behaviorLib.HarassHeroNewUtility(self)
	local unitTarget = behaviorLib.unitHarassTarget
		
	if true then
		local vecMyPos = core.unitSelf:GetPosition()
		
		--behaviorLib.HitBuildingUtility(self)
		
		local unitTower = core.GetClosestEnemyTower(vecMyPos)
		
		if unitTower then
			local vecToMe = Vector3.Normalize(vecMyPos - unitTower:GetPosition())
			
			if unitTarget then
				--core.AdjustMovementForTowerLogic(unitTarget:GetPosition())
			else
				core.AdjustMovementForTowerLogic(unitTower:GetPosition() + vecToMe * 150)
			end
			
			BotEcho("TowerSafe: "..tostring(core.IsTowerSafe(unitTower, core.unitSelf)))
			core.DrawXPosition(unitTower:GetPosition(), 'red')
		end
	end		
		
	if unitTarget ~= nil then
		local vecTargetPos = unitTarget:GetPosition()
		local nDistSq = Vector3.Distance2D(unitSelf:GetPosition(), vecTargetPos)
		local nAttackRangeSq = core.GetAbsoluteAttackRangeToUnit(unitSelf, unitTarget, true)
		nAttackRangeSq = nAttackRangeSq * nAttackRangeSq
		
		if nDistSq < nAttackRangeSq and unitSelf:IsAttackReady() and core.CanSeeUnit(self, unitTarget) then
			local bInTowerRange = core.NumberElements(core.GetTowersThreateningUnit(unitSelf)) > 0
			local bShouldDive = behaviorLib.lastHarassUtil >= behaviorLib.diveThreshold
			
			--BotEcho(format("inTowerRange: %s  bShouldDive: %s", tostring(bInTowerRange), tostring(bShouldDive)))
			
			if not bInTowerRange or bShouldDive then
				BotEcho("ATTAKIN NOOBS! divin: "..tostring(bShouldDive))
			end
		end
	end
	
	behaviorLib.HarassHeroExecute(self)
end

-- Aggro target test
if false then
	local tEnemyCreeps = core.localUnits["EnemyCreeps"]

	local unitTarget = nil
	local bAggrodCreeps = false
	for id, enemyCreep in pairs(tEnemyCreeps) do
		local unitAggroTarget = enemyCreep:GetAttackTarget()
		--BotEcho(format("%s targeting %s", enemyCreep:GetTypeName(), unitAggroTarget and unitAggroTarget:GetTypeName() or "nil"))
		if unitAggroTarget and unitAggroTarget:GetUniqueID() == core.unitSelf:GetUniqueID() then
			bAggrodCreeps = true
			break
		end
	end
	
	if unitTarget then
		local vecDesiredPos = (
			unitTarget:GetPosition() + Vector3.Normalize(
				core.unitSelf:GetPosition() - unitTarget:GetPosition()
			) * 200
		)
		
		core.DrawXPosition(vecDesiredPos, 'blue')
		
		--core.OrderMoveToPos(self, core.unitSelf, vecDesiredPos)
		--core.OrderMoveToPosAndHold(self, core.unitSelf, vecDesiredPos)
		--if not self.bHeld then
			core.OrderStop(self, core.unitSelf)
		--	self.bHeld = true
		--end
	end
end
	
-- IsTowerSafe test
if false then
	local vecMyPos = core.unitSelf:GetPosition()
	
	--behaviorLib.HitBuildingUtility(self)
	
	local unitTower = core.GetClosestEnemyTower(vecMyPos)
	
	if unitTower then
		--local vecToMe = Vector3.Normalize(vecMyPos - unitTower:GetPosition())
		--core.AdjustMovementForTowerLogic(unitTower:GetPosition() + vecToMe * 150)
		BotEcho(tostring(core.IsTowerSafe(unitTower, core.unitSelf)))
		core.DrawXPosition(unitTower:GetPosition(), 'red')
	end
	
	--behaviorLib.HarassHeroBehavior["Utility"](self)
	--behaviorLib.HarassHeroBehavior["Execute"](self)
end
	
-- Auto-toggle test
if false then 
	if false then
		behaviorLib.SellLowestItems(self, 12)
	end
	
	--Toggle Harkons and Inhuman Nature every 3s
	if object.nTestTime == nil then
		object.nTestTime = HoN.GetGameTime()
	end
	
	local itemHarkons = core.unitSelf:GetItem(1)
	if itemHarkons ~= nil and itemHarkons:GetTypeName() ~= "Item_HarkonsBlade" then
		itemHarkons = nil
	end
	
	if HoN.GetGameTime() > object.nTestTime then
		if skills.abilInhumanNature:GetLevel() > 0 then
			core.ToggleAutoCastAbility(self, skills.abilInhumanNature)
		end
		
		if itemHarkons then
			core.ToggleAutoCastItem(self, itemHarkons)
		end
		
		object.nTestTime = object.nTestTime + 3000
	end
	BotEcho("InhumanNature :"..(skills.abilInhumanNature:IsAutoCasting() and "auto-casting" or "off"))
	BotEcho("Harkons :"..(itemHarkons ~= nil and itemHarkons:IsAutoCasting() and "auto-casting" or "off"))
end

-- Status tests
if false then 
	behaviorLib.HarassHeroBehavior["Utility"](self)
	--behaviorLib.HarassHeroBehavior["Execute"](self)
	
	local unitTarget = behaviorLib.heroTarget
	if unitTarget then
		local bImmobilized	= unitTarget:IsImmobilized()
		local bStunned 		= unitTarget:IsStunned()
		local bPerplexed	= unitTarget:IsPerplexed()
		local bSilenced		= unitTarget:IsSilenced()
		local bDisarmed		= unitTarget:IsDisarmed()

		BotEcho(format("bImmobilized: %s  bStunned: %s  bPerplexed: %s  bSilenced: %s  bDisarmed: %s", 
			tostring(bImmobilized), tostring(bStunned), tostring(bPerplexed), tostring(bSilenced), tostring(bDisarmed)
		))
	end
end

-- Test scores (on teambotbrain)
if false then
	-- Returned table is indexable by name, as well as by teamID (available through HoN.GetLegionTeam(), etc)
	-- Note: In game, Players see score as total deaths of the other team, where as spectators see score as total kills.
	--   The score HoN.GetScores() returns is what players see (your team's score == total deaths of the other team)
	local tScores = HoN.GetScores()
	BotEcho(format("Legion: %i  Hellbourne: %i", tScores["Legion"], tScores["Hellbourne"])) 
	
	-- Test KDA
	-- Returned table is indexable by "nKills", "nDeaths", "nAssists" as well as 1,2,3)
	BotEcho("Allies: ")
	for id, unitHero in pairs(self.tAllyHeroes) do
		local tKDA = unitHero:GetKDA()
		BotEcho(format("%s: %i/%i/%i", unitHero:GetTypeName(), tKDA[1], tKDA[2], tKDA[3]))		
	end
	BotEcho("Enemies: ")
	for id, unitHero in pairs(self.tEnemyHeroes) do
		local tKDA = unitHero:GetKDA()
		BotEcho(format("%s: %i/%i/%i", unitHero:GetTypeName(), tKDA[1], tKDA[2], tKDA[3]))	
	end
end
	
-- Test GetAllNodes and GetIndex
if false then
	local t = BotMetaData.GetAllNodes()
	for nIndex, Node in pairs(t) do
		Echo(nIndex..": "..tostring(Node:GetPosition()))
		if nIndex ~= Node:GetIndex() then
			Echo("OH GOD NO!!!!!!!!!!!!!!!!!\n\n")
		end
	end
end

-- Test CreepKills, CreepDenies, and NeutralKills
if false then
	local unitSelf = core.unitSelf
	if unitSelf ~= nil then	
		BotEcho(format("CK: %d  CD: %d  NK: %d", 
			unitSelf:GetCreepKills(), unitSelf:GetCreepDenies(), unitSelf:GetNeutralKills()))
	end
end

-- Test GetHeading
if false then
	local unitSelf = core.unitSelf	
	if unitSelf ~= nil then	
		unitSelf:TeamShare()
		local myPos = unitSelf:GetPosition()	
		core.DrawDebugArrow(myPos, myPos + unitSelf:GetHeading() * 150, 'white')
	end
end


--[[
runfile "bots/miscTestCode.lua"
function object:onthinkOverride(tGameVariables)
	self:onthinkOld(tGameVariables)
	
	core.unitSelf:TeamShare()
	
	core.DrawXPosition(core.unitSelf:GetPosition(), "teal", 150)

	if self.testDisplayAllNodes == nil then
		Echo("derp")
	else
		self.testDisplayAllNodes()
	end
end
object.onthinkOld = object.onthink
object.onthink 	= object.onthinkOverride
--]]

-- Display all nodes
function object.testDisplayAllNodes()
	local tNodes = BotMetaData.GetAllNodes()
	
	if tNodes == nil then
		return
	end
	
	for nIndex, node in pairs(tNodes) do
		
		local nDistanceSq = Vector3.Distance2DSq(core.unitSelf:GetPosition(), node:GetPosition())
		if (nDistanceSq < 1300*1300) then		
			--function behaviorLib.PathLogic(botBrain, vecDesiredPosition)
			local bDebugLines = true
			local bMarkProperties = true

			--Lines
			if bDebugLines then
				local nLineLen = 125
				
				local tTowerUIDs = {}
				local vecNodePosition = node:GetPosition()
				
				if bMarkProperties then
					local sZoneProperty  = node:GetProperty("zone")
					local bTowerProperty = node:GetProperty("tower")
					local bBaseProperty  = node:GetProperty("base")
					local bUnzoned = false
					
					if sZoneProperty then
						local sColor = ""
						if sZoneProperty == "hellbourne" then
							sColor = "red"
						elseif sZoneProperty == "legion" then
							sColor = "green"
						elseif sZoneProperty == "river" then
							sColor = "blue"
						elseif sZoneProperty == "kongor" then
							sColor = "brown"
						else
							bUnzoned = true
						end
						
						core.DrawDebugLine(vecNodePosition, vecNodePosition + Vector3.Create(0, 1) * nLineLen, sColor)
					end
					
					if bBaseProperty then
						core.DrawDebugLine(vecNodePosition, vecNodePosition + Vector3.Create(1, 0) * nLineLen, "orange")
					end
					if bTowerProperty then
						--check if the tower is there
						local tBuildings = HoN.GetUnitsInRadius(node:GetPosition(), 1000, core.UNIT_MASK_ALIVE + core.UNIT_MASK_BUILDING)
						
						bTowerProperty = false
						for _, unitBuilding in pairs(tBuildings) do
							if unitBuilding:IsTower() and tTowerUIDs[unitBuilding:GetUniqueID()] == nil then
								core.DrawDebugLine(vecNodePosition, vecNodePosition + Vector3.Create(-1, 0) * nLineLen, "yellow")
								tTowerUIDs[unitBuilding:GetUniqueID()] = true
								bTowerProperty = true
							end
						end
					end
					
					--if bUnzoned and not bTowerProperty and not bBaseProperty then
						core.DrawXPosition(node:GetPosition(), "white", 150)
					--end
				else
					core.DrawXPosition(node:GetPosition(), "white", 150)
				end
			end
		end
	end
end
