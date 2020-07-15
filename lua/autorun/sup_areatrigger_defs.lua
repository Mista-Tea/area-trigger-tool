areatrigger = areatrigger or {}

local definitions = {}
local definitions_mapped = {}
local playersettings = {}

if SERVER then
    util.AddNetworkString 'sup_areatrigger.SetInfo'
    util.AddNetworkString 'sup_areatrigger.RemoveInfo'
end

function areatrigger.GetPlayerSettings(pl)
    return playersettings[pl]
end

function areatrigger.SendDefinition(id, valuePnl, once)
    local def = areatrigger.GetDefintiion(id)
    if not def then 
        return 
    end

    local value = def.PanelGetValue and def:PanelGetValue(valuePnl, valuePnl:GetParent()) or valuePnl:GetValue()
    local valid = def:Validate(value, valuePnl)
    if not valid then
        return 
    end

    if valid ~= true then
        value = valid
    end

    net.Start 'sup_areatrigger.SetInfo'
        net.WriteUInt(def.internal, 8)
        if def.WriteNet then
            def:WriteNet(value)
        else
            net.WriteString(tostring(value))
        end
        net.WriteBool(once)
    net.SendToServer()
end

function areatrigger.RemoveDefitinion(id)
    local def = areatrigger.GetDefintiion(id)
    if not def then 
        return 
    end

    net.Start 'sup_areatrigger.RemoveInfo'
        net.WriteUInt(def.internal, 8)
    net.SendToServer()
end

function areatrigger.AddDefinition(id, data)
    data.id = id
    data.internal = table.insert(definitions_mapped, data)
    definitions[id] = data
end

function areatrigger.GetDefintiion(id, internal)
    return internal and definitions_mapped[id] or definitions[id]
end

function areatrigger.GetDefintiions(lst)
    return lst and definitions_mapped or definitions
end

function areatrigger.CreatePanel(parent, defid)
    local def = areatrigger.GetDefintiion(defid)
    if not def then 
        return 
    end

    local class = def.Panel or 'DPanel'
    local pnl = vgui.Create(class, parent)
    pnl:Dock(TOP)

    if def.PanelSetup then
        def:PanelSetup(pnl, parent)
    end

    return pnl
end

net.Receive('sup_areatrigger.SetInfo', function(_, pl) 
    if not pl:IsSeniorGM() then
        srp.notif.Warning(pl, 3, 'You must be SGM to use this feature.')
        return
    end

    local def = areatrigger.GetDefintiion(net.ReadUInt(8), true)
    local value = def.ReadNet and def:ReadNet(pl) or net.ReadString()
    local once = net.ReadBool()

    if def:Validate(value) then
        playersettings[pl] = playersettings[pl] or {}
        playersettings[pl][def.internal] = {
            Value = value,
            Once = once
        }
        srp.notif.Success(pl, 3, 'Added defintion')
    end    
end)

net.Receive('sup_areatrigger.RemoveInfo', function(_, pl) 
    local def = areatrigger.GetDefintiion(net.ReadUInt(8), true)
    if def and playersettings[pl] then 
        playersettings[pl][def.internal] = nil
        srp.notif.Warning(pl, 3, 'Removed defintion')
        return 
    end
end)

local props = {
    prop_physics = true, 
    prop_effect = true,
    prop_static = true,
}

local formats = {
    ['target_steamid'] = function(ent) return ent:SteamID() end,
    ['target_name'] = function(ent) return ent:GetName() end,
    ['target_location'] = function(ent) return ent:GetLocation().name end,
}

local function formatString(str, ent)
	return str:gsub('{([^{}]+)}', function(token)
		local format = formats[token]
		return format and format(ent) or token
	end)
end

areatrigger.AddDefinition('describeall', {
    Name = 'Describe All',
    Panel = 'DTextEntry',
    PanelGetValue = function(self, pnl)
        return pnl:GetValue()
    end,
    Validate = function(self, value)
        return string.len(value) > 2 and string.len(value) < 255
    end,
    Apply = function(self, trigger, ent, value)
        chat.Send('DescriptionAll', trigger:GetGMOwner(), value)
    end
})

areatrigger.AddDefinition('describe', {
    Name = 'Describe',
    Panel = 'DTextEntry',
    PanelGetValue = function(self, pnl)
        return pnl:GetValue()
    end,
    Validate = function(self, value)
        return string.len(value) > 2 and string.len(value) < 255
    end,
    Apply = function(self, trigger, ent, value)
        chat.Send('DescriptionFromEntity', trigger, value)
    end
})

areatrigger.AddDefinition('resetstats', {
    Name = 'Reset All Stats',
    Panel = 'DCheckBox',
    PanelSetup = function(self, pnl)
        pnl:GetParent():SetTall(40)
        pnl:SetVisible(false)
    end,
    PanelGetValue = function(self, pnl)
        return 'true'
    end,
    Validate = function(self, value)
        return value == 'true'
    end,
    Apply = function(self, trigger, ent, value)
        ent.gmstats = {}
        srp.talents.SyncAll(ent)
	    ent:SetGravity(1)
    end
})

areatrigger.AddDefinition('resetstat', {
    Name = 'Reset Stat',
    Panel = 'DComboBox',
    PanelSetup = function(self, pnl)
        pnl:SetValue('Select Stat')

        local first = true
        for id, data in pairs(srp.talents.GetTalents()) do           
            pnl:AddChoice(data.name, id, first) 
            first = false
        end
    end,
    PanelGetValue = function(self, pnl)
        local _, data = pnl:GetSelected()
        return data
    end,
    Validate = function(self, value)
        return true
    end,
    Apply = function(self, trigger, ent, value)
        if ent.gmstats then
            ent.gmstats[value] = nil
            ent:ApplyTalent(value)
        end
    end
})

areatrigger.AddDefinition('tempfreeze', {
    Name = 'Temp Freeze',
    Min = 1,
    Max = 10,
    Panel = 'DNumSlider',
    PanelSetup = function(self, pnl)
        pnl:SetText 'Duration'
        pnl:SetMinMax(self.Min, self.Max)
        pnl:SetDecimals(0)
    end,
    WriteNet = function(self, value)
        net.WriteUInt(value, 4)
    end,
    ReadNet = function(self)
        return net.ReadUInt(4)
    end,
    Validate = function(self, value)
        return value >= self.Min and value <= self.Max
    end,
    Apply = function(self, trigger, ent, value)
        if not ent:Alive() then 
            return 
        end

        ent.areatrigger_freeze = true
        ent:Lock()

        timer.Create('areatrigger_freeze.' .. ent:SteamID(), value, 1, function() 
            if ent.areatrigger_freeze and IsValid(ent) then
                ent:UnLock() 
            end
        end)
    end
})

areatrigger.AddDefinition('delayeddeath', {
    Name = 'Delayed Death',
    Min = 1,
    Max = 10,
    Panel = 'DNumSlider',
    PanelSetup = function(self, pnl)
        pnl:SetText 'Delay'
        pnl:SetMinMax(self.Min, self.Max)
        pnl:SetDecimals(0)
    end,
    WriteNet = function(self, value)
        net.WriteUInt(value, 4)
    end,
    ReadNet = function(self)
        return net.ReadUInt(4)
    end,
    Validate = function(self, value)
        return value >= self.Min and value <= self.Max
    end,
    Apply = function(self, trigger, ent, value)
        if not ent:Alive() then 
            return 
        end

        ent.areatrigger_death = true

        timer.Create('areatrigger_delayeddeath.' .. ent:SteamID(), value, 1, function() 
            if ent.areatrigger_death and IsValid(ent) and ent:Alive() then
                ent:Kill() 
            end
        end)
    end
})

areatrigger.AddDefinition('runconcommand', {
    Name = 'Console Command',
    Panel = 'DTextEntry',
    PanelSetup = function(self, pnl)
        pnl:SetPlaceholderText 'say {target_name} ({target_steamid}) is in my trigger'
        pnl:SetText 'say {target_name} ({target_steamid}) is in my trigger'
    end,
    Validate = function(self, value)
        return value:len() > 3
    end,
    Apply = function(self, trigger, pl, value)
        local findFirstCmd = value:Explode(';')[1]
        value = (findFirstCmd and findFirstCmd ~= ';') and findFirstCmd or value
        if IsValid(trigger:GetGMOwner()) then
            trigger:GetGMOwner():ConCommand(formatString(value, pl))
        end
    end
})

hook.Add('PlayerDeath', 'areatrigger', function(pl) 
    if pl.areatrigger_freeze then
        pl.areatrigger_freeze = false
        pl:UnLock()
    end

    pl.areatrigger_death = false

    local sid = pl:SteamID()
    timer.Remove('areatrigger_freeze.'..sid)
    timer.Remove('areatrigger_death.'..sid)
end)

areatrigger.AddDefinition('uncloakplayer', {
    Name = 'Uncloak Player',
    Panel = 'DCheckBox',
    PanelSetup = function(self, pnl)
        pnl:GetParent():SetTall(40)
        pnl:SetVisible(false)
    end,
    PanelGetValue = function(self, pnl)
        return 'true'
    end,
    Validate = function(self, value)
        return value == 'true'
    end,
    Apply = function(self, trigger, ent, value)
        if ent:IsCloaked() then
            ent:SetCloaked(false)
        end
    end
})

areatrigger.AddDefinition('stripweapons', {
    Name = 'Strip Weapons',
    Panel = 'DCheckBox',
    PanelSetup = function(self, pnl)
        pnl:GetParent():SetTall(40)
        pnl:SetVisible(false)
    end,
    PanelGetValue = function(self, pnl)
        return 'true'
    end,
    Validate = function(self, value)
        return value == 'true'
    end,
    Apply = function(self, trigger, ent, value)
        ent:StripWeapons()
        ent:Give 'weapon_holster'

        if ent:IsGameMaster() then
            ent:Give 'gmod_tool'
            ent:Give 'weapon_physgun'
        end
    end
})

areatrigger.AddDefinition('addvelocity', {
    Name = 'Add Velocity',
    Panel = 'DComboBox',
    Min = 1,
    Max = 1000,
    Constant = true,
    Direction = {
        {'Up', function(ent) return ent:GetUp() end},
        {'Down', function(ent) return -ent:GetUp() end},
        {'Left', function(ent) return -ent:GetRight() end},
        {'Right', function(ent) return -ent:GetRight() end},
        {'Forward', function(ent) return ent:GetForward() end},
        {'Backward', function(ent) return -ent:GetForward() end},
    },
    PanelSetup = function(self, pnl, parentPnl)
        parentPnl:SetTall(170)
        pnl:SetValue 'Direction'

        for i = 1, #self.Direction do
            pnl:AddChoice(self.Direction[i][1], i, i == 1) 
        end

        local check = vgui.Create('DCheckBoxLabel', parentPnl)
        check:SetText 'From Local'
        check:SetChecked(true)
        check:Dock(TOP)
        check:SetTextColor(color_black)
        check:DockMargin(5, 0, 5, 0)
        parentPnl.checkbox = check

        local check = vgui.Create('DCheckBoxLabel', parentPnl)
        check:SetText 'Aim to Direction'
        check:SetChecked(false)
        check:Dock(TOP)
        check:SetTextColor(color_black)
        check:DockMargin(5, 0, 5, 0)
        parentPnl.direction = check

        local power = vgui.Create('DNumSlider', parentPnl)
        power:Dock(TOP)
        power:SetText 'Power'
        power:SetMinMax(self.Min, self.Max)
        power:SetDecimals(0)
        power:DockMargin(5, 0, 5, 0)
        power.Label:SetTextColor(color_black)
        parentPnl.power = power
    end,
    PanelGetValue = function(self, pnl, parentPnl)
        local _, id = pnl:GetSelected()
        local fromLocal = parentPnl.checkbox:GetChecked()
        local forceDirection = parentPnl.direction:GetChecked()
        local power = math.Clamp(parentPnl.power:GetValue(), self.Min, self.Max)
        return {
            dirid = id,
            forceDirection = forceDirection,
            power = power,
            fromLocal = true,
        }
    end,
    WriteNet = function(self, value)
        net.WriteBool(value.fromLocal)
        net.WriteBool(value.forceDirection)
        net.WriteUInt(value.dirid, 4)
        net.WriteUInt(value.power, 10)
    end,
    ReadNet = function(self)
        return {
            fromLocal = net.ReadBool(),
            forceDirection = net.ReadBool(),
            dirid = net.ReadUInt(4),
            power = net.ReadUInt(10)
        }
    end,
    Validate = function(self, value)
        if not istable(value) then 
            return false 
        end

        if not isbool(value.fromLocal) then 
            return false 
        end

        if value.power < self.Min or value.power > self.Max then 
            return false 
        end

        if not self.Direction[value.dirid] then 
            return false 
        end
        return true
    end,
    Apply = function(self, trigger, ent, value)
        local funcDir = (self.Direction[value.dirid] and self.Direction[value.dirid][2]) or self.Direction[1][2]

        dir = funcDir(self.fromLocal and ent or trigger)

        ent:SetAbsVelocity(Vector(0,0,0))
        timer.Simple(0, function() 
            ent:SetVelocity(dir * value.power)
        end)

        if value.forceDirection then
            ent:SetEyeAngles(dir:Angle())
        end

        return 0.1
    end
})

areatrigger.AddDefinition('removeentity', {
    Name = 'Remove Entity',
    Panel = 'DComboBox',
    PanelSetup = function(self, pnl)
        pnl:SetValue('Entity')

        local tbl = ents.GetAll()
        local selected = {}

        for i = 1, #tbl do
            local ent = tbl[i]
            if IsValid(ent) and not ent:IsPlayer() and props[ent:GetClass()] then              
                table.insert(selected, ent)
            end
        end

        local pos = LocalPlayer():GetPos()
        table.sort(selected, function(a, b) 
            return a:GetPos():Distance(pos) < b:GetPos():Distance(pos)
        end)

        for i = 1, #selected do
            local ent = selected[i]
            local tbl = string.Explode('/', (ent:GetModel() or '/error.mdl'):Replace('.mdl', ''), false)
            local mdl = tbl[#tbl]
            if mdl then
                pnl:AddChoice(mdl.. ' Index #' .. ent:EntIndex() , ent, i == 1) 
            end
        end
    end,
    PanelGetValue = function(self, pnl)
        local _, data = pnl:GetSelected()
        return data
    end,
    WriteNet = function(self, value)
        net.WriteEntity(value)
    end,
    ReadNet = function(self)
        return net.ReadEntity()
    end,
    Validate = function(self, value)
        return IsValid(value) and not value:IsPlayer() and props[value:GetClass()]
    end,
    Apply = function(self, trigger, ent, value)
        if IsValid(value) then
            value:PrecacheGibs()
            value:GibBreakClient(Vector(0,0,1))
            SafeRemoveEntity(value)
        end
    end
})

areatrigger.AddDefinition('playeranim', {
    Name = 'Player Animation',
    Panel = 'DComboBox',
    IgnoreAnims = {
        'aimlayer',
        'aim_',
        'aimmatrix',
        'crouchaim',
        'reload',
        'reference',
        '_aim_',
        'c_crouch',
        'blend_',
        '_blend',
        'crouchidle',
        'proneidle',
        'drawprone',
        'drawcrouch',
        'drawidle',
        'attack_deploy',
        'attack_prone',
        'attack_crouch',
        'attack_swim',
        'attackprone',
        'attackcrouch',
        'attackdeploy',
        'attackswim',
        'head_',
        '_rot_',
        '_mod',
        'mode_',
        'rot_',
        'flinch',
        'finger_',
        'draw_',
        'dive_',
        'draw_',
        'drawswim',
        'flinch',
        'walkdivel',
        'fingerr',
        'duckjump',
        'cwalk_',
        'layer',
        'original',
        'meleeswim',
        'meleeprone',
        'r_',
        'holsterprone',
        'holsterswim',
        'holstercrouch',
        'proneup',
        'pronewalk',
        'swim',
        'roll_',
        'range_',
        'pronedown',
        'w_walk',
        's_sprint',
        'prone_',
        'meleecrouch',
        'wos_l4d',
        'wos_chiv',
        'aoc_',
        'wos_fn_',
        'ragdoll'
    },
    PanelSetup = function(self, pnl)
        pnl:SetValue('Select Animation')
        local tbl = LocalPlayer():GetSequenceList()
        
        local first = true
        for i = 1, #tbl do
            local valid = true
            local seqid = tbl[i]:lower()

            for j = 1, #self.IgnoreAnims do
                if string.find(seqid, self.IgnoreAnims[j]) then
                    valid = false
                    break
                end
            end

            if valid then
                pnl:AddChoice(seqid, tbl[i], first)
                first = false
            end
        end
    end,
    PanelGetValue = function(self, pnl)
        local _, data = pnl:GetSelected()
        return data
    end,
    Validate = function(self, value)
        local val = value:lower()
        for i = 1, #self.IgnoreAnims do
            if string.find(val, self.IgnoreAnims[i]) then
                return false
            end
        end
        return true
    end,
    Apply = function(self, trigger, ent, value)
        local id = ent:LookupSequence(value)
        if id and id > 0 then
            ent:PlayAnimation(value)
        end
    end
})

areatrigger.AddDefinition('playsound', {
    Name = 'Play Sound',
    ValidPaths = {
        '^sound/[A-z0-9/_]+%.mp3$',
        '^sound/[A-z0-9/_]+%.wav$',
        '^sound/[A-z0-9/_]+%.ogg$',
    },
    Panel = 'DTextEntry',
    PanelSetup = function(self, pnl)
        pnl:SetText 'sound/music/hl1_song14.mp3'
    end,
    Validate = function(self, value)
        local val = string.Trim(value):Replace('\\', '/'):Replace('..', '')

        for i = 1, #self.ValidPaths do
            if string.match(val, self.ValidPaths[i]) ~= nil then
                return val
            end
        end

        return false
    end,
    Apply = function(self, trigger, ent, value)
        ent:EmitSound(value:Replace('sound/'))
    end
})

areatrigger.AddDefinition('setmodel', {
    Name = 'Set Model',
    ValidPath = '^models/[A-z0-9/_]+%.mdl$',
    Panel = 'DTextEntry',
    PanelSetup = function(self, pnl)
        pnl:SetText 'models/player/zombie_soldier.mdl'
    end,
    Validate = function(self, value)
        local val = string.Trim(value):Replace('\\', '/'):Replace('..', '')
        if string.match(val, self.ValidPath) ~= nil then
            return val
        end

        return false
    end,
    Apply = function(self, trigger, ent, value)
        ent:SetModel(value)
    end
})

areatrigger.AddDefinition('setrunspeed', {
    Name = 'Set Runspeed',
    Min = 1,
    Max = 500,
    Panel = 'DNumSlider',
    PanelSetup = function(self, pnl)
        pnl:SetText 'Speed'
        pnl:SetMinMax(self.Min, self.Max)
        pnl:SetDecimals(0)
    end,
    WriteNet = function(self, value)
        net.WriteUInt(value, 8)
    end,
    ReadNet = function(self)
        return net.ReadUInt(8)
    end,
    Validate = function(self, value)
        return value >= self.Min and value <= self.Max
    end,
    Apply = function(self, trigger, ent, value)
        ent:SetRunSpeed(value)
    end
})

areatrigger.AddDefinition('setjumpheight', {
    Name = 'Jump Power',
    Min = 1,
    Max = 4000,
    Panel = 'DNumSlider',
    PanelSetup = function(self, pnl)
        pnl:SetText 'Power'
        pnl:SetMinMax(self.Min, self.Max)
        pnl:SetDecimals(0)
    end,
    WriteNet = function(self, value)
        net.WriteUInt(value, 12)
    end,
    ReadNet = function(self)
        return net.ReadUInt(12)
    end,
    Validate = function(self, value)
        return value >= self.Min and value <= self.Max
    end,
    Apply = function(self, trigger, ent, value)
        ent:SetJumpPower(value)
    end
})

areatrigger.AddDefinition('sethealth', {
    Name = 'Set Health',
    Min = 0,
    Max = 1000, 
    Panel = 'DNumSlider',
    PanelSetup = function(self, pnl)
        pnl:SetText 'Set Health'
        pnl:SetMinMax(self.Min, self.Max)
        pnl:SetDecimals(0)
    end,
    WriteNet = function(self, value)
        net.WriteUInt(value, 10)
    end,
    ReadNet = function(self)
        return net.ReadUInt(10)
    end,
    Validate = function(self, value)
        return value >= self.Min and value <= self.Max
    end,
    Apply = function(self, trigger, ent, value)
        if value == 0 then
            ent:Kill()
        else
            ent:SetHealth(value)
        end
    end
})

areatrigger.AddDefinition('adjhealth', {
    Name = 'Adjust Health',
    Min = -500,
    Max = 500,
    Panel = 'DNumSlider',
    PanelSetup = function(self, pnl)
        pnl:SetText 'Set Health'
        pnl:SetMinMax(self.Min, self.Max)
        pnl:SetDecimals(0)
    end,
    WriteNet = function(self, value)
        net.WriteInt(value, 10)
    end,
    ReadNet = function(self)
        return net.ReadInt(10)
    end,
    Validate = function(self, value)
        return value >= self.Min and value <= self.Max
    end,
    Apply = function(self, trigger, ent, value)
        local hp = math.Max(ent:Health() + value, 0)
        ent:SetHealth(hp)
        if hp == 0 then
            ent:Kill()
        end
    end
})

areatrigger.AddDefinition('setarmour', {
    Name = 'Set Armour',
    Min = 0,
    Max = 255, 
    Panel = 'DNumSlider',
    PanelSetup = function(self, pnl)
        pnl:SetText 'Set Armour'
        pnl:SetMinMax(self.Min, self.Max)
        pnl:SetDecimals(0)
    end,
    WriteNet = function(self, value)
        net.WriteUInt(value, 8)
    end,
    ReadNet = function(self)
        return net.ReadUInt(8)
    end,
    Validate = function(self, value)
        return value >= self.Min and value <= self.Max
    end,
    Apply = function(self, trigger, ent, value)
        ent:SetArmor(value)
    end
})

areatrigger.AddDefinition('adjarmour', {
    Name = 'Adjust Armour',
    Min = -500,
    Max = 500,
    Panel = 'DNumSlider',
    PanelSetup = function(self, pnl)
        pnl:SetText 'Set Armour'
        pnl:SetMinMax(self.Min, self.Max)
        pnl:SetDecimals(0)
    end,
    WriteNet = function(self, value)
        net.WriteInt(value, 10)
    end,
    ReadNet = function(self)
        return net.ReadInt(10)
    end,
    Validate = function(self, value)
        return value >= self.Min and value <= self.Max
    end,
    Apply = function(self, trigger, ent, value)
        ent:SetArmor(math.Clamp(ent:Armor() + value, 0, 500))
    end
})

areatrigger.AddDefinition('giveweapon', {
    Name = 'Give Weapon',
    Panel = 'DComboBox',
    PanelSetup = function(self, pnl)
        pnl:SetValue('Add Weapon')
        local weps = list.Get('NPCUsableWeapons')
        for i = 1, #weps do
            local wep = weps[i]
            pnl:AddChoice(wep.title, wep, i == 1)
        end
    end,
    PanelGetValue = function(self, pnl)
        local _, data = pnl:GetSelected()
        return data and data.class or 'none'
    end,
    Validate = function(self, value)
        if value == 'none' or value == '' then
            return true 
        end

        local weps = list.Get('NPCUsableWeapons')
        for i = 1, #weps do
            if weps[i].class == value then
                return true
            end
        end
    end,
    Apply = function(self, trigger, ent, value)
        ent:SetHealth(ent:Health() - value)
    end
})

areatrigger.AddDefinition('igniteplayer', {
    Name = 'Ignite Player',
    Min = 1,
    Max = 60,
    Panel = 'DNumSlider',
    PanelSetup = function(self, pnl)
        pnl:SetText 'Duration'
        pnl:SetMinMax(self.Min, self.Max)
        pnl:SetDecimals(0)
    end,
    WriteNet = function(self, value)
        net.WriteUInt(value, 8)
    end,
    ReadNet = function(self)
        return net.ReadUInt(8)
    end,
    Validate = function(self, value)
        return value >= self.Min and value <= self.Max
    end,
    Apply = function(self, trigger, ent, value)
        ent:Ignite(value)
    end
})

areatrigger.AddDefinition('igniteaoe', {
    Name = 'Ignite AOE',
    Min = 10,
    Max = 400,
    Panel = 'DNumSlider',
    PanelSetup = function(self, pnl)
        pnl:SetText 'Range from Trigger'
        pnl:SetMinMax(self.Min, self.Max)
        pnl:SetDecimals(0)
    end,
    WriteNet = function(self, value)
        net.WriteUInt(value, 8)
    end,
    ReadNet = function(self)
        return net.ReadUInt(8)
    end,
    Validate = function(self, value)
        return value >= self.Min and value <= self.Max
    end,
    Apply = function(self, trigger, ent, value)
        local rang = value
        local pos = ent:GetPos()
        local playes = player.GetAll()

        for i = 1, #players do
            local pl = players[i]
            if IsValid(pl) and pl:GetPos():Distance(pos) <= value then
                ent:Ignite(30)
            end
        end
    end
})

local doors = {
    func_door = true,
}

areatrigger.AddDefinition('unlockdoor', {
    Name = 'Door - Unlock',
    Panel = 'DComboBox',
    PanelSetup = function(self, pnl)
        pnl:SetValue('Select Door')
        local tbl = ents.GetAll()
        local first = true
        for i = 1, #tbl do
            local ent = tbl[i]
            if IsValid(ent) and doors[ent:GetClass()] then
                pnl:AddChoice(ent:GetClass() .. ' Index #' .. ent:EntIndex() , ent, first)
                first = false
            end
        end
    end, 
    PanelGetValue = function(self, pnl)
        local _, data = pnl:GetSelected()
        return data
    end,
    WriteNet = function(self, value)
        net.WriteEntity(value)
    end,
    ReadNet = function(self)
        return net.ReadEntity()
    end,
    Validate = function(self, value)
        return IsValid(value) and doors[value:GetClass()]
    end,
    Apply = function(self, trigger, ent, value)
        if IsValid(value) then
            value:Fire('unlock')
        end
    end
})

areatrigger.AddDefinition('opendoor', {
    Name = 'Door - Open',
    Panel = 'DComboBox',
    PanelSetup = function(self, pnl)
        pnl:SetValue('Select Door')
        local tbl = ents.GetAll()
        local first = true
        for i = 1, #tbl do
            local ent = tbl[i]
            if IsValid(ent) and doors[ent:GetClass()] then
                pnl:AddChoice(ent:GetClass() .. ' Index #' .. ent:EntIndex() , ent, first)
                first = false
            end
        end
    end, 
    PanelGetValue = function(self, pnl)
        local _, data = pnl:GetSelected()
        return data
    end,
    WriteNet = function(self, value)
        net.WriteEntity(value)
    end,
    ReadNet = function(self)
        return net.ReadEntity()
    end,
    Validate = function(self, value)
        return IsValid(value) and doors[value:GetClass()]
    end,
    Apply = function(self, trigger, ent, value)
        if IsValid(value) then
            value:Fire('unlock', 1)
            value:Fire('open', '', 1)
        end
    end
})

areatrigger.AddDefinition('doortoggle', {
    Name = 'Door - Toggle',
    Panel = 'DComboBox',
    PanelSetup = function(self, pnl)
        pnl:SetValue('Select Door')
        local tbl = ents.GetAll()
        local first = true
        for i = 1, #tbl do
            local ent = tbl[i]
            if IsValid(ent) and doors[ent:GetClass()] then
                pnl:AddChoice(ent:GetClass() .. ' Index #' .. ent:EntIndex() , ent, first)
                first = false
            end
        end
    end, 
    PanelGetValue = function(self, pnl)
        local _, data = pnl:GetSelected()
        return data
    end,
    WriteNet = function(self, value)
        net.WriteEntity(value)
    end,
    ReadNet = function(self)
        return net.ReadEntity()
    end,
    Validate = function(self, value)
        return IsValid(value) and doors[value:GetClass()]
    end,
    Apply = function(self, trigger, ent, value)
        if IsValid(value) then
            value:Fire('unlock', 1)
            value:Fire('toggle', '', 1)
        end
    end
})

areatrigger.AddDefinition('closedoor', {
    Name = 'Door - Close',
    Panel = 'DComboBox',
    PanelSetup = function(self, pnl)
        pnl:SetValue('Select Door')
        local tbl = ents.GetAll()
        local first = true
        for i = 1, #tbl do
            local ent = tbl[i]
            if IsValid(ent) and doors[ent:GetClass()] then
                pnl:AddChoice(ent:GetClass() .. ' Index #' .. ent:EntIndex() , ent, first)
                first = false
            end
        end
    end,
    PanelGetValue = function(self, pnl)
        local _, data = pnl:GetSelected()
        return data
    end,
    WriteNet = function(self, value)
        net.WriteEntity(value)
    end,
    ReadNet = function(self)
        return net.ReadEntity()
    end,
    Validate = function(self, value)
        return IsValid(value) and doors[value:GetClass()]
    end,
    Apply = function(self, trigger, ent, value)
        if IsValid(value) then
            value:Fire('unlock', 1)
            value:Fire('close', '', 1)
        end
    end
})

areatrigger.AddDefinition('lockdoor', {
    Name = 'Door - Lock',
    Panel = 'DComboBox',
    PanelSetup = function(self, pnl)
        pnl:SetValue('Select Door')
        local tbl = ents.GetAll()
        local first = true
        for i = 1, #tbl do
            local ent = tbl[i]
            if IsValid(ent) and doors[ent:GetClass()] then
                pnl:AddChoice(ent:GetClass() .. ' Index #' .. ent:EntIndex() , ent, first)
                first = false
            end
        end
    end, 
    PanelGetValue = function(self, pnl)
        local _, data = pnl:GetSelected()
        return data
    end,
    WriteNet = function(self, value)
        net.WriteEntity(value)
    end,
    ReadNet = function(self)
        return net.ReadEntity()
    end,
    Validate = function(self, value)
        return IsValid(value) and doors[value:GetClass()]
    end,
    Apply = function(self, trigger, ent, value)
        if IsValid(value) then
            value:Fire('lock')
        end
    end
})