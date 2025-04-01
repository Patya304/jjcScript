local http = game:GetService("HttpService")
local req = (syn and syn.request) or (http_request or request or http.request)
local player = game.Players.LocalPlayer

-- ====== CONFIGURATION SECTION ======
local CONFIG = {
    WEBHOOKS = {
        STARTUP = "https://discord.com/api/webhooks/1346500502757572678/NMS__yzvsi58tJOzwkjRxbrfNJa1h7pFjUNN3_xrZWU9_3P3-GVXx_SY3T_mT4HwRW3W",
        KILLS = "https://discord.com/api/webhooks/1346500505719017472/s-h3UZKUhIHh5jJNRleGgRGcDpQ1OJ67CBcfvrvRfj3-HnebEnCKaGaMCMZRzDk6mbR6"
    },
    
    BOSS_LIST = {"Sukuna", "Meguna", "UltSukuna", "Choso", "Kashimo", "TheStrongest"},
    
    TELEPORT_LOCATIONS = {
        ["Miyashi Park"] = CFrame.new(-819, 76, 509),
        ["Spin Location"] = CFrame.new(-620, 76, 472),
        ["Shop"] = CFrame.new(1415, 210, 174),
        ["Rank Up"] = CFrame.new(1207, 149, 678),
        ["Black Flash"] = CFrame.new(1205, 154, 903),
        ["Toju"] = CFrame.new(-741, 77, 722),
        ["The King"] = CFrame.new(17613, 84, -36)
    },
    
    DEFAULT_GRAVITY = 162.2,
    BOSS_FARM_OFFSET = Vector3.new(0, 0, 7),
    RESPAWN_CHECK_INTERVAL = 3 -- Seconds between respawn checks
}

-- ====== UTILITY FUNCTIONS ======
local function SendDiscordWebhook(webhookUrl, embedData)
    local data = {
        embeds = {embedData}
    }
    
    pcall(function()
        req({
            Url = webhookUrl,
            Method = "POST",
            Headers = {["Content-Type"] = "application/json"},
            Body = http:JSONEncode(data)
        })
    end)
end

local function SetupCharacter(character)
    for _, part in pairs(character:GetDescendants()) do
        if part:IsA("BasePart") then
            part.CanCollide = false
        end
    end
end

local function ExecuteAttack(target, behindPlayer)
    local character = player.Character or player.CharacterAdded:Wait()
    
    -- Swing attack
    game:GetService("Players").LocalPlayer.Character.Main_Client.Main_Server.Swing:FireServer()
    
    -- Combat event
    local args = {
        [1] = {
            ["Character"] = character,
            ["Action"] = "M1",
            ["Combo"] = 1,
            ["Target"] = target,
            ["BehindPlayer"] = behindPlayer
        }
    }
    game:GetService("ReplicatedStorage").Events.CombatEvent:FireServer(unpack(args))
end

-- ====== NOTIFICATION SYSTEM ======
local function SendStartNotification()
    SendDiscordWebhook(CONFIG.WEBHOOKS.STARTUP, {
        title = "✅ Script Activated",
        description = "`" .. player.Name .. "` has started the script.",
        color = 0x00FF00,
        fields = {
            {name = "Player Profile", value = "[Click Here](https://www.roblox.com/users/"..player.UserId.."/profile)", inline = true},
            {name = "Time", value = os.date("`%Y.%m.%d` **|** `%H:%M`"), inline = true}
        },
        footer = {text = "JJC Boss Tracker"}
    })
end

-- ====== BOSS TRACKER SYSTEM ======
local BossTracker = {
    ReportedKills = {},
    Cooldown = 5 -- Seconds between reports
}

function BossTracker:LogKill(bossName)
    local now = os.time()
    if self.ReportedKills[bossName] and (now - self.ReportedKills[bossName]) < self.Cooldown then
        return
    end

    SendDiscordWebhook(CONFIG.WEBHOOKS.KILLS, {
        title = "👑 "..bossName.." ELIMINATED",
        description = "`"..player.Name.."` defeated the boss!",
        color = 0xFF3030,
        fields = {
            {name = "Player Profile", value = "[Click Here](https://www.roblox.com/users/"..player.UserId.."/profile)", inline = true},
            {name = "Time", value = os.date("`%Y.%m.%d` **|** `%H:%M`"), inline = true}
        },
        footer = {text = "JJC Boss Logger"}
    })

    self.ReportedKills[bossName] = now
end

local function MonitorBossDeaths()
    while task.wait(1) do
        for _, bossName in ipairs(CONFIG.BOSS_LIST) do
            local boss = workspace:FindFirstChild(bossName)
            if boss and boss:FindFirstChild("Humanoid") and boss.Humanoid.Health <= 0 then
                BossTracker:LogKill(bossName)
                task.wait(0.5) -- Small delay between checks
            end
        end
    end
end

-- ====== IMPROVED AUTO FARM FUNCTIONS ======
local function CreateAutoFarmToggle(tab, name, targetName, isBoss)
    local toggle = false
    local lastValidTarget = nil
    
    tab:AddToggle({
        Name = name,
        Default = false,
        Callback = function(value)
            toggle = value
            if toggle then
                workspace.Gravity = 0
                
                -- Main farming loop
                while toggle do
                    task.wait(0.1)
                    if not toggle then break end

                    -- Wait for character to respawn if dead
                    if not player.Character or not player.Character:FindFirstChild("Humanoid") or player.Character.Humanoid.Health <= 0 then
                        repeat
                            task.wait(1)
                        until player.Character and player.Character:FindFirstChild("Humanoid") and player.Character.Humanoid.Health > 0
                        
                        -- Reset collision after respawn
                        SetupCharacter(player.Character)
                    end

                    local character = player.Character
                    if not character or not character:FindFirstChild("HumanoidRootPart") then
                        task.wait(1)
                        continue
                    end

                    SetupCharacter(character)
                    
                    -- Target finding with respawn detection
                    local target = nil
                    
                    -- Check if last target is still valid
                    if lastValidTarget and lastValidTarget.Parent and lastValidTarget:FindFirstChild("Humanoid") and lastValidTarget.Humanoid.Health > 0 then
                        target = lastValidTarget
                    else
                        -- Find new target
                        target = workspace:FindFirstChild(targetName)
                        lastValidTarget = target
                        
                        -- If no target found, wait for respawn check interval
                        if not target then
                            task.wait(CONFIG.RESPAWN_CHECK_INTERVAL)
                            continue
                        end
                    end
                    
                    -- Skip if target is dead
                    if target:FindFirstChild("Humanoid") and target.Humanoid.Health <= 0 then
                        lastValidTarget = nil
                        task.wait(1)
                        continue
                    end
                    
                    -- Teleport and attack
                    local targetRoot = target:FindFirstChild("HumanoidRootPart")
                    local charRoot = character:FindFirstChild("HumanoidRootPart")
                    
                    if targetRoot and charRoot then
                        charRoot.CFrame = targetRoot.CFrame * CFrame.new(CONFIG.BOSS_FARM_OFFSET)
                        ExecuteAttack(target, true)
                    end
                end
                
                workspace.Gravity = CONFIG.DEFAULT_GRAVITY
                lastValidTarget = nil
            end
        end
    })
end

local function CreateSkillToggle(tab, name, keyCode)
    local toggle = false
    tab:AddToggle({
        Name = name,
        Default = false,
        Callback = function(value)
            toggle = value
            if toggle then
                while toggle do
                    if not toggle then return end
                    task.wait(1)
                    game:GetService("VirtualInputManager"):SendKeyEvent(true, keyCode, false, game)
                end
            end
        end
    })
end

-- ====== UI INITIALIZATION ======
local OrionLib = loadstring(game:HttpGet("https://raw.githubusercontent.com/Xtentacion178/Dbbdbr/main/Rbsbbs"))()

-- Initial notifications
OrionLib:MakeNotification({
    Name = "Loading...",
    Content = "Script Loading, please wait",
    Image = "rbxassetid://4483345998",
    Time = 1
})

local Window = OrionLib:MakeWindow({
    Name = "Remake Jujutsu Chronicles",
    HidePremium = false,
    SaveConfig = true,
    ConfigFolder = "OrionConfig"
})

OrionLib:MakeNotification({
    Name = "Loaded",
    Content = "Script made by gokuooo99",
    Image = "rbxassetid://4483345998",
    Time = 1
})

-- ====== MAIN TABS ======

-- Auto Farm Tab
local AutoFarmTab = Window:MakeTab({
    Name = "Auto Farm",
    Icon = "rbxassetid://4483345998",
    PremiumOnly = false
})

-- Strength Restart
local punchToggle = false
AutoFarmTab:AddToggle({
    Name = "Strength Restart",
    Default = false,
    Callback = function(value)
        punchToggle = value
        if punchToggle then
            while punchToggle do 
                task.wait(0.001)
                if punchToggle then
                    game:GetService("Players").LocalPlayer.Character.Main_Client.Main_Server.Swing:FireServer()
                    local args = {
                        [1] = {
                            ["Character"] = workspace:WaitForChild(player.Name),
                            ["Action"] = "M1",
                            ["Combo"] = 1,
                            ["Target"] = workspace:WaitForChild(player.Name),
                            ["BehindPlayer"] = true
                        }
                    }
                    game:GetService("ReplicatedStorage").Events.CombatEvent:FireServer(unpack(args))
                    local character = player.Character or player.CharacterAdded:Wait() 
                    local humanoidrootpart = character:WaitForChild("HumanoidRootPart") 
                    task.wait(0.0001)
                    humanoidrootpart.CFrame = CFrame.new(1205, 154, 950)
                end
            end
        end
    end
})

-- Skill Toggles
CreateSkillToggle(AutoFarmTab, "Auto Z Skill", Enum.KeyCode.Z)
CreateSkillToggle(AutoFarmTab, "Auto X Skill", Enum.KeyCode.X)
CreateSkillToggle(AutoFarmTab, "Auto C Skill", Enum.KeyCode.C)
CreateSkillToggle(AutoFarmTab, "Auto B Skill", Enum.KeyCode.B)
CreateSkillToggle(AutoFarmTab, "Auto N Skill", Enum.KeyCode.N)

-- Auto Strength
local dummyToggle = false
AutoFarmTab:AddToggle({
    Name = "Auto Strength (Dummy)",
    Default = false,
    Callback = function(value)
        dummyToggle = value
        if dummyToggle then
            workspace.Gravity = 0
            while dummyToggle do
                task.wait()
                
                local character = player.Character or player.CharacterAdded:Wait()
                SetupCharacter(character)
                
                local npc = workspace:FindFirstChild("Dummy")
                if npc then
                    local npcRoot = npc:WaitForChild("HumanoidRootPart")
                    local charRoot = character:WaitForChild("HumanoidRootPart")
                    
                    if npcRoot and charRoot then
                        charRoot.CFrame = npcRoot.CFrame * CFrame.new(CONFIG.BOSS_FARM_OFFSET)
                        ExecuteAttack(npc, false)
                    end
                end
            end
            workspace.Gravity = CONFIG.DEFAULT_GRAVITY
        end
    end
})

-- Auto Sorcerer
CreateAutoFarmToggle(AutoFarmTab, "Auto Sorcerer", "Sorcerer", false)

-- Bosses Tab
local BossTab = Window:MakeTab({
    Name = "Bosses",
    Icon = "rbxassetid://4483345998",
    PremiumOnly = false
})

-- Create boss toggles from config
for _, bossName in ipairs(CONFIG.BOSS_LIST) do
    CreateAutoFarmToggle(BossTab, "Auto "..bossName, bossName, true)
end

-- Teleport Tab
local TeleportTab = Window:MakeTab({
    Name = "Teleport",
    Icon = "rbxassetid://4483345998",
    PremiumOnly = false
})

-- Create teleport buttons from config
for locationName, cframe in pairs(CONFIG.TELEPORT_LOCATIONS) do
    TeleportTab:AddButton({
        Name = locationName,
        Callback = function()
            local character = player.Character or player.CharacterAdded:Wait()
            local humanoidRootPart = character:WaitForChild("HumanoidRootPart")
            humanoidRootPart.CFrame = cframe
        end
    })
end

-- ====== INITIALIZATION ======
SendStartNotification()
task.spawn(MonitorBossDeaths)

-- Anti-AFK
loadstring(game:HttpGet("https://raw.githubusercontent.com/hassanxzayn-lua/Anti-afk/main/antiafkbyhassanxzyn"))()
