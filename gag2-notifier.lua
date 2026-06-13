-- ================================================
--          GAG2 STOCK NOTIFIER
--    Seed | Gear | Props | Weather
-- ================================================

-- ================================================
-- PER-ITEM ROLE PINGS
-- Fill in your role IDs for each item you want
-- to ping. Leave as "" to use the default ping.
-- ================================================
local ROLE_PINGS = {
    -- SEEDS
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
    -- GEARS
    ["Common Watering Can"]   = "<@&YOUR_ROLE_ID>",
    ["Common Sprinkler"]      = "<@&YOUR_ROLE_ID>",
    ["Master Sprinkler"]      = "<@&YOUR_ROLE_ID>",
    ["Legendary Sprinkler"]   = "<@&YOUR_ROLE_ID>",
    ["Trowel"]                = "<@&YOUR_ROLE_ID>",
    ["Recall Wrench"]         = "<@&YOUR_ROLE_ID>",
    ["Favorite Tool"]         = "<@&YOUR_ROLE_ID>",
    -- PROPS
    ["Ladder Crate"]       = "<@&YOUR_ROLE_ID>",
    ["Bench Crate"]        = "<@&YOUR_ROLE_ID>",
    ["Light Crate"]        = "<@&YOUR_ROLE_ID>",
    -- WEATHER
    ["Rain"]               = "<@&YOUR_ROLE_ID>",
    ["Lightning"]          = "<@&YOUR_ROLE_ID>",
    ["Bloodmoon"]          = "<@&YOUR_ROLE_ID>",
    ["Snowfall"]           = "<@&YOUR_ROLE_ID>",
    ["Night"]              = "<@&YOUR_ROLE_ID>",
    ["Starfall"]           = "<@&YOUR_ROLE_ID>",
    ["Rainbow"]            = "<@&YOUR_ROLE_ID>",
}

local DEFAULT_PING = "@everyone"
local SCAN_INTERVAL = 15

-- ================================================
-- SERVICES
-- ================================================
local Players      = game:GetService("Players")
local HttpService  = game:GetService("HttpService")
local LocalPlayer  = Players.LocalPlayer
local PlayerGui    = LocalPlayer.PlayerGui

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
    if ok and data and data ~= "" then WEBHOOK_URL = data end
    return WEBHOOK_URL
end

-- ================================================
-- WEBHOOK SENDER
-- ================================================
local function getPing(name)
    return ROLE_PINGS[name] or DEFAULT_PING
end

local function sendWebhook(title, description, color, pingName)
    if WEBHOOK_URL == "" then
        warn("[GAG2 Notifier] No webhook URL set!")
        return
    end
    local data = {
        content = getPing(pingName or ""),
        embeds = {{
            title = title,
            description = description,
            color = color or 5763719,
            footer = { text = "GAG2 Notifier • " .. os.date("%X") }
        }}
    }
    local ok, err = pcall(function()
        HttpService:PostAsync(WEBHOOK_URL, HttpService:JSONEncode(data), Enum.HttpContentType.ApplicationJson)
    end)
    if not ok then warn("[GAG2 Notifier] Webhook error: " .. tostring(err)) end
end

local function testWebhook()
    sendWebhook("✅ GAG2 Notifier Connected!", "Webhook is working! You will now receive stock & weather alerts.", 3066993, "")
end

-- ================================================
-- COLORS PER RARITY
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
        if item.Name == "ItemTemplate" or item.Name == "Sheckles_Shelf" or item.Name == "Robux_Shelf" then continue end
        local mf = item:FindFirstChild("Main_Frame")
        if not mf then continue end
        local name   = mf:FindFirstChild("Seed_Text") and mf.Seed_Text.Text or item.Name
        local cost   = mf:FindFirstChild("Cost_Text") and mf.Cost_Text.Text or "?"
        local rarity = mf:FindFirstChild("Rarity") and mf.Rarity:FindFirstChild("Rarity_Text") and mf.Rarity.Rarity_Text.Text or "?"
        local stock  = mf:FindFirstChild("Stock_Text") and mf.Stock_Text.Text or "?"
        local inStock = cost ~= "NO STOCK" and cost ~= "SOLD OUT" and cost ~= "OWNED"
        if inStock and not lastSeedStock[name] then
            table.insert(restocked, {name=name, cost=cost, rarity=rarity, stock=stock})
        end
        lastSeedStock[name] = inStock
    end

    if #restocked > 0 then
        local desc = "**Next Restock:** " .. restockTime .. "\n\n"
        local color, pingName = 5763719, ""
        for _, item in ipairs(restocked) do
            desc = desc .. "🌱 **" .. item.name .. "**\n"
            desc = desc .. "💰 " .. item.cost .. "  |  📦 " .. item.stock .. "  |  ⭐ " .. item.rarity .. "\n\n"
            color = getColor(item.rarity)
            pingName = item.name
        end
        sendWebhook("🌱 Seed Shop Restocked!", desc, color, pingName)
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
        if item.Name == "ItemTemplate" or item.Name == "Sheckles_Shelf" or item.Name == "Robux_Shelf" then continue end
        local mf = item:FindFirstChild("Main_Frame")
        if not mf then continue end
        local name   = mf:FindFirstChild("Seed_Text") and mf.Seed_Text.Text or item.Name
        local cost   = mf:FindFirstChild("Cost_Text") and mf.Cost_Text.Text or "?"
        local rarity = mf:FindFirstChild("Rarity") and mf.Rarity:FindFirstChild("Rarity_Text") and mf.Rarity.Rarity_Text.Text or "?"
        local stock  = mf:FindFirstChild("Stock_Text") and mf.Stock_Text.Text or "?"
        local inStock = cost ~= "NO STOCK" and cost ~= "SOLD OUT" and cost ~= "OWNED"
        if inStock and not lastGearStock[name] then
            table.insert(restocked, {name=name, cost=cost, rarity=rarity, stock=stock})
        end
        lastGearStock[name] = inStock
    end

    if #restocked > 0 then
        local desc = "**Next Restock:** " .. restockTime .. "\n\n"
        local color, pingName = 5763719, ""
        for _, item in ipairs(restocked) do
            desc = desc .. "⚙️ **" .. item.name .. "**\n"
            desc = desc .. "💰 " .. item.cost .. "  |  📦 " .. item.stock .. "  |  ⭐ " .. item.rarity .. "\n\n"
            color = getColor(item.rarity)
            pingName = item.name
        end
        sendWebhook("⚙️ Gear Shop Restocked!", desc, color, pingName)
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
        if item.Name == "ItemTemplate" or item.Name == "Sheckles_Shelf" or item.Name == "Robux_Shelf" then continue end
        local mf = item:FindFirstChild("Main_Frame")
        if not mf then continue end
        local name   = mf:FindFirstChild("Seed_Text") and mf.Seed_Text.Text or item.Name
        local cost   = mf:FindFirstChild("Cost_Text") and mf.Cost_Text.Text or "?"
        local rarity = mf:FindFirstChild("Rarity") and mf.Rarity:FindFirstChild("Rarity_Text") and mf.Rarity.Rarity_Text.Text or "?"
        local stock  = mf:FindFirstChild("Stock_Text") and mf.Stock_Text.Text or "?"
        local inStock = cost ~= "NO STOCK" and cost ~= "SOLD OUT" and cost ~= "OWNED"
        if inStock and not lastPropsStock[name] then
            table.insert(restocked, {name=name, cost=cost, rarity=rarity, stock=stock})
        end
        lastPropsStock[name] = inStock
    end

    if #restocked > 0 then
        local desc = "**Next Restock:** " .. restockTime .. "\n\n"
        local color, pingName = 5763719, ""
        for _, item in ipairs(restocked) do
            desc = desc .. "🏠 **" .. item.name .. "**\n"
            desc = desc .. "💰 " .. item.cost .. "  |  📦 " .. item.stock .. "  |  ⭐ " .. item.rarity .. "\n\n"
            color = getColor(item.rarity)
            pingName = item.name
        end
        sendWebhook("🏠 Props Shop Restocked!", desc, color, pingName)
    end
end

-- ================================================
-- SCAN: WEATHER
-- ================================================
local weatherEmojis = {
    Rain = "🌧️", Lightning = "⚡", Bloodmoon = "🩸",
    Snowfall = "❄️", Night = "🌙", Starfall = "⭐", Rainbow = "🌈",
}

local function scanWeather()
    local gui = PlayerGui:FindFirstChild("WeatherUI")
    if not gui then return end
    local frame = gui:FindFirstChild("Frame")
    if not frame then return end
    for _, item in pairs(frame:GetChildren()) do
        local nameLabel = item:FindFirstChild("Weather")
        local timeLabel = item:FindFirstChild("Time")
        if not nameLabel or not timeLabel then continue end
        local name = nameLabel.Text
        local time = timeLabel.Text
        local isActive = time ~= "0s" and time ~= "" and time ~= "0m 0s"
        if isActive and not lastWeather[name] then
            local emoji = weatherEmojis[name] or "🌤️"
            local desc = emoji .. " **" .. name .. "** is now active!\n⏱️ Duration: **" .. time .. "**"
            sendWebhook(emoji .. " Weather Alert: " .. name .. "!", desc, 15844367, name)
        end
        lastWeather[name] = isActive
    end
end

-- ================================================
-- WEBHOOK GUI
-- ================================================
local function createGui()
    local existing = PlayerGui:FindFirstChild("GAG2NotifierGui")
    if existing then existing:Destroy() end

    local ScreenGui = Instance.new("ScreenGui")
    ScreenGui.Name = "GAG2NotifierGui"
    ScreenGui.ResetOnSpawn = false
    ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    ScreenGui.Parent = PlayerGui

    local Main = Instance.new("Frame")
    Main.Name = "Main"
    Main.Size = UDim2.new(0, 340, 0, 220)
    Main.Position = UDim2.new(0.5, -170, 0.5, -110)
    Main.BackgroundColor3 = Color3.fromRGB(18, 18, 24)
    Main.BorderSizePixel = 0
    Main.Active = true
    Main.Draggable = true
    Main.Parent = ScreenGui
    Instance.new("UICorner", Main).CornerRadius = UDim.new(0, 10)
    local ms = Instance.new("UIStroke", Main)
    ms.Color = Color3.fromRGB(60, 200, 100)
    ms.Thickness = 1.5

    -- Title Bar
    local TitleBar = Instance.new("Frame", Main)
    TitleBar.Size = UDim2.new(1, 0, 0, 40)
    TitleBar.BackgroundColor3 = Color3.fromRGB(25, 25, 35)
    TitleBar.BorderSizePixel = 0
    Instance.new("UICorner", TitleBar).CornerRadius = UDim.new(0, 10)
    local TFix = Instance.new("Frame", TitleBar)
    TFix.Size = UDim2.new(1, 0, 0.5, 0)
    TFix.Position = UDim2.new(0, 0, 0.5, 0)
    TFix.BackgroundColor3 = Color3.fromRGB(25, 25, 35)
    TFix.BorderSizePixel = 0

    local Title = Instance.new("TextLabel", TitleBar)
    Title.Size = UDim2.new(1, -10, 1, 0)
    Title.Position = UDim2.new(0, 10, 0, 0)
    Title.BackgroundTransparency = 1
    Title.Text = "🌱 GAG2 Notifier"
    Title.TextColor3 = Color3.fromRGB(60, 200, 100)
    Title.TextSize = 16
    Title.Font = Enum.Font.GothamBold
    Title.TextXAlignment = Enum.TextXAlignment.Left

    local CloseBtn = Instance.new("TextButton", TitleBar)
    CloseBtn.Size = UDim2.new(0, 30, 0, 30)
    CloseBtn.Position = UDim2.new(1, -35, 0, 5)
    CloseBtn.BackgroundColor3 = Color3.fromRGB(200, 60, 60)
    CloseBtn.Text = "✕"
    CloseBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    CloseBtn.TextSize = 14
    CloseBtn.Font = Enum.Font.GothamBold
    CloseBtn.BorderSizePixel = 0
    Instance.new("UICorner", CloseBtn).CornerRadius = UDim.new(0, 6)
    CloseBtn.MouseButton1Click:Connect(function() ScreenGui:Destroy() end)

    -- Status
    local StatusLabel = Instance.new("TextLabel", Main)
    StatusLabel.Size = UDim2.new(1, -20, 0, 20)
    StatusLabel.Position = UDim2.new(0, 10, 0, 48)
    StatusLabel.BackgroundTransparency = 1
    StatusLabel.Text = "⚪ Not connected"
    StatusLabel.TextColor3 = Color3.fromRGB(180, 180, 180)
    StatusLabel.TextSize = 13
    StatusLabel.Font = Enum.Font.Gotham
    StatusLabel.TextXAlignment = Enum.TextXAlignment.Left

    -- Webhook Label
    local WebhookLabel = Instance.new("TextLabel", Main)
    WebhookLabel.Size = UDim2.new(1, -20, 0, 20)
    WebhookLabel.Position = UDim2.new(0, 10, 0, 76)
    WebhookLabel.BackgroundTransparency = 1
    WebhookLabel.Text = "Paste your Discord Webhook URL:"
    WebhookLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
    WebhookLabel.TextSize = 13
    WebhookLabel.Font = Enum.Font.Gotham
    WebhookLabel.TextXAlignment = Enum.TextXAlignment.Left

    -- Input
    local InputBg = Instance.new("Frame", Main)
    InputBg.Size = UDim2.new(1, -20, 0, 36)
    InputBg.Position = UDim2.new(0, 10, 0, 100)
    InputBg.BackgroundColor3 = Color3.fromRGB(30, 30, 42)
    InputBg.BorderSizePixel = 0
    Instance.new("UICorner", InputBg).CornerRadius = UDim.new(0, 8)
    local InputStroke = Instance.new("UIStroke", InputBg)
    InputStroke.Color = Color3.fromRGB(60, 60, 80)
    InputStroke.Thickness = 1

    local WebhookInput = Instance.new("TextBox", InputBg)
    WebhookInput.Size = UDim2.new(1, -16, 1, 0)
    WebhookInput.Position = UDim2.new(0, 8, 0, 0)
    WebhookInput.BackgroundTransparency = 1
    WebhookInput.PlaceholderText = "https://discord.com/api/webhooks/..."
    WebhookInput.PlaceholderColor3 = Color3.fromRGB(100, 100, 120)
    WebhookInput.Text = loadWebhook()
    WebhookInput.TextColor3 = Color3.fromRGB(220, 220, 220)
    WebhookInput.TextSize = 12
    WebhookInput.Font = Enum.Font.Gotham
    WebhookInput.TextXAlignment = Enum.TextXAlignment.Left
    WebhookInput.ClearTextOnFocus = false

    -- Save Button
    local SaveBtn = Instance.new("TextButton", Main)
    SaveBtn.Size = UDim2.new(1, -20, 0, 36)
    SaveBtn.Position = UDim2.new(0, 10, 0, 144)
    SaveBtn.BackgroundColor3 = Color3.fromRGB(60, 200, 100)
    SaveBtn.Text = "💾  Save Webhook"
    SaveBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    SaveBtn.TextSize = 14
    SaveBtn.Font = Enum.Font.GothamBold
    SaveBtn.BorderSizePixel = 0
    Instance.new("UICorner", SaveBtn).CornerRadius = UDim.new(0, 8)

    SaveBtn.MouseButton1Click:Connect(function()
        local url = WebhookInput.Text
        if url:find("discord.com/api/webhooks") then
            saveWebhook(url)
            StatusLabel.Text = "✅ Connected!"
            StatusLabel.TextColor3 = Color3.fromRGB(60, 200, 100)
            InputStroke.Color = Color3.fromRGB(60, 200, 100)
        else
            StatusLabel.Text = "❌ Invalid webhook URL"
            StatusLabel.TextColor3 = Color3.fromRGB(200, 60, 60)
            InputStroke.Color = Color3.fromRGB(200, 60, 60)
        end
    end)

    -- Test Button
    local TestBtn = Instance.new("TextButton", Main)
    TestBtn.Size = UDim2.new(1, -20, 0, 26)
    TestBtn.Position = UDim2.new(0, 10, 0, 186)
    TestBtn.BackgroundTransparency = 1
    TestBtn.Text = "🔔  Test Webhook"
    TestBtn.TextColor3 = Color3.fromRGB(100, 160, 255)
    TestBtn.TextSize = 13
    TestBtn.Font = Enum.Font.GothamBold
    TestBtn.BorderSizePixel = 0

    TestBtn.MouseButton1Click:Connect(function()
        if WEBHOOK_URL ~= "" then
            testWebhook()
            StatusLabel.Text = "📨 Test sent!"
            StatusLabel.TextColor3 = Color3.fromRGB(100, 160, 255)
        else
            StatusLabel.Text = "❌ Save a webhook first!"
            StatusLabel.TextColor3 = Color3.fromRGB(200, 60, 60)
        end
    end)

    if WEBHOOK_URL ~= "" then
        StatusLabel.Text = "✅ Connected!"
        StatusLabel.TextColor3 = Color3.fromRGB(60, 200, 100)
        InputStroke.Color = Color3.fromRGB(60, 200, 100)
    end
end

-- ================================================
-- START
-- ================================================
createGui()
print("[GAG2 Notifier] Started! Scanning every " .. SCAN_INTERVAL .. "s")

while true do
    local ok, err = pcall(function()
        scanSeedShop()
        scanGearShop()
        scanPropsShop()
        scanWeather()
    end)
    if not ok then warn("[GAG2 Notifier] Scan error: " .. tostring(err)) end
    task.wait(SCAN_INTERVAL)
end
