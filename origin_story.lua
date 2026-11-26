-- Anime Card Online: compatibility loader for the previous script path.
local url="https://raw.githubusercontent.com/aquapy1075-blip/animecardclashscript/anime-card-online/anime_card_online.lua"
local source=game:HttpGet(url.."?v="..tostring(os.time()),true)
local run,err=loadstring(source)
assert(run,err)
return run()
