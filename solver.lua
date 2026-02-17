-- Konfigurasi
-- Masukkan API Key WinterCode Anda di sini
WinterConfig = {
    ApiKey = "ISI_API_KEY_DISINI",
    PlaceId = 4483381587
}

print("❄️ Connecting...")
local url = "https://raw.githubusercontent.com/dvn-hub/solver/main/source.lua"
local handle = io.popen("curl -s -k " .. url)
local script = handle:read("*a")
handle:close()

if script and #script > 10 then
    load(script)()
else
    print("❌ Gagal download script!")
end
