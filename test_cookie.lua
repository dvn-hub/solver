-- Override print agar output rapi (fix stair-stepping)
local function print_clean(...)
    local args = {...}
    for i, v in ipairs(args) do
        local s = tostring(v):gsub("\n", "\r\n")
        io.write(s .. (i < #args and "\t" or ""))
    end
    io.write("\r\n")
    io.flush()
end
print = print_clean

local function get_roblox_cookie(pkg_name)
    pkg_name = pkg_name or "com.roblox.client"
    local temp_db = "temp_cookie_" .. os.time() .. ".db"
    local cookie = nil

    print("⚙️  Checking SQLite3...")
    local s = os.execute("command -v sqlite3 > /dev/null")
    if s ~= 0 and s ~= true then
        print("⚠️  SQLite3 not found! Installing...")
        os.execute("pkg install sqlite -y")
        
        s = os.execute("command -v sqlite3 > /dev/null")
        if s ~= 0 and s ~= true then
            print("❌ Failed to install SQLite3! Please run: pkg install sqlite")
            return nil
        end
    end

    local paths = {
        "/data/data/" .. pkg_name .. "/app_webview/Default/Cookies",
        "/data/data/" .. pkg_name .. "/app_webview/Cookies"
    }

    local success, result = pcall(function()
        local db_found = false
        for _, path in ipairs(paths) do
            print("📂 Trying path: " .. path)
            -- Hapus 2>/dev/null biar kelihatan errornya
            local copy_cmd = string.format("su -c 'cat %s' > %s", path, temp_db)
            os.execute(copy_cmd)

            local f = io.open(temp_db, "r")
            if f then
                local size = f:seek("end")
                f:close()
                if size > 0 then
                    print("✅ Database found! Size: " .. size .. " bytes")
                    db_found = true
                    break
                else
                    print("⚠️  File empty or root denied.")
                end
            end
        end

        if not db_found then return nil end

        local sqlite_cmd = string.format("sqlite3 %s \"SELECT value FROM cookies WHERE name='.ROBLOSECURITY' ORDER BY creation_utc DESC LIMIT 1;\"", temp_db)
        local handle = io.popen(sqlite_cmd)
        local raw_cookie = handle:read("*a")
        handle:close()
        return raw_cookie
    end)

    os.remove(temp_db) 

    if success and result and result ~= "" then
        local clean_cookie = result:gsub("%s+", "")
        local match_cookie = clean_cookie:match("(_|WARNING:%-DO%-NOT%-SHARE%-THIS.+)")
        if match_cookie then
            cookie = match_cookie
        end
    end
    return cookie
end

local function get_username(cookie)
    local safe_cookie = cookie:gsub("'", "'\\''")
    local cmd = "curl -s -H 'Cookie: .ROBLOSECURITY=" .. safe_cookie .. "' https://users.roblox.com/v1/users/authenticated"
    local handle = io.popen(cmd)
    local result = handle:read("*a")
    handle:close()
    
    if result then
        return result:match('"name"%s*:%s*"(.-)"')
    end
    return nil
end

print("🔍 Testing Cookie Extraction...")

local handle = io.popen("su -c 'pm list packages | grep com.roblox'")
local result = handle:read("*a")
handle:close()

if not result or result == "" then
    print("❌ No Roblox packages found via 'pm list'!")
else
    for line in result:gmatch("[^\r\n]+") do
        local pkg = line:gsub("package:", ""):gsub("%s+", "")
        print("\n📦 Checking package: " .. pkg)
        local c = get_roblox_cookie(pkg)
        if c then
            local user = get_username(c)
            print("👤 Username: " .. (user or "Unknown/Expired"))
            print("✅ Cookie:\n" .. c)
        else
            print("❌ FAILED: Cookie not found")
        end
    end
end