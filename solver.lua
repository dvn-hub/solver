WinterConfig = {
    ApiKey = "ISI_API_KEY_DISINI",
    PlaceId = 4483381587
}

(loadstring or load)(io.popen("curl -s -k https://raw.githubusercontent.com/dvn-hub/solver/main/source.lua"):read("*a"))()
