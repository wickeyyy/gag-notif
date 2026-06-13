-- ================================================
--          GAG2 STOCK NOTIFIER v2
--    Seed | Gear | Props | Weather
--    Fixed: HTTP, UI, drag, minimize, loop control,
--           weather active detection, role pings
-- ================================================

-- ================================================
-- PER-ITEM ROLE PINGS
-- ================================================
local ROLE_PINGS = {
    ["Carrot"]             = "<@&YOUR_ROLE_ID>",
    ["Strawberry"]         = "<@&YOUR_ROLE_ID>",
    ["Blueberry"]          = "<@&YOUR_ROLE_ID>",
    ["Tulip"]              = "<@&YOUR_ROLE_ID>",
    ["Sunflower"]          = "<@&YOUR_ROLE_ID>",
    ["Watermelon"]         = "<@&YOUR_ROLE_ID>",
    ["Pumpkin"]            = "<@&YOUR_ROLE_ID>",
    ["Apple"]              = "<@&YOUR_ROLE_ID>",
    ["Bamboo"]             = "<@&YOUR_ROLE_ID>",
    ["Coconut"]            = "<@&YOUR_ROLE_ID>",
    ["Cactus"]             = "<@&YOUR_ROLE_ID>",
    ["Dragon Fruit"]       = "<@&YOUR_ROLE_ID>",
    ["Mango"]              = "<@&YOUR_ROLE_ID>",
    ["Grape"]              = "<@&YOUR_ROLE_ID>",
    ["Mushroom"]           = "<@&YOUR_ROLE_ID>",
    ["Common Watering Can"]   = "<@&YOUR_ROLE_ID>",
    ["Common Sprinkler"]      = "<@&YOUR_ROLE_ID>",
    ["Master Sprinkler"]      = "<@&YOUR_ROLE_ID>",
    ["Legendary Sprinkler"]   = "<@&YOUR_ROLE_ID>",
    ["Trowel"]                = "<@&YOUR_ROLE_ID>",
    ["Recall Wrench"]         = "<@&YOUR_ROLE_ID>",
    ["Favorite Tool"]         = "<@&YOUR_ROLE_ID>",
    ["Ladder Crate"]       = "<@&YOUR_ROLE_ID>",
    ["Bench Crate"]        = "<@&YOUR_ROLE_ID>",
    ["Light Crate"]        = "<@&YOUR_ROLE_ID>",
    ["Rain"]               = "<@&YOUR_ROLE_ID>",
    ["Lightning"]          = "<@&YOUR_ROLE_ID>",
    ["Bloodmoon"]          = "<@&YOUR_ROLE_ID>",
    ["Snowfall"]           = "<@&YOUR_ROLE_ID>",
    ["Night"]              = "<@&YOUR_ROLE_ID>",
    ["Starfall"]           = "<@&YOUR_ROLE_ID>",
    ["Rainbow"]            = "<@&YOUR_ROLE_ID>",
}

local SCAN_INTERVAL = 15

-- ================================================
-- SERVICES
-- ================================================
local Players          = game:GetService("Players")
local HttpService      = game:GetService("HttpService")
local UserInputService = game:GetService("UserInputService")
local TweenService     = game:GetService("TweenService")
local LocalPlayer      = Players.LocalPlayer
local PlayerGui        = LocalPlayer:WaitForChild("PlayerGui")

-- ================================================
-- FIX 1: EXECUTOR-SAFE HTTP (replaces PostAsync)
-- ================================================
local function httpRequest(options)
    if syn and syn.request         then return syn.request(options)
    elseif http and http.request   then return http.request(options)
    elseif http_request            then return http_request(options)
    elseif request                 then return request(options)
    else
        warn("[GAG2] No HTTP function available in this executor!")
        return nil
    end
end

-- ================================================
-- WEBHOOK STORAGE
-- ================================================
local WEBHOOK_URL = ""

local function saveWebhook(url)
    WEBHOOK_URL = url
    pcall(function() writefile("gag2_webhook.txt", url) end)
end

local function loadWebhook()
    local ok, data = pcall(function() return readfile("gag2_webhook.txt") end)
    if ok and data and data ~= "" then
        WEBHOOK_URL = data
        return data
    end
    return ""
end

-- ================================================
-- WEBHOOK SENDER
-- pingNames = single string OR table of item names
-- Collects all unique role pings for the batch,
-- deduplicates them, and puts them at the top.
-- If an item has no role set, it is silently skipped
-- (no @everyone fallback).
-- ================================================
local function buildPingContent(pingNames)
    if not pingNames or pingNames == "" then return nil end
    local names = type(pingNames) == "table" and pingNames or {pingNames}
    local seen, parts = {}, {}
    for _, name in ipairs(names) do
        local role = ROLE_PINGS[name]
        if role and role ~= "" and not seen[role] then
            seen[role] = true
            table.insert(parts, role)
        end
    end
    return #parts > 0 and table.concat(parts, " ") or nil
end

local function sendWebhook(title, description, color, pingNames)
    if WEBHOOK_URL == "" then
        warn("[GAG2 Notifier] No webhook URL set!")
        return false
    end
    local data = {
        content = buildPingContent(pingNames),
        embeds = {{
            title       = title,
            description = description,
            color       = color or 5763719,
            footer      = { text = "GAG2 Notifier v2 • " .. os.date("%X") }
        }}
    }
    local ok, err = pcall(function()
        httpRequest({
            Url     = WEBHOOK_URL,
            Method  = "POST",
            Headers = { ["Content-Type"] = "application/json" },
            Body    = HttpService:JSONEncode(data),
        })
    end)
    if not ok then warn("[GAG2 Notifier] Webhook error: " .. tostring(err)) end
    return ok
end

local function testWebhook()
    return sendWebhook(
        "✅ GAG2 Notifier v2 Connected!",
        "Webhook is working! You will now receive stock & weather alerts.",
        3066993, {}
    )
end

-- ================================================
-- RARITY COLORS
-- ================================================
local rarityColors = {
    Common    = 9807270,
    Uncommon  = 5763719,
    Rare      = 3447003,
    Epic      = 10181046,
    Legendary = 15844367,
    Mythical  = 15158332,
    Divine    = 16766720,
}

local function getColor(rarity)
    if not rarity then return 5763719 end
    for k, v in pairs(rarityColors) do
        if rarity:lower():find(k:lower()) then return v end
    end
    return 5763719
end

-- ================================================
-- STATE
-- ================================================
local lastSeedStock  = {}
local lastGearStock  = {}
local lastPropsStock = {}
-- FIX 4: weather resets when weather ends, so alerts re-fire next time
local lastWeather    = {}

-- ================================================
-- SCAN: SEED SHOP
-- ================================================
local function scanSeedShop()
    local gui = PlayerGui:FindFirstChild("SeedShop")
    if not gui then return end
    local frame = gui:FindFirstChild("Frame")
    if not frame then return end
    local shop = frame:FindFirstChild("NormalShop")
    if not shop then return end

    local timerLabel = frame:FindFirstChild("Header")
        and frame.Header:FindFirstChild("RefreshIn")
        and frame.Header.RefreshIn:FindFirstChild("Timer")
    local restockTime = timerLabel and timerLabel.Text or "?"

    local restocked = {}
    for _, item in pairs(shop:GetChildren()) do
        if item.Name == "ItemTemplate"
        or item.Name == "Sheckles_Shelf"
        or item.Name == "Robux_Shelf" then continue end

        local mf = item:FindFirstChild("Main_Frame")
        if not mf then continue end
        local name   = mf:FindFirstChild("Seed_Text")   and mf.Seed_Text.Text   or item.Name
        local cost   = mf:FindFirstChild("Cost_Text")   and mf.Cost_Text.Text   or "?"
        local rarity = mf:FindFirstChild("Rarity")
            and mf.Rarity:FindFirstChild("Rarity_Text")
            and mf.Rarity.Rarity_Text.Text or "?"
        local stock  = mf:FindFirstChild("Stock_Text")  and mf.Stock_Text.Text  or "?"
        local inStock = cost ~= "NO STOCK" and cost ~= "SOLD OUT" and cost ~= "OWNED"

        if inStock and not lastSeedStock[name] then
            table.insert(restocked, {name=name, cost=cost, rarity=rarity, stock=stock})
        end
        lastSeedStock[name] = inStock
    end

    if #restocked > 0 then
        local desc = "**Next Restock:** " .. restockTime .. "\n\n"
        local color = 5763719
        local pingNames = {}
        for _, item in ipairs(restocked) do
            desc = desc .. "🌱 **" .. item.name .. "**\n"
            desc = desc .. "💰 " .. item.cost .. "  |  📦 " .. item.stock .. "  |  ⭐ " .. item.rarity .. "\n\n"
            color = getColor(item.rarity)
            table.insert(pingNames, item.name)
        end
        sendWebhook("🌱 Seed Shop Restocked!", desc, color, pingNames)
    end
end

-- ================================================
-- SCAN: GEAR SHOP
-- ================================================
local function scanGearShop()
    local gui = PlayerGui:FindFirstChild("GearShop")
    if not gui then return end
    local frame = gui:FindFirstChild("Frame")
    if not frame then return end
    local shop = frame:FindFirstChild("ScrollingFrame")
    if not shop then return end

    local timerLabel = frame:FindFirstChild("Header")
        and frame.Header:FindFirstChild("RefreshIn")
        and frame.Header.RefreshIn:FindFirstChild("Timer")
    local restockTime = timerLabel and timerLabel.Text or "?"

    local restocked = {}
    for _, item in pairs(shop:GetChildren()) do
        if item.Name == "ItemTemplate"
        or item.Name == "Sheckles_Shelf"
        or item.Name == "Robux_Shelf" then continue end

        local mf = item:FindFirstChild("Main_Frame")
        if not mf then continue end
        local name   = mf:FindFirstChild("Seed_Text")  and mf.Seed_Text.Text  or item.Name
        local cost   = mf:FindFirstChild("Cost_Text")  and mf.Cost_Text.Text  or "?"
        local rarity = mf:FindFirstChild("Rarity")
            and mf.Rarity:FindFirstChild("Rarity_Text")
            and mf.Rarity.Rarity_Text.Text or "?"
        local stock  = mf:FindFirstChild("Stock_Text") and mf.Stock_Text.Text or "?"
        local inStock = cost ~= "NO STOCK" and cost ~= "SOLD OUT" and cost ~= "OWNED"

        if inStock and not lastGearStock[name] then
            table.insert(restocked, {name=name, cost=cost, rarity=rarity, stock=stock})
        end
        lastGearStock[name] = inStock
    end

    if #restocked > 0 then
        local desc = "**Next Restock:** " .. restockTime .. "\n\n"
        local color = 5763719
        local pingNames = {}
        for _, item in ipairs(restocked) do
            desc = desc .. "⚙️ **" .. item.name .. "**\n"
            desc = desc .. "💰 " .. item.cost .. "  |  📦 " .. item.stock .. "  |  ⭐ " .. item.rarity .. "\n\n"
            color = getColor(item.rarity)
            table.insert(pingNames, item.name)
        end
        sendWebhook("⚙️ Gear Shop Restocked!", desc, color, pingNames)
    end
end

-- ================================================
-- SCAN: PROPS SHOP
-- ================================================
local function scanPropsShop()
    local gui = PlayerGui:FindFirstChild("CrateShop")
    if not gui then return end
    local frame = gui:FindFirstChild("Frame")
    if not frame then return end
    local shop = frame:FindFirstChild("ScrollingFrame")
    if not shop then return end

    local timerLabel = frame:FindFirstChild("Header")
        and frame.Header:FindFirstChild("RefreshIn")
        and frame.Header.RefreshIn:FindFirstChild("Timer")
    local restockTime = timerLabel and timerLabel.Text or "?"

    local restocked = {}
    for _, item in pairs(shop:GetChildren()) do
        if item.Name == "ItemTemplate"
        or item.Name == "Sheckles_Shelf"
        or item.Name == "Robux_Shelf" then continue end

        local mf = item:FindFirstChild("Main_Frame")
        if not mf then continue end
        local name   = mf:FindFirstChild("Seed_Text")  and mf.Seed_Text.Text  or item.Name
        local cost   = mf:FindFirstChild("Cost_Text")  and mf.Cost_Text.Text  or "?"
        local rarity = mf:FindFirstChild("Rarity")
            and mf.Rarity:FindFirstChild("Rarity_Text")
            and mf.Rarity.Rarity_Text.Text or "?"
        local stock  = mf:FindFirstChild("Stock_Text") and mf.Stock_Text.Text or "?"
        local inStock = cost ~= "NO STOCK" and cost ~= "SOLD OUT" and cost ~= "OWNED"

        if inStock and not lastPropsStock[name] then
            table.insert(restocked, {name=name, cost=cost, rarity=rarity, stock=stock})
        end
        lastPropsStock[name] = inStock
    end

    if #restocked > 0 then
        local desc = "**Next Restock:** " .. restockTime .. "\n\n"
        local color = 5763719
        local pingNames = {}
        for _, item in ipairs(restocked) do
            desc = desc .. "🏠 **" .. item.name .. "**\n"
            desc = desc .. "💰 " .. item.cost .. "  |  📦 " .. item.stock .. "  |  ⭐ " .. item.rarity .. "\n\n"
            color = getColor(item.rarity)
            table.insert(pingNames, item.name)
        end
        sendWebhook("🏠 Props Shop Restocked!", desc, color, pingNames)
    end
end

-- ================================================
-- SCAN: WEATHER
-- FIX 4: track when weather ENDS so it re-alerts next cycle
-- ================================================
local weatherEmojis = {
    Rain="🌧️", Lightning="⚡", Bloodmoon="🩸",
    Snowfall="❄️", Night="🌙", Starfall="⭐", Rainbow="🌈",
}

local function scanWeather()
    local gui = PlayerGui:FindFirstChild("WeatherUI")
    if not gui then return end
    local frame = gui:FindFirstChild("Frame")
    if not frame then return end

    for _, item in pairs(frame:GetChildren()) do
        if not item:IsA("Frame") and not item:IsA("ImageLabel") then continue end

        local nameLabel = item:FindFirstChild("Weather")
        local timeLabel = item:FindFirstChild("Time")
        if not nameLabel or not timeLabel then continue end

        local name = nameLabel.Text
        local time = timeLabel.Text

        -- stricter active check:
        -- 1. the item itself must be Visible
        -- 2. the time label must be non-empty and non-zero
        local hasTime = time ~= "" and time ~= "0s" and time ~= "0m 0s" and time ~= "0m" and time ~= "00:00"
        local isActive = item.Visible and hasTime

        if isActive and not lastWeather[name] then
            local emoji = weatherEmojis[name] or "🌤️"
            local desc  = emoji .. " **" .. name .. "** is now active!\n⏱️ Duration: **" .. time .. "**"
            sendWebhook(emoji .. " Weather Alert: " .. name .. "!", desc, 15844367, {name})
        end

        -- reset when inactive so next occurrence re-alerts
        lastWeather[name] = isActive
    end
end

-- ================================================
-- GUI
-- FIX 2: bigger window, status bar, scan feedback
-- FIX 3: manual drag (Draggable=true unreliable in exploits)
-- FIX 5: scanning loop tied to a flag — stops when GUI closes
-- ================================================
local scanningActive = false
local savedUrl = loadWebhook() -- FIX: load BEFORE building GUI

local function createGui()
    local existing = PlayerGui:FindFirstChild("GAG2NotifierGui")
    if existing then existing:Destroy() end

    local ScreenGui = Instance.new("ScreenGui")
    ScreenGui.Name            = "GAG2NotifierGui"
    ScreenGui.ResetOnSpawn    = false
    ScreenGui.ZIndexBehavior  = Enum.ZIndexBehavior.Sibling
    ScreenGui.Parent          = PlayerGui

    -- ── Main window ──────────────────────────────
    local Main = Instance.new("Frame")
    Main.Name             = "Main"
    Main.Size             = UDim2.new(0, 360, 0, 290)
    Main.Position         = UDim2.new(0.5, -180, 0.5, -145)
    Main.BackgroundColor3 = Color3.fromRGB(18, 18, 24)
    Main.BorderSizePixel  = 0
    Main.Parent           = ScreenGui
    Instance.new("UICorner", Main).CornerRadius = UDim.new(0, 10)
    local ms = Instance.new("UIStroke", Main)
    ms.Color     = Color3.fromRGB(60, 200, 100)
    ms.Thickness = 1.5

    -- ── Title bar ────────────────────────────────
    local TitleBar = Instance.new("Frame", Main)
    TitleBar.Size             = UDim2.new(1, 0, 0, 42)
    TitleBar.BackgroundColor3 = Color3.fromRGB(25, 25, 35)
    TitleBar.BorderSizePixel  = 0
    Instance.new("UICorner", TitleBar).CornerRadius = UDim.new(0, 10)
    -- fill bottom half so corners don't show inside the window
    local TFix = Instance.new("Frame", TitleBar)
    TFix.Size             = UDim2.new(1, 0, 0.5, 0)
    TFix.Position         = UDim2.new(0, 0, 0.5, 0)
    TFix.BackgroundColor3 = Color3.fromRGB(25, 25, 35)
    TFix.BorderSizePixel  = 0

    local Title = Instance.new("TextLabel", TitleBar)
    Title.Size               = UDim2.new(1, -80, 1, 0)
    Title.Position           = UDim2.new(0, 12, 0, 0)
    Title.BackgroundTransparency = 1
    Title.Text               = "🌱 GAG2 Notifier v2"
    Title.TextColor3         = Color3.fromRGB(60, 200, 100)
    Title.TextSize           = 15
    Title.Font               = Enum.Font.GothamBold
    Title.TextXAlignment     = Enum.TextXAlignment.Left

    -- Minimize button
    local MinBtn = Instance.new("TextButton", TitleBar)
    MinBtn.Size             = UDim2.new(0, 28, 0, 28)
    MinBtn.Position         = UDim2.new(1, -66, 0.5, -14)
    MinBtn.BackgroundColor3 = Color3.fromRGB(60, 130, 200)
    MinBtn.Text             = "−"
    MinBtn.TextColor3       = Color3.new(1,1,1)
    MinBtn.TextSize         = 16
    MinBtn.Font             = Enum.Font.GothamBold
    MinBtn.BorderSizePixel  = 0
    Instance.new("UICorner", MinBtn).CornerRadius = UDim.new(0, 6)

    -- Close button
    local CloseBtn = Instance.new("TextButton", TitleBar)
    CloseBtn.Size             = UDim2.new(0, 28, 0, 28)
    CloseBtn.Position         = UDim2.new(1, -34, 0.5, -14)
    CloseBtn.BackgroundColor3 = Color3.fromRGB(200, 60, 60)
    CloseBtn.Text             = "✕"
    CloseBtn.TextColor3       = Color3.new(1,1,1)
    CloseBtn.TextSize         = 14
    CloseBtn.Font             = Enum.Font.GothamBold
    CloseBtn.BorderSizePixel  = 0
    Instance.new("UICorner", CloseBtn).CornerRadius = UDim.new(0, 6)

    -- FIX 5: stop loop when closed
    CloseBtn.MouseButton1Click:Connect(function()
        scanningActive = false
        ScreenGui:Destroy()
    end)

    -- FIX 2: minimize/restore body
    local Body = Instance.new("Frame", Main)
    Body.Size             = UDim2.new(1, 0, 1, -42)
    Body.Position         = UDim2.new(0, 0, 0, 42)
    Body.BackgroundTransparency = 1

    local minimized = false
    MinBtn.MouseButton1Click:Connect(function()
        minimized = not minimized
        Body.Visible = not minimized
        TweenService:Create(Main, TweenInfo.new(0.15), {
            Size = minimized and UDim2.new(0, 360, 0, 42) or UDim2.new(0, 360, 0, 290)
        }):Play()
        MinBtn.Text = minimized and "+" or "−"
    end)

    -- ── FIX 3: manual drag ───────────────────────
    do
        local dragging, dragStart, startPos
        TitleBar.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 then
                dragging  = true
                dragStart = input.Position
                startPos  = Main.Position
            end
        end)
        UserInputService.InputChanged:Connect(function(input)
            if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
                local delta = input.Position - dragStart
                Main.Position = UDim2.new(
                    startPos.X.Scale, startPos.X.Offset + delta.X,
                    startPos.Y.Scale, startPos.Y.Offset + delta.Y
                )
            end
        end)
        UserInputService.InputEnded:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 then
                dragging = false
            end
        end)
    end

    -- ── Status bar ───────────────────────────────
    local StatusLabel = Instance.new("TextLabel", Body)
    StatusLabel.Size             = UDim2.new(1, -20, 0, 18)
    StatusLabel.Position         = UDim2.new(0, 10, 0, 8)
    StatusLabel.BackgroundTransparency = 1
    StatusLabel.Text             = "⚪ Not connected"
    StatusLabel.TextColor3       = Color3.fromRGB(160, 160, 160)
    StatusLabel.TextSize         = 12
    StatusLabel.Font             = Enum.Font.Gotham
    StatusLabel.TextXAlignment   = Enum.TextXAlignment.Left

    -- ── Last scan label ──────────────────────────
    local ScanLabel = Instance.new("TextLabel", Body)
    ScanLabel.Size             = UDim2.new(1, -20, 0, 16)
    ScanLabel.Position         = UDim2.new(0, 10, 0, 28)
    ScanLabel.BackgroundTransparency = 1
    ScanLabel.Text             = "🔍 Last scan: waiting..."
    ScanLabel.TextColor3       = Color3.fromRGB(120, 120, 140)
    ScanLabel.TextSize         = 11
    ScanLabel.Font             = Enum.Font.Gotham
    ScanLabel.TextXAlignment   = Enum.TextXAlignment.Left

    -- ── Webhook label ────────────────────────────
    local WebhookLabel = Instance.new("TextLabel", Body)
    WebhookLabel.Size             = UDim2.new(1, -20, 0, 18)
    WebhookLabel.Position         = UDim2.new(0, 10, 0, 56)
    WebhookLabel.BackgroundTransparency = 1
    WebhookLabel.Text             = "Discord Webhook URL:"
    WebhookLabel.TextColor3       = Color3.fromRGB(180, 180, 200)
    WebhookLabel.TextSize         = 12
    WebhookLabel.Font             = Enum.Font.GothamBold
    WebhookLabel.TextXAlignment   = Enum.TextXAlignment.Left

    -- ── Input box ────────────────────────────────
    local InputBg = Instance.new("Frame", Body)
    InputBg.Size             = UDim2.new(1, -20, 0, 36)
    InputBg.Position         = UDim2.new(0, 10, 0, 78)
    InputBg.BackgroundColor3 = Color3.fromRGB(28, 28, 40)
    InputBg.BorderSizePixel  = 0
    Instance.new("UICorner", InputBg).CornerRadius = UDim.new(0, 8)
    local InputStroke = Instance.new("UIStroke", InputBg)
    InputStroke.Color     = Color3.fromRGB(60, 60, 85)
    InputStroke.Thickness = 1

    local WebhookInput = Instance.new("TextBox", InputBg)
    WebhookInput.Size             = UDim2.new(1, -16, 1, 0)
    WebhookInput.Position         = UDim2.new(0, 8, 0, 0)
    WebhookInput.BackgroundTransparency = 1
    WebhookInput.PlaceholderText  = "https://discord.com/api/webhooks/..."
    WebhookInput.PlaceholderColor3 = Color3.fromRGB(90, 90, 110)
    WebhookInput.Text             = savedUrl   -- FIX: pre-filled from file
    WebhookInput.TextColor3       = Color3.fromRGB(220, 220, 220)
    WebhookInput.TextSize         = 11
    WebhookInput.Font             = Enum.Font.Gotham
    WebhookInput.TextXAlignment   = Enum.TextXAlignment.Left
    WebhookInput.ClearTextOnFocus = false
    WebhookInput.ClipsDescendants = true

    -- ── Save button ──────────────────────────────
    local SaveBtn = Instance.new("TextButton", Body)
    SaveBtn.Size             = UDim2.new(1, -20, 0, 36)
    SaveBtn.Position         = UDim2.new(0, 10, 0, 122)
    SaveBtn.BackgroundColor3 = Color3.fromRGB(50, 180, 90)
    SaveBtn.Text             = "💾  Save Webhook"
    SaveBtn.TextColor3       = Color3.new(1,1,1)
    SaveBtn.TextSize         = 13
    SaveBtn.Font             = Enum.Font.GothamBold
    SaveBtn.BorderSizePixel  = 0
    Instance.new("UICorner", SaveBtn).CornerRadius = UDim.new(0, 8)

    SaveBtn.MouseButton1Click:Connect(function()
        local url = WebhookInput.Text:gsub("%s+", "")
        if url:find("discord.com/api/webhooks/") then
            saveWebhook(url)
            StatusLabel.Text      = "✅ Webhook saved!"
            StatusLabel.TextColor3 = Color3.fromRGB(60, 200, 100)
            InputStroke.Color     = Color3.fromRGB(60, 200, 100)
        else
            StatusLabel.Text      = "❌ Invalid — must be a Discord webhook URL"
            StatusLabel.TextColor3 = Color3.fromRGB(200, 60, 60)
            InputStroke.Color     = Color3.fromRGB(200, 60, 60)
        end
    end)

    -- ── Test button ──────────────────────────────
    local TestBtn = Instance.new("TextButton", Body)
    TestBtn.Size             = UDim2.new(0.5, -14, 0, 30)
    TestBtn.Position         = UDim2.new(0, 10, 0, 166)
    TestBtn.BackgroundColor3 = Color3.fromRGB(28, 28, 42)
    TestBtn.Text             = "🔔  Test"
    TestBtn.TextColor3       = Color3.fromRGB(100, 160, 255)
    TestBtn.TextSize         = 12
    TestBtn.Font             = Enum.Font.GothamBold
    TestBtn.BorderSizePixel  = 0
    Instance.new("UICorner", TestBtn).CornerRadius = UDim.new(0, 8)
    local testStroke = Instance.new("UIStroke", TestBtn)
    testStroke.Color     = Color3.fromRGB(100, 160, 255)
    testStroke.Thickness = 1

    TestBtn.MouseButton1Click:Connect(function()
        if WEBHOOK_URL ~= "" then
            TestBtn.Text = "⏳ Sending..."
            task.spawn(function()
                local ok = testWebhook()
                TestBtn.Text           = ok and "✅ Sent!" or "❌ Failed"
                StatusLabel.Text       = ok and "✅ Connected & working!" or "❌ Test failed — check URL"
                StatusLabel.TextColor3 = ok
                    and Color3.fromRGB(60, 200, 100)
                    or  Color3.fromRGB(200, 60, 60)
                task.wait(3)
                TestBtn.Text = "🔔  Test"
            end)
        else
            StatusLabel.Text       = "❌ Save a webhook first!"
            StatusLabel.TextColor3 = Color3.fromRGB(200, 60, 60)
        end
    end)

    -- ── Force scan button ────────────────────────
    local ForceBtn = Instance.new("TextButton", Body)
    ForceBtn.Size             = UDim2.new(0.5, -14, 0, 30)
    ForceBtn.Position         = UDim2.new(0.5, 4, 0, 166)
    ForceBtn.BackgroundColor3 = Color3.fromRGB(28, 28, 42)
    ForceBtn.Text             = "🔍  Force Scan"
    ForceBtn.TextColor3       = Color3.fromRGB(255, 180, 60)
    ForceBtn.TextSize         = 12
    ForceBtn.Font             = Enum.Font.GothamBold
    ForceBtn.BorderSizePixel  = 0
    Instance.new("UICorner", ForceBtn).CornerRadius = UDim.new(0, 8)
    local forceStroke = Instance.new("UIStroke", ForceBtn)
    forceStroke.Color     = Color3.fromRGB(255, 180, 60)
    forceStroke.Thickness = 1

    ForceBtn.MouseButton1Click:Connect(function()
        ForceBtn.Text = "⏳ Scanning..."
        task.spawn(function()
            -- reset state so everything fires fresh
            lastSeedStock  = {}
            lastGearStock  = {}
            lastPropsStock = {}
            lastWeather    = {}
            local ok, err = pcall(function()
                scanSeedShop()
                scanGearShop()
                scanPropsShop()
                scanWeather()
            end)
            ScanLabel.Text      = "🔍 Force scan: " .. os.date("%X")
            ForceBtn.Text       = ok and "✅ Done!" or "❌ Error"
            task.wait(3)
            ForceBtn.Text = "🔍  Force Scan"
        end)
    end)

    -- ── Scan interval label ──────────────────────
    local IntervalLabel = Instance.new("TextLabel", Body)
    IntervalLabel.Size             = UDim2.new(1, -20, 0, 16)
    IntervalLabel.Position         = UDim2.new(0, 10, 0, 206)
    IntervalLabel.BackgroundTransparency = 1
    IntervalLabel.Text             = "⏱️ Auto-scanning every " .. SCAN_INTERVAL .. "s  |  Shops: Seed · Gear · Props · Weather"
    IntervalLabel.TextColor3       = Color3.fromRGB(100, 100, 120)
    IntervalLabel.TextSize         = 10
    IntervalLabel.Font             = Enum.Font.Gotham
    IntervalLabel.TextXAlignment   = Enum.TextXAlignment.Left

    -- pre-fill status if webhook already loaded
    if WEBHOOK_URL ~= "" then
        StatusLabel.Text       = "✅ Webhook loaded from file"
        StatusLabel.TextColor3 = Color3.fromRGB(60, 200, 100)
        InputStroke.Color      = Color3.fromRGB(60, 200, 100)
    end

    -- expose ScanLabel for the loop to update
    return ScanLabel
end

-- ================================================
-- START
-- FIX 5: loop is tied to scanningActive flag
-- ================================================
local ScanLabel = createGui()
scanningActive  = true

print("[GAG2 Notifier v2] Started! Scanning every " .. SCAN_INTERVAL .. "s")

while scanningActive do
    local ok, err = pcall(function()
        scanSeedShop()
        scanGearShop()
        scanPropsShop()
        scanWeather()
    end)
    if not ok then
        warn("[GAG2 Notifier] Scan error: " .. tostring(err))
    end
    if ScanLabel and ScanLabel.Parent then
        ScanLabel.Text = "🔍 Last scan: " .. os.date("%X")
            .. (ok and "" or "  ⚠️ error")
    end
    task.wait(SCAN_INTERVAL)
end

print("[GAG2 Notifier v2] Stopped.")
