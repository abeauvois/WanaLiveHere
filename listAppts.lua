local json = require("json")
local http = require("socket.http")

ListAppts = {}
-- {"type":"Appartement 1 chambre","aptlink":"/fr/paris/description/20211848-rue-poissonniere-appartement/",
-- "aptid":20211848,"surface":16.0,"road":"Rue Poissonni\u00e8re , paris","floor":3.0,"price":840.0}

local function networkListener( event )
		if ( event.isError ) then
			myText.text = "Network error!"
		else
			local r=event.response:gsub("\u00e8","e") -- TODO All French ... unicodes
			myText.text = "See Corona Terminal for response"
			print ( "RESPONSE: " .. r)
			return json.decode(r)
		end
end

-- http.request( url, "GET", networkListener )
function getListAppts(url)
	if not url then url = "http://82.247.10.128:3000/properties/2.json" end --= "http://localhost:3000/properties/2.json" end
	print (currentAddress)
	local response, httpCode, header = http.request(url)

	if response == nil then
	    -- the httpCode variable contains the error message instead
	    print(httpCode)
		return
	end
	local r=response:gsub("\u00e8","e") -- TODO All French ... unicodes

	--//////////DEBUG
	print ( "RESPONSE: " .. r)
	ListAppts = json.decode(r)

end

--ListAppts={{"type","Appartement 1 chambre"},{"aptid",20211848},{"surface",16.0},{"road","Rue Poissonni\ere , paris"},{"floor",3.0},{"price",840.0}}