
-- Shared helpers: resolving a container definition into final interaction settings,
-- picking sounds and playing the player's gesture. Edit sh_config.lua, not this file.

-- Fields of a container definition that may override the interaction type's fields.
local OVERRIDABLE = {
	"text", "time", "distance", "maxMove", "gesture", "material", "soundLevel", "closeDelay"
}

--- Returns the definition registered for a model, or nil.
function ix.container.GetDefinition(model)
	if (!model) then
		return
	end

	return ix.container.stored[tostring(model):lower()]
end

--- Returns the id of the interaction type a definition uses (falls back to the default one).
function ix.container.GetInteractionID(definition)
	local id = definition and definition.interaction

	if (id and ix.container.interactions[id]) then
		return id
	end

	if (ix.container.interactions[ix.container.defaultInteraction]) then
		return ix.container.defaultInteraction
	end

	return (next(ix.container.interactions))
end

--- Merges the interaction type with the per-prop overrides. The result is cached on the definition.
function ix.container.GetSettings(definition)
	if (!definition) then
		return
	end

	if (definition.settings) then
		return definition.settings
	end

	local id = ix.container.GetInteractionID(definition)
	local interaction = ix.container.interactions[id]

	if (!interaction) then
		return
	end

	local settings = {id = id, sounds = {}, animation = {}}

	for k, v in pairs(interaction) do
		if (k != "sounds" and k != "animation") then
			settings[k] = v
		end
	end

	for _, key in ipairs(OVERRIDABLE) do
		if (definition[key] != nil) then
			settings[key] = definition[key]
		end
	end

	-- sounds and animation are merged key by key, the prop wins over the type
	for _, field in ipairs({"sounds", "animation"}) do
		for k, v in pairs(interaction[field] or {}) do
			settings[field][k] = v
		end

		for k, v in pairs(definition[field] or {}) do
			settings[field][k] = v
		end
	end

	-- backwards compatibility with the old `locksound` field
	if (definition.locksound and definition.locksound != "") then
		settings.sounds.locked = definition.locksound
	end

	settings.time = tonumber(settings.time) or 1
	settings.distance = tonumber(settings.distance) or 96
	settings.soundLevel = tonumber(settings.soundLevel) or 60
	settings.closeDelay = tonumber(settings.closeDelay) or 0

	definition.settings = settings

	return settings
end

--- Picks a sound for the given key ("start", "open", "close", "locked").
-- Order: prop/type `sounds` table, then the material set. `false` means silence.
function ix.container.GetSound(settings, key)
	if (!settings) then
		return
	end

	local value = settings.sounds[key]

	if (value == nil) then
		local set = ix.container.materials[settings.material]
		value = set and set[key]
	end

	if (istable(value)) then
		value = value[math.random(#value)]
	end

	if (isstring(value) and value != "") then
		return value
	end
end

--- Converts "ACT_GMOD_GESTURE_ITEM_PLACE" (or a number) to the activity number.
function ix.container.ResolveAct(value)
	if (isnumber(value)) then
		return value
	end

	if (isstring(value)) then
		local act = _G[value]

		if (isnumber(act)) then
			return act
		end
	end
end

if (SERVER) then
	util.AddNetworkString("ixContainerGesture")

	--- Plays the interaction gesture on a player for everyone who can see them.
	-- Pass bReset = true to stop the gesture (the action was interrupted).
	function ix.container.PlayGesture(client, settings, bReset)
		if (!IsValid(client)) then
			return
		end

		local act = -1

		if (!bReset) then
			act = settings and ix.container.ResolveAct(settings.gesture)

			if (!act) then
				return
			end
		end

		net.Start("ixContainerGesture")
			net.WriteEntity(client)
			net.WriteInt(act, 32)
		net.SendPVS(client:GetPos())
	end
else
	net.Receive("ixContainerGesture", function()
		local client = net.ReadEntity()
		local act = net.ReadInt(32)

		if (!IsValid(client)) then
			return
		end

		if (act < 0) then
			client:AnimResetGestureSlot(GESTURE_SLOT_CUSTOM)
		else
			client:AnimRestartGesture(GESTURE_SLOT_CUSTOM, act, true)
		end
	end)
end
