-- eventsLib v1.0


local _G = getfenv(0)
local object = _G.object

object.eventsLib = object.eventsLib or {}
local eventsLib, core, behaviorLib = object.eventsLib, object.core, object.behaviorLib

local print, ipairs, pairs, string, table, next, type, tinsert, tremove, tsort, format, tostring, tonumber, strfind, strsub
	= _G.print, _G.ipairs, _G.pairs, _G.string, _G.table, _G.next, _G.type, _G.table.insert, _G.table.remove, _G.table.sort, _G.string.format, _G.tostring, _G.tonumber, _G.string.find, _G.string.sub
local ceil, floor, pi, tan, atan, atan2, abs, cos, sin, acos, max, random
	= _G.math.ceil, _G.math.floor, _G.math.pi, _G.math.tan, _G.math.atan, _G.math.atan2, _G.math.abs, _G.math.cos, _G.math.sin, _G.math.acos, _G.math.max, _G.math.random

local BotEcho, VerboseLog, BotLog = core.BotEcho, core.VerboseLog, core.BotLog


local _G = getfenv(0)
local tinsert = _G.table.insert

eventsLib.recentDamage = 0
eventsLib.recentDamageSec = 0
eventsLib.recentDamageHalfSec = 0
eventsLib.recentDamagePrevHalfSec = 0
eventsLib.recentHeroDamage = 0
eventsLib.recentHeroDamageSec = 0
eventsLib.recentHeroDamageHalfSec = 0
eventsLib.recentHeroDamagePrevHalfSec = 0

eventsLib.nextUpdateTime = 0
eventsLib.nextUpdateInterval = 0
eventsLib.nextDmgReportTime = 0
eventsLib.nextDmgReportInterval = 250

eventsLib.incomingProjectiles = {}
eventsLib.incomingProjectiles["all"] = {}
eventsLib.incomingProjectiles["towers"] = {}
eventsLib.incomingProjectiles["heroes"] = {}
eventsLib.recentDamageTable = {}
eventsLib.recentDamageTable["all"] = {}
eventsLib.recentDamageTable["heroes"] = {}
eventsLib.damageMemory = 3000
eventsLib.recentDotTime = 0
eventsLib.recentDotMemory = 600

--Called when the engine gives us events
function object:oncombatevent(EventData)
	local bPrintCombatEvent = false
	
	--if object.myName == "HammerBot" then bPrintCombatEvent = true end
	
	--[[
	EventData:
		Type {Invalid, Damage, Heal, Buff, Debuff, State, Item, Ability, Attack, Set_Health, Buff_Swap, Buff_End, Debuff_End, State_End, Purge, Dispel, Kill, Death, Respawn, Killed, Linked_Damage, Projectile_Target, Other}
		Times
		TimeStamp
		SourcePlayerName
		SourcePlayerColor
		TargetPlayerName
		TargetPlayerColor
		InflictorName
		SourceName
		TargetName
		InflictorUnit
		SourceUnit
		TargetUnit
		DamageApplied
		DamageType {Attack, Physical, Magic, StatusBuff, StatusDebuff, StatusDisable, StatusStealth, Dominate, Transmute, Disable, Astrolabe, Replenish, Transfigure, Push, Splash, DOT, Buff, DeBuff, Returned, BarrierIdol, NeutralAggro, SuperiorMagic, SuperiorPhysical, Interrupting, Cleave, AbilityBasedProjectile, BindingProjectile}
		DamageAttempted
		DamageSuperType {Invalid, Attack, Spell}
		EffectType {Attack, Physical, Magic, StatusBuff, StatusDebuff, StatusDisable, StatusStealth, Dominate, Transmute, Disable, Astrolabe, Replenish, Transfigure, Push, Splash, DOT, Buff, DeBuff, Returned, BarrierIdol, NeutralAggro, SuperiorMagic, SuperiorPhysical, Interrupting, Cleave, AbilityBasedProjectile, BindingProjectile}
		Healed
		SateDuration
		StateName
		StateLevel 
		ProjectileLifetime
		ProjectileDisjointable
		ProjectileID
	--]]
	
	if bPrintCombatEvent then
		eventsLib.printCombatEvent(EventData)
	end
	
	local curTimeMS = HoN.GetGameTime()
	
	local addBonus = 0
	
	if EventData.Type == "Projectile_Target" then
		--BotEcho("Projectile Incomming!  source: "..EventData.SourceName)
		tinsert(eventsLib.incomingProjectiles["all"], EventData)
		
		if EventData.SourceUnit and EventData.SourceUnit:IsTower() and EventData.SourceUnit:GetTeam() ~= core.myTeam then
			tinsert(eventsLib.incomingProjectiles["towers"], EventData)
		end
		
		if EventData.SourceUnit and EventData.SourceUnit:IsHero() and EventData.SourceUnit:GetTeam() ~= core.myTeam then
			tinsert(eventsLib.incomingProjectiles["heroes"], EventData)
		end
	elseif EventData.Type == "Damage" then
		--BotEcho("Damage Event Recieved!!!")
		tinsert(eventsLib.recentDamageTable["all"], EventData)
		
		if EventData.SourceUnit ~= nil and EventData.SourceUnit:IsHero() then
			tinsert(eventsLib.recentDamageTable["heroes"], EventData)
		end
		
		if EventData.DamageType == "DOT" then
			eventsLib.recentDotTime = curTimeMS + eventsLib.recentDotMemory
		end
	elseif EventData.Type == "Item" then
		--BotEcho("ITEM EVENT!  InflictorName: "..EventData.InflictorName)		
		if core.itemGhostMarchers ~= nil and EventData.InflictorName == core.itemGhostMarchers:GetName() then
			--BotEcho("Ghost marchers used!")
			core.itemGhostMarchers.expireTime = curTimeMS + core.itemGhostMarchers.duration
			addBonus = addBonus + 15
		elseif core.itemRoT ~= nil and EventData.InflictorName == core.itemRoT:GetName() then
			--BotEcho("RoT used!")
			core.itemRoT.nNextUpdateTime = 0
		elseif EventData.InflictorName == core.idefHomecomingStone:GetName() then
			--BotEcho("Port used!")
			behaviorLib.bLastPortResult = false
		end
	elseif EventData.Type == "State" or EventData.Type == "Buff" then
		if core.idefBlightStones ~= nil and EventData.StateName == core.idefBlightStones.stateName then
			--BotEcho("Runes of Blight applied")
			core.idefBlightStones.expireTime = curTimeMS + EventData.StateDuration
		elseif core.idefHealthPotion ~= nil and EventData.StateName == core.idefHealthPotion.stateName then
			--BotEcho("health pot applied")
			core.idefHealthPotion.expireTime = curTimeMS + EventData.StateDuration
		end
	elseif EventData.Type == "Kill" then
		--BotEcho("Kill event on "..EventData.TargetName)
		core.ProcessKillChat(EventData.TargetUnit, EventData.TargetPlayerName)
		behaviorLib.ProcessKill(EventData.TargetUnit)
	elseif EventData.Type == "Death" then	
		--BotEcho("Death event on "..EventData.SourceName)
		core.ProcessDeathChat(EventData.SourceUnit, EventData.SourcePlayerName)
		behaviorLib.ProcessDeath(EventData.SourceUnit)
	elseif EventData.Type == "Respawn" then	
		--BotEcho("Respawning")
		core.ProcessRespawnChat()
	elseif EventData.Type == "Killed" then
		--BotEcho("Killed event by "..EventData.SourceName)
		core.ProcessKilledChat(EventData.SourceUnit)
	end
	
	if addBonus > 0 then
		--decay before we add
		core.DecayBonus(self)
	
		core.nHarassBonus = core.nHarassBonus + addBonus
	end
end

function eventsLib.UpdateRecentEvents()
	--Current "short-term memory"
	local bReportDamage = false

	local curTimeMS = HoN.GetGameTime()
	if eventsLib.nextUpdateTime > curTimeMS then
		return
	end	
	
	eventsLib.nextUpdateTime = eventsLib.nextUpdateTime + eventsLib.nextUpdateInterval
	
	eventsLib.recentDamage = 0
	eventsLib.recentDamageTwoSec = 0
	eventsLib.recentDamageSec = 0
	eventsLib.recentDamagePrevSec = 0
	
	eventsLib.recentHeroDamage = 0
	eventsLib.recentHeroDamageSec = 0
	eventsLib.recentHeroDamageHalfSec = 0
	eventsLib.recentHeroDamagePrevHalfSec = 0
	
	--Tally recent damage
	--	Clear expired damage events
	for i, damageEvent in ipairs(eventsLib.recentDamageTable["all"]) do
		if damageEvent.TimeStamp + eventsLib.damageMemory < curTimeMS then
			tremove(eventsLib.recentDamageTable["all"], i)
		else
			eventsLib.recentDamage = eventsLib.recentDamage + damageEvent.DamageApplied
			
			if curTimeMS - damageEvent.TimeStamp <= 2000 then
				eventsLib.recentDamageTwoSec = eventsLib.recentDamageTwoSec + damageEvent.DamageApplied
				
				if curTimeMS - damageEvent.TimeStamp <= 1000 then
					eventsLib.recentDamageSec = eventsLib.recentDamageSec + damageEvent.DamageApplied
				else
					eventsLib.recentDamagePrevSec = eventsLib.recentDamagePrevSec + damageEvent.DamageApplied
				end				
			end
		end
	end
	--  hero damage
	for i, damageEvent in ipairs(eventsLib.recentDamageTable["heroes"]) do
		if damageEvent.TimeStamp + eventsLib.damageMemory < curTimeMS then
			tremove(eventsLib.recentDamageTable["heroes"], i)
		else
			eventsLib.recentHeroDamage = eventsLib.recentHeroDamage + damageEvent.DamageApplied
			
			if curTimeMS - damageEvent.TimeStamp <= 1000 then
				eventsLib.recentHeroDamageSec = eventsLib.recentHeroDamageSec + damageEvent.DamageApplied
				
				if curTimeMS - damageEvent.TimeStamp <= 500 then
					eventsLib.recentHeroDamageHalfSec = eventsLib.recentHeroDamageHalfSec + damageEvent.DamageApplied
				else
					eventsLib.recentHeroDamagePrevHalfSec = eventsLib.recentHeroDamagePrevHalfSec + damageEvent.DamageApplied
				end				
			end
		end
	end
	
	
	--Clean up incoming projectiles
	for i, projectileEvent in ipairs(eventsLib.incomingProjectiles["all"]) do
		if not HoN.GameEntityExists(projectileEvent.ProjectileID) then
			tremove(eventsLib.incomingProjectiles["all"], i)
		end
	end
	for i, projectileEvent in ipairs(eventsLib.incomingProjectiles["towers"]) do
		if not HoN.GameEntityExists(projectileEvent.ProjectileID) then
			tremove(eventsLib.incomingProjectiles["towers"], i)
		end
	end
	for i, projectileEvent in ipairs(eventsLib.incomingProjectiles["heroes"]) do
		if not HoN.GameEntityExists(projectileEvent.ProjectileID) then
			tremove(eventsLib.incomingProjectiles["heroes"], i)
		end
	end
	
	
	if bReportDamage and curTimeMS > eventsLib.nextDmgReportTime then
		BotEcho(format("TowerPoj: %i  RecentDamage: %g  TwoSec: %g  Sec: %g  PrevSec: %g", #eventsLib.incomingProjectiles["towers"], eventsLib.recentDamage, eventsLib.recentDamageTwoSec, eventsLib.recentDamageSec, eventsLib.recentDamagePrevSec))
		BotEcho("RecentHeroDamage: "..eventsLib.recentHeroDamage.."  Sec: "..eventsLib.recentHeroDamageSec.."  HalfSec: "..eventsLib.recentHeroDamageHalfSec.."  PrevHalfSef: "..eventsLib.recentHeroDamagePrevHalfSec)
		
		eventsLib.nextDmgReportTime = eventsLib.nextDmgReportTime + eventsLib.nextDmgReportInterval
	end
	
	--Update utility bonuses
	core.DecayBonus(self)
end

function eventsLib.printCombatEvent(EventData)
	BotEcho("OnCombatEvent: ")
	if EventData == nil then
		BotEcho("  EventData is nil!")
		return;
	end
	
	if EventData.Type ~= nil then
		BotEcho("  Type = "..tostring(EventData.Type))
	else
		BotEcho("  Type = "..tostring(EventData.Type))
	end
	
	if EventData.Times ~= nil then
		BotEcho("  Times = "..tostring(EventData.Times))
	else
		BotEcho("  Times = "..tostring(EventData.Times))
	end
	
	if EventData.TimeStamp ~= nil then
		BotEcho("  TimeStamp = "..tostring(EventData.TimeStamp))
	else
		BotEcho("  TimeStamp = "..tostring(EventData.TimeStamp))
	end 
	
	if EventData.SourcePlayerName ~= nil then
		BotEcho("  SourcePlayerName = "..tostring(EventData.SourcePlayerName))
	else
		BotEcho("  SourcePlayerName = "..tostring(EventData.SourcePlayerName))
	end
	
	if EventData.SourcePlayerColor ~= nil then
		BotEcho("  SourcePlayerColor = "..tostring(EventData.SourcePlayerColor))
	else
		BotEcho("  SourcePlayerColor = "..tostring(EventData.SourcePlayerColor))
	end
	
	if EventData.TargetPlayerName ~= nil then
		BotEcho("  TargetPlayerName = "..tostring(EventData.TargetPlayerName))
	else
		BotEcho("  TargetPlayerName = "..tostring(EventData.TargetPlayerName))
	end
	
	if EventData.TargetPlayerColor ~= nil then
		BotEcho("  TargetPlayerColor = "..tostring(EventData.TargetPlayerColor))
	else
		BotEcho("  TargetPlayerColor = "..tostring(EventData.TargetPlayerColor))
	end
	 
	if EventData.InflictorName ~= nil then
		BotEcho("  InflictorName = "..tostring(EventData.InflictorName))
	else
		BotEcho("  InflictorName = "..tostring(EventData.InflictorName))
	end
	
	if EventData.SourceName ~= nil then
		BotEcho("  SourceName = "..tostring(EventData.SourceName))
	else
		BotEcho("  SourceName = "..tostring(EventData.SourceName))
	end
	
	if EventData.TargetName ~= nil then
		BotEcho("  TargetName = "..tostring(EventData.TargetName))
	else
		BotEcho("  TargetName = "..tostring(EventData.TargetName))
	end 
	
	if EventData.InflictorUnit ~= nil then
		BotEcho("  InflictorUnit = "..tostring(EventData.InflictorUnit))
	else
		BotEcho("  InflictorUnit = "..tostring(EventData.InflictorUnit))
	end
	
	if EventData.SourceUnit ~= nil then
		BotEcho("  SourceUnit = "..tostring(EventData.SourceUnit))
	else
		BotEcho("  SourceUnit = "..tostring(EventData.SourceUnit))
	end
	
	if EventData.TargetUnit ~= nil then
		BotEcho("  TargetUnit = "..tostring(EventData.TargetUnit))
	else
		BotEcho("  TargetUnit = "..tostring(EventData.TargetUnit))
	end 
	
	if EventData.DamageApplied ~= nil then
		BotEcho("  DamageApplied = "..tostring(EventData.DamageApplied))
	else
		BotEcho("  DamageApplied = "..tostring(EventData.DamageApplied))
	end  
	
	if EventData.DamageType ~= nil then
		BotEcho("  DamageType = "..tostring(EventData.DamageType))
	else
		BotEcho("  DamageType = "..tostring(EventData.DamageType))
	end
	
	if EventData.DamageSuperType ~= nil then
		BotEcho("  DamageSuperType = "..tostring(EventData.DamageSuperType))
	else
		BotEcho("  DamageSuperType = "..tostring(EventData.DamageSuperType))
	end 
	
	if EventData.EffectType ~= nil then
		BotEcho("  EffectType = "..tostring(EventData.EffectType))
	else
		BotEcho("  EffectType = "..tostring(EventData.EffectType))
	end 
	
	if EventData.Healed ~= nil then
		BotEcho("  Healed = "..tostring(EventData.Healed))
	else
		BotEcho("  Healed = "..tostring(EventData.Healed))
	end  
	
	if EventData.StateDuration ~= nil then
		BotEcho("  StateDuration = "..tostring(EventData.StateDuration))
	else
		BotEcho("  StateDuration = "..tostring(EventData.StateDuration))
	end 
	
	if EventData.StateName ~= nil then
		BotEcho("  StateName = "..tostring(EventData.StateName))
	else
		BotEcho("  StateName = "..tostring(EventData.StateName))
	end 
	
	if EventData.StateLevel ~= nil then
		BotEcho("  StateLevel = "..tostring(EventData.StateLevel))
	else
		BotEcho("  StateLevel = "..tostring(EventData.StateLevel))
	end
	
	if EventData.ProjectileLifetime ~= nil then
		BotEcho("  ProjectileLifetime = "..tostring(EventData.ProjectileLifetime))
	else
		BotEcho("  ProjectileLifetime = "..tostring(EventData.ProjectileLifetime))
	end
	
	if EventData.ProjectileDisjointable ~= nil then
		BotEcho("  ProjectileDisjointable = "..tostring(EventData.ProjectileDisjointable))
	else
		BotEcho("  ProjectileDisjointable = "..tostring(EventData.ProjectileDisjointable))
	end		
	
	if EventData.ProjectileID ~= nil then
		BotEcho("  ProjectileID = "..tostring(EventData.ProjectileID))
	else
		BotEcho("  ProjectileID = "..tostring(EventData.ProjectileID))
	end	
end
