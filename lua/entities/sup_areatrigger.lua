AddCSLuaFile()

ENT.Type = 'ai'
ENT.Base = 'base_anim'

ENT.PrintName   = 'SUP Area Trigger'
ENT.Author      = 'Scott (STEAM_0:1:26675200)'
ENT.Information = ''
ENT.Editable    = false
ENT.Spawnable   = false
ENT.AdminOnly   = false
ENT.RenderGroup = RENDERGROUP_BOTH

function ENT:SetupDataTables()
	self:NetworkVar('Vector', 0, 'Min')
    self:NetworkVar('Vector', 1, 'Max')
    self:NetworkVar('String', 1, 'DisplayName')
    self:NetworkVar('Entity', 0, 'GMOwner')

    if SERVER then
        self:SetMin(Vector(-40, -40, 0))
        self:SetMax(Vector(40, 40, 80))
    end
end

function ENT:Initialize()
    if SERVER then
        self.cooldowns = {}
        self.globalcooldowns = {}

        self:SetModel 'models/hunter/blocks/cube2x2x2.mdl'
        self:SetTrigger(true)
        self:DrawShadow(false)
        self:SetMoveType(MOVETYPE_NONE)
        self:SetCollisionGroup(COLLISION_GROUP_DEBRIS)
        self:SetSolid(SOLID_BBOX)
    end
end

function ENT:UpdateTransmitState()
	return TRANSMIT_ALWAYS
end

function ENT:SetRemoveOnUse(b)
    self.RemoveOnUse = b
end

function ENT:SetEventCharacters(b)
    self.EventCharactersOnly = b
end

function ENT:GetEventCharactersOnly()
    return self.EventCharactersOnly
end

function ENT:SetArea(min, max)
    self:SetMin(min)
    self:SetMax(max)
    self:SetCollisionBounds(min, max)
end

function ENT:StartTouch(pl)
    if  not IsValid(pl) or 
        not pl:IsPlayer() or pl:GetMoveType() ~= MOVETYPE_WALK then
        return
    end

    if self:GetEventCharactersOnly() and not pl:GetAllegiance():IsEvent() then
        return
    end

    self:RunTriggers(pl)
end

function ENT:Touch(pl)
    if  not IsValid(pl) or 
        not pl:IsPlayer() or pl:GetMoveType() ~= MOVETYPE_WALK then
        return
    end

    if self.RemoveOnUse then
        return
    end

    if self:GetEventCharactersOnly() and not pl:GetAllegiance():IsEvent() then
        return
    end

    self:RunTriggersInside(pl)
end

function ENT:RunTrigger(pl, id, data)
    local def = areatrigger.GetDefintiion(id, true)
    if not def then 
        return 
    end

    local curTime = CurTime()
    local hasCooldown = false

    if  (self.globalcooldowns[def.id] and self.globalcooldowns[def.id] > curTime) or 
        (self.cooldowns[pl][id] and self.cooldowns[pl][id] > curTime) then
        return
    end

    local once = data.Once or def.Once
    if once and self.cooldowns[pl][id] then
        return
    end

    local cd = def:Apply(self, pl, data.Value) or def.Cooldown
    if cd or once then
        self.cooldowns[pl][id] = once and (curTime + 999999) or (curTime + cd)
    end

    if def.GlobalCooldown then
        self.globalcooldowns[def.id] = curTime + def.GlobalCooldown
    end
end

function ENT:RunTriggers(pl)
    if not self.definitions then 
        return 
    end

    self.cooldowns[pl] = self.cooldowns[pl] or {}

    for id, data in pairs(self.definitions) do
        if not data.Constant then
            self:RunTrigger(pl, id, data)
        end
    end

    if self.RemoveOnUse then
        self:Remove()
    end
end


function ENT:RunTriggersInside(pl)
    if not self.definitions then 
        return 
    end

    self.cooldowns[pl] = self.cooldowns[pl] or {}

    for id, data in pairs(self.definitions) do
        if data.Constant then
            self:RunTrigger(pl, id, data)
        end
    end
end

function ENT:PopulateDefinitions()
    local pl = self:GetGMOwner()
    if IsValid(pl) then
        self.definitions = table.Copy(areatrigger.GetPlayerSettings(pl))
    end    
end

local black = Color(0, 0, 0, 200)
local offset = Vector(0, 0, 2)

function ENT:Draw()
    if LocalPlayer() ~= self:GetGMOwner() then
        return
    end
    
    local wep = LocalPlayer():GetActiveWeapon()
    if (not IsValid(wep) or wep:GetClass() ~= 'gmod_tool') then
        return
    end

    local min, max = self:GetMin(), self:GetMax()
    if not min or not max then 
        return 
    end

	render.SetColorMaterial()
	render.DrawBox(self:GetPos(), self:GetAngles(), min, max, black, true)

    local name = self:GetDisplayName() or ''
    cam.Start3D2D(self:GetPos() + offset, self:GetAngles(), 0.25)
        draw.DrawText(name, 'ui_header.xl', 0, 0, color_white, TEXT_ALIGN_CENTER)
    cam.End3D2D()
end