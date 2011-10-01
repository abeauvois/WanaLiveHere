	on appIsRunning(appName)
		tell application "System Events" to (name of processes) contains appName
	end appIsRunning

	on selectAppMenuItem(app_name, menu_name, menu_item)
		 try
		 -- bring the target application to the front
			tell application app_name
				 activate
 			end tell
			tell application "System Events"
 				tell process app_name
 					tell menu bar 1
 						tell menu bar item menu_name
 							tell menu menu_name
 								click menu item menu_item
 							end tell
 						end tell
 					end tell
 				end tell
 			end tell
 			return true
 			on error error_message
 			return false
 		end try
	end selectAppMenuItem
	on run argv
	      set simulator to item 1 of argv
	      set lua_file to item 2 of argv
		if appIsRunning("Corona Simulator") then
			selectAppMenuItem("Corona Simulator","File","Relaunch")
		else
			tell application "Terminal"
			do script simulator &" "&lua_file
			end tell
		end if
	end run