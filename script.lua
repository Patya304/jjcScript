local http = game:GetService("HttpService")
local req = (syn and syn.request) or (http_request or request or http.request)
local player = game.Players.LocalPlayer

-- ====== KONFIGURÁCIÓ ======
local CONFIG = {
    WEBHOOKS = {
        STARTUP = "https://discord.com/api/webhooks/1346500502757572678/NMS__yzvsi58tJOzwkjRxbrfNJa1h7pFjUNN3_xrZWU9_3P3-GVXx_SY3T_mT4HwRW3W",
        KILLS = "https://discord.com/api/webhooks/1346500505719017472/s-h3UZKUhIHh5jJNRleGgRGcDpQ1OJ67CBcfvrvRfj3-HnebEnCKaGaMCMZRzDk6mbR6"
    },
    
    BOSS_LIST = {"Sukuna", "Meguna", "UltSukuna", "Choso", "Kashimo", "TheStrongest"},
    
    SETTINGS = {
        BOSS_OFFSET = Vector3.new(0, 7, 0),
        GRAVITY = {
            NORMAL = 162.2,
            ZERO = 0
        },
        COOLDOWNS = {
            BOSS_REPORT = 5
        },
        RESPAWN_CHECK_INTERVAL = 3 -- Seconds between respawn checks
    }
}

-- ====== SEGÉDFÜGGVÉNYEK ======
local function SendNotification(title, content)
    OrionLib:MakeNotification({
        Name = title,
        Content = content,
        Image = "rbxassetid://4483345998",
        Time = 3
    })
end

local function SetCharacterCollision(character, state)
    for _, part in pairs(character:GetDescendants()) do
        if part:IsA("BasePart") then
            part.CanCollide = state
        end
    end
end

local function TeleportToTarget(character, target)
    local charRoot = character:FindFirstChild("HumanoidRootPart")
    local targetRoot = target:FindFirstChild("HumanoidRootPart")
    
    if charRoot and targetRoot then
        -- Mögé teleportálás a konfigban megadott offsettel
        charRoot.CFrame = targetRoot.CFrame * CFrame.new(CONFIG.SETTINGS.BOSS_OFFSET)
        return true
    end
    return false
end

local function PerformAttack(target)
    game:GetService("Players").LocalPlayer.Character.Main_Client.Main_Server.Swing:FireServer()
    local args = {
        [1] = {
            ["Character"] = workspace:WaitForChild(player.Name),
            ["Action"] = "M1",
            ["Combo"] = 1,
            ["Target"] = target,
            ["BehindPlayer"] = true
        }
    }
    game:GetService("ReplicatedStorage"):WaitForChild("Events"):WaitForChild("CombatEvent"):FireServer(unpack(args))
end

-- ====== WEBHOOK KEZELÉS ======
local function SendStartNotification()
    local data = {
        embeds = {{
            title = "✅ Script Activated",
            description = "`" .. player.Name .. "` has started the script.",
            color = 0x00FF00,
            fields = {
                {name = "Player Profile", value = "[Click Here](https://www.roblox.com/users/"..player.UserId.."/profile)", inline = true},
                {name = "Time", value = os.date("`%Y.%m.%d` **|** `%H:%M`"), inline = true}
            },
            footer = {text = "JJC Boss Tracker"}
        }}
    }
    
    pcall(function()
        req({
            Url = CONFIG.WEBHOOKS.STARTUP,
            Method = "POST",
            Headers = {["Content-Type"] = "application/json"},
            Body = http:JSONEncode(data)
        })
    end)
end

local BossTracker = {
    ReportedKills = {},
    Cooldown = CONFIG.SETTINGS.COOLDOWNS.BOSS_REPORT
}

function BossTracker:LogKill(bossName)
    local now = os.time()
    if self.ReportedKills[bossName] and (now - self.ReportedKills[bossName]) < self.Cooldown then
        return
    end

    local data = {
        embeds = {{
            title = "👑 "..bossName.." ELIMINATED",
            description = "`"..player.Name.."` defeated the boss!",
            color = 0xFF3030,
            fields = {
                {name = "Player Profile", value = "[Click Here](https://www.roblox.com/users/"..player.UserId.."/profile)", inline = true},
                {name = "Time", value = os.date("`%Y.%m.%d` **|** `%H:%M`"), inline = true}
            },
            footer = {text = "JJC Boss Logger"}
        }}
    }

    pcall(function()
        req({
            Url = CONFIG.WEBHOOKS.KILLS,
            Method = "POST",
            Headers = {["Content-Type"] = "application/json"},
            Body = http:JSONEncode(data)
        })
    end)

    self.ReportedKills[bossName] = now
end

-- ====== JAVÍTOTT AUTOMATIZÁLÁSOK ======
local function CreateAutoFarmToggle(tab, name, targetName, description)
    local toggle = false
    local lastValidTarget = nil
    
    tab:AddToggle({
        Name = name,
        Default = false,
        Tooltip = description,
        Callback = function(value)
            toggle = value
            if toggle then
                workspace.Gravity = CONFIG.SETTINGS.GRAVITY.ZERO
                
                -- Character monitoring thread
                local function MonitorCharacter()
                    while toggle do
                        -- Wait if character is dead
                        if not player.Character or not player.Character:FindFirstChild("Humanoid") or player.Character.Humanoid.Health <= 0 then
                            repeat
                                task.wait(1)
                            until player.Character and player.Character:FindFirstChild("Humanoid") and player.Character.Humanoid.Health > 0
                            
                            -- Reset collision after respawn
                            SetCharacterCollision(player.Character, false)
                        end
                        task.wait(0.5)
                    end
                end
                
                task.spawn(MonitorCharacter)
                
                -- Main farming loop
                while toggle do
                    task.wait(0.1)
                    if not toggle then break end
                    
                    local character = player.Character
                    if not character or not character:FindFirstChild("HumanoidRootPart") then
                        task.wait(1)
                        continue
                    end
                    
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
                            task.wait(CONFIG.SETTINGS.RESPAWN_CHECK_INTERVAL)
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
                    SetCharacterCollision(character, false)
                    if TeleportToTarget(character, target) then
                        PerformAttack(target)
                    end
                end
                
                workspace.Gravity = CONFIG.SETTINGS.GRAVITY.NORMAL
                lastValidTarget = nil
            end
        end
    })
end

-- ====== MENÜ INICIALIZÁLÁS ======
local OrionLib = loadstring(game:HttpGet("https://raw.githubusercontent.com/Xtentacion178/Dbbdbr/main/Rbsbbs"))()

-- Fő ablak
local Window = OrionLib:MakeWindow({
    Name = "Jujutsu Chronicles - Premium",
    HidePremium = false,
    SaveConfig = true,
    ConfigFolder = "JJCConfig"
})

-- Értesítések
SendNotification("Betöltés...", "A script inicializálása folyamatban...")
SendStartNotification()

-- ====== FÜLÖK LÉTREHOZÁSA ======
-- Auto Farm fül
local AutoFarmTab = Window:MakeTab({
    Name = "Auto Farm",
    Icon = "rbxassetid://4483345998",
    PremiumOnly = false
})

-- Strength Farm
CreateAutoFarmToggle(AutoFarmTab, "Strength Farm", "Dummy", "Automatikusan farmolja az erőt a bábunál")
CreateAutoFarmToggle(AutoFarmTab, "Sorcerer Farm", "Sorcerer", "Automatikusan farmolja a varázslókat")

-- Skill Automation
AutoFarmTab:AddLabel("Skill Automation")
CreateSkillToggle(AutoFarmTab, "Auto Z Skill", "Z")
CreateSkillToggle(AutoFarmTab, "Auto X Skill", "X")
CreateSkillToggle(AutoFarmTab, "Auto C Skill", "C")
CreateSkillToggle(AutoFarmTab, "Auto B Skill", "B")
CreateSkillToggle(AutoFarmTab, "Auto N Skill", "N")

-- Boss Farm fül
local BossTab = Window:MakeTab({
    Name = "Boss Farm",
    Icon = "rbxassetid://4483345998",
    PremiumOnly = false
})

-- Boss Farmolások
for _, bossName in ipairs(CONFIG.BOSS_LIST) do
    CreateAutoFarmToggle(BossTab, "Auto "..bossName, bossName, "Automatikusan farmolja a(z) "..bossName.." boss-t")
end

-- Teleport fül
local TeleportTab = Window:MakeTab({
    Name = "Teleport",
    Icon = "rbxassetid://4483345998",
    PremiumOnly = false
})

-- Teleport helyek
local TELEPORT_LOCATIONS = {
    ["Miyashi Park"] = CFrame.new(-819, 76, 509),
    ["Spin Location"] = CFrame.new(-620, 76, 472),
    ["Shop"] = CFrame.new(1415, 210, 174),
    ["Rank Up"] = CFrame.new(1207, 149, 678),
    ["Black Flash"] = CFrame.new(1205, 154, 903),
    ["Toju"] = CFrame.new(-741, 77, 722),
    ["The King"] = CFrame.new(17613, 84, -36)
}

for name, cf in pairs(TELEPORT_LOCATIONS) do
    TeleportTab:AddButton({
        Name = name,
        Callback = function()
            local character = player.Character or player.CharacterAdded:Wait()
            local root = character:WaitForChild("HumanoidRootPart")
            root.CFrame = cf
            SendNotification("Teleport", "Sikeresen teleportálva: "..name)
        end
    })
end

-- ====== BOSS FIGYELÉS ======
local function MonitorBossDeaths()
    while task.wait(1) do
        for _, bossName in ipairs(CONFIG.BOSS_LIST) do
            local boss = workspace:FindFirstChild(bossName)
            if boss and boss:FindFirstChild("Humanoid") and boss.Humanoid.Health <= 0 then
                BossTracker:LogKill(bossName)
                task.wait(0.5)
            end
        end
    end
end

-- ====== INICIALIZÁLÁS ======
task.spawn(MonitorBossDeaths)
SendNotification("Kész!", "A script sikeresen betöltődött!")
loadstring(game:HttpGet("https://raw.githubusercontent.com/hassanxzayn-lua/Anti-afk/main/antiafkbyhassanxzyn"))()
