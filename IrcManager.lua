local API = "https://awseaqwf-production.up.railway.app"
local FLOW_KEY = getgenv().FLOW_KEY

local hs = game:GetService("HttpService")
local rs = game:GetService("RunService")
local plrs = game:GetService("Players")
local lp = plrs.LocalPlayer
local cam = workspace.CurrentCamera

local discordId = tostring(getgenv().FLOW_DISCORD_ID or "n/a")
local isAdmin = discordId == "1285058734858440806" or discordId == "1284644914226790490"

local function api(method, path, body)
    local ok, res = pcall(request, {
        Url = API .. path,
        Method = method,
        Headers = { ["Content-Type"] = "application/json", ["X-Flow-Key"] = FLOW_KEY },
        Body = body and hs:JSONEncode(body) or nil,
    })
    if not ok or not res or res.StatusCode ~= 200 then return nil end
    local dok, data = pcall(hs.JSONDecode, hs, res.Body)
    return dok and data or nil
end

local Library = getgenv().Library
if not Library then
    Library = loadstring(readfile("gitdfnshbajfdn/Library.lua"))()
end

getgenv().Options = getgenv().Options or {}
local Options = getgenv().Options

local Win = getgenv().FLOW_WINDOW or Library:CreateWindow({
    Title = "flow irc",
    Center = false,
    AutoShow = true,
    TabPadding = 8,
    MenuFadeTime = 0.2,
})

local IrcTab = Win:AddTab("IRC")
IrcTab:SetColumnLayout(2/3, 1/3)

local ChatGroup = IrcTab:AddLeftGroupbox("Chat")
local InfoGroup = IrcTab:AddRightGroupbox("Info")

local chat = ChatGroup:AddChatArea(300)

local nameCache = {}
local myUsername = nil

local function resolveId(id, cb)
    if not id or id == "" or id == "n/a" then cb(nil); return end
    if nameCache[id] then cb(nameCache[id]); return end
    task.spawn(function()
        local data = api("GET", "/discord/resolve/" .. id)
        local name = data and data.username
        name = name and name:sub(1, 15) or id:sub(1, 15)
        nameCache[id] = name
        cb(name)
    end)
end

if discordId ~= "n/a" then
    resolveId(discordId, function(name) myUsername = name end)
end

local goldenIds = { ["1285058734858440806"] = true, ["1284644914226790490"] = true }

local function devTag()
    return '<b><font color="rgb(139,0,0)">DEV</font></b>'
end

local function addChatLine(discordIdVal, discordUsernameVal, body, isSelf)
    if not discordIdVal or discordIdVal == "" or discordIdVal == "n/a" then
        chat:AddMessage(devTag(), body)
    else
        local name = discordUsernameVal or nameCache[discordIdVal] or discordIdVal:sub(1, 15)
        if goldenIds[discordIdVal] then
            chat:AddMessage(nil, '<font color="rgb(255,193,7)">[' .. name .. ']</font> ' .. body)
        else
            local color = isSelf and Color3.fromRGB(120, 180, 255) or Color3.fromRGB(200, 200, 200)
            chat:AddMessage(name, body, color)
        end
    end
end

ChatGroup:AddChatInput("irc_input", {
    Placeholder = "message or /command...",
    Callback = function(txt)
        if txt:sub(1, 1) == "/" then
            if not isAdmin then return end
            local cmd, arg = txt:match("^/(%S+)%s*(.*)")
            cmd = cmd and cmd:lower()
            if cmd == "purge" then
                local ok = api("POST", "/purge", { discordId = discordId })
                if ok then
                    chat:Clear()
                    chat:AddMessage(nil, "* chat purged.", Color3.fromRGB(100, 200, 100))
                else
                    chat:AddMessage(nil, "* purge failed.", Color3.fromRGB(200, 80, 80))
                end
            elseif cmd == "mute" and arg ~= "" then
                local ok = api("POST", "/mute", { discordId = arg })
                chat:AddMessage(nil, "* " .. (ok and "muted " .. arg or "mute failed."), ok and Color3.fromRGB(100, 200, 100) or Color3.fromRGB(200, 80, 80))
            elseif cmd == "unmute" and arg ~= "" then
                local ok = api("POST", "/unmute", { discordId = arg })
                chat:AddMessage(nil, "* " .. (ok and "unmuted " .. arg or "unmute failed."))
            else
                chat:AddMessage(nil, "* unknown command.", Color3.fromRGB(200, 80, 80))
            end
        else
            task.spawn(function()
                local ok = api("POST", "/chat", { username = lp.Name, discordId = discordId, discordUsername = myUsername, body = txt })
                if not ok then
                    chat:AddMessage(nil, "* failed to send.", Color3.fromRGB(200, 80, 80))
                end
            end)
        end
    end,
})

local onlineLbl = InfoGroup:AddLabel("Online: 1")
local countdownLbl = InfoGroup:AddLabel("Purge in: --:--:--")
InfoGroup:AddBlank(4)
InfoGroup:AddLabel("Same server:", true)
local sameServerLbl = InfoGroup:AddLabel("none", true)

if isAdmin then
    InfoGroup:AddBlank(4)
    InfoGroup:AddDivider()
    InfoGroup:AddLabel("Discord ID")
    InfoGroup:AddInput("irc_admin_id", {
        Text = "",
        Placeholder = "discord id...",
        Callback = function() end,
    })
    InfoGroup:AddButton({
        Text = "Purge Chat",
        Func = function()
            local ok = api("POST", "/purge", { discordId = discordId })
            if ok then
                chat:Clear()
                chat:AddMessage(nil, "* chat purged.", Color3.fromRGB(100, 200, 100))
            else
                chat:AddMessage(nil, "* purge failed.", Color3.fromRGB(200, 80, 80))
            end
        end,
    })
    InfoGroup:AddButton({
        Text = "Mute",
        Func = function()
            local id = (Options.irc_admin_id and Options.irc_admin_id.Value or ""):match("^%s*(.-)%s*$")
            if id == "" then return end
            local ok = api("POST", "/mute", { discordId = id })
            chat:AddMessage(nil, "* " .. (ok and "muted " .. id or "mute failed."), ok and Color3.fromRGB(100, 200, 100) or Color3.fromRGB(200, 80, 80))
        end,
    })
    InfoGroup:AddButton({
        Text = "Unmute",
        Func = function()
            local id = (Options.irc_admin_id and Options.irc_admin_id.Value or ""):match("^%s*(.-)%s*$")
            if id == "" then return end
            api("POST", "/unmute", { discordId = id })
            chat:AddMessage(nil, "* unmuted " .. id)
        end,
    })
end

local knownUsers = {}
local lastId = 0
local lastPurgeCount = 0

local function secsUntilPurge()
    local d = os.date("!*t", os.time())
    local rem = 5 * 3600 - (d.hour * 3600 + d.min * 60 + d.sec)
    if rem <= 0 then rem = rem + 86400 end
    return rem
end

local function fmtCountdown(s)
    return string.format("Purge in: %02d:%02d:%02d", math.floor(s / 3600), math.floor((s % 3600) / 60), s % 60)
end

local flowTags = {}

local function getTag(player)
    if not flowTags[player] then
        local t = Drawing.new("Text")
        t.Text = "flow"
        t.Size = 13
        t.Font = Drawing.Fonts.Plex
        t.Color = Color3.fromRGB(125, 86, 243)
        t.Outline = true
        t.OutlineColor = Color3.fromRGB(0, 0, 0)
        t.Center = true
        t.Visible = false
        flowTags[player] = t
    end
    return flowTags[player]
end

plrs.PlayerRemoving:Connect(function(p)
    if flowTags[p] then flowTags[p]:Remove(); flowTags[p] = nil end
end)

task.spawn(function()
    api("POST", "/heartbeat", { username = lp.Name, jobId = game.JobId, gameId = tostring(game.GameId), discordId = discordId })
    while task.wait(10) do
        api("POST", "/heartbeat", { username = lp.Name, jobId = game.JobId, gameId = tostring(game.GameId), discordId = discordId })
    end
end)

lp.AncestryChanged:Connect(function()
    pcall(api, "DELETE", "/heartbeat/" .. lp.Name, nil)
end)

task.spawn(function()
    while task.wait(5) do
        local users = api("GET", "/users")
        if not users then continue end

        local fresh = {}
        for _, u in ipairs(users) do
            fresh[u.username] = u
            if u.discordId and u.discordId ~= "" and u.discordId ~= "n/a" and not nameCache[u.discordId] then
                resolveId(u.discordId, function() end)
            end
        end

        local function displayName(u)
            if not u.discordId or u.discordId == "" or u.discordId == "n/a" then return "DEV" end
            return nameCache[u.discordId] or u.discordId:sub(1, 15)
        end

        for name, u in pairs(fresh) do
            if not knownUsers[name] and name ~= lp.Name then
                local dn = displayName(u)
                chat:AddMessage(nil, "* " .. dn .. " online" .. (u.jobId == game.JobId and " [here]" or ""), Color3.fromRGB(100, 200, 100))
            end
        end
        for name in pairs(knownUsers) do
            if not fresh[name] and name ~= lp.Name then
                local dn = displayName(knownUsers[name])
                chat:AddMessage(nil, "* " .. dn .. " offline", Color3.fromRGB(200, 100, 100))
            end
        end

        knownUsers = fresh

        local count = 0
        for _ in pairs(fresh) do count += 1 end
        onlineLbl:SetText("Online: " .. count)

        local sameList = {}
        for n, u in pairs(fresh) do
            if u.jobId == game.JobId and n ~= lp.Name then
                sameList[#sameList+1] = displayName(u)
            end
        end
        sameServerLbl:SetText(#sameList > 0 and table.concat(sameList, ", ") or "none")
    end
end)

task.spawn(function()
    while task.wait(2) do
        local data = api("GET", "/chat?since=" .. lastId)
        if not data then continue end

        if data.purgeCount and data.purgeCount > lastPurgeCount then
            lastPurgeCount = data.purgeCount
            chat:Clear()
        end

        for _, m in ipairs(data.messages or {}) do
            if m.id > lastId then
                lastId = m.id
                addChatLine(m.discordId, m.discordUsername, m.body, m.discordId == discordId)
            end
        end
    end
end)

rs.Heartbeat:Connect(function()
    countdownLbl:SetText(fmtCountdown(secsUntilPurge()))
    local espOn = getgenv().FLOW_ESP_ENABLED == true
    for _, player in ipairs(plrs:GetPlayers()) do
        if player == lp then continue end
        local tag = getTag(player)
        if not espOn then tag.Visible = false; continue end
        local u = knownUsers[player.Name]
        if not u or u.jobId ~= game.JobId then tag.Visible = false; continue end
        local head = player.Character and player.Character:FindFirstChild("Head")
        if not head then tag.Visible = false; continue end
        local pos, onscreen = cam:WorldToViewportPoint(head.Position + Vector3.new(0, 1.8, 0))
        tag.Visible = onscreen
        if onscreen then tag.Position = Vector2.new(pos.X, pos.Y) end
    end
end)

local motds = {
    "got so bored i made an irc.. w updates ❤️‍🩹",
    "this feature is genuinely fucking useless",
    "could you paste this?",
    "priv9 patch when?",
    "The axal exit scam was something we ALL saw coming..",
    "Malignant may be the best website of all time??",
    "discord.gg/flowcc",
    "Hi, federal agent",
}
chat:AddMessage(nil, "* " .. motds[math.random(#motds)], Color3.fromRGB(125, 86, 243))
if isAdmin then
    chat:AddMessage(nil, "* admin: /purge  /mute &lt;id&gt;  /unmute &lt;id&gt;", Color3.fromRGB(180, 130, 255))
end
