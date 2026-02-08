local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TableUtil = require(ReplicatedStorage.Packages.TableUtil)
local Trove = require(ReplicatedStorage.Packages.Trove)

local AnimationUtils = {}
AnimationUtils.CharacterAnimationTypes = {
	idle = "idle",
	walk = "walk",
	run = "run",
	swim = "swim",
	swimidle = "swimidle",
	jump = "jump",
	fall = "fall",
	climb = "climb",
	sit = "sit",
	toolnone = "toolnone",
	toolslash = "toolslash",
	toollunge = "toollunge",
	wave = "wave",
	point = "point",
	dance = "dance",
	dance2 = "dance2",
	dance3 = "dance3",
	laugh = "laugh",
	cheer = "cheer",
}

AnimationUtils.DefaultHumanoidAnimations = {
	idle = {
		{ id = "http://www.roblox.com/asset/?id=507766666", weight = 1 },
		{ id = "http://www.roblox.com/asset/?id=507766951", weight = 1 },
		{ id = "http://www.roblox.com/asset/?id=507766388", weight = 9 },
	},
	walk = {
		{ id = "http://www.roblox.com/asset/?id=507777826", weight = 10 },
	},
	run = {
		{ id = "http://www.roblox.com/asset/?id=507767714", weight = 10 },
	},
	swim = {
		{ id = "http://www.roblox.com/asset/?id=507784897", weight = 10 },
	},
	swimidle = {
		{ id = "http://www.roblox.com/asset/?id=507785072", weight = 10 },
	},
	jump = {
		{ id = "http://www.roblox.com/asset/?id=507765000", weight = 10 },
	},
	fall = {
		{ id = "http://www.roblox.com/asset/?id=507767968", weight = 10 },
	},
	climb = {
		{ id = "http://www.roblox.com/asset/?id=507765644", weight = 10 },
	},
	sit = {
		{ id = "http://www.roblox.com/asset/?id=2506281703", weight = 10 },
	},
	toolnone = {
		{ id = "http://www.roblox.com/asset/?id=507768375", weight = 10 },
	},
	toolslash = {
		{ id = "http://www.roblox.com/asset/?id=522635514", weight = 10 },
	},
	toollunge = {
		{ id = "http://www.roblox.com/asset/?id=522638767", weight = 10 },
	},
	wave = {
		{ id = "http://www.roblox.com/asset/?id=507770239", weight = 10 },
	},
	point = {
		{ id = "http://www.roblox.com/asset/?id=507770453", weight = 10 },
	},
	dance = {
		{ id = "http://www.roblox.com/asset/?id=507771019", weight = 10 },
		{ id = "http://www.roblox.com/asset/?id=507771955", weight = 10 },
		{ id = "http://www.roblox.com/asset/?id=507772104", weight = 10 },
	},
	dance2 = {
		{ id = "http://www.roblox.com/asset/?id=507776043", weight = 10 },
		{ id = "http://www.roblox.com/asset/?id=507776720", weight = 10 },
		{ id = "http://www.roblox.com/asset/?id=507776879", weight = 10 },
	},
	dance3 = {
		{ id = "http://www.roblox.com/asset/?id=507777268", weight = 10 },
		{ id = "http://www.roblox.com/asset/?id=507777451", weight = 10 },
		{ id = "http://www.roblox.com/asset/?id=507777623", weight = 10 },
	},
	laugh = {
		{ id = "http://www.roblox.com/asset/?id=507770818", weight = 10 },
	},
	cheer = {
		{ id = "http://www.roblox.com/asset/?id=507770677", weight = 10 },
	},
}

function AnimationUtils.PlayAnimation(
	animator: Animator,
	animationID: string,
	fadeTime: number?,
	weight: number?,
	speed: number?
)
	local animationTrack = AnimationUtils.CreateAnimationTrack(animator, animationID, fadeTime, weight, speed)
	animationTrack:Play()
	return animationTrack
end

-- call waitforchild on character animator script outside of function!
function AnimationUtils.SetCharacterAnimations(character, characterAnimationType, animationIDs)
	local animationContainer = character.Animate[characterAnimationType]

	-- destroy old animations
	for _, animation in animationContainer:GetChildren() do
		animation:Destroy()
	end

	-- create new animations
	for _, animationID in pairs(animationIDs) do
		local animation = Instance.new("Animation")
		animation.AnimationId = animationID
		animation.Parent = animationContainer
	end
end

function AnimationUtils.GetCharacterAnimationIDs(character, characterAnimationType)
	return TableUtil.Map(character.Animate[characterAnimationType]:GetChildren(), function(animation)
		return animation.AnimationId
	end)
end

function AnimationUtils.AnimateHumanoid(character, animNames)
	local trove = Trove.new()
	local Humanoid = character:WaitForChild("Humanoid")
	local Animator = Humanoid:WaitForChild("Animator")

	animNames = TableUtil.Reconcile(animNames, AnimationUtils.DefaultHumanoidAnimations)

	local currentAnimationType = nil
	local currentAnimationTrack: AnimationTrack = nil

	local currentAnimationTrove = trove:Extend()
	local function playRandomAnimation(animName, fadeTime, speed)
		print("playing animation")
		currentAnimationTrove:Clean()

		currentAnimationType = animName
		speed = speed or 1
		local animData = animNames[animName][math.random(1, #animNames[animName])]
		currentAnimationTrack = currentAnimationTrove:Add(
			AnimationUtils.PlayAnimation(Animator, animData.id, fadeTime, animData.weight, speed)
		)
		currentAnimationTrove:Add(function()
			currentAnimationTrack:Stop()
			currentAnimationType = nil
			currentAnimationTrack = nil
		end)
	end

	-- connect events
	trove:Add(Humanoid.Died:Connect(function()
		trove:Clean()
	end))
	trove:Add(Humanoid.Running:Connect(function(speed)
		print("running", speed)
		if speed > 0 then
			local animSpeed = speed / 10

			if currentAnimationType ~= AnimationUtils.CharacterAnimationTypes.run then
				playRandomAnimation(AnimationUtils.CharacterAnimationTypes.run, 0.2, animSpeed)
			end

			currentAnimationTrack:AdjustSpeed(animSpeed)
		else
			playRandomAnimation(AnimationUtils.CharacterAnimationTypes.idle, 0.2)
		end
	end))
	trove:Add(Humanoid.Jumping:Connect(function()
		playRandomAnimation(AnimationUtils.CharacterAnimationTypes.jump, 0.2)
	end))
	-- Humanoid.Climbing:connect(onClimbing)
	-- Humanoid.GettingUp:connect(onGettingUp)
	-- Humanoid.FreeFalling:connect(onFreeFall)
	-- Humanoid.FallingDown:connect(onFallingDown)
	-- Humanoid.Seated:connect(onSeated)
	-- Humanoid.PlatformStanding:connect(onPlatformStanding)
	-- Humanoid.Swimming:connect(onSwimming)

	return trove
end

function AnimationUtils.CreateAnimationTrack(
	animator: Animator,
	animationID: string,
	fadeTime: number?,
	weight: number?,
	speed: number?
)
	local animation = Instance.new("Animation")
	animation.AnimationId = animationID
	local animationTrack = animator:LoadAnimation(animation)
	return animationTrack
end

return AnimationUtils
