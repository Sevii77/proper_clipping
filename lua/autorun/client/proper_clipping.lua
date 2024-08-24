ProperClipping = ProperClipping or {}

local cvar_clips = CreateConVar("proper_clipping_max_visual", "6", FCVAR_ARCHIVE, "Max clips a entity can have", 0, 6)

----------------------------------------
local render_EnableClipping = render.EnableClipping
local render_CullMode = render.CullMode
local render_PopCustomClipPlane = render.PopCustomClipPlane
local render_PushCustomClipPlane = render.PushCustomClipPlane

local entMeta = FindMetaTable("Entity")
local GetTable = entMeta.GetTable
local GetPos = entMeta.GetPos
local GetAngles = entMeta.GetAngles
local DrawModel = entMeta.DrawModel

local maxClips = cvar_clips:GetInt()
cvars.AddChangeCallback("proper_clipping_max_visual", function(_, _, new)
	maxClips = tonumber(new)
end)

local function renderOverride(self)
	local selfTbl = GetTable(self)
	if not selfTbl.Clipped or not selfTbl.ClipData then return end
	
	local prev = render_EnableClipping(true)
	local planes = 0
	local inside = false
	
	local pos = GetPos(self)
	local ang = GetAngles(self)
	
	for i, clip in ipairs(selfTbl.ClipData) do
		if not inside and clip.inside then
			inside = true
		end
		
		if i <= maxClips then
			planes = i
			
			local norm = Vector(clip.norm)
			norm:Rotate(ang)
			
			render_PushCustomClipPlane(norm, norm:Dot(pos + norm * clip.dist))
		end
	end
	
	DrawModel(self)
	
	if inside then
		render_CullMode(MATERIAL_CULLMODE_CW)
		DrawModel(self)
		render_CullMode(MATERIAL_CULLMODE_CCW)
	end
	
	for _ = 1, planes do
		render_PopCustomClipPlane()
	end
	
	render_EnableClipping(prev)
end

function ProperClipping.AddVisualClip(ent, norm, dist, inside, physics)
	if not ent.Clipped then
		ent.RenderOverride_preclipping = ent.RenderOverride
		ent.RenderOverride = renderOverride
		
		ent.Clipped = true
		ent.ClipData = {}
	end
	
	table.insert(ent.ClipData, {
		origin = norm * dist,
		norm = norm,
		n = norm:Angle(),
		dist = dist,
		d = norm:Dot(norm * dist - (ent.OBBCenterOrg or ent:OBBCenter())),
		inside = inside,
		physics = physics,
		new = true -- still no clue what this is for, meh w/e
	})
	
	hook.Run("ProperClippingClipAdded", ent, norm, dist, inside, physics)
end

function ProperClipping.RemoveVisualClips(ent)
	if not ent.Clipped then return end
	
	ent.Clipped = nil
	ent.ClipData = nil
	
	ent.RenderOverride = ent.RenderOverride_preclipping
	ent.RenderOverride_preclipping = nil
	
	hook.Run("ProperClippingClipsRemoved", ent)
end

----------------------------------------

local clip_queue = {}

local function attemptClip(id, clips)
	local ent = Entity(id)
	if not IsValid(ent) then return false end
	-- Wait for the spawneffect to end before we clip the entity
	if ent.SpawnEffect then return false end
	
	ProperClipping.RemoveVisualClips(ent)
	ProperClipping.ResetPhysics(ent)
	
	local norms, dists = {}, {}
	local physcount = 1
	for _, clip in ipairs(clips) do
		local norm, dist, inside, physics = unpack(clip)
		
		ProperClipping.AddVisualClip(ent, norm, dist, inside, physics)
		
		if physics then
			norms[physcount] = norm
			dists[physcount] = dist
			physcount = physcount + 1
		end
	end
	
	if physcount ~= 1 then
		ProperClipping.ClipPhysics(ent, norms, dists)
	end
	
	hook.Run("ProperClippingClipAdded", ent, index)
	
	return true
end

timer.Create("proper_clipping_attemptclip", 0.1, 0, function()
	for id, clips in pairs(clip_queue) do
		if attemptClip(id, clips) then
			clip_queue[id] = nil
		end
	end
end)

net.Receive("proper_clipping", function()
	local id = net.ReadUInt(14)
	local add = net.ReadBool()
	
	if not add then
		clip_queue[id] = nil
		
		local ent = Entity(id)
		if not IsValid(ent) then return end
		
		ProperClipping.RemoveVisualClips(ent)
		ProperClipping.ResetPhysics(ent)
		
		return
	end
	
	local clips = {}
	
	for i = 1, net.ReadUInt(4) do
		clips[i] = {
			Vector(net.ReadFloat(), net.ReadFloat(), net.ReadFloat()),
			net.ReadFloat(),
			net.ReadBool(),
			net.ReadBool()
		}
	end
	
	if not attemptClip(id, clips) then
		clip_queue[id] = clips
	end
end)
