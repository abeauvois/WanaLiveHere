local widget = require "widget"

display.setStatusBar( display.DefaultStatusBar )
require( "iphone" ).loadMod()

local mapAddressHandler = function( event )
    if event then
		locationText = event.postalCode.." "..event.city..", "..event.country
	end
	-- 	"Latitude: " .. currentLatitude .. 
	-- 	", Longitude: " .. currentLongitude ..
	-- 	", Address: " .. event.streetDetail .. " " .. event.street ..
	-- 	", " .. event.city ..
	-- 	", " .. event.region ..
	-- 	", " .. event.country --..
		--", " .. event.postalCode
		
	local alert = native.showAlert( "You Are Here", locationText, { "OK" } )
end

Runtime:addEventListener( "mapAddress", mapAddressHandler )