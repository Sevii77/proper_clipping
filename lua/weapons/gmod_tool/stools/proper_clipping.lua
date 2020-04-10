TOOL.Category = "Construction"
TOOL.Name = "#Tool.proper_clipping.name"

TOOL.ClientConVar.mode    = "0" -- int
TOOL.ClientConVar.offset  = "0" -- float
TOOL.ClientConVar.physics = "0" -- bool

if CLIENT then
	language.Add("Tool.proper_clipping.name", "Proper Clipping")
	language.Add("Tool.proper_clipping.desc", "Visually or Physically clip entities")
	
	language.Add("Tool.proper_clipping.mode.0", "Hitplane")
	language.Add("Tool.proper_clipping.mode.1", "Point to Point")
	
	language.Add("Tool.proper_clipping.info1", "Hold ALT to invert the plane normal")
	language.Add("Tool.proper_clipping.info2", "Hold SHIFT to enable inside rendering")
	language.Add("Tool.proper_clipping.right", "Clip entity")
	language.Add("Tool.proper_clipping.reload", "Remove all clips")
	
	language.Add("Tool.proper_clipping.left_op0", "Define plane")
	
	language.Add("Tool.proper_clipping.left_op1_stage0", "Define start point")
	language.Add("Tool.proper_clipping.left_op1_stage1", "Define end point")
	
	TOOL.Information = {
		{stage = 0, name = "info1"},
		{stage = 0, name = "info2"},
		{stage = 0, name = "reload"},
		
		{op = 0, name = "left_op0"},
		
		{op = 1, stage = 0, name = "left_op1_stage0"},
		{op = 1, stage = 1, name = "left_op1_stage1"},
		
		"right"
	}
	
	function TOOL.BuildCPanel(panel)
		panel:AddControl("ListBox", {
			Label = "Mode",
			Options = {
				["#Tool.proper_clipping.mode.0"] = {proper_clipping_mode = 0},
				["#Tool.proper_clipping.mode.1"] = {proper_clipping_mode = 1}
			}
		})
		
		panel:AddControl("Slider", {
			label = "Offset",
			type = "float",
			command = "proper_clipping_offset",
			min = -50,
			max =  50
		})
		
		panel:AddControl("Checkbox", {
			label = "Physics",
			command = "proper_clipping_physics"
		})
	end
	
end

----------------------------------------

-- local instead of part of tool so that when you regain the toolgun it keeps em
local origin = Vector()
local norm = Vector(0, 0, 1)

function TOOL:Think()
	local new = math.floor(self:GetClientNumber("mode"))
	
	if new == self:GetOperation() then return end
	
	self:SetOperation(new)
	self:SetStage(0)
end

function TOOL:LeftClick(tr)
	local ent = tr.Entity
	
	local op = self:GetOperation()
	local stage = self:GetStage()
	
	if not (op == 1 and stage == 1 and ent:IsWorld()) then
		if not ent or not ent:IsValid() then return end
		if ent:IsPlayer() or ent:IsWorld() then return end
	end
	
	if op == 0 then
		norm = tr.HitNormal
		origin = tr.HitPos
	elseif op == 1 then
		if stage == 0 then
			origin = tr.HitPos
			self:SetStage(1)
		else
			norm = (tr.HitPos - origin):GetNormalized()
			self:SetStage(0)
		end
	end
	
	return true
end

function TOOL:RightClick(tr)
	if self:GetStage() == 1 then return end
	local ent = tr.Entity
	if not ent or not ent:IsValid() then return end
	if ent:IsPlayer() or ent:IsWorld() then return end
	if CLIENT then return true end
	
	local owner = self:GetOwner()
	local norm_org = norm
	local norm = norm * (owner:KeyDown(IN_WALK) and -1 or 1)
	local dist = -norm:Dot(ent:LocalToWorld(Vector()) - (origin + norm_org * self:GetClientNumber("offset")))
	local norm = ent:WorldToLocalAngles(norm:Angle()):Forward() * -1
	
	local physics = self:GetClientNumber("physics") ~= 0
	
	if physics and not ProperClipping.CanAddPhysicsClip(ent, owner) then
		owner:ChatPrint("Max physics clips per entity reached (max " .. ProperClipping.MaxPhysicsClips() .. ")")
		physics = false
	end
	
	ProperClipping.AddClip(ent, norm, dist, owner:KeyDown(IN_SPEED), physics)
	
	return true
end

function TOOL:Reload(tr)
	if self:GetStage() == 1 then return end
	local ent = tr.Entity
	if not ent or not ent:IsValid() then return end
	if ent:IsPlayer() or ent:IsWorld() then return end
	if CLIENT then return true end
	
	ProperClipping.RemoveClips(ent)
	
	return true
end

----------------------------------------

if CLIENT then
	
	local color_red = Color(255, 80, 100)
	local color_green = Color(30, 255, 120, 190)
	local color_green2 = Color(25, 200, 90, 100)
	
	local model1 = ClientsideModel("models/error.mdl")
	local model2 = ClientsideModel("models/error.mdl")
	model1:SetMaterial("models/debug/debugwhite")
	model2:SetMaterial("models/debug/debugwhite")
	model1:SetNoDraw(true)
	model2:SetNoDraw(true)
	
	function TOOL:DrawHUD()
		local owner = self:GetOwner()
		local tr = owner:GetEyeTrace()
		
		local op = self:GetOperation()
		local stage = self:GetStage()
		
		cam.Start3D()
		
		if op == 1 and stage == 1 then
			-- Line mode
			local norm = (tr.HitPos - origin):GetNormalized()
			
			render.SetColorMaterial()
			render.DrawQuadEasy(origin, norm, 16, 16, color_green)
			render.DrawQuadEasy(origin, -norm, 16, 16, color_green2)
			render.DrawLine(origin, origin + norm * 16, color_red)
		else
			-- Preview
			local ent = tr.Entity
			if ent and ent:IsValid() and not ent:IsPlayer() then
				local mdl = ent:GetModel()
				local pos = ent:GetPos()
				local ang = ent:GetAngles()
				
				model1:SetModel(mdl)
				model2:SetModel(mdl)
				model1:SetPos(pos)
				model2:SetPos(pos)
				model1:SetAngles(ang)
				model2:SetAngles(ang)
				
				local i = owner:KeyDown(IN_WALK)
				local offset = self:GetClientNumber("offset") * (i and -1 or 1)
				
				local prev = render.EnableClipping(true)
				
				render.PushCustomClipPlane(norm * (i and 1 or -1), norm:Dot(origin) * (i and 1 or -1) - offset)
				render.SetColorModulation(0.3, 2, 0.5)
				model1:DrawModel()
				render.PopCustomClipPlane()
				
				render.PushCustomClipPlane(norm * (i and -1 or 1), norm:Dot(origin) * (i and -1 or 1) + offset)
				render.SetColorModulation(2, 0.2, 0.3)
				model2:DrawModel()
				render.PopCustomClipPlane()
				
				render.EnableClipping(prev)
			end
		end
		
		cam.End3D()
	end
	
end
