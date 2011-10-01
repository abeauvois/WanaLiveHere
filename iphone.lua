--*********************************************************************************************

module(..., package.seeall)

local coronaui = require ("coronaui")
require ("gmap")
require("listAppts")

listBoxStart = display.statusBarHeight + 45
local price = 1200
local surface = 40

function loadMod()
	
	-- create a white background for the app "stage"
	local whiteBg = display.newRect( 0, 0, display.contentWidth, display.contentHeight )
	whiteBg:setFillColor( 255, 255, 255, 255 )
	
	-- forward references
	local myPanel, homeScr, listScr, scrollView, leftList, rightList, rowOfButtons
	
	-- listener for back button
	local backBtn_release = function( event )
		-- slide the button panel group out of view
		listScr:slideToRight(homeScr)
		-- slide the previous list back into view
		transition.to( myMap, { time=400, x=display.contentWidth/2, transition=easing.outLinear, nil } )
		--listScr:slideRight{ alpha=1.0 } --, onComplete=removeButton }	
		return true
	end
	
	local listBtn_release = function()
	-- {"type":"Appartement 1 chambre","aptlink":"/fr/paris/description/20211848-rue-poissonniere-appartement/",
	-- "aptid":20211848,"surface":16.0,"road":"Rue Poissonni\u00e8re , paris","floor":3.0,"price":840.0}


		homeScr:slideToLeft(listScr)
		transition.to( myMap, { time=500, x=-300, transition=easing.outLinear, nil } )
		--homeScr:slidetoLeft(listScr) --,onComplete=removeHome }
		-- remove status bar touch event from apiList:
		--apiList:removeStatusBarTouch()
	end

	local function gotoWeb(url)
		print(url)
	end
	
	local startApp = function()
		local tableRows
		local function onOffclick (event)
			print("click")
		end
		local function displayApptParams() 
			local selected=0
			for i=1,3 do 
				if homeScr.tableView.listItems[i+5].checkMark.isVisible then 
					local t=homeScr.tableView.listItems[i+5].labelText
					t:updateText(tableRows[i+5][3].."  "..price.." € "..surface.." m2")
					selected = i
				end
			end
		end

		local function choosePrice (event)
			--if event.item
			price = 400+event.value*40
			--homeScr.tableView.listItems[8].sliderControl.valueText:updateText(price.." €")
			--setMyLocation()
			--for x, v in pairs(homeScr.tableView.listItems[6]) do print(x, v) end
			--for x, v in pairs(homeScr.tableView.selectionTables["type1c"]) do print(x, v) end
			displayApptParams()
		end
		
		local function chooseSurface (event)
			surface = 9+event.value*2
			--homeScr.tableView.listItems[6]..valueText:updateText(surface.." m2")
			displayApptParams()
		end
		
		tableRows = {
		 { "nobg"},
		 { "nobg"},
		 { "nobg"},
		 { "nobg"},
		 { "nobg"},
		 --{ "nobg", "Multiple Selection:" },
		 { "multipleitemselection", "noicon","Studio", "Studio","type_appt","c" },
		 { "multipleitemselection", "noicon","1 chambre", "1 chambre","type_appt","c" },
		 { "multipleitemselection", "noicon","2 chambres", "2 chambres","type_appt","c" },
--		 { "whitebg", "noicon", "Critères" },
		 --{ "whitebg", "noicon", "Date", "12/25/2010", chooseDate },
		 --{ "whitebg", "myicon.png", "Example Item" },
		 --{ "whitebg", "noicon", "Loc ou achat ?","onOff", "on",onOffclick },
--		 { "nobg"},--,"surf"},
		 { "slider", 50, choosePrice,"Prix " },
		 { "slider", 50, chooseSurface,"Surf." },
		 -- { "nobg", "Surface" },
		 -- { "slider", 50,chooseSurface },

		 -- { "nobg", "Single Selection:" },
		 -- { "singleitemselection", "noicon", "Yes", "yes","myOtherID" },
		 -- { "singleitemselection", "noicon", "No", "no","myOtherID" }
		}
		
		homeScr = coronaui.newScreen( nil, true, "Wana Live Here", "stripes",false )
		homeScr:createTableList( tableRows)
		--homeScr.tableView.selectionTables["type_appt"][1]=tableRows[6][3]
		--homeScr.tableView.listItems[6].background:dispatchEvent{ name="touch", target=homeScr.tableView.listItems[6].background, phase="began"} 
		--for x, v in pairs(homeScr.tableView.listItems[6].checkMark) do print(x, v) end
		homeScr.tableView.listItems[6].checkMark.isVisible=true
		choosePrice({value=50})
		chooseSurface({value=50})
		getListAppts("http://82.247.10.128:3000/properties/2.json?type=")
		for i=1,#ListAppts do
			getmark(ListAppts[i])		
		end
		-- -- for x, v in pairs(homeScr.tableView.listItems[10].labelText.textObject) do
		-- -- 	print(x,v)
		-- -- 	 --for i, v1 in pairs(v) do print(i, v1) end
		-- -- end
		homeScr:addRightButton( "List",listBtn_release)

		listScr = coronaui.newScreen( nil, true, "List", "stripes",false )
		--screenGroup:newList( top, bottom, hasTitle, hasStatusBar, rowHeight, selectionList, fillColor, hideLines, tearEffect, scrollDisabled, customTitleHeight )	

		local lst=listScr:newList( 0, display.contentHeight , true, true, 60 )

		local apiListItems = {}
		local icon = {
			image = "anscaLogo.png",
			width = 32,
			height = 32,
			paddingTop = 12,
			paddingRight = 15
		}
		local item
		for i=1,#ListAppts do
			local road = string.gsub(ListAppts[i].road," , paris","")
			item = { title = road.." - "..ListAppts[i].price.."€ " , subtitle = ListAppts[i].type.." : "..ListAppts[i].surface.."m2 "..ListAppts[i].floor.."e étage", onTouch=gotoWeb(ListAppts[i].aptlink) } --! créer URL pour gotoweb = ListAppts[i].aptlink
			--table.insert( apiListItems, item )	
			--addItem( iconparams, mainTitle, subTitle, onTouch, hideArrow, isCategory, categoryBg, categoryHeight, categoryTextR, categoryTextG, categoryTextB )
			lst:addItem (icon,item.title, item.subtitle, item.onTouch, false)	
		end

		listScr.x=display.contentWidth

		listScr:addBackButton(backBtn_release)

	end
	
	local newSegmentedControl_release = function()
		
		-- change the app's toolbar label
		--!appToolbar.label = "Segmented Control"
		
		myPanel = display.newGroup()
		
		-- event listener for all the buttons
		local onBtnPress = function( event )
			print( "You pressed button #" .. event.target.id )
			
			local id = tonumber(event.target.id)
				
			if id == 1 then
				
			elseif id == 2 then
			
			elseif id == 3 then
				
			end
			
			return true
		end
		
		-- set up a table to hold button information
		local myButtons = {
			{ label="Map", onPress=onBtnPress, isDown=true },
			{ label="List", onPress=onBtnPress },
			{ label="...", onPress=onBtnPress }
		}
		
		-- set up the segmented control
		rowOfButtons = newSegmentedControl( myButtons )
		rowOfButtons:setReferencePoint( display.CenterReferencePoint )
		rowOfButtons.x = display.contentWidth * 0.5
		rowOfButtons.y = 100
		myPanel:insert( rowOfButtons.view )

		-- create back button
		local myButton3 = newButton{ label="Go Back", x=0, y=display.contentHeight - 75, default="customButton.png", over="customButton_over.png", onRelease=onButtonRelease }
		myButton3:setReferencePoint( display.CenterReferencePoint )
		myButton3.x = display.contentWidth * 0.5
		myPanel:insert( myButton3.view )

		-- position this panel to the right of current view
		myPanel.x = display.contentWidth
		
		-- slide the api list to the left
		apiList.view:slideLeft{ alpha=0 }
		
		-- slide the content of this new "panel" to the left
		myPanel:slideLeft{ slideAlpha=0, distance=display.contentWidth }
	end
	
	
	local newScrollView_release = function()
		
		-- change the app's toolbar label
		--!appToolbar.label = "ScrollView Widget"
		
		myPanel = display.newGroup()
		
		scrollView = newScrollView{ y=listBoxStart, height=320 }
		myPanel:insert( scrollView.view )	--> remember, you must remove scrollView manually
			
		-- create image (for scrolling)
		local scrollImage = display.newImageRect( "scrollimage.png", 320, 1024 )
		scrollImage:setReferencePoint( display.TopLeftReferencePoint )
		scrollImage.x, scrollImage.y = 0, 0
		scrollView:insert( scrollImage )
		
		-- create line to go underneath the scrollView
		local lineY = listBoxStart + 320 + 1
		local bottomLine = display.newLine( 0, lineY, display.contentWidth, lineY )
		bottomLine:setColor( 0, 0, 0, 255 )
		myPanel:insert( bottomLine )
		
		-- create back button
		local myButton3 = newButton{ label="Go Back", x=0, y=display.contentHeight - 75, default="customButton.png", over="customButton_over.png", onRelease=onButtonRelease }
		myButton3:setReferencePoint( display.CenterReferencePoint )
		myButton3.x = display.contentWidth * 0.5
		myPanel:insert( myButton3.view )
		
		-- position this panel to the right of current view
		myPanel.x = display.contentWidth
		
		-- slide the api list to the left
		apiList.view:slideLeft{ alpha=0 }
		
		-- slide the content of this new "panel" to the left
		myPanel:slideLeft{ slideAlpha=0, distance=display.contentWidth }
	end
	
	local newTableView_release = function()
		-- change the app's toolbar label
		--!appToolbar.label = "TableView Widgets"
		
		myPanel = display.newGroup()
		
		local itemData = {}
		local deleteButton
		
		-- onRelease event for each list item
		local helloWorld = function( event )
			print( "\"Hello\" from " .. event.target.titleText.text )
		end
		
		-- onSwipe event listener for individual list items
		local onSwipe = function( event )
			local listItem = event.target
			local swipeDirection = event.direction
			
			if swipeDirection == "left" then
				print( "You swiped '" .. listItem.titleText.text .. "' left!" )
				
				--leftList:deleteRow( event.target )
				
				local itemTarget = event.target
				
				local onDeleteRelease = function( event )
					leftList:deleteRow( itemTarget )
				end
				
				-- remove existing delete button (if it exists)
				display.remove( deleteButton )
				
				-- create a new delete button
				deleteButton = newButton{ label="Delete", buttonTheme="red", x=0, y=0, onRelease=onDeleteRelease }
				event.target.itemContent:insert( deleteButton.view )
				deleteButton.y = event.target.rowHeight * 0.5 - deleteButton.height * 0.5
				deleteButton.x = display.contentWidth - deleteButton.width - 10
				deleteButton.view:setReferencePoint( display.TopRightReferencePoint )
				deleteButton.view.xScale = 0.1
				
				transition.to( deleteButton.view, { xScale=1.0, time=100 } )
				
			elseif swipeDirection == "right" then
				print( "You swiped '" .. listItem.titleText.text .. "' right!" )
				
				-- remove existing delete button (if it exists)
				local removeButton = function()
					display.remove( deleteButton )
					deleteButton = nil
				end
				
				if deleteButton then
					deleteButton.view:setReferencePoint( display.TopRightReferencePoint )
					transition.to( deleteButton.view, { xScale=0.1, time=100, onComplete=removeButton } )
				end
			end
			
			return true
		end
		
		-- populate data table
		for i=1,50 do
			
			local item = {
				icon = {
					image = "anscaLogo.png",
					width = 32,
					height = 32,
					paddingTop = 12,
					paddingRight = 15
				},
				title = { label = "List Item #" .. i },
				subtitle = { label = "Desc text for #" .. i .. "..." },
				onRelease = helloWorld,
				onLeftSwipe = onSwipe,
				onRightSwipe = onSwipe,
				hideArrow = true
			}
			
			itemData[i] = item
		end
		
		-- add in some categories
		table.insert( itemData, 10, { categoryName="Category 1" } )
		table.insert( itemData, 25, { categoryName="Category 2" } )
		table.insert( itemData, 35, { categoryName="Category 3" } )
		
		-- create a tableView, and insert into the myPanel group
		leftList = newTableView{ y=listBoxStart, rowHeight=60, height=320, width=320, backgroundColor="none" }
		myPanel:insert( leftList.view )		--> remember, you must remove leftList manually
		
		-- sync both tableViews with data table
		leftList:sync( itemData )
		
		-- create line to go underneath the tableViews
		local lineY = listBoxStart + 320 + 1
		local bottomLine = display.newLine( 0, lineY, display.contentWidth, lineY )
		bottomLine:setColor( 0, 0, 0, 255 )
		myPanel:insert( bottomLine )
		
		-- create back button
		local myButton3 = newButton{ label="Go Back", x=0, y=display.contentHeight - 75, default="customButton.png", over="customButton_over.png", onRelease=onButtonRelease }
		myButton3:setReferencePoint( display.CenterReferencePoint )
		myButton3.x = display.contentWidth * 0.5
		myPanel:insert( myButton3.view )

		-- position this panel to the right of current view
		myPanel.x = display.contentWidth
		
		-- slide the api list to the left
		apiList.view:slideLeft{ alpha=0 }
		
		-- slide the content of this new "panel" to the left
		myPanel:slideLeft{ slideAlpha=0, distance=display.contentWidth }
	end

	local newPickerWheel_release = function()
		
		-- change the app's toolbar label
		--!appToolbar.label = "Picker Wheel"
		
		myPanel = display.newGroup()
		
		local dateText, isPickerShowing, myPicker
		
		-- create touchable text
		local dateText = display.newText( "Touch to Choose Date.", 0, 0, "HelveticaNeue-Bold", 22 )
		dateText:setTextColor( 0, 0, 0, 255 )
		dateText:setReferencePoint( display.CenterReferencePoint )
		dateText.x = display.contentWidth * 0.5
		dateText.y = 175
		myPanel:insert( dateText )
		
		-- touch listener for label (display.newText)
		function dateText:touch( event )
			if event.phase == "began" and not isPickerShowing then
				isPickerShowing = true
				
				local doneButton
				
				local onDone = function( event )
					
					-- get values from picker wheel
					local m = myPicker.col1.value
					local d = myPicker.col2.value
					local y = myPicker.col3.value
					
					if myPicker.col1.listItems then
						print( myPicker.col1.listItems[1].titleText.text )
					end
					
					-- Update label text
					dateText.text = m .. " " .. d .. ", " .. y	
					
					-- remove the button
					display.remove( doneButton )
					doneButton = nil
					
					-- remove the picker wheel
					display.remove( myPicker )
					myPicker = nil
					
					-- make date text touchable again
					isPickerShowing = false
				end
				
				doneButton = newButton{ label="Done", size=12, onRelease=onDone }
				doneButton:setReferencePoint( display.CenterRightReferencePoint )
				doneButton.x = display.contentWidth - 5
				doneButton.y = listBoxStart
				
				myPicker = newPickerWheel{ preset="usDate", startMonth="feb", startDay=19, startYear=2011 }
				myPicker.y = display.contentHeight - myPicker.height
			end
		end
		
		-- add touch listener to label text
		dateText:addEventListener( "touch", dateText )
		
		-- create back button
		local myButton3 = newButton{ label="Go Back", x=0, y=display.contentHeight - 75, default="customButton.png", over="customButton_over.png", onRelease=onButtonRelease }
		myButton3:setReferencePoint( display.CenterReferencePoint )
		myButton3.x = display.contentWidth * 0.5
		myPanel:insert( myButton3.view )
		
		-- position this panel to the right of current view
		myPanel.x = display.contentWidth
		
		-- slide the api list to the left
		--!apiList.view:slideLeft{ alpha=0 }
		apiListScr:slideLeft{ alpha=0 }
		-- slide the content of this new "panel" to the left
		myPanel:slideLeft{ slideAlpha=0, distance=display.contentWidth }
		
	end
	
	startApp()

end

--Runtime:addEventListener( "mapAddress", mapAddressHandler )