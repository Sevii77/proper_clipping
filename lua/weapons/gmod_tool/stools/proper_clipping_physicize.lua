TOOL.Category = "Construction"
TOOL.Name = "#Tool.proper_clipping_physicize.name"

if CLIENT then
	language.Add("Tool.proper_clipping_physicize.name", "Proper Clipping Physicize")
	language.Add("Tool.proper_clipping_physicize.desc", "Convert non-physics clips to physics")
	
	language.Add("Tool.proper_clipping_physicize.left", "Convert")
	
	TOOL.Information = {
		{stage = 0, name = "left"}
	}
end

function TOOL:LeftClick(tr)
	local ent = tr.Entity
	if not ent.Clipped then return end
	if CLIENT then return true end
	
	local owner = self:GetOwner()
	local valid, left = ProperClipping.CanAddPhysicsClip(ent, owner)
	
	if not valid then
		owner:ChatPrint("Entity cannot be physically clipped")
		
		return
	end
	
	local norms, dists, insides, physicss = {}, {}, {}, {}
	local i = 1
	for _, clip in ipairs(ent.ClipData) do
		if not clip.physics then
			left = left - 1
			
			if left < 0 then
				owner:ChatPrint("Max physics clips per entity reached (max " .. ProperClipping.MaxPhysicsClips() .. ") converted " .. (i - 1) .. " clips")
				
				break
			end
			
			norms[i] = clip.norm
			dists[i] = clip.dist
			insides[i] = clip.inside
			physicss[i] = true
			i = i + 1
		end
	end
	
	if #norms > 0 then
		for i = 1, #norms do
			ProperClipping.RemoveClip(ent, select(2, ProperClipping.ClipExists(ent, norms[i], dists[i])))
		end
		
		ProperClipping.AddClip(ent, norms, dists, insides, physicss)
	end
	
	owner:ChatPrint("Converted " .. (i - 1) .. " clips")
	
	return true
end
