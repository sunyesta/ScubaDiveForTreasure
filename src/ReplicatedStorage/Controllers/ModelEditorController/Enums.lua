local Enums = {}

Enums.States = {
	Updating = "Updating",
	Idle = "Idle",
	Moving = "Moving",
	Rotating = "Rotating",
	Painting = "Painting",
	Referencing = "Referencing",
	Resizing = "Resizing",
}

Enums.Gizmos = {
	Transform = "Transform",
	Scale = "Scale",
}

Enums.MoveStatuses = {
	Moved = "Moved",
	InvalidPlacement = "InvalidPlacement",
	Discarded = "Discarded",
}

table.freeze(Enums.States)
table.freeze(Enums.Gizmos)
table.freeze(Enums.MoveStatuses)

return Enums
