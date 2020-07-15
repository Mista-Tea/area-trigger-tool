local triggerClass = 'sup_areatrigger'

TOOL.Category = 'Superior Tools'
TOOL.Name = 'Area Triggers'

TOOL.ClientConVar['triggername'] = 'Trigger Name'
TOOL.ClientConVar['area_w'] = 100
TOOL.ClientConVar['area_h'] = 100
TOOL.ClientConVar['enableevents'] = 0
TOOL.ClientConVar['helperview'] = 1
TOOL.ClientConVar['removeuse'] = 0

if CLIENT then
	language.Add('Tool.sup_areatrigger.name', 'Area Trigger')
	language.Add('Tool.sup_areatrigger.triggername', 'Trigger ID')
	language.Add('Tool.sup_areatrigger.left', 'Spawns an Area Trigger with the selected options')
	language.Add('Tool.sup_areatrigger.right', 'Updates the closest Area Trigger with the selected options')
	language.Add('Tool.sup_areatrigger.desc', 'Do shit to the player who passes into the area')
	language.Add('Tool.sup_areatrigger.enableevents', 'Event Characters')
	language.Add('Tool.sup_areatrigger.enableevents.help', 'Event characters can trigger this')
	language.Add('Tool.sup_areatrigger.helperview', 'Enable helper overlay')
	language.Add('Tool.sup_areatrigger.helperview.help', 'Pick a overlay type from the dropdown to see the ent ids in game. Helps with some specific trigger types.')
	language.Add('Tool.sup_areatrigger.removeuse', 'Remove after triggered')
end

TOOL.Information = {
	{ name = 'left' },
	{ name = 'right' },
}

local blue = Color(10, 189, 227)
local black = Color(0, 0, 0, 200)
local selectedLookup = 'func_door'

local classLookups = {
	{'Doors', 'func_door'},
	{'Lights', 'light'},
	{'Props', 'prop_physics'},
}

function TOOL:LeftClick(trace)
	local w, h = math.Clamp(self:GetClientNumber('area_w') or 20, 1, 500), math.Clamp(self:GetClientNumber('area_h') or 20, 1, 500)
	local min = Vector(-w/2, -w/2, 0)
	local max = Vector(w/2, w/2, h)

	local owner = self:GetOwner()
	local ang = Angle(0, owner:GetAngles().y, 0)
	local ent = ents.Create(triggerClass)

	ent:SetRemoveOnUse(self:GetClientNumber('removeuse') == 1)
	ent:SetGMOwner(owner)
	ent:SetPropOwner(owner)
	ent:SetEventCharacters(self:GetClientNumber('enableevents') == 1)
	ent:SetPos(trace.HitPos)
	ent:SetAngles(ang)
	ent:SetDisplayName(self:GetClientInfo('triggername') or '')
	ent:PopulateDefinitions()
	ent:Spawn()
	ent:SetArea(min, max)

	undo.Create('sup_areatrigger')
		undo.SetPlayer(owner)
		undo.AddEntity(ent)
		undo.SetCustomUndoText('Removed Area Trigger')
	undo.Finish()
end

function TOOL:RightClick(trace)
	local ent = trace.Entity

	if not IsValid(ent) or ent:GetClass() ~= triggerClass then
		local pos = trace.HitPos
		local enttbl = ents.FindByClass(triggerClass)
		local dist

		for i = 1, #enttbl do
			local targ = enttbl[i]
			local thisdist = targ:GetPos():Distance(pos)
			if targ:GetGMOwner() == self:GetOwner() and (not dist or thisdist < dist) then
				ent = targ
				dist = thisdist
			end
		end

		if not IsValid(ent) then
			return
		end
	end

	local w, h = math.Clamp(self:GetClientNumber('area_w') or 20, 1, 500), math.Clamp(self:GetClientNumber('area_h') or 20, 1, 500)
	local min = Vector(-w/2, -w/2, 0)
	local max = Vector(w/2, w/2, h)

	ent:SetRemoveOnUse(self:GetClientNumber('removeuse') == 1)
	ent:SetEventCharacters(self:GetClientNumber('enableevents') == 1)
	ent:SetDisplayName(self:GetClientInfo('triggername') or '')
	ent:SetArea(min, max)
	ent:PopulateDefinitions()
end

local function CreateAreaDefinition(cpnl, def)
	local pnl = vgui.Create('DPanel')
	pnl:SetTall(105)
	pnl:DockPadding(0, 0, 0, 5)
	pnl:DockMargin(0, 0, 0, 0)
	pnl.id = def.id

	local header = vgui.Create('DPanel', pnl)
	header:Dock(TOP)
	header:SetTall(25)
	header:DockPadding(5, 1, 1, 5)
	header:DockMargin(0, 0, 0, 10)
	header.Paint = function(s, w, h)
		surface.SetDrawColor(blue)
		surface.DrawRect(0, 0, w, h)
	end

	local name = vgui.Create('DLabel', header)
	name:Dock(FILL)
	name:SetText(def.Name or def.id)
	name:SetTextColor(color_white)
	name:DockMargin(0, 0, 0, 0)

	local class = def.Panel or 'DTextEntry'
	local valuePnl = vgui.Create(class, pnl)
	valuePnl:Dock(TOP)
	valuePnl:DockPadding(5, 5, 5, 5)
	valuePnl:DockMargin(5, 2, 5, 5)

	if valuePnl.SetTextColor then
		valuePnl:SetTextColor(color_black)
	elseif valuePnl.Label then
		valuePnl.Label:SetTextColor(color_black)
	end

	if def.PanelSetup then
		def:PanelSetup(valuePnl, pnl)
	end

	local bottomPnl = vgui.Create('DPanel', pnl)
	bottomPnl:Dock(BOTTOM)
	bottomPnl:SetTall(25)
	bottomPnl:DockPadding(1, 1, 1, 1)
	bottomPnl:DockMargin(5, 0, 5, 0)
	bottomPnl.Paint = function() end

	local oncePerLife = vgui.Create('DCheckBoxLabel', bottomPnl)
	oncePerLife:Dock(LEFT)
	oncePerLife:SetTextColor(color_black)
	oncePerLife:SetText('Once Per Life')
	oncePerLife:SetValue(false)

	local apply = vgui.Create('DButton', bottomPnl)
	apply:Dock(RIGHT)
	apply:SetText 'Apply'
	apply.DoClick = function(self, val) 
		areatrigger.SendDefinition(pnl.id, valuePnl, oncePerLife:GetChecked())
	end

	local remove = vgui.Create('DButton', bottomPnl)
	remove:Dock(RIGHT)
	remove:SetText 'Remove'
	remove.DoClick = function(self, val)
		areatrigger.RemoveDefitinion(pnl.id)
		pnl:Remove()
	end

	pnl:Dock(TOP)
	cpnl.Scroll:AddItem(pnl)
end

local function CreateAreaTriggerSelection(cpnl)
	local pnl = vgui.Create('DPanel', cpnl)
	pnl:SetTall(22)
	pnl:DockPadding(0,0,0,0)
	pnl:DockMargin(10, 10, 20, 10)
	pnl:Dock(TOP)
	pnl.Paint = function() end

	local ddown = vgui.Create('DComboBox', pnl)
	ddown:DockMargin(0, 0, 0, 0)
	ddown:Dock(FILL)
	
	local btn = vgui.Create('DButton', pnl)
	btn:DockMargin(1, 1, 1, 1)
	btn:SetTextColor(color_white)
	btn:SetWidth(20)
	btn:Dock(RIGHT)
	btn:SetText '+'
	btn.Paint = function(self, w, h)
		draw.RoundedBox(2, 0, 0, w, h, blue)
	end
	btn.DoClick = function(s, index, value, data)
		local _, data = ddown:GetSelected()
		CreateAreaDefinition(cpnl, data)
	end

	local definitions = areatrigger.GetDefintiions(true)
	for i = 1, #definitions do
		local def = definitions[i]
		ddown:AddChoice(def.Name or def.id, def, i == 1)
	end

	local scrollcontainer = vgui.Create('DPanel', cpnl)
	scrollcontainer:Dock(TOP)
	scrollcontainer:SetTall(550)
	scrollcontainer:DockMargin(10, 10, 20, 10)

	local scroll = vgui.Create('DScrollPanel', scrollcontainer)
	scroll:Dock(FILL)
	cpnl.Scroll = scroll
end

function TOOL.BuildCPanel(cpnl)
	cpnl:AddControl('Header', { Description = '#tool.sup_areatrigger.desc'})
	cpnl:AddControl('CheckBox', {Label = '#tool.sup_areatrigger.enableevents', Command = 'sup_areatrigger_enableevents', Help = true})
	cpnl:AddControl('CheckBox', {Label = '#tool.sup_areatrigger.removeuse', Command = 'sup_areatrigger_removeuse', Help = false})
	cpnl:AddControl('CheckBox', {Label = '#tool.sup_areatrigger.helperview', Command = 'sup_areatrigger_helperview', Help = true})
	local ddown = vgui.Create('DComboBox', cpnl)
	ddown:DockMargin(10, 10, 10, 10)
	ddown:Dock(TOP)
	ddown.OnSelect = function(self, index, value, data)
		selectedLookup = data
	end

	for i = 1, #classLookups do
		ddown:AddChoice(classLookups[i][1], classLookups[i][2], i == 1)
	end

	cpnl:AddControl('Textbox', {Label = '#tool.sup_areatrigger.triggername', Command = 'sup_areatrigger_triggername', Help = true})
	cpnl:NumSlider('Area Width', 'sup_areatrigger_area_w', 20, 500, 0)
	cpnl:NumSlider('Area Height', 'sup_areatrigger_area_h', 20, 500, 0)
	CreateAreaTriggerSelection(cpnl)
end

function TOOL:DrawHUD()
	local tr = LocalPlayer():GetEyeTrace()
	local w, h = self:GetClientNumber('area_w') or 20, self:GetClientNumber('area_h') or 20

	local min = Vector(-w/2, -w/2, 0)
	local max = Vector(w/2, w/2, h)

	if self:GetClientNumber('helperview') == 1 then
		for _, ent in pairs(ents.FindByClass(selectedLookup)) do
			if IsValid(ent) then
				local pos = ent:GetPos():ToScreen()
				if pos.visible then 
					draw.DrawText(ent:EntIndex(), 'default', pos.x, pos.y, color_white, TEXT_ALIGN_CENTER) 
				end
			end
		end
	end

	cam.Start3D()
		render.SetColorMaterial()
		render.DrawBox(tr.HitPos, Angle(0, LocalPlayer():GetAngles().y, 0), min, max, black, true)
	cam.End3D()
end