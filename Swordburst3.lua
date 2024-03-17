local library = loadstring(game:GetObjects("rbxassetid://7657867786")[1].Source)()
local Wait = library.subs.Wait -- Only returns if the GUI has not been terminated. For 'while Wait() do' loops
local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")
local player = Players.LocalPlayer
local RunService = game:GetService("RunService")

-- ====================================Global Variables====================================
local selectedMobName = nil
local autofarmEnabled = false
local tweenInProgress = false
local yOffset = 2
local proximityThreshold = 5 -- Distance in studs at which to attach to the mob
local attachment = nil -- To keep track of attachment constraint
local trackingConnection = nil
-- ====================================Functions==============================================
-- Function to get a list of mob
local function getMobNames()
    local mobNames = {}
    local added = {}

    for _, mob in ipairs(workspace.Mobs:GetChildren()) do
        if not added[mob.Name] then -- checks if mob name hasn't been added
            table.insert(mobNames, mob.Name)
            added[mob.Name] = true
        end
    end
    return mobNames
end

-- Function to get mobs sorted by distance to the player
local function getMobsSortedByDistance()
    local player = game.Players.LocalPlayer
    local character = player.Character
    local humanoidRootPart = character and character:FindFirstChild("HumanoidRootPart")
    local mobs = {}

    if humanoidRootPart then
        for _, mob in ipairs(workspace.Mobs:GetChildren()) do
            if mob:FindFirstChild("HumanoidRootPart") then
                local distance = (mob.HumanoidRootPart.Position - humanoidRootPart.Position).magnitude
                table.insert(mobs, {
                    mob = mob,
                    distance = distance
                })
            end
        end
        -- Sort the table based on distance
        table.sort(mobs, function(a, b)
            return a.distance < b.distance
        end)
    end

    -- Return only the mob names, in order of distance
    local sortedMobNames = {}
    for _, mobInfo in ipairs(mobs) do
        table.insert(sortedMobNames, mobInfo.mob.Name)
    end
    return sortedMobNames
end

-- Function to dynamically update the player's position to follow the mob
local function updateAttachmentPosition(mob)
    if not attachment or not attachment.Parent then
        attachment = Instance.new("BodyPosition", player.Character.HumanoidRootPart)
        attachment.MaxForce = Vector3.new(50000, 50000, 50000)
        attachment.D = 100
        attachment.P = 3000
    end

    -- Dynamic update loop
    if trackingConnection then
        trackingConnection:Disconnect() -- Disconnect previous tracking to avoid duplicates
    end
    trackingConnection = RunService.Heartbeat:Connect(function()
        if mob and mob:FindFirstChild("HumanoidRootPart") and attachment then
            attachment.Position = mob.HumanoidRootPart.Position + Vector3.new(0, yOffset, 0)
        end
    end)
end

-- Function to set noclip (collision) state
local function setNoclipEnabled(enabled)
    local character = player.Character
    if character then
        for _, part in ipairs(character:GetDescendants()) do
            if part:IsA("BasePart") then
                part.CanCollide = not enabled
            end
        end
    end
end

-- Function to check if a mob is dead
local function isMobDead(mob)
    return mob.HumanoidRootPart.BrickColor == BrickColor.new("Toothpaste")
end

-- Function to move the player to the mob with TweenService
local function moveToMobWithTween(mob)
    if not mob or not mob:FindFirstChild("HumanoidRootPart") then
        return
    end

    local mobPos = mob.HumanoidRootPart.Position + Vector3.new(0, yOffset, 0)
    local tweenInfo = TweenInfo.new((player.Character.HumanoidRootPart.Position - mobPos).magnitude / 50,
        Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
    local tween = TweenService:Create(player.Character.HumanoidRootPart, tweenInfo, {
        CFrame = CFrame.new(mobPos)
    })

    tween:Play()
    tween.Completed:Connect(function()
        updateAttachmentPosition(mob) -- Attach to the mob when the tween completes
    end)
end

-- Function to detach the player from the mob
local function detachFromMob()
    if attachment then
        attachment:Destroy()
        attachment = nil
    end
    if trackingConnection then
        trackingConnection:Disconnect()
        trackingConnection = nil
    end
end

-- Main logic to handle mob targeting and waiting for it to "die"
local function handleMobTargeting()
    local mobNames = getMobsSortedByDistance() -- Get the initial sorted list
    local currentMobIndex = 1 -- Start with the closest mob

    while autofarmEnabled and Wait() do
        local currentMobName = mobNames[currentMobIndex]
        local mob = workspace.Mobs:FindFirstChild(currentMobName)

        if mob and mob:FindFirstChild("HumanoidRootPart") and not isMobDead(mob) then
            moveToMobWithTween(mob)
        else
            -- Mob is dead or not found, find next closest mob
            currentMobIndex = currentMobIndex + 1
            if currentMobIndex > #mobNames then
                mobNames = getMobsSortedByDistance() -- Recalculate distances
                currentMobIndex = 1 -- Reset index to start with the closest mob again
            end
            selectedMobName = mobNames[currentMobIndex] -- Update the global variable for UI consistency
            print("Switching to next closest mob: " .. selectedMobName)
        end
    end
end

-- ======================================Pepsi UI==========================================
local PepsisWorld = library:CreateWindow({
    Name = "Pepsi's World",
    Themeable = {
        Info = "Discord Server: VzYTJ7Y"
    }
})

-- General Tab
local GeneralTab = PepsisWorld:CreateTab({
    Name = "General"
})

-- ->Farming Section
local MobFarmingSection = GeneralTab:CreateSection({
    Name = "Mob Farming"
})

-- Toggle Callback Updated to Incorporate Continuous Following Logic
MobFarmingSection:AddToggle({
    Name = "Autofarm Mobs",
    Callback = function(state)
        autofarmEnabled = state

        if state then
            local mob = workspace.Mobs:FindFirstChild(selectedMobName)
            if mob then
                moveToMobWithTween(mob) -- Move and initiate tracking
            end
        else
            detachFromMob() -- Clean up and stop tracking when autofarming stops
        end
    end
})

local mobNames = getMobNames() -- Get list of mob names in this floor

MobFarmingSection:AddDropdown({
    Name = "Select a mob",
    Flag = "MobFarmingSection_MobNames",
    List = mobNames,
    Callback = function(selectedItem)
        selectedMobName = selectedItem
        print("Selected mob " .. selectedMobName)
    end
})

-- Add a slider to the UI for Y-axis offset control
MobFarmingSection:AddSlider({
    Name = "Farming Position",
    Min = -25,
    Max = 25,
    Value = yOffset, -- Default value
    Callback = function(value)
        yOffset = value -- Update the global Y-offset based on the slider
    end
})
