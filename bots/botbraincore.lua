-- botbraincore v1.1

--[[ Change Log: 
(v1.1)	Added ToggleAutoCastItem() and ToggleAutoCastAbility()
--]]

local _G = getfenv(0)
local object = _G.object

object.core = object.core or {}
local core, eventsLib, behaviorLib, metadata = object.core, object.eventsLib, object.behaviorLib, object.metadata

local print, ipairs, pairs, string, table, next, type, tinsert, tremove, tsort, format, tostring, tonumber, strfind, strsub
	= _G.print, _G.ipairs, _G.pairs, _G.string, _G.table, _G.next, _G.type, _G.table.insert, _G.table.remove, _G.table.sort, _G.string.format, _G.tostring, _G.tonumber, _G.string.find, _G.string.sub
local ceil, floor, pi, tan, atan, atan2, abs, cos, sin, acos, max, random
	= _G.math.ceil, _G.math.floor, _G.math.pi, _G.math.tan, _G.math.atan, _G.math.atan2, _G.math.abs, _G.math.cos, _G.math.sin, _G.math.acos, _G.math.max, _G.math.random

local BotEcho, VerboseLog, BotLog = core.BotEcho, core.VerboseLog, core.BotLog
	
local nSqrtTwo = math.sqrt(2)
	
core.unitSelf = nil
core.teamBotBrain = nil

core.tNextOrderTimes = {}
core.timeBetweenOrders = 250

core.nHarassBonus = 0
core.lastHarassBonusUpdate = -1
core.harassBonusDecay = 2

core.itemGhostMarchers = nil
core.itemHatchet = nil

core.tMessageList = {}

object.nCurrentBehavior = nil
object.sCurrentBehaviorName = ""
object.sLastBehaviorName = ""

core.botBrainInitialized = false

core.bTutorialBehaviorReset = true
core.nbTutorialBehaviorResetTime = core.MinToMS(9)

core.nEasyAbilityRangeSq = 450*450

core.bEasyRandomAggression = false
core.nEasyAggroPercent = 0.066666
core.nEasyAggroTime = 0
core.nEasyAggroDuraiton = 2000
core.nEasyAggroReassessTime = 0
core.nEasyAggroReassessInterval = 60000
core.nEasyAggroHarassBonus = 35
core.nEasyAggroAbilityBonus = 30

--Called every frame the engine gives us during the pick phase
function object:onpickframe()
	if self:CanSelectHero(self.heroName) == true then
		BotEcho('Picking '..self.heroName)
		self:SelectHero(self.heroName)
		self:Ready()
	end
end

--Called every frame the engine gives us during the actual match
function object:onthink(tGameVariables)

	StartProfile('onthink')
	if core.coreInitialized == false or core.coreInitialized == nil then
		core.CoreInitialize(self)
	end

	if metadata.bInitialized == false then
		metadata.Initialize()
	end

	if core.botBrainInitialized == false or core.unitSelf == nil then
		core.BotBrainCoreInitialize(tGameVariables)
	end
	
	--BotEcho('======= ON THINK =======')
	
	if self.bRunLogic == false then
		StopProfile()
		return
	end
	
	local nGameTime = HoN.GetGameTime()
	
	--[Tutorial] After the reset time, switch legion to different behaviors. 
	--  This also stop doing some tutorial-specific crutches
	if core.bIsTutorial and core.bTutorialBehaviorReset == false and HoN.GetMatchTime() > core.nbTutorialBehaviorResetTime then
		if core.myTeam == HoN.GetLegionTeam() then
			core.nDifficulty = core.nMEDIUM_DIFFICULTY
			behaviorLib.harassUtilityWeight = 0.65
		end
		core.bTutorialBehaviorReset = true
	end
	
	--[Difficulty: Easy] Randomly be more aggressive and ready to use abilties for an interval
	if core.nDifficulty == core.nEASY_DIFFICULTY then
		--6.666% chance every 2s to have 2s of crazy aggression, with no 
		--  aggressive interval occuring more than once in a 30s period.
		--  The end result is once an aggressive interval occurs, we will
		--	not have another one for 30-60s
	
		if core.bEasyRandomAggression and nGameTime >= core.nEasyAggroTime + core.nEasyAggroDuraiton then
			--Done with this interval
			core.bEasyRandomAggression = false
		end
		
		if nGameTime >= core.nEasyAggroReassessTime then
			if random() < core.nEasyAggroPercent then
				-- on, try again in 20s
				core.bEasyRandomAggression = true
				core.nEasyAggroTime = nGameTime
				core.nEasyAggroReassessTime = nGameTime + core.nEasyAggroReassessInterval
			else
				-- off, try again in 2s
				core.bEasyRandomAggression = false
				core.nEasyAggroReassessTime = nGameTime + core.nEasyAggroDuraiton
			end
		end
		
		local bDebugEchos = false
		--if core.unitSelf:GetTypeName() == "Hero_Frosty" then bDebugEchos = true end
		if bDebugEchos then BotEcho("Time until next check: "..(core.nEasyAggroReassessTime-nGameTime)/1000) end
	end		
	
	StartProfile('Chat')
	core.ProcessChatMessages(self)
	StopProfile()

	if core.unitSelf:GetHealth() <= 0 then
		StopProfile()
		return
	end

	if object.bUpdates ~= false then
	StartProfile('Updates')
		StartProfile('Update unit collections')
			core.UpdateLocalUnits(self)
			core.UpdateControllableUnits(self)
			core.UpdateCreepTargets(self)
		StopProfile()
		
		StartProfile('Update Events')
			eventsLib.UpdateRecentEvents()
		StopProfile()
		
		core.UpdateLane()
		core.FindItems(self)
	StopProfile()
	end
	
	if core.tMyLane ~= nil then
		object.vecLaneForward, object.vecLaneForwardOrtho = core.AssessLaneDirection(core.unitSelf:GetPosition(), core.tMyLane, core.bTraverseForward)
	end

	StartProfile('Validate')
	core.ValidateUnitReferences()
	StopProfile()

	StartProfile('Skills')
	if self.SkillBuild then
		self:SkillBuild()
	end
	StopProfile()
	
	if self.bRunBehaviors ~= false then
		StartProfile('Assess behaviors')
		if nGameTime >= behaviorLib.nNextBehaviorTime then
			behaviorLib.nNextBehaviorTime = behaviorLib.nNextBehaviorTime + behaviorLib.nBehaviorAssessInterval
		
			self.tEvaluatedBehaviors = {}
			core.AssessBehaviors(self.tEvaluatedBehaviors)
		
			self.nCurrentBehavior = nil
			if #self.tEvaluatedBehaviors > 0 then
				self.nCurrentBehavior = 1
			end

			if self.bReportBehavior == true then
				if self.nCurrentBehavior >= 1 then
					local sName = core.GetCurrentBehaviorName(self)
					BotEcho("CurBehavior: "..sName) 
				else
					BotEcho("CurBehavior: no evaluated behaviors!")
				end
			end
		end
		
		StopProfile()
	
		StartProfile('Execute behaviors')
		if object.nCurrentBehavior ~= nil then
			-- Assume failure until we hit a successful behavior
			local nFirstBehavior = object.nCurrentBehavior
			object.nCurrentBehavior = nil
	
			self.sLastBehaviorName = self.sCurrentBehaviorName
			for i=nFirstBehavior,#object.tEvaluatedBehaviors do
				if object.tEvaluatedBehaviors[i].Behavior.Execute ~= nil then
					self.sCurrentBehaviorName = object.tEvaluatedBehaviors[i].Behavior.Name
					
					--[Difficulty: Easy] Bots can't use abils if they aren't within a certain range 
					--  and are above 50% HP. Also, for randomly for an interval, bots will be more 
					--  aggressive (see HarassHeroUtility) and more willing to use their abilities.
					local nOldHarassUtility = nil
					if core.nDifficulty == core.nEASY_DIFFICULTY and behaviorLib.heroTarget then
						if self.sCurrentBehaviorName == behaviorLib.HarassHeroBehavior["Name"] then
							local bUseAbils = false
							
							local heroTarget = behaviorLib.heroTarget
							if core.CanSeeUnit(self, heroTarget) and heroTarget:GetHealthPercent() > 0.5 then
								local nDistanceSq = Vector3.Distance2DSq(heroTarget:GetPosition(), core.unitSelf:GetPosition())
								if nDistanceSq < core.nEasyAbilityRangeSq then
									bUseAbils = true
								end
							end
							
							if not bUseAbils then
								self.bAbilityCommands = false
							elseif self.bAbilityCommandsDefault then --don't set to true if the default is false
								self.bAbilityCommands = true
								
								if core.bEasyRandomAggression then
									nOldHarassUtility = behaviorLib.lastHarassUtil
									behaviorLib.lastHarassUtil = behaviorLib.lastHarassUtil + core.nEasyAggroAbilityBonus
								end
							end
						end
					elseif self.bAbilityCommandsDefault then --don't set to true if the default is false
						self.bAbilityCommands = true 
					end
					--[/Difficulty: Easy]
					
					StartProfile(object.tEvaluatedBehaviors[i].Behavior.Name .. " - Execute")
					local bSuccessful = object.tEvaluatedBehaviors[i].Behavior.Execute(self)
					StopProfile()
					
					--[Difficulty: Easy] Reset aggro
					if nOldHarassUtility then
						behaviorLib.lastHarassUtil = nOldHarassUtility
					end
					
					if object.bDebugExecute then BotEcho("Executed "..self.sCurrentBehaviorName.."  success: "..tostring(bSuccessful)) end
										
					if bSuccessful ~= false then
						object.nCurrentBehavior = i
						
						if self.sCurrentBehaviorName ~= self.sLastBehaviorName then
							core.BehaviorsSwitched()
						end
						
						break
					end
					
					if object.bDebugExecute then
						local sNextName = "nil"
						if i + 1 <= #object.tEvaluatedBehaviors then
							sNextName = object.tEvaluatedBehaviors[i+1].Behavior.Name
						end
						BotEcho(self.sCurrentBehaviorName.." failed! Proceeding with "..sNextName)
					end
				end
			end
		else
			BotEcho("CurBehavior: no evaluated behaviors!")
		end
	
		if object.nCurrentBehavior == nil then
			BotEcho('No current behavior!!!')
		end
		StopProfile()
	end
	
	StopProfile()
end
object.bAbilityCommandsDefault = object.bAbilityCommands

function core.BotBrainCoreInitialize(tGameVariables)
	BotEcho('BotBrainCoreInitializing')
	
	core.unitSelf = object:GetHeroUnit()
	core.teamBotBrain = HoN.GetTeamBotBrain()
	
	if core.teamBotBrain == nil then
		BotEcho('teamBotBrain is nil!')		
	end
	
	core.unitSelf = core.teamBotBrain:CreateMemoryUnit(core.unitSelf)
			
	local tThreatMultipliers = behaviorLib.tThreatMultipliers
	local tHeroes = HoN.GetHeroes(core.enemyTeam)
	for _, unitHero in pairs(tHeroes) do
		tThreatMultipliers[unitHero:GetUniqueID()] = 1
	end
	
	--For debugging purposes
	--core.unitSelf:TeamShare()
	
	if core.tGameVariables == nil then
		if tGameVariables == nil then
			BotEcho("TGAMEVARIABLES IS NIL OH GOD OH GOD WHYYYYYYYY!??!?!!?")
		else
			core.tGameVariables = tGameVariables
			core.bIsTutorial = (core.tGameVariables.sMapName == 'tutorial')
			core.nDifficulty = core.tGameVariables.nDifficulty or core.nEASY_DIFFICULTY
		end
	end
	
	--[Difficulty]
	if core.nDifficulty == core.nEASY_DIFFICULTY then
		behaviorLib.harassUtilityWeight = 0.30
	elseif core.nDifficulty == core.nMEDIUM_DIFFICULTY then
		behaviorLib.harassUtilityWeight = 0.65
	elseif core.nDifficulty == core.nHARD_DIFFICULTY then
		--leave everything in
	end
	
	--[Tutorial] Make everyone less aggressive and easy mode. Later legion will switch to Medium.
	if core.bIsTutorial then
		core.nDifficulty = core.nEASY_DIFFICULTY
		behaviorLib.harassUtilityWeight = 0.3
		
		core.bTutorialBehaviorReset = false
	end
	
	core.botBrainInitialized = true
end

function core.BehaviorsSwitched()
	--Reset any stateful behavior stuff
	behaviorLib.bCheckPorting = true
end


function core.AssessBehaviors(tOutputBehaviors)
-- returns: the behavior whose logic the bot wants to run
	
	--[[
	Behavior structure:
		behavior["Utility"](botBrain), a function which returns a 0 - 100 number expressing how important it is
		behavior["Execute"](botBrain), a function which executes the logic and commands of the behavior
		behavior["Name"], which is a string of the behavior's name
	--]]
	
	if object.bDebugUtility == true then
		BotEcho("Assessing behaviors")
	end
	
	local nNumEvaluatedBehaviors = 0
	
	for i, curBehavior in ipairs(behaviorLib.tBehaviors) do
		if curBehavior["Utility"] ~= nil and curBehavior["Execute"] ~= nil then
			StartProfile(curBehavior["Name"] .. " - Utility")
			local nUtil = curBehavior["Utility"](object)
			nNumEvaluatedBehaviors = nNumEvaluatedBehaviors + 1
			tOutputBehaviors[nNumEvaluatedBehaviors] = {Utility = nUtil, Behavior = curBehavior}
			StopProfile()
		else
			BotEcho("ERROR: behavior's utility and/or execute fns are nil")
		end
	end
	
	local function BehaviorOrder(Behavior1, Behavior2)
		return Behavior1.Utility > Behavior2.Utility
	end
	
	table.sort(tOutputBehaviors, BehaviorOrder)
end

function core.ReassessBehaviors()
	behaviorLib.nNextBehaviorTime = 0
end

function core.GetCurrentBehaviorName(botBrain)
	return botBrain.sCurrentBehaviorName
end

function core.GetLastBehaviorName(botBrain)
	return botBrain.sLastBehaviorName
end

-- Each entry in core.tMessageList is {nTimeToSend, bAllChat, sMessage}
function core.ProcessChatMessages(botBrain)
	local nCurrentTime = HoN.GetGameTime()
	local tOutMessages = {}
	
	-- Current Schema:
	--{nDelayMS, bAllChat, sMessage, bLocalizeMessage, tStringTableTokens}
	
	for key, tMessageStruct in pairs(core.tMessageList) do
		if tMessageStruct[1] < nCurrentTime then
			tinsert(tOutMessages, tMessageStruct)
			core.tMessageList[key] = nil
		end
	end
	
	if #tOutMessages > 1 then	
		BotEcho("tOutMessages pre:")
		core.printTableTable(tOutMessages)
		tsort(tOutMessages, function(a,b) return (a[1] < b[1]) end)
		BotEcho("tOutMessages post:")
		core.printTableTable(tOutMessages)
	end
	
	for i, tMessageStruct in ipairs(tOutMessages) do
		local bAllChat = tMessageStruct[2]
		local sMessage = tMessageStruct[3]
		local bLocalizeMessage = tMessageStruct[4]
		local tStringTableTokens = tMessageStruct[5]
		
		if bLocalizeMessage == true then
			botBrain:SendBotMessage(bAllChat, sMessage, tStringTableTokens)
		else
			if bAllChat == true then
				botBrain:Chat(sMessage)
			else
				botBrain:ChatTeam(sMessage)
			end
		end
	end
end

function core.AllChat(sMessage, nDelayMS)
	--BotEcho("AllChat("..sMessage..")")

	nDelayMS = nDelayMS or 0
	if sMessage == nil or sMessage == "" then
		return
	end
	
	local nCurrentTime = HoN.GetGameTime()
	tinsert(core.tMessageList, {(nCurrentTime + nDelayMS), true, sMessage})
end

function core.TeamChat(sMessage, nDelayMS)
	nDelayMS = nDelayMS or 0
	if sMessage == nil or sMessage == "" then
		return
	end
	
	local nCurrentTime = HoN.GetGameTime()
	tinsert(core.tMessageList, {(nCurrentTime + nDelayMS), false, sMessage})
end

--All chats the localized message corresponding to sMessageKey in the appropriate bot_messages_??.str stringtable
function core.AllChatLocalizedMessage(sMessageKey, tTokens, nDelayMS)
	nDelayMS = nDelayMS or 0
	if sMessageKey == nil or sMessageKey == "" then
		return
	end
	
	tTokens = tTokens or {}
	
	local nCurrentTime = HoN.GetGameTime()
	tinsert(core.tMessageList, {(nCurrentTime + nDelayMS), true, sMessageKey, true, tTokens})
end

--Team chats the localized message corresponding to sMessageKey in the appropriate bot_messages_??.str stringtable
function core.TeamChatLocalizedMessage(sMessageKey, tTokens, nDelayMS)
	nDelayMS = nDelayMS or 0
	if sMessageKey == nil or sMessageKey == "" then
		return
	end
	
	tTokens = tTokens or {}
	
	local nCurrentTime = HoN.GetGameTime()
	tinsert(core.tMessageList, {(nCurrentTime + nDelayMS), false, sMessageKey, true, tTokens})
end


core.bDebugChats = false
core.nChatDelayMin = 2000
core.nChatDelayMax = 4500

core.nNextChatEventTime = 0
core.nChatEventInterval = 1000

core.nKillChatChance 	= 0.25
core.nDeathChatChance 	= 0.25
core.nRespawnChatChance	= 0.30

core.tKillChatKeys = { "kill1", "kill2", "kill3", "kill4", "kill5", "kill6" }
core.tKillBotKeys = { "kill_bot" }
core.tKillHumanKeys = { "kill_human1", "kill_human2" }

core.tDeathChatKeys = { "death1", "death2", "death3", "death4", "death5" }
core.tDeathBotKeys = { "death_bot" }
core.tDeathHumanKeys = { "death_human" }

core.tRespawnChatKeys = { "respawn1", "respawn2", "respawn3", "respawn4", "respawn5" }

function core.GetKillKeys(unitTarget)
	local tChatKeys = core.CopyTable(core.tKillChatKeys)
	
	if unitTarget:IsBotControlled() then
		core.InsertToTable(tChatKeys, core.tKillBotKeys)
	else
		core.InsertToTable(tChatKeys, core.tKillHumanKeys)
	end
	
	return tChatKeys
end

function core.ProcessKillChat(unitTarget, sTargetPlayerName)
	local nCurrentTime = HoN.GetGameTime()
	if nCurrentTime < core.nNextChatEventTime then
		return
	end
	
	local nChance = random()
	if core.bDebugChats then BotEcho("Kill: "..nChance.." < "..core.nKillChatChance.." is "..tostring(nChance < core.nKillChatChance)) end
	if nChance < core.nKillChatChance then
		local nDelay = random(core.nChatDelayMin, core.nChatDelayMax) 
		
		local tChatKeys = core.GetKillKeys(unitTarget)
		
		local nRand = random(1, #tChatKeys)
		
		local sTargetName = sTargetPlayerName or unitTarget:GetDisplayName()
		if sTargetName == nil or sTargetName == "" then
			sTargetName = unitTarget:GetTypeName()
		end
		core.AllChatLocalizedMessage(tChatKeys[nRand], {target=sTargetName}, nDelay)
	end
	
	core.nNextChatEventTime = nCurrentTime + core.nChatEventInterval
end

function core.GetDeathKeys(unitSource)
	local tChatKeys = core.CopyTable(core.tDeathChatKeys)
	
	if unitSource then
		if unitSource:IsBotControlled() then
			core.InsertToTable(tChatKeys, core.tDeathBotKeys)
		else
			core.InsertToTable(tChatKeys, core.tDeathHumanKeys)
		end
	end

	return tChatKeys
end

function core.ProcessDeathChat(unitSource, sSourcePlayerName)
	local nCurrentTime = HoN.GetGameTime()
	if nCurrentTime < core.nNextChatEventTime then
		return
	end
	
	local nChance = random()
	if core.bDebugChats then BotEcho("Death: "..nChance.." < "..core.nDeathChatChance.." is "..tostring(nChance < core.nDeathChatChance)) end
	if nChance < core.nDeathChatChance then
		local nDelay = random(core.nChatDelayMin, core.nChatDelayMax) 
		
		local tChatKeys = core.GetDeathKeys(unitSource)
		
		local nRand = random(1, #tChatKeys)
		
		local sSourceName = sSourcePlayerName or (unitSource and unitSource:GetDisplayName())
		if sSourceName == nil or sSourceName == "" then
			sSourceName = (unitSource and unitSource:GetTypeName()) or "The Hand of God"
		end
		
		core.AllChatLocalizedMessage(tChatKeys[nRand], {source=sSourceName}, nDelay)
	end
	
	core.nNextChatEventTime = nCurrentTime + core.nChatEventInterval
end

function core.GetRespawnKeys()
	local tChatKeys = core.CopyTable(core.tRespawnChatKeys)
	return tChatKeys
end

function core.ProcessRespawnChat()
	local nCurrentTime = HoN.GetGameTime()
	if nCurrentTime < core.nNextChatEventTime then
		return
	end

	local nChance = random()
	if core.bDebugChats then BotEcho("Respawn: "..nChance.." < "..core.nRespawnChatChance.." is "..tostring(nChance < core.nRespawnChatChance)) end
	if nChance < core.nRespawnChatChance and HoN.GetMatchTime() > 0 then
		local nDelay = random(core.nChatDelayMin, core.nChatDelayMax) 
		
		local tChatKeys = core.GetRespawnKeys()
		local nRand = random(1, #tChatKeys)
		
		core.AllChatLocalizedMessage(tChatKeys[nRand], nil, nDelay)
	end
	
	core.nNextChatEventTime = nCurrentTime + core.nChatEventInterval
end

function core.ProcessKilledChat(unitSource)
	--local nDelay = random(core.nChatDelayMin, core.nChatDelayMax) 
	--core.AllChat("I was killed by "..(unitSource and unitSource:GetTypeName() or "God"), nDelay + 1000)
end


------------------- General Functions --------------------
core.localUnits = nil
core.tControllableUnits = nil
core.localTrees = nil
core.nLocalTreesTime = 0

function core.UpdateLocalUnits(botBrain)
	local bDebugEchos = false
	
	--if object.myName == "GlaciusBot" then bDebugEchos = true end

	core.localUnits = core.AssessLocalUnits(botBrain)
	
	if bDebugEchos then
		BotEcho("LocalUnits:")
		print("Neutrals ")			core.printGetTypeNameTable(core.localUnits["Neutrals"])
		print("AllyTowers ")		core.printGetTypeNameTable(core.localUnits["AllyTowers"])
		print("AllyRax ")			core.printGetTypeNameTable(core.localUnits["AllyRax"])
		print("AllyBuildings ")		core.printGetTypeNameTable(core.localUnits["AllyBuildings"])
		print("AllyUnits ")			core.printGetTypeNameTable(core.localUnits["AllyUnits"])
		print("AllyHeroes ")		core.printGetTypeNameTable(core.localUnits["AllyHeroes"])
		print("AllyCreeps ")		core.printGetTypeNameTable(core.localUnits["AllyCreeps"])
		print("Allies ")			core.printGetTypeNameTable(core.localUnits["Allies"])
		print("EnemyTowers ")		core.printGetTypeNameTable(core.localUnits["EnemyTowers"])
		print("EnemyRax ")			core.printGetTypeNameTable(core.localUnits["EnemyRax"])
		print("EnemyBuildings ")	core.printGetTypeNameTable(core.localUnits["EnemyBuildings"])
		print("EnemyUnits ")		core.printGetTypeNameTable(core.localUnits["EnemyUnits"])
		print("EnemyHeroes ")		core.printGetTypeNameTable(core.localUnits["EnemyHeroes"])
		print("EnemyCreeps ")		core.printGetTypeNameTable(core.localUnits["EnemyCreeps"])
		print("Enemies ")			core.printGetTypeNameTable(core.localUnits["Enemies"])
	end
end

function core.UpdateControllableUnits(botBrain)
	local bDebugInfo = false
	
	core.tControllableUnits = botBrain:GetControllableUnits()
	
	if bDebugInfo then
		BotEcho("ControllableUnits:")
		Echo("AllControllableUnits\n{")	core.printGetTypeNameTable(core.tControllableUnits["AllUnits"]) Echo("}")
		Echo("InventoryUnits\n{")	core.printGetTypeNameTable(core.tControllableUnits["InventoryUnits"]) Echo("}")
	end
end

function core.UpdateLocalTrees()
	local nTime = HoN.GetGameTime()
	if nTime == core.nLocalTreesTime then
		return
	end
	
	core.nLocalTreesTime = nTime
	core.localTrees = HoN.GetTreesInRadius(core.unitSelf:GetPosition(), core.localTreeRange)
end

core.unitAllyCreepTarget = nil
core.unitEnemyCreepTarget = nil
core.unitCreepTarget = nil
function core.UpdateCreepTargets(botBrain)
	local bDebugLines = false

	local enemyCreeps = core.localUnits["EnemyCreeps"]
	local allyCreeps = 	core.localUnits["AllyCreeps"]

	local unitSelf = core.unitSelf;
	local myPos = unitSelf:GetPosition()

	local curHP = 0

	--consider lasthits
	local lowestEnemyHP = 9999
	local lowestEnemyCreep = nil
	for id, creep in pairs(enemyCreeps) do
		curHP = creep:GetHealth()
		--BotEcho('creepHealth '..curHP)
		if curHP < lowestEnemyHP then
			lowestEnemyHP = curHP
			lowestEnemyCreep = creep
		end
	end

	--consider denies
	local lowestAllyHP = 9999
	local lowestHPAlly = nil
	for id, creep in pairs(allyCreeps) do
		curHP = creep:GetHealth()
		if creep:HasDeniablePotential() and curHP < lowestAllyHP then
			lowestAllyHP = curHP
			lowestHPAlly = creep
		end
		
		if false and bDebugLines then
			local sColor = 'orange'
			if creep:HasDeniablePotential() == true then
				sColor = 'red'
			end
			core.DrawXPosition(creep:GetPosition(), sColor)
		end
	end
	
	local unitTarget = lowestEnemyCreep
	if lowestAllyHP < lowestEnemyHP then
		unitTarget = lowestHPAlly
	end
	
	core.unitEnemyCreepTarget = lowestEnemyCreep
	core.unitAllyCreepTarget = lowestHPAlly	
	core.unitCreepTarget = unitTarget
	
	if bDebugLines then
		if lowestEnemyCreep ~= nil then
			core.DrawXPosition(lowestEnemyCreep:GetPosition(), 'yellow', 125)
		end
		if lowestHPAlly ~= nil then
			core.DrawXPosition(lowestHPAlly:GetPosition(), 'lime', 125)
		end
		if core.unitCreepTarget ~= nil then
			local color = 'orange'
			if unitTarget:GetHealth() <= core.GetFinalAttackDamageAverage(unitSelf) then
				color = 'red'
			end
			core.DrawXPosition(unitTarget:GetPosition(), color)
		end
	end
end

core.tMyLane = nil
core.nLaneUpdateTime = 0
core.nLaneUpdateInterval = core.SToMS(30)
core.nTeamBotBrainPushState = -1
function core.UpdateLane()
	local curTime = HoN.GetGameTime()
	local teamBotBrain = core.teamBotBrain
	
	if HoN.GetRemainingPreMatchTime() <= core.teamBotBrain.nInitialBotMove then 
		if core.tMyLane == nil or curTime > core.nLaneUpdateTime or core.nTeamBotBrainPushState ~= teamBotBrain.nPushState then
			core.tMyLane = core.teamBotBrain:GetDesiredLane(core.unitSelf)
			
			core.nLaneUpdateTime = core.nLaneUpdateTime + core.nLaneUpdateInterval -- + randomTime
			core.nTeamBotBrainPushState = teamBotBrain.nPushState
			
			if core.tMyLane == nil then
				BotEcho('Lane update failed!')
			end
		end
	end
end

function core.FindItems(botBrain)
	--seach for the key Items of ours that we want to track
	
	if core.itemGhostMarchers ~= nil and not core.itemGhostMarchers:IsValid() then
		core.itemGhostMarchers = nil
	end
	if core.itemHatchet ~= nil and not core.itemHatchet:IsValid() then
		core.itemHatchet = nil
	end	
	if core.itemRoT ~= nil and not core.itemRoT:IsValid() then
		core.itemRoT = nil
	end
	
	local unitSelf = core.unitSelf
	
	local inventory = unitSelf:GetInventory(true)
	for slot = 1, 12, 1 do
		local curItem = inventory[slot]
		if curItem then
			if core.itemGhostMarchers == nil and curItem:GetName() == "Item_EnhancedMarchers" then
				core.itemGhostMarchers = core.WrapInTable(curItem)
				core.itemGhostMarchers.expireTime = 0
				core.itemGhostMarchers.duration = 6000
				core.itemGhostMarchers.msMult = 0.12
				--Echo("Saving ghostmarchers")
			end
			
			if core.itemHatchet == nil and curItem:GetName() == "Item_LoggersHatchet" then
				core.itemHatchet = core.WrapInTable(curItem)
				if unitSelf:GetAttackType() == "melee" then
					core.itemHatchet.creepDamageMul = 1.32
				else
					core.itemHatchet.creepDamageMul = 1.12
				end
				--Echo("Saving hatchet")
			end
			
			if core.itemRoT == nil and curItem:GetName() == "Item_ManaRegen3" then
				core.itemRoT = core.WrapInTable(curItem)
				core.itemRoT.bHeroesOnly = (curItem:GetActiveModifierKey() == "ringoftheteacher_heroes")
				core.itemRoT.nNextUpdateTime = 0
				core.itemRoT.Update = function() 
					local nCurrentTime = HoN.GetGameTime()
					if nCurrentTime > core.itemRoT.nNextUpdateTime then
						core.itemRoT.bHeroesOnly = (core.itemRoT:GetActiveModifierKey() == "ringoftheteacher_heroes")
						core.itemRoT.nNextUpdateTime = nCurrentTime + 800
					end
				end
			end
		end
	end
	
	return true
end

function core.DecayBonus(botBrain)
	--Decay the various bonuses utility functions recieve
	local curTimeMS = HoN.GetGameTime()
	if core.lastHarassBonusUpdate ~= -1 then
		core.nHarassBonus = core.nHarassBonus - core.harassBonusDecay * (curTimeMS - core.lastHarassBonusUpdate) / 1000
		if core.nHarassBonus < 0 then
			core.nHarassBonus = 0
		end
	end	
	core.lastHarassBonusUpdate = curTimeMS
end

---------------------  Wrappers ---------------------
function core.GetNextOrderTime(unit)
	local nUID = unit:GetUniqueID()
	return core.tNextOrderTimes[nUID] or 0
end

function core.SetNextOrderTime(unit, nTime)
	local nUID = unit:GetUniqueID()
	core.tNextOrderTimes[nUID] = nTime
end

function core.OrderAttack(botBrain, unit, unitTarget, bQueueCommand)
	if object.bRunCommands == false or object.bAttackCommands == false then
		return false
	end
	
	if bQueueCommand == nil then
		bQueueCommand = false
	end

	local queue = "None"
	if bQueueCommand then
		queue = "Back"
	end
	
	botBrain:OrderEntity(unit.object or unit, "Attack", unitTarget.object or unitTarget, queue)
	return true
end

function core.OrderAttackClamp(botBrain, unit, unitTarget, bQueueCommand)
	if object.bRunCommands == false or object.bAttackCommands == false then
		return false
	end
	
	if bQueueCommand == nil then
		bQueueCommand = false
	end
	
	local curTimeMS = HoN.GetGameTime()
	--stagger updates so we don't have permajitter
	if curTimeMS < core.GetNextOrderTime(unit) then
		return true
	end
	
	local queue = "None"
	if bQueueCommand then
		queue = "Back"
	end
	
	botBrain:OrderEntity(unit.object or unit, "Attack", unitTarget.object or unitTarget, queue)

	core.SetNextOrderTime(unit, curTimeMS + core.timeBetweenOrders)
	return true
end

function core.OrderMoveToUnitClamp(botBrain, unit, unitTarget, bInterruptAttacks, bQueueCommand)
	if object.bRunCommands == false or object.bMoveCommands == false then
		return false
	end

	--stagger updates so we don't have permajitter
	local curTimeMS = HoN.GetGameTime()
	if curTimeMS < core.GetNextOrderTime(unit) then
		return true
	end

	core.OrderMoveToUnit(botBrain, unit, unitTarget, bInterruptAttacks, bQueueCommand)

	core.SetNextOrderTime(unit, curTimeMS + core.timeBetweenOrders)
	return true
end

function core.OrderMoveToUnit(botBrain, unit, unitTarget, bInterruptAttacks, bQueueCommand)
	if object.bRunCommands == false or object.bMoveCommands == false then
		return false
	end
	
	if bQueueCommand == nil then
		bQueueCommand = false
	end
	
	if bInterruptAttacks == nil then
		bInterruptAttacks = true
	end
	
	if not bInterruptAttacks then
		local status = core.GetAttackSequenceProgress(unit)
		if status == "windup" then
			return true
		end
	end

	local queue = "None"
	if bQueueCommand then
		queue = "Back"
	end
	
	botBrain:OrderEntity(unit.object or unit, "Move", unitTarget.object or unitTarget, queue)
	return true
end

function core.OrderFollow(botBrain, unit, target, bInterruptAttacks, bQueueCommand)
	if object.bRunCommands == false or object.bMoveCommands == false then
		return false
	end
	
	if bQueueCommand == nil then
		bQueueCommand = false
	end
	
	if bInterruptAttacks == nil then
		bInterruptAttacks = true
	end
	
	if not bInterruptAttacks then
		local status = core.GetAttackSequenceProgress(unit)
		if status == "windup" then
			return true
		end
	end

	local queue = "None"
	if bQueueCommand then
		queue = "Back"
	end
	
	botBrain:OrderEntity(unit.object or unit, "Follow", target.object or target, queue)
	return true
end

function core.OrderTouch(botBrain, unit, target, bInterruptAttacks, bQueueCommand)
	if object.bRunCommands == false or object.bMoveCommands == false then
		return false
	end
	
	if bQueueCommand == nil then
		bQueueCommand = false
	end
	
	if bInterruptAttacks == nil then
		bInterruptAttacks = true
	end
	
	if not bInterruptAttacks then
		local status = core.GetAttackSequenceProgress(unit)
		if status == "windup" then
			return true
		end
	end
	
	local queue = "None"
	if bQueueCommand then
		queue = "Back"
	end
	
	botBrain:OrderEntity(unit.object or unit, "Touch", target.object or target, queue)
	return true
end

function core.OrderStop(botBrain, unit, bInterruptAttacks, bQueueCommand)
	if object.bRunCommands == false or object.bMoveCommands == false then
		return false
	end
	
	if bQueueCommand == nil then
		bQueueCommand = false
	end
	
	if bInterruptAttacks == nil then
		bInterruptAttacks = true
	end
	
	if not bInterruptAttacks then
		local status = core.GetAttackSequenceProgress(unit)
		if status == "windup" then
			return true
		end
	end

	local queue = "None"
	if bQueueCommand then
		queue = "Back"
	end
	
	botBrain:Order(unit.object or unit, "Stop")
	return true
end

function core.OrderHoldClamp(botBrain, unit, bInterruptAttacks, bQueueCommand)
	if object.bRunCommands == false or object.bMoveCommands == false then
		return false
	end
	
	local curTimeMS = HoN.GetGameTime()
	--stagger updates so we don't have permajitter
	if curTimeMS < core.GetNextOrderTime(unit) then
		return true
	end
	
	core.OrderHold(botBrain, unit, bInterruptAttacks, bQueueCommand)

	core.SetNextOrderTime(unit, curTimeMS + core.timeBetweenOrders)
	return true
end

function core.OrderHold(botBrain, unit, bInterruptAttacks, bQueueCommand)
	if object.bRunCommands == false or object.bMoveCommands == false then
		return false
	end
	
	if bQueueCommand == nil then
		bQueueCommand = false
	end
	
	if bInterruptAttacks == nil then
		bInterruptAttacks = true
	end
	
	if not bInterruptAttacks then
		local status = core.GetAttackSequenceProgress(unit)
		if status == "windup" then
			return true
		end
	end

	local queue = "None"
	if bQueueCommand then
		queue = "Back"
	end
	
	botBrain:Order(unit.object or unit, "Hold", queue)
	return true
end

function core.OrderGiveItem(botBrain, unit, target, item, bInterruptAttacks, bQueueCommand)
	if object.bRunCommands == false or object.bOtherCommands == false then
		return false
	end
	
	if bQueueCommand == nil then
		bQueueCommand = false
	end
	
	if bInterruptAttacks == nil then
		bInterruptAttacks = true
	end
	
	if not bInterruptAttacks then
		local status = core.GetAttackSequenceProgress(unit)
		if status == "windup" then
			return true
		end
	end

	local queue = "None"
	if bQueueCommand then
		queue = "Back"
	end
	
	botBrain:OrderEntity(unit.object or unit, "GiveItem", target.object or target, queue, item)
	return true
end

function core.OrderMoveToPosClamp(botBrain, unit, position, bInterruptAttacks, bQueueCommand)
	if object.bRunCommands == false or object.bMoveCommands == false then
		return false
	end

	local curTimeMS = HoN.GetGameTime()
	if curTimeMS < core.GetNextOrderTime(unit) then
		return true
	end
	
	if Vector3.Distance2DSq(unit:GetPosition(), position) > core.distSqTolerance then
		core.OrderMoveToPos(botBrain, unit, position, bInterruptAttacks, bQueueCommand)
	end

	core.SetNextOrderTime(unit, curTimeMS + core.timeBetweenOrders)
	return true
end

function core.OrderMoveToPosAndHoldClamp(botBrain, unit, position, bInterruptAttacks, bQueueCommand)
	if object.bRunCommands == false or object.bMoveCommands == false then
		return false
	end
	
	local curTimeMS = HoN.GetGameTime()
	if curTimeMS < core.GetNextOrderTime(unit) then
		return true
	end
	
	core.OrderMoveToPosAndHold(botBrain, unit, position, bInterruptAttacks, bQueueCommand)

	core.SetNextOrderTime(unit, curTimeMS + core.timeBetweenOrders)
	return true
end

function core.OrderMoveToPosAndHold(botBrain, unit, position, bInterruptAttacks, bQueueCommand)
	if object.bRunCommands == false or object.bMoveCommands == false then
		return false
	end
	
	if Vector3.Distance2DSq(unit:GetPosition(), position) > core.distSqTolerance then
		core.OrderMoveToPos(botBrain, unit, position, bInterruptAttacks, bQueueCommand)
	else
		core.OrderHold(botBrain, unit, bInterruptAttacks, bQueueCommand)
	end
	return true
end

function core.OrderMoveToPos(botBrain, unit, position, bInterruptAttacks, bQueueCommand)
	if object.bRunCommands == false or object.bMoveCommands == false then
		return false
	end
	
	if bQueueCommand == nil then
		bQueueCommand = false
	end
	
	if bInterruptAttacks == nil then
		bInterruptAttacks = true
	end
	
	if not bInterruptAttacks then
		local status = core.GetAttackSequenceProgress(unit)
		if status == "windup" then
			return true
		end
	end
	
	local queue = "None"
	if bQueueCommand then
		queue = "Back"
	end
	
	--BotEcho('C++ call: OrderPosition('..unit:GetTypeName()..', "Move", {'..tostring(position)..'}, '..tostring(bQueueCommand)..')')
	
	botBrain:OrderPosition(unit.object or unit, "Move", position, queue)
	return true
end

function core.OrderAttackPositionClamp(botBrain, unit, position, bInterruptAttacks, bQueueCommand)
	if object.bRunCommands == false or object.bMoveCommands == false then
		return false
	end
	
	local curTimeMS = HoN.GetGameTime()
	if curTimeMS < core.GetNextOrderTime(unit) then
		return true
	end
	
	core.OrderAttackPosition(botBrain, unit, position, bInterruptAttacks, bQueueCommand)

	core.SetNextOrderTime(unit, curTimeMS + core.timeBetweenOrders)
	return true
end

function core.OrderAttackPosition(botBrain, unit, position, bInterruptAttacks, bQueueCommand)
	if object.bRunCommands == false or object.bMoveCommands == false or object.bAttackCommands == false then
		return false
	end
	
	if bQueueCommand == nil then
		bQueueCommand = false
	end
	
	if bInterruptAttacks == nil then
		bInterruptAttacks = true
	end
	
	if not bInterruptAttacks then
		local status = core.GetAttackSequenceProgress(unit)
		if status == "windup" then
			return true
		end
	end

	local queue = "None"
	if bQueueCommand then
		queue = "Back"
	end
	
	botBrain:OrderPosition(unit.object or unit, "Attack", position, queue)
	return true
end

function core.OrderDropItem(botBrain, unit, position, item, bInterruptAttacks, bQueueCommand)
	if object.bRunCommands == false or object.bOtherCommands == false then
		return false
	end
	
	if bQueueCommand == nil then
		bQueueCommand = false
	end
	
	if bInterruptAttacks == nil then
		bInterruptAttacks = true
	end
	
	if not bInterruptAttacks then
		local status = core.GetAttackSequenceProgress(unit)
		if status == "windup" then
			return true
		end
	end

	local queue = "None"
	if bQueueCommand then
		queue = "Back"
	end
	
	botBrain:OrderPosition(unit.object or unit, "DropItem", position, queue, item.object or item)
	return true
end


function core.OrderItemEntityClamp(botBrain, unit, item, entity, bInterruptAttacks, bQueueCommand)
	if object.bRunCommands == false or object.bOtherCommands == false then
		return false
	end
	
	if bQueueCommand == nil then
		bQueueCommand = false
	end
	
	if bInterruptAttacks == nil then
		bInterruptAttacks = true
	end
	
	if not bInterruptAttacks then
		local status = core.GetAttackSequenceProgress(unit)
		if status == "windup" then
			return true
		end
	end

	local curTimeMS = HoN.GetGameTime()
	--stagger updates so we don't have permajitter
	if curTimeMS < core.GetNextOrderTime(unit) then
		return
	end
	
	local queue = "None"
	if bQueueCommand then
		queue = "Back"
	end
	
	botBrain:OrderItemEntity(item.object or item, entity.object or entity, queue)

	core.SetNextOrderTime(unit, curTimeMS + core.timeBetweenOrders)
	return true
end

function core.OrderItemClamp(botBrain, unit, item, bInterruptAttacks, bQueueCommand)
	if object.bRunCommands == false or object.bOtherCommands == false then
		return false
	end
	
	if bQueueCommand == nil then
		bQueueCommand = false
	end
	
	if bInterruptAttacks == nil then
		bInterruptAttacks = true
	end
	
	if not bInterruptAttacks then
		local status = core.GetAttackSequenceProgress(unit)
		if status == "windup" then
			return true
		end
	end

	local curTimeMS = HoN.GetGameTime()
	--stagger updates so we don't have permajitter
	if curTimeMS < core.GetNextOrderTime(unit) then
		return true
	end
	
	local queue = "None"
	if bQueueCommand then
		queue = "Back"
	end
	
	botBrain:OrderItem(item.object or item, queue)

	core.SetNextOrderTime(unit, curTimeMS + core.timeBetweenOrders)
	return true
end

function core.OrderItemPosition(botBrain, unit, item, vecTarget, bInterruptAttacks, bQueueCommand)
	if object.bRunCommands == false or object.bOtherCommands == false then
		return false
	end
	
	if bQueueCommand == nil then
		bQueueCommand = false
	end
	
	if bInterruptAttacks == nil then
		bInterruptAttacks = true
	end
	
	if not bInterruptAttacks then
		local status = core.GetAttackSequenceProgress(unit)
		if status == "windup" then
			return true
		end
	end
	
	local queue = "None"
	if bQueueCommand then
		queue = "Back"
	end
	
	botBrain:OrderItemPosition(item.object or item, vecTarget)
	return true
end

function core.ToggleAutoCastItem(botBrain, item, bInterruptAttacks, bQueueCommand)
	if object.bRunCommands == false or object.bAbilityCommands == false then
		return false
	end
	
	if bQueueCommand == nil then
		bQueueCommand = false
	end
	
	if bInterruptAttacks == nil then
		bInterruptAttacks = true
	end
	
	if not bInterruptAttacks then
		local sStatus = core.GetAttackSequenceProgress(unit)
		if sStatus == "windup" then
			return true
		end
	end
	
	botBrain:OrderItem2(item, bQueueCommand)
	return true
end


function core.OrderAbility(botBrain, ability, bInterruptAttacks, bQueueCommand)
	if object.bRunCommands == false or object.bAbilityCommands == false then
		return false
	end
	
	if bQueueCommand == nil then
		bQueueCommand = false
	end
	
	if bInterruptAttacks == nil then
		bInterruptAttacks = true
	end
	
	if not bInterruptAttacks then
		local sStatus = core.GetAttackSequenceProgress(unit)
		if sStatus == "windup" then
			return true
		end
	end
	
	botBrain:OrderAbility(ability, bQueueCommand)
	return true
end

function core.OrderAbilityPosition(botBrain, ability, vecTarget, bInterruptAttacks, bQueueCommand)
	if object.bRunCommands == false or object.bAbilityCommands == false then
		return false
	end
	
	if bQueueCommand == nil then
		bQueueCommand = false
	end
	
	if bInterruptAttacks == nil then
		bInterruptAttacks = true
	end
	
	if not bInterruptAttacks then
		local sStatus = core.GetAttackSequenceProgress(unit)
		if sStatus == "windup" then
			return true
		end
	end
	
	botBrain:OrderAbilityPosition(ability, vecTarget, bQueueCommand)
	return true
end

function core.OrderAbilityEntity(botBrain, ability, unitTarget, bInterruptAttacks, bQueueCommand)
	if object.bRunCommands == false or object.bAbilityCommands == false then
		return false
	end
	
	if bQueueCommand == nil then
		bQueueCommand = false
	end
	
	if bInterruptAttacks == nil then
		bInterruptAttacks = true
	end
	
	if not bInterruptAttacks then
		local sStatus = core.GetAttackSequenceProgress(unit)
		if sStatus == "windup" then
			return true
		end
	end
	
	botBrain:OrderAbilityEntity(ability, unitTarget.object or unitTarget, bQueueCommand)
	return true
end

function core.ToggleAutoCastAbility(botBrain, ability, bInterruptAttacks, bQueueCommand)
	if object.bRunCommands == false or object.bAbilityCommands == false then
		return false
	end
	
	if bQueueCommand == nil then
		bQueueCommand = false
	end
	
	if bInterruptAttacks == nil then
		bInterruptAttacks = true
	end
	
	if not bInterruptAttacks then
		local sStatus = core.GetAttackSequenceProgress(unit)
		if sStatus == "windup" then
			return true
		end
	end
	
	botBrain:OrderAbility2(ability, bQueueCommand)
	return true
end

function core.OrderAbilityEntityVector(botBrain, ability, unitTarget, vecDelta, bInterruptAttacks, bQueueCommand)
	if object.bRunCommands == false or object.bAbilityCommands == false then
		return false
	end
	
	if bQueueCommand == nil then
		bQueueCommand = false
	end
	
	if bInterruptAttacks == nil then
		bInterruptAttacks = true
	end
	
	if not bInterruptAttacks then
		local sStatus = core.GetAttackSequenceProgress(unit)
		if sStatus == "windup" then
			return true
		end
	end
	
	botBrain:OrderAbilityEntityVector(ability, unitTarget.object or unitTarget, vecDelta, bQueueCommand)
	return true
end

--======================================================================================

function core.GetRemainingCooldownTime(unit, itemDefinition)
	return unit:GetRemainingCooldownTime(itemDefinition.object or itemDefinition)
end


