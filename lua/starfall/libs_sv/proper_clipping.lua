local checkluatype = SF.CheckLuaType
local checkpermission = SF.Permissions.check
local registerprivilege = SF.Permissions.registerPrivilege

registerprivilege("entities.visclip", "Visual Clipping", "Allows the used to add visual clips to entities", { entities = {} })
registerprivilege("entities.physclip", "Physics Clipping", "Allows the used to add physics clips to entities", { entities = {} })

-- --------------------------------------
-- Instance

return function(instance)

local ents_methods, ent_meta, ewrap, eunwrap = instance.Types.Entity.Methods, instance.Types.Entity, instance.Types.Entity.Wrap, instance.Types.Entity.Unwrap
local vwrap, vunwrap = instance.Types.Vector.Wrap, instance.Types.Vector.Unwrap

local getent
instance:AddHook("initialize", function()
	getent = instance.Types.Entity.GetEntity
end)

-- --------------------------------------
-- Check funcs

local function checkvis(ent)
	checkpermission(instance, ent, "entities.visclip")
	if not ProperClipping.CanAddClip(ent, instance.player) then
		SF.Throw("Not allowed to make visual clips.", 3)
	end
end

local function checkphys(ent)
	checkpermission(instance, ent, "entities.physclip")
	if not ProperClipping.CanAddPhysicsClip(ent, instance.player) then
		SF.Throw("Not allowed to make physics clips or limit has been reached.", 3)
	end
end

-- --------------------------------------
-- Methods

--- Creates visual clip
-- @param origin Origin vector
-- @param normal Normal vector
-- @param inside Optional bool (Default false), should the inside be rendered
-- @param physics Optional bool (Default false), should the physics be clipped
-- @return True or false if it was succesfull
function ents_methods:addClip(origin, normal, inside, phys)
	local ent = getent(self)
	
	if not inside then inside = false else checkluatype(inside, TYPE_BOOL) end
	if not phys then phys = false else checkluatype(phys, TYPE_BOOL) end
	
	checkvis(ent)
	if phys then checkphys(ent) end
	
	local origin = vunwrap(origin)
	local normal = vunwrap(normal)
	
	return ProperClipping.AddClip(ent, normal, normal:Dot(origin), inside, phys)
end

--- Removes all clips
-- @return True or false if it was succesfull
function ents_methods:removeClips()
	local ent = getent(self)
	
	checkvis(ent)
	
	return ProperClipping.RemoveClips(ent)
end

--- Removes a clip given origin and normal
-- @param origin Origin vector
-- @param normal Normal vector
-- @return True or false if it was succesfull
function ents_methods:removeClip(origin, normal)
	local ent = getent(self)
	
	checkvis(ent)
	
	local origin = vunwrap(origin)
	local normal = vunwrap(normal)
	
	local exists, index = ProperClipping.ClipExists(ent, normal, normal:Dot(origin))
	if not exists then return false end
	
	return ProperClipping.RemoveClip(ent, index)
end

--- Removes a clip given its index
-- @param index Index number
-- @return True or false if it was succesfull
function ents_methods:removeClipByIndex(index)
	local ent = getent(self)
	
	checkvis(ent)
	
	return ProperClipping.RemoveClip(ent, index)
end

--- Returns if a clip exists and if so its index
-- @param origin Origin vector
-- @param normal Normal vector
-- @return Exists bool, Index number
function ents_methods:clipExists(origin, normal)
	local ent = getent(self)
	
	local origin = vunwrap(origin)
	local normal = vunwrap(normal)
	
	return ProperClipping.ClipExists(ent, normal, normal:Dot(origin))
end

--- Returns the clip index, nil if it doesnt exist
-- @param origin Origin vector
-- @param normal Normal vector
-- @return Index number
function ents_methods:getClipIndex(origin, normal)
	local ent = getent(self)
	
	local origin = vunwrap(origin)
	local normal = vunwrap(normal)
	
	local _, index = ProperClipping.ClipExists(ent, normal, normal:Dot(origin))
	return index
end

--- Returns the amount of physics clips left
-- @return Count number
function ents_methods:physicsClipsLeft()
	local ent = getent(self)
	return ProperClipping.PhysicsClipsLeft(ent)
end

end