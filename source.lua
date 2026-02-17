-- Konfigurasi
--[[
    ❄️ WINTER SOLVER TERMUX ❄️
    
    [ CARA PENGGUNAAN ]
    1. Masukkan API Key WinterCode Anda di bagian 'WinterConfig' di bawah.
    2. Pastikan sudah install dependencies: pkg install tsu lua sqlite
    3. Jalankan dengan perintah: tsu -c "lua solver.lua"
]]

WinterConfig = {
    ApiKey = "ISI_API_KEY_DISINI",  -- Masukkan API Key WinterCode Anda
    PlaceId = 4483381587            -- ID Place Roblox (Default)
}

local function get_roblox_cookie(pkg_name)
    pkg_name = pkg_name or "com.roblox.client"
    
    -- Menggunakan metode copy + sqlite3 untuk akurasi yang lebih baik
    local temp_db = "temp_cookie_" .. os.time() .. ".db"
    
    -- Salin db cookies ke folder lokal (membutuhkan akses root untuk membaca)
    os.execute(string.format("su -c 'cat /data/data/%s/app_webview/Default/Cookies' > %s 2>/dev/null", pkg_name, temp_db))
    
    local cmd = string.format("sqlite3 %s \"SELECT value FROM cookies WHERE name='.ROBLOSECURITY' LIMIT 1;\"", temp_db)
    local handle = io.popen(cmd)
    local cookie = handle:read("*a")
    handle:close()
    
    os.remove(temp_db)

    if cookie and cookie ~= "" then
        cookie = cookie:gsub("%s+", "")
        if cookie:match("WARNING:-DO-NOT-SHARE-THIS") then
            return cookie
        end
    end
    return nil
end

if WinterConfig.ApiKey == "ISI_API_KEY_DISINI" then
    print("TOLONG EDIT FILE INI: Masukkan API Key WinterCode Anda di bagian WinterConfig (atas script)!")
    os.exit()
end

local WINTER_COOKIE = ""

local logs = {}
local dashboard_state = {
    status = "IDLE",
    taskId = "-",
    message = "Ready to start",
    instances = {}
}

function draw_dashboard()
    io.write("\27[2J\27[H")
    
    local function print_r(text)
        io.write(text .. "\r\n")
    end

    print_r("╔══════════════════════════════════════════╗")
    print_r("║ WINTER SOLVER API AND MONITORING BY DVN  ║")
    print_r("╠══════════════════════════════════════════╣")
    print_r(string.format("║ STATUS  : %-30s ║", dashboard_state.status))
    print_r(string.format("║ TASK ID : %-30s ║", dashboard_state.taskId))
    print_r("╠══════════════════════════════════════════╣")
    print_r("║ ROBLOX INSTANCE DETECTION:               ║")
    print_r("║ PACKAGE NAME          | STATUS           ║")
    print_r("╠═══════════════════════╪══════════════════╣")
    
    local count = dashboard_state.instances and #dashboard_state.instances or 0
    if count == 0 then
        print_r("║  [ No com.roblox* packages ]             ║")
    else
        for i, inst in ipairs(dashboard_state.instances) do
            local name = inst.name
            if #name > 21 then name = ".." .. name:sub(-19) end
            
            local status = inst.status
            if #status > 16 then status = status:sub(1, 14) .. ".." end
            
            print_r(string.format("║ %-21s | %-16s ║", name, status))
        end
    end
    
    print_r("╠══════════════════════════════════════════╣")
    print_r("║ ACTIVITY LOG:                            ║")
    for i = 1, 5 do
        local log_line = logs[i] or ""
        print_r(string.format("║ > %-38s ║", log_line))
    end
    print_r("╚══════════════════════════════════════════╝")
    io.flush()
end

function get_json_value(json_str, key)
    local pattern = '"' .. key .. '"%s*:%s*"(.-)"'
    local value = json_str:match(pattern)
    if not value then
        pattern = '"' .. key .. '"%s*:%s*([%d%.]+)'
        value = json_str:match(pattern)
    end
    if not value then
        pattern = '"' .. key .. '"%s*:%s*(%a+)'
        value = json_str:match(pattern)
    end
    return value
end

function update_ui(status, message, taskId)
    if status then dashboard_state.status = status end
    if taskId then dashboard_state.taskId = taskId end
    if message then
        local last_msg = logs[1] and logs[1]:sub(10) or ""
        if last_msg ~= " " .. message then
            table.insert(logs, 1, os.date("%H:%M:%S") .. " " .. message)
            if #logs > 10 then table.remove(logs) end
        end
    end
    draw_dashboard()
end

function solve_captcha(blob_data, pkg_name)
    update_ui("CREATING", "Sending request to WinterCode...")
    
    local safe_cookie = WINTER_COOKIE:gsub('"', '\\"')
    local safe_blob = blob_data and blob_data:gsub('"', '\\"') or ""
    
    local json_payload = string.format('{"cookie":"%s","placeId":%d,"blob":"%s"}', safe_cookie, WinterConfig.PlaceId, safe_blob)
    
    local cmd = 'curl -s -k -X POST "https://apiweb.wintercode.dev/api/captcha/solve" ' ..
                '-H "Content-Type: application/json" ' ..
                '-H "X-API-Key: ' .. WinterConfig.ApiKey .. '" ' ..
                '-d \'' .. json_payload:gsub("'", "'\\''") .. '\''
                
    local handle = io.popen(cmd)
    local result = handle:read("*a")
    handle:close()
    
    if not result or result == "" then
        update_ui("FAILED", "WinterCode: No response.")
        return nil
    end
    
    local success = get_json_value(result, "success")
    local status = get_json_value(result, "status")
    local token = result:match('"token"%s*:%s*"(.-)"')
    
    if success == "true" or status == "CAPTCHA_SUCCESS" or status == "NO_CAPTCHA" then
        if token then
            update_ui("SOLVED", "WinterCode: Success!")
            os.execute("termux-clipboard-set '" .. token .. "'")
            return token
        else
            update_ui("SOLVED", "WinterCode: No Captcha Needed")
            return "NO_CAPTCHA_NEEDED"
        end
    else
        local err = get_json_value(result, "error") or status
        if tostring(err):match("YesCaptcha") then
            update_ui("FAILED", "YESCAPTCHA BALANCE/KEY EMPTY! Check Dashboard.")
        else
            update_ui("FAILED", "WinterCode Error: " .. tostring(err))
        end
        if pkg_name then os.execute("su -c 'am force-stop " .. pkg_name .. "'") end
        return nil
    end
end

function check_captcha_status()
    while true do
        local handle = io.popen("su -c 'pm list packages | grep com.roblox'")
        local result = handle:read("*a")
        handle:close()
        
        local instances_data = {}
        local captcha_detected = false
        local found_blob = nil
        local found_pkg = nil
        local any_running = false
        
        if result then
            for line in result:gmatch("[^\r\n]+") do
                local pkg_name = line:gsub("package:", ""):gsub("%s+", "")
                local status_text = "CLOSE"
                
                local h_pid = io.popen(string.format("su -c 'pidof %s'", pkg_name))
                local pid_res = h_pid:read("*a")
                h_pid:close()
                
                local pid = pid_res and pid_res:match("%d+")
                
                if pid then
                    status_text = "OPEN"
                    any_running = true
                    
                    local cmd_log = string.format("su -c 'logcat -d -t 500 --pid=%s'", pid)
                    local h_log = io.popen(cmd_log)
                    local logs_pid = h_log:read("*a") or ""
                    h_log:close()
                    
                    local lower_logs = logs_pid:lower()

                    local metadata_b64 = logs_pid:match("challenge%-metadata%-json=([^&%s]+)")
                    if metadata_b64 then
                        metadata_b64 = metadata_b64:gsub("%%(%x%x)", function(h) return string.char(tonumber(h, 16)) end)
                        
                        local safe_b64 = metadata_b64:gsub("'", "")
                        local h_dec = io.popen("echo '" .. safe_b64 .. "' | base64 -d 2>/dev/null")
                        local decoded_json = h_dec:read("*a")
                        h_dec:close()
                        
                        if decoded_json then
                            local extracted_blob = decoded_json:match('"dataExchangeBlob":"([^"]+)"')
                            if extracted_blob then
                                found_blob = extracted_blob
                                found_pkg = pkg_name
                                status_text = "CAPTCHA PUZZLE"
                                captcha_detected = true
                            end
                        end
                    end

                    if not captcha_detected then
                        if lower_logs:match("verifying") or lower_logs:match("challenge") or lower_logs:match("security") then
                            status_text = "CAPTCHA LOADING"
                        elseif lower_logs:match("arkose") or lower_logs:match("funcaptcha") or lower_logs:match("blob") then
                            status_text = "CAPTCHA PUZZLE"
                            captcha_detected = true
                            
                            local temp_blob = logs_pid:match('"data":"([^"]+)"')
                            if not temp_blob then temp_blob = logs_pid:match('\\"data\\":\\"([^"]+)\\"') end
                            if temp_blob and #temp_blob > 50 then 
                                found_blob = temp_blob 
                                found_pkg = pkg_name
                            end
                        elseif lower_logs:match("joining") then
                            status_text = "JOINING"
                        elseif lower_logs:match("login") or lower_logs:match("webview") then
                            status_text = "NO CAPTCHA"
                        end
                    end
                end
                
                table.insert(instances_data, {name = pkg_name, status = status_text})
            end
        end
        
        table.sort(instances_data, function(a, b) return a.name < b.name end)
        
        dashboard_state.instances = instances_data
        
        if found_blob then
            update_ui("DETECTED", "Blob detected! DO NOT CLICK PUZZLE...")
            return found_blob, found_pkg
        elseif captcha_detected then
            update_ui("WAITING_BLOB", "Captcha detected, waiting for blob data...")
        elseif any_running then
            update_ui("MONITORING", "Scanning " .. #instances_data .. " packages...")
        else
            update_ui("MONITORING", "Scanning " .. #instances_data .. " packages...")
            update_ui("IDLE", "Waiting for Roblox to open...")
        end
        
        os.execute("sleep 0.5")
    end
end

os.execute("sleep 2")

os.execute("su -c 'logcat -c'")

while true do
    local last_pkg = nil
    local success_flag = false
    for i = 1, 10 do
        update_ui("STARTING", "Searching for captcha (Attempt " .. i .. "/10)...")
        local status_result, detected_pkg = check_captcha_status()
        if detected_pkg then last_pkg = detected_pkg end

        if status_result then
            local blob_input = nil
            if type(status_result) == "string" then
                blob_input = status_result
            end
            
            if detected_pkg then
                local auto_cookie = get_roblox_cookie(detected_pkg)
                if auto_cookie then
                    WINTER_COOKIE = auto_cookie
                    update_ui("COOKIE", "Cookie loaded (" .. #auto_cookie .. " chars): " .. detected_pkg)
                else
                    update_ui("WARNING", "Failed to get cookie " .. detected_pkg)
                end
            end

            if WINTER_COOKIE == "" then
                update_ui("FAILED", "Cookie not found! Check Root/Login.")
                os.execute("sleep 5")
            else
                local token_hasil = solve_captcha(blob_input, detected_pkg)
                
                if token_hasil then
                    print("\nToken Final:\n" .. token_hasil)
                    success_flag = true
                    break
                else
                    update_ui("RETRYING", "Failed, retrying in 5 seconds...")
                    os.execute("sleep 5")
                end
            end
        end
        os.execute("su -c 'logcat -c'")
    end

    if success_flag then
        update_ui("SUCCESS", "Captcha solved! Returning to monitoring...")
        os.execute("su -c 'logcat -c'")
        os.execute("sleep 2")
    elseif last_pkg then
        update_ui("KILL", "Failed 10x. Force Stop " .. last_pkg .. "...")
        os.execute("su -c 'am force-stop " .. last_pkg .. "'")
        os.execute("sleep 2")
        update_ui("WAITING", "Please OPEN Roblox MANUALLY...")
    else
        update_ui("RESTART", "Failed 10x. Restarting monitoring loop...")
    end
    os.execute("sleep 2")
end
