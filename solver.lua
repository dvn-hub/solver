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

if WinterConfig.ApiKey == "ISI_API_KEY_DISINI" then
    print("❌ ERROR: API Key belum diisi! Silakan edit file ini (solver.lua) dulu.")
    os.exit()
end

-------------------------------------------------------------------------------
-- LOADER SYSTEM (JANGAN DIUBAH DI BAWAH INI)
-------------------------------------------------------------------------------

print("❄️ Connecting to Winter Server...")

local GITHUB_RAW_URL = "https://raw.githubusercontent.com/dvn-hub/solver/refs/heads/main/source.lua"

local handle = io.popen("curl -s -k " .. GITHUB_RAW_URL)
local script_content = handle:read("*a")
handle:close()

if not script_content or script_content == "" then
    print("❌ Gagal mengambil script! Cek koneksi internet atau URL GitHub.")
    os.exit()
end

local chunk, err = load(script_content)
if chunk then
    chunk() -- Jalankan script yang didownload
else
    print("❌ Error pada script server: " .. tostring(err))
end
