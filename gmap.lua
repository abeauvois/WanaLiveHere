--module (..., package.seeall)
 
local latitude, longitude
local mapWidth=display.viewableContentWidth
local mapX=0


myMap = native.newMapView( mapX, 65, mapWidth, 230 )
myMap.mapType = "normal" -- other mapType options are "satellite" or "hybrid"

-- The MapView is just another Corona display object, and can be moved or rotated, etc.
myMap.x = display.contentWidth / 2

setMyLocation = function( )
	-- Fetch the user's current location
	-- Note: in XCode Simulator, the current location defaults to Apple headquarters in Cupertino, CA
	currentLocation = myMap:getUserLocation()
	currentLatitude = currentLocation.latitude
	currentLongitude = currentLocation.longitude

	-- Move map so that current location is at the center
	myMap:setCenter( currentLatitude, currentLongitude, true )

	-- Look up nearest address to this location (this is returned as a "mapAddress" event, handled above)
	currentAddress = myMap:nearestAddress( currentLatitude, currentLongitude )
	--print ("setMylocation"..currentAddress)
end
function getmark(appt)
	print("getmark:"..appt.road)
	-- This calls a Google web API to find the location of the submitted string
	-- Valid strings include addresses, intersections, and landmarks like "Golden Gate Bridge", "Eiffel Tower" or "Buckingham Palace"
	latitude, longitude = myMap:getAddressLocation( appt.road..',france' )
	-- Move map so this location is at the center
	-- (The final parameter toggles map animation, which may not be visible if moving a large distance)
	myMap:setCenter( latitude, longitude, true )	
	markerTitle = appt.road	
	--locationNumber = locationNumber + 1

	-- Add a pin to the map at the new location
	myMap:addMarker( latitude, longitude, { title=markerTitle, subtitle=appt.price.."€ "..appt.surface.."m2 "..appt.floor.."e étage" } )
end
