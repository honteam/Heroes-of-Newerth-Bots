local _G = getfenv(0)
local herobot = _G.object

herobot.myName = herobot:GetName()

herobot.bRunLogic     = true
herobot.bRunBehaviors = true
herobot.bUpdates      = true
herobot.bUseShop      = true

herobot.bRunCommands     = true
herobot.bMoveCommands    = true
herobot.bAttackCommands  = true
herobot.bAbilityCommands = true
herobot.bOtherCommands   = true

herobot.bReportBehavior = false
herobot.bDebugUtility   = false
herobot.bDebugExecute   = false

herobot.logger = {}
herobot.logger.bWriteLog   = false
herobot.logger.bVerboseLog = false

herobot.core        = {}
herobot.eventsLib   = {}
herobot.metadata    = {}
herobot.behaviorLib = {}
herobot.skills      = {}

runfile "bots/core.lua"
runfile "bots/botbraincore.lua"
runfile "bots/eventsLib.lua"
runfile "bots/metadata.lua"
runfile "bots/behaviorLib.lua"

local core = herobot.core

herobot.tSkills = {
	0, 1, 0, 1, 0,
	3, 0, 1, 1, 2,
	3, 2, 2, 2, 4,
	3
}

function herobot:SkillBuildAssignSkills()
end

function herobot:SkillBuild()
	self:SkillBuildAssignSkills()

	local unitSelf = core.unitSelf
	if unitSelf:GetAbilityPointsAvailable() <= 0 then
		return
	end

	local nLevel = unitSelf:GetLevel()
	local nPoints = unitSelf:GetAbilityPointsAvailable()
	local nStartPoint = 1 + nLevel - nPoints -- This makes sure that correct skill is leveled up after ReloadBots
	local tSkills = self.tSkills
	for i = nStartPoint, nLevel do
		unitSelf:GetAbility( tSkills[i] or 4 ):LevelUp()
	end
end
