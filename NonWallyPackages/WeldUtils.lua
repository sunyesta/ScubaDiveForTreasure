local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DefaultValue = require(ReplicatedStorage.NonWallyPackages.DefaultValue)
local TableUtil = require(ReplicatedStorage.Packages.TableUtil)
local TableUtil2 = require(ReplicatedStorage.NonWallyPackages.TableUtil2)
local WeldUtils = {}

function WeldUtils.Weld(part0, part1, prexistingWeld)
	local WeldConstraint
	if prexistingWeld then
		WeldConstraint = prexistingWeld
	else
		WeldConstraint = Instance.new("WeldConstraint")
		WeldConstraint.Parent = part0
	end

	WeldConstraint.Part0 = part0
	WeldConstraint.Part1 = part1

	return WeldConstraint
end

function WeldUtils.WeldRelative(part0, part1, part1CFrameOffset, prexistingWeld)
	part1CFrameOffset = part1CFrameOffset or part0:ToObjectSpace(part1)
	part1.CFrame = part0.CFrame * part1CFrameOffset

	return WeldUtils.Weld(part0, part1, prexistingWeld)
end

function WeldUtils.WeldAccessory(accessory, character, prexistingWeld)
	local accessoryAttachment = accessory.Handle:FindFirstChildWhichIsA("Attachment")
	assert(accessoryAttachment, "requires an attachment")
	local characterAttachment = character:FindFirstChild(accessoryAttachment.Name, true)
	assert(characterAttachment, "could not find attachment with name " .. accessoryAttachment.Name .. " in character")

	return WeldUtils.WeldAttachments(
		accessory.Handle,
		characterAttachment.Parent,
		accessoryAttachment.Name,
		prexistingWeld
	)
end

function WeldUtils.WeldAttachments(part1Attachment, part2Attachment, prexistingWeld)
	local part1 = part1Attachment.Parent
	local part2 = part2Attachment.Parent

	local oldPivotOffset = part2.PivotOffset

	part2.PivotOffset = part2Attachment.CFrame
	part2:PivotTo(part1Attachment.WorldCFrame)
	part2.PivotOffset = oldPivotOffset

	return WeldUtils.Weld(part1, part2, prexistingWeld)
end

-- returns all parts attached to part including the part (ignores disabled joints)
-- stopAtAnchored decaults to true
function WeldUtils.GetAttachedParts(part, stopAtAnchored, onlyRigidConstraints)
	assert(part:IsA("BasePart"), "Only baseparts allowed")
	stopAtAnchored = DefaultValue(stopAtAnchored, true)

	local anchoredPart

	local attachedParts = {}
	attachedParts[part] = true

	local function getAttachedParts(basePart)
		local function jointUsesParts(joint)
			return joint:IsA("Weld") or joint:IsA("WeldConstraint") or joint:IsA("Motor6D")
		end

		-- get all parts attached to the base part
		local neighborParts = TableUtil.Map(basePart:GetJoints(), function(joint)
			if jointUsesParts(joint) then
				if joint.Part0 == basePart then
					return joint.Part1
				else
					return joint.Part0
				end
			else
				if onlyRigidConstraints then
					return nil
				else
					print(joint, joint.Parent)

					if joint.Attachment0.Parent == basePart then
						return joint.Attachment1.Parent
					else
						return joint.Attachment0.Parent
					end
				end
			end
		end)

		for _, nPart in pairs(neighborParts) do
			if nPart.Anchored and anchoredPart == nil then
				anchoredPart = nPart
			end
			if not attachedParts[nPart] and (stopAtAnchored == false or nPart.Anchored == false) then
				attachedParts[nPart] = true
				getAttachedParts(nPart)
			end
		end
	end

	getAttachedParts(part)

	return TableUtil.Keys(attachedParts), anchoredPart
end

function WeldUtils.GetMountedParts(part)
	local bottomJoints = TableUtil.Filter(part:GetJoints(), function(joint)
		return joint.Part0 == part
	end)

	for _, joint in pairs(bottomJoints) do
		joint.Enabled = false
	end

	local mountedParts = WeldUtils.GetAttachedParts(part)

	for _, joint in pairs(bottomJoints) do
		joint.Enabled = true
	end

	return mountedParts
end

function WeldUtils.IsAttachedToAnchoredPart(part, onlyWelds)
	local _, anchoredPart = WeldUtils.GetAttachedParts(part, true, onlyWelds)
	return anchoredPart
end

return WeldUtils
