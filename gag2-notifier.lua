-- ================================================
-- GAG2 STOCK NOTIFIER
-- By W_Wick | Scans Seed, Gear, Props & Weather
-- ================================================

-- CONFIG (EDIT THESE)
local WEBHOOK_URL = "YOUR_WEBHOOK_URL_HERE"
local ROLE_ID = "YOUR_ROLE_ID_HERE" -- e.g. "123456789012345678"
local SCAN_INTERVAL = 15 -- seconds between each scan

-- ================================================
-- STATE
-- ================================================
local lastSeedStock = {}
local lastGearStock = {}
local lastPropsStock = {}
local lastWeather = {}

-- ================================================
-- WEBHOOK SENDER
-- ================================================
local HttpService = game:GetService("HttpService")

local function sendWebhook(title, description, color)
    local data = {
        content = "<@&" .. ROLE_ID .. ">",
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
    if not ok then warn("Webhook failed: " .. tostring(err)) end
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
}

local function getColor(rarity)
    for k, v in pairs(rarityColors) do
        if rarity:lower():find(k:lower()) then return v end
    end
    return 5763719
end

-- ================================================
-- WATCHLIST
-- Add item names below to get extra pings for them
-- ================================================
local watchlist = {
    -- "Dragon Fruit",
    -- "Legendary Sprinkler",
}

local function isWatched(name)
    for _, w in ipairs(watchlist) do
        if name:lower() == w:lower() then return true end
    end
    return false
end

-- ================================================
-- SCAN: SEED SHOP
-- ================================================
local function scanSeedShop()
    local gui = game:GetService("Players").LocalPlayer.PlayerGui:FindFirstChild("SeedShop")
    if not gui then return end
    local frame = gui:FindFirstChild("Frame")
    if not frame then return end
    local shop = frame:FindFirstChild("NormalShop")
    if not shop then return end

    local timer = frame:FindFirstChild("Header") and frame.Header:FindFirstChild("RefreshIn")
    local restockTime = timer and timer:FindFirstChild("Timer") and timer.Timer.Text or "?"

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
        local wasInStock = lastSeedStock[name]

        if inStock and not wasInStock then
            table.insert(restocked, {name=name, cost=cost, rarity=rarity, stock=stock})
        end

        lastSeedStock[name] = inStock
    end

    if #restocked > 0 then
        local desc = "**Restock Timer:** " .. restockTime .. "\n\n"
        local color = 5763719
        for _, item in ipairs(restocked) do
            desc = desc .. "🌱 **" .. item.name .. "**\n"
            desc = desc .. "💰 " .. item.cost .. " | 📦 " .. item.stock .. " | ⭐ " .. item.rarity .. "\n"
            if isWatched(item.name) then desc = desc .. "🔔 **WATCHLIST HIT!**\n" end
            desc = desc .. "\n"
            color = getColor(item.rarity)
        end
        sendWebhook("🌱 Seed Shop Restocked!", desc, color)
    end
end

-- ================================================
-- SCAN: GEAR SHOP
-- ================================================
local function scanGearShop()
    local gui = game:GetService("Players").LocalPlayer.PlayerGui:FindFirstChild("GearShop")
    if not gui then return end
    local frame = gui:FindFirstChild("Frame")
    if not frame then return end
    local shop = frame:FindFirstChild("ScrollingFrame")
    if not shop then return end

    local timer = frame:FindFirstChild("Header") and frame.Header:FindFirstChild("RefreshIn")
    local restockTime = timer and timer:FindFirstChild("Timer") and timer.Timer.Text or "?"

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
        local wasInStock = lastGearStock[name]

        if inStock and not wasInStock then
            table.insert(restocked, {name=name, cost=cost, rarity=rarity, stock=stock})
        end

        lastGearStock[name] = inStock
    end

    if #restocked > 0 then
        local desc = "**Restock Timer:** " .. restockTime .. "\n\n"
        local color = 5763719
        for _, item in ipairs(restocked) do
            desc = desc .. "⚙️ **" .. item.name .. "**\n"
            desc = desc .. "💰 " .. item.cost .. " | 📦 " .. item.stock .. " | ⭐ " .. item.rarity .. "\n"
            if isWatched(item.name) then desc = desc .. "🔔 **WATCHLIST HIT!**\n" end
            desc = desc .. "\n"
            color = getColor(item.rarity)
        end
        sendWebhook("⚙️ Gear Shop Restocked!", desc, color)
    end
end

-- ================================================
-- SCAN: PROPS SHOP (CrateShop)
-- ================================================
local function scanPropsShop()
    local gui = game:GetService("Players").LocalPlayer.PlayerGui:FindFirstChild("CrateShop")
    if not gui then return end
    local frame = gui:FindFirstChild("Frame")
    if not frame then return end
    local shop = frame:FindFirstChild("ScrollingFrame")
    if not shop then return end

    local timer = frame:FindFirstChild("Header") and frame.Header:FindFirstChild("RefreshIn")
    local restockTime = timer and timer:FindFirstChild("Timer") and timer.Timer.Text or "?"

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
        local wasInStock = lastPropsStock[name]

        if inStock and not wasInStock then
            table.insert(restocked, {name=name, cost=cost, rarity=rarity, stock=stock})
        end

        lastPropsStock[name] = inStock
    end

    if #restocked > 0 then
        local desc = "**Restock Timer:** " .. restockTime .. "\n\n"
        local color = 5763719
        for _, item in ipairs(restocked) do
            desc = desc .. "🏠 **" .. item.name .. "**\n"
            desc = desc .. "💰 " .. item.cost .. " | 📦 " .. item.stock .. " | ⭐ " .. item.rarity .. "\n"
            if isWatched(item.name) then desc = desc .. "🔔 **WATCHLIST HIT!**\n" end
            desc = desc .. "\n"
            color = getColor(item.rarity)
        end
        sendWebhook("🏠 Props Shop Restocked!", desc, color)
    end
end

-- ================================================
-- SCAN: WEATHER
-- ================================================
local weatherEmojis = {
    Rain      = "🌧️",
    Lightning = "⚡",
    Bloodmoon = "🩸",
    Snowfall  = "❄️",
    Night     = "🌙",
    Starfall  = "⭐",
    Rainbow   = "🌈",
}

local function scanWeather()
    local gui = game:GetService("Players").LocalPlayer.PlayerGui:FindFirstChild("WeatherUI")
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
        local wasActive = lastWeather[name]

        if isActive and not wasActive then
            local emoji = weatherEmojis[name] or "🌤️"
            local desc = emoji .. " **" .. name .. "** is now active!\n"
            desc = desc .. "⏱️ Duration: **" .. time .. "**"
            sendWebhook(emoji .. " Weather Alert: " .. name .. "!", desc, 15844367)
        end

        lastWeather[name] = isActive
    end
end

-- ================================================
-- MAIN LOOP
-- ================================================
print("[GAG2 Notifier] Started! Scanning every " .. SCAN_INTERVAL .. "s")

while true do
    local ok, err = pcall(function()
        scanSeedShop()
        scanGearShop()
        scanPropsShop()
        scanWeather()
    end)
    if not ok then warn("[GAG2 Notifier] Error: " .. tostring(err)) end
    task.wait(SCAN_INTERVAL)
end
