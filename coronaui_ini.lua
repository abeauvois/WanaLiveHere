module(..., package.seeall)

--*********************************************************************************************
--
-- coronaui.lua
--
-- Version 1.0
--
-- Copyright (C) 2010 ANSCA Inc. All Rights Reserved.
--
-- Permission is hereby granted, free of charge, to any person obtaining a copy of 
-- this software and associated documentation files (the "Software"), to deal in the 
-- Software without restriction, including without limitation the rights to use, copy, 
-- modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, 
-- and to permit persons to whom the Software is furnished to do so, subject to the 
-- following conditions:
-- 
-- The above copyright notice and this permission notice shall be included in all copies 
-- or substantial portions of the Software.
-- 
-- THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, 
-- INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR 
-- PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE 
-- FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR 
-- OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER 
-- DEALINGS IN THE SOFTWARE.

--
-- Unofficial Version 1.1 Updatd Picker to return nil if the user selects cancel
-- keith foster - april 2011
-- Based on the work previous baseline.
-- Original from https://developer.anscamobile.com/code/ui-library
--
--
-- Unofficial Version 1.2 Updatd Picker to support single window custom objects
-- keith foster - june 2011
--
-- Unofficial Version 1.3 Updatd Slider to have an integer and/or text output to an event
--	listener.
-- keith foster - june 2011




currentScreen = nil
lastScreen = nil
currentPicker = nil

local contentH = display.contentHeight

local scrollView = require("coronaui_scrollView")
local pickerScroller = require("coronaui_pickerscrollView")
local daypickerScroller = require("coronaui_daypickerscrollView")
local yearpickerScroller = require("coronaui_yearpickerscrollView")
local ui = require( "coronaui_ui" )
local mc = require( "coronaui_movieclip" )
local mFloor = math.floor

-- ======================================================================================
-- 
-- XML Stuff
--
-- ======================================================================================

function newXmlParser()
	
	local XmlParser = {}
	
	function XmlParser:ToXmlString(value)
		value = string.gsub (value, "&", "&amp;");		-- '&' -> "&amp;"
		value = string.gsub (value, "<", "&lt;");		-- '<' -> "&lt;"
		value = string.gsub (value, ">", "&gt;");		-- '>' -> "&gt;"
		--value = string.gsub (value, "'", "&apos;");	-- '\'' -> "&apos;"
		value = string.gsub (value, "\"", "&quot;");	-- '"' -> "&quot;"
		-- replace non printable char -> "&#xD;"
		value = string.gsub(value, "([^%w%&%;%p%\t% ])",
			function (c) 
				return string.format("&#x%X;", string.byte(c)) 
				--return string.format("&#x%02X;", string.byte(c)) 
				--return string.format("&#%02d;", string.byte(c)) 
			end);
		return value;
	end
	
	function XmlParser:FromXmlString(value)
		value = string.gsub(value, "&#x([%x]+)%;",
			function(h) 
				return string.char(tonumber(h,16)) 
			end);
		value = string.gsub(value, "&#([0-9]+)%;",
			function(h) 
				return string.char(tonumber(h,10)) 
			end);
		value = string.gsub (value, "&quot;", "\"");
		value = string.gsub (value, "&apos;", "'");
		value = string.gsub (value, "&gt;", ">");
		value = string.gsub (value, "&lt;", "<");
		value = string.gsub (value, "&amp;", "&");
		return value;
	end
	   
	function XmlParser:ParseArgs(s)
	  local arg = {}
	  string.gsub(s, "(%w+)=([\"'])(.-)%2", function (w, _, a)
			arg[w] = self:FromXmlString(a);
		end)
	  return arg
	end
	
	function XmlParser:ParseXmlText(xmlText)
	  local stack = {}
	  local top = {Name=nil,Value=nil,Attributes={},ChildNodes={}}
	  table.insert(stack, top)
	  local ni,c,label,xarg, empty
	  local i, j = 1, 1
	  while true do
		ni,j,c,label,xarg, empty = string.find(xmlText, "<(%/?)([%w:]+)(.-)(%/?)>", i)
		if not ni then break end
		local text = string.sub(xmlText, i, ni-1);
		if not string.find(text, "^%s*$") then
		  top.Value=(top.Value or "")..self:FromXmlString(text);
		end
		if empty == "/" then  -- empty element tag
		  table.insert(top.ChildNodes, {Name=label,Value=nil,Attributes=self:ParseArgs(xarg),ChildNodes={}})
		elseif c == "" then   -- start tag
		  top = {Name=label, Value=nil, Attributes=self:ParseArgs(xarg), ChildNodes={}}
		  table.insert(stack, top)   -- new level
		  --print("openTag ="..top.Name);
		else  -- end tag
		  local toclose = table.remove(stack)  -- remove top
		  --print("closeTag="..toclose.Name);
		  top = stack[#stack]
		  if #stack < 1 then
			error("XmlParser: nothing to close with "..label)
		  end
		  if toclose.Name ~= label then
			error("XmlParser: trying to close "..toclose.Name.." with "..label)
		  end
		  table.insert(top.ChildNodes, toclose)
		end
		i = j+1
	  end
	  local text = string.sub(xmlText, i);
	  if not string.find(text, "^%s*$") then
		  stack[#stack].Value=(stack[#stack].Value or "")..self:FromXmlString(text);
	  end
	  if #stack > 1 then
		error("XmlParser: unclosed "..stack[stack.n].Name)
	  end
	  return stack[1].ChildNodes[1];
	end
	
	function XmlParser:ParseXmlFile(xmlFileName)
		local path = system.pathForFile( xmlFileName, system.ResourcesDirectory )
		local hFile = io.open(path,"r");
		
		if hFile then
			local xmlText=hFile:read("*a"); -- read file content
			io.close(hFile);
			return self:ParseXmlText(xmlText),nil;
		else
			return nil
		end
	end
	
	return XmlParser
end

-- ======================================================================================
-- 
-- hex2rgb converts an html color code to rgb (ex. FFFFFF = white, 000000 = black)
--
-- ======================================================================================

local hex2rgb = function(sHexString)
	if string.len(sHexString) ~= 6 then
		return 0,0,0
	else
		red = string.sub( sHexString, 1, 2 )
		green = string.sub( sHexString, 3, 4 )
		blue = string.sub( sHexString, 5, 6 )
		red = tonumber(red, 16).."";
		green = tonumber(green, 16).."";
		blue = tonumber(blue, 16).."";
		return red, green, blue
	end
end

-- ======================================================================================
-- 
-- cleanGroups() removes all display objects within a group, and within children groups
--
-- ======================================================================================

local coronaMetaTable = getmetatable(display.getCurrentStage())
 
local isDisplayObject = function(aDisplayObject)
	return (type(aDisplayObject) == "table" and getmetatable(aDisplayObject) == coronaMetaTable)
end

local function cleanGroups( objectOrGroup )
    if(not isDisplayObject(objectOrGroup)) then return end
    
    if objectOrGroup.numChildren then
		-- we have a group, so first clean that out
		while objectOrGroup.numChildren > 0 do
			-- clean out the last member of the group (work from the top down!)
			cleanGroups ( objectOrGroup[objectOrGroup.numChildren])
		end
    end
    
    -- check if object/group has an attached touch listener
    if objectOrGroup.touch then
    	objectOrGroup:removeEventListener( "touch", objectOrGroup )
    	objectOrGroup.touch = nil
    end
    
    -- check to see if this object has any attached
	-- enterFrame listeners via object.enterFrame or
	-- object.repeatFunction
	if objectOrGroup.enterFrame then
		Runtime:removeEventListener( "enterFrame", objectOrGroup )
		objectOrGroup.enterFrame = nil
	end
	
	if objectOrGroup.repeatFunction then
		Runtime:removeEventListener( "enterFrame", objectOrGroup )
		objectOrGroup.repeatFunction = nil
	end
    
    -- we have either an empty group or a normal display object - remove it
  	objectOrGroup:removeSelf()
    
    return
end

--===================================================================================
--
-- Retina Display Text (sharp text for iPhone4 retina displays AND older displays)
--
--===================================================================================

function newRetinaText( textString, x, y, fontName, fontSize, r, g, b, alignment, embossOn, parentGroup )
	
	local textGroup = display.newGroup()
	local doubleSize
	
	if not textString then textString = "Text"; end
	if not x then x = display.contentWidth * 0.5; end
	if not y then y = display.contentHeight * 0.5; end
	if not fontName then fontName = "Helvetica"; end
	if not fontSize then fontSize = 40; doubleSize = fontSize; else doubleSize = fontSize * 2; end
	if not r then r = 255; end
	if not g then g = 255; end
	if not b then b = 255; end
	if not alignment then alignment = "center"; end
	
	local labelHighlight
	local labelShadow
	local labelText
	
	if embossOn then
		-- Make the label text look "embossed" (also adjusts effect for textColor brightness)
		local textBrightness = ( r + g + b ) / 3
		
		labelHighlight = display.newText( textString, x, y, fontName, doubleSize )
		if ( textBrightness > 127) then
			labelHighlight:setTextColor( 255, 255, 255, 20 )
		else
			labelHighlight:setTextColor( 255, 255, 255, 140 )
		end
		
		labelHighlight.x = labelHighlight.x + 1.5; labelHighlight.y = labelHighlight.y + 1.5
	
		labelShadow = display.newText( textString, x, y, fontName, doubleSize )
		if ( textBrightness > 127) then
			labelShadow:setTextColor( 0, 0, 0, 128 )
		else
			labelShadow:setTextColor( 0, 0, 0, 20 )
		end
		
		labelShadow.x = labelShadow.x - 1; labelShadow.y = labelShadow.y - 1
		
		labelHighlight.xScale = 0.5; labelHighlight.yScale = 0.5
		labelShadow.xScale = 0.5; labelShadow.yScale = 0.5
		
		textGroup.highlight = labelHighlight
		textGroup.shadow = labelShadow
		
		textGroup:insert( textGroup.highlight, true )
		textGroup:insert( textGroup.shadow, true )
	end
	
	local textObject = display.newText( textString, x, y, fontName, doubleSize )
	textObject:setTextColor( r, g, b, 255 )
	textObject.text = textString
	textObject.xScale = 0.5; textObject.yScale = 0.5
	
	textObject.defaultX = x
	textObject.defaultY = y
	
	--textObject.isVisible = false
	
	if alignment == "left" then
		textObject.x = x + ( textObject.contentWidth * 0.5 )
		if embossOn then
			labelHighlight.x = textObject.x
			labelHighlight.x = labelHighlight.x + 1.5; labelHighlight.y = labelHighlight.y + 1.5
			labelShadow.x = textObject.x
			labelShadow.x = labelShadow.x - 1; labelShadow.y = labelShadow.y - 1
		end
	elseif alignment == "center" then
		textObject.x = x
		if embossOn then
			labelHighlight.x = textObject.x
			labelHighlight.x = labelHighlight.x + 1.5; labelHighlight.y = labelHighlight.y + 1.5
			labelShadow.x = textObject.x
			labelShadow.x = labelShadow.x - 1; labelShadow.y = labelShadow.y - 1
		end
	elseif alignment == "right" then
		textObject.x = x - ( textObject.contentWidth * 0.5 )
		if embossOn then
			labelHighlight.x = textObject.x
			labelHighlight.x = labelHighlight.x + 1.5; labelHighlight.y = labelHighlight.y + 1.5
			labelShadow.x = textObject.x
			labelShadow.x = labelShadow.x - 1; labelShadow.y = labelShadow.y - 1
		end
	end
	
	textObject.y = y
	
	textGroup.textObject = textObject
	textGroup:insert( textGroup.textObject )
	
	if parentGroup and type(parentGroup) == "table" then
		parentGroup:insert( textGroup )
	end
	
	--
	
	-------------------------------------------------------------------------
	--
	-------------------------------------------------------------------------
	
	function textGroup:getTextString()
		local textString = self.textObject.text
		
		return textString
	end
	
	--
	
	-------------------------------------------------------------------------
	--
	-------------------------------------------------------------------------
	
	function textGroup:updateText( textString )
		if not textString then textString = self.textObject.text; end
		
		self.textObject.text = textString
		self.textObject.xScale = 0.5; self.textObject.yScale = 0.5
		
		if self.highlight then
			self.highlight.text = textString
			self.highlight.xScale = 0.5; self.highlight.yScale = 0.5
		end
		
		if self.shadow then
			self.shadow.text = textString
			self.shadow.xScale = 0.5; self.shadow.yScale = 0.5
		end
		
		if alignment == "left" then
			self.textObject.x = self.textObject.defaultX + ( self.textObject.contentWidth * 0.5 )
			
			if self.highlight and self.shadow then
				self.highlight.x = self.textObject.x
				self.highlight.x = self.highlight.x + 1.5; self.highlight.y = self.highlight.y + 1.5
				self.shadow.x = self.textObject.x
				self.shadow.x = self.shadow.x - 1; self.shadow.y = self.shadow.y - 1
			end
			
		elseif alignment == "center" then
			self.textObject.x = self.textObject.defaultX
			if self.highlight and self.shadow then
				self.highlight.x = self.textObject.x
				self.highlight.x = self.highlight.x + 1.5; self.highlight.y = self.highlight.y + 1.5
				self.shadow.x = self.textObject.x
				self.shadow.x = self.shadow.x - 1; self.shadow.y = self.shadow.y - 1
			end
			
		elseif alignment == "right" then
			self.textObject.x = self.textObject.defaultX - ( self.textObject.contentWidth * 0.5 )
			
			if self.highlight and self.shadow then
				self.highlight.x = self.textObject.x
				self.highlight.x = self.highlight.x + 1.5; self.highlight.y = self.highlight.y + 1.5
				self.shadow.x = self.textObject.x
				self.shadow.x = self.shadow.x - 1; self.shadow.y = self.shadow.y - 1
			end
		end
		
		self.textObject.y = self.textObject.defaultY
		
		if self.highlight and self.shadow then
			self.highlight.y = self.textObject.defaultY
			self.shadow.y = self.textObject.defaultY
		end
	end
	
	return textGroup
end

--

-- ======================================================================================
--
-- ======================================================================================

function newOnOffSwitch( x, y, startingValue )
	-- Staring value can either be "on" or "off"
	
	-- declare groups
	local onOffSwitch = display.newGroup()	--> holds entire switch
	
	print("hello there......")
	
	-- START DEFAULT VAUES:
	
	if not x then x = 0; end
	if not y then y = 0; end
	
	if not startingValue then
		onOffSwitch.value = "on"
	else
		onOffSwitch.value = startingValue
	end
	
	-- // END DEFAULT VALUES
	
	-- create the actual on/off switch graphic
	local onOffSwitchGraphic = display.newImageRect( "coronaui_onoffslider.png", 156, 36 )
	
	-- if onOffSwitch is set to "off", change it's position
	if onOffSwitch.value == "off" then
		onOffSwitchGraphic.x = -54
	end
	
	onOffSwitchGraphic.prevPos = onOffSwitchGraphic.x
	
	onOffSwitch:insert( onOffSwitchGraphic )
	
	-- create a bitmap mask and set it on the whole group
	local onOffMask = graphics.newMask( "coronaui_onoffslidermask.png" )
	onOffSwitch:setMask( onOffMask )
	
	onOffSwitch.maskScaleX, onOffSwitch.maskScaleY = .5, .5
	
	-- START TOUCH LISTENER FOR ACTUAL ON/OFF SLIDER:
	
	function onOffSwitchGraphic:touch( event )
		if event.phase == "began" then
			
			display.getCurrentStage():setFocus( self )
			self.isFocus = true
			
			print("began")
			
			self.delta = 0
		
		elseif( self.isFocus ) then
			if event.phase == "moved" then
				
				--self.x = event.x - event.xStart
				self.delta = event.x - self.prevPos
				self.prevPos = event.x
				
				print("moved..")
				
				self.x = self.x + self.delta
				
				if self.x < -54 then self.x = -54; end
				if self.x > 0 then self.x = 0; end
			
			elseif event.phase == "ended" or event.phase == "cancelled" then
				display.getCurrentStage():setFocus( nil )
				self.isFocus = false
				
				if self.tween then transition.cancel( self.tween ); self.tween = nil; end
				
				print("ended")
				local assessSwitch = function()
					if self.x > -23 then
						self.parent.value = "on"
					else
						self.parent.value = "off"
					end
				end
				
				if self.parent.value == "off" then
					self.tween = transition.to( self, { time=200, x=0, transition=easing.outQuad, onComplete=assessSwitch } )
				else
					self.tween = transition.to( self, { time=200, x=-54, transition=easing.outQuad, onComplete=assessSwitch } )
				end
			end
		end
	end
	
	onOffSwitchGraphic:addEventListener( "touch", onOffSwitchGraphic )
	
	-- // END TOUCH LISTENER FOR ON/OFF SLIDER
	
	-- finally, position entire group:
	onOffSwitch.x = x
	onOffSwitch.y = y
	
	return onOffSwitch
end

-- ======================================================================================
--
-- ======================================================================================

function newSliderControl( x, y, startingValue, callbackListener )
	-- Staring value is a value between 1-100
	
	-- declare groups
	local sliderControl = display.newGroup()	--> holds entire switch
	local maskGroup = display.newGroup()		--> will mask everything within
	
	sliderControl:insert( maskGroup )
	
	-- START DEFAULT VAUES:
	
	if not x then x = display.contentWidth * 0.5; end
	if not y then y = display.contentHeight * 0.5; end
	
	if not startingValue then
		sliderControl.value = 50
	else
		sliderControl.value = startingValue
	end
	
	-- // END DEFAULT VALUES
	
	-- create the actual on/off switch graphic
	local sliderGraphic = display.newImageRect( "coronaui_slider.png", 480, 28 )
	
	-- determine position and adjust accordingly
	local pixelPosition = ((sliderControl.value * 220) / 100) - 110
	sliderGraphic:setReferencePoint( display.CenterReferencePoint )
	sliderGraphic.x = pixelPosition
	
	maskGroup:insert( sliderGraphic )
	
	-- create the slider handle
	local sliderHandle = display.newImageRect( "coronaui_sliderhandle.png", 480, 28 )
	
	-- determine position and adjust accordingly
	sliderHandle:setReferencePoint( display.CenterReferencePoint )
	sliderHandle.x = pixelPosition
	
	sliderControl:insert( sliderHandle )
	sliderControl.handle = sliderHandle
	
	-- create a bitmap mask and set it on the whole group
	local sliderMask = graphics.newMask( "coronaui_slidermask.png" )
	maskGroup:setMask( sliderMask )
	maskGroup.maskScaleX, maskGroup.maskScaleY = .5, .5
	
	-- START TOUCH LISTENER FOR ACTUAL SLIDER CONTROL:
	
	function sliderGraphic:touch( event )
		if event.phase == "began"  and event.y > 64 then
			display.getCurrentStage():setFocus( self )
			self.isFocus = true
			
			theParent = self.parent.parent
			self.x = event.x - 160
			theParent.handle.x = self.x
			
			if self.x < -110 then self.x = -110; theParent.handle.x = self.x; end
			if self.x > 111 then self.x = 111; theParent.handle.x = self.x; end
			
			-- adjust value depending on where slider control was touched
			if self.x > -112 and self.x < 112 then
				local newValue = mFloor((((112 + self.x) * 100) / 220))
				theParent.value = newValue
				
				if theParent.value < 0 then theParent.value = 0; end
				if theParent.value > 100 then theParent.value = 100; end
				
				--print( theParent.value )
			end
			
		elseif event.phase == "moved" and self.isFocus then
			
			local theParent = self.parent.parent
			
			self.x = event.x - 160
			theParent.handle.x = self.x
			
			-- keep it within slider bounds
			if self.x < -110 then self.x = -110; theParent.handle.x = self.x; end
			if self.x > 111 then self.x = 111; theParent.handle.x = self.x; end
			
			-- change value as slider is moved
			if self.x > -112 and self.x < 112 then
				local newValue = mFloor((((112 + self.x) * 100) / 220))
				theParent.value = newValue
				
				if theParent.value < 0 then theParent.value = 0; end
				if theParent.value > 100 then theParent.value = 100; end
				
				--print( theParent.value )
			end
			
			-- call the listener (if it exists)
			if callbackListener and type( callbackListener ) == "function" then
				local theEvent = {
					value = theParent.value
				}
				callbackListener( theEvent )
			end
			
		elseif event.phase == "ended" or event.phase == "cancelled" and self.isFocus then
			display.getCurrentStage():setFocus( nil )
			self.isFocus = false
			
		end
	end
	
	sliderGraphic:addEventListener( "touch", sliderGraphic )
	
	-- // END TOUCH LISTENER FOR SLIDER CONTROL
	
	-- finally, position entire group:
	sliderControl.x = x
	sliderControl.y = y
	
	return sliderControl
end

--

-- ======================================================================================
--
-- ======================================================================================

function newCustomPicker( customData, startKey, callbackListener )
	if customData and type(customData) == "table" then
		local numItems = #customData
		local jsonString = "var customItems = { "
		local i = 1
		local path = system.pathForFile( "wheeldata.json", system.TemporaryDirectory )
		local tempFile = io.open( path, "w+" )
		
		for i=1,numItems,1 do
			if i == numItems then
				jsonString = jsonString .. i .. ": '" .. customData[i] .. "'"
			else
				jsonString = jsonString .. i .. ": '" .. customData[i] .. "', "
			end
		end
		
		jsonString = jsonString .. " }"
		
		tempFile:write( jsonString )
		io.close( tempFile )
		
		-- listener for web popup:
		local urlListener = function( event )
			local shouldLoad = true

			local url = event.url
			if string.find( url, "corona:close" ) == 1 then
				-- First get the value of selected item according to key passed from url var:
				local selectedKey, selectedValue
				local selValLoc = string.find( url, "?=" )
				
				if selValLoc then
					selValLoc = selValLoc + 2
					
					selectedKey = tonumber( string.sub( url, selValLoc ) )
					selectedValue = customData[selectedKey]
					
					local theEvent = {
						key = selectedKey,
						value = tostring( selectedValue )
					}
					
					callbackListener( theEvent )
				end
				
				-- Close the web popup
				shouldLoad = false
			end
		
			return shouldLoad
		end
		
		-- show the webpopup with custom picker
		local wheelUrl = "coronaui_wheel.html?type=custom&" .. "startkey=" .. tostring(startKey) .. "&json=" .. tostring( path )
		native.showWebPopup( wheelUrl, { baseUrl=system.ResourceDirectory, hasBackground=false, urlRequest=urlListener } )
	end
end

--

-- ======================================================================================
--
-- ======================================================================================

function newTimePicker( startHour, startMinute, startAmPm, callbackListener )		
	-- listener for web popup:
	local urlListener = function( event )
		local shouldLoad = true

		local url = event.url
		if string.find( url, "corona:close" ) == 1 then
			-- First get the value of selected item according to key passed from url var:
			--[[
			local selectedKey, selectedValue
			local selValLoc = string.find( url, "?=" )
			
			if selValLoc then
				selValLoc = selValLoc + 2
				
				selectedKey = tonumber( string.sub( url, selValLoc ) )
				selectedValue = customData[selectedKey]
				
				local theEvent = {
					key = selectedKey,
					value = tostring( selectedValue )
				}
				
				if callbackListener then
					callbackListener( theEvent )
				end
			end
			]]--
			
			local startingLoc = string.find( url, "?" )
			startingLoc = startingLoc + 1

			url = string.sub( url, startingLoc )
			
			local unescape = function(s)
			  s = string.gsub(s, "+", " ")
			  s = string.gsub(s, "%%(%x%x)", function (h)
					return string.char(tonumber(h, 16))
				  end)
			  return s
			end
			
			local urlVars = {}
			local decode = function(s)
			  for name, value in string.gfind(s, "([^&=]+)=([^&=]+)") do
				name = unescape(name)
				value = unescape(value)
				urlVars[name] = value
			  end
			end
			
			decode(url)
			
			local theHour = urlVars['hour']
			local theMinute = urlVars['minute']
			local theAmPm = urlVars['ampm']
			
			local theEvent = {
				hour = theHour,
				minute = theMinute,
				ampm = theAmPm
			}
			
			if callbackListener then
				callbackListener( theEvent )
			end
			
			-- Close the web popup
			shouldLoad = false
		end
	
		return shouldLoad
	end
	
	-- show the webpopup with custom picker
	local wheelUrl = "coronaui_wheel.html?type=time"
	native.showWebPopup( wheelUrl, { baseUrl=system.ResourceDirectory, hasBackground=false, urlRequest=urlListener } )
end

-- ======================================================================================
--
-- ======================================================================================

function newSearchScreen( listObjectToSearch, backScreen, startVisible, width, customTitleBg, customBackImg, customBackWidth, customBackHeight, customBackOver )
	local list = listObjectToSearch
	local rowHeight = list.rowHeight
	
	if not width then width = display.contentWidth; end
	
	-- remove event listeners from list object
	list:removeListeners()
	
	-- create the screen object
	local searchScreen = newScreen( width, true, "Search", "white", false, customTitleBg )
	
	-- create a blank list (that will hold search results)
	local resultsList = searchScreen:newList( 44, 0, true, true, list.rowHeight )
	resultsList.upperLimit = resultsList.upperLimit + 44
	--searchScreen.results = resultsList
	
	--For testing: local resultsList = searchScreen:copyFromList( list, searchScreen, true, false )
	
	-- create search bar at the top
	local searchBar = display.newImageRect( "coronaui_searchpanelbg.png", width, 44 )
	searchBar:setReferencePoint( display.TopCenterReferencePoint )
	searchBar.x = width * 0.5
	searchBar.y = 64
	searchScreen:insertUnderTitle( searchBar )
	
	-- create fake input box
	local fakeInput = display.newImageRect( "coronaui_searchpanelinput.png", width, 44 )
	fakeInput:setReferencePoint( display.TopCenterReferencePoint )
	fakeInput.x = width * 0.5
	fakeInput.y = 64
	searchScreen:insertUnderTitle( fakeInput )
	
	local searchBox, shadeRect
	
	--[[
	for i=1,20,1 do
		resultsList:addItem( { icon="none" }, "Test", "Test Description" )
	end
	]]--
	
	local endSearch = function()
		
		-- input box stuff
		if searchBox then
			-- store text as searchString
			if not isEditing then
			
				-- remove the textfield
				searchBox:removeSelf()
				searchBox = nil
			end
			
			-- remove shade rect
			shadeRect:removeSelf()
			shadeRect = nil
		end
		
		fakeInput.isVisible = true
		-- end input box stuff
		
	end
	
	-- fieldHandler() will determine what to do with inputted text
	local fieldHandler = function( event )
		if event.phase == "submitted" then
			endSearch()
			
		elseif event.phase == "editing" then
			local searchString = string.lower( tostring( event.oldString ) ) .. string.lower( tostring( event.newCharacters ) )
			
			-- first, clear previous list
			resultsList:removeAllItems()
			shadeRect.isVisible = true
			
			if searchString ~= "" then
				shadeRect.isVisible = false
				local numItems = #list.listItems
				local i
				
				-- go through each item and find search string in
				-- either the title and/or subtitle (if applicable)
				for i=1,numItems,1 do
					local listItem = list.listItems[i]
					
					local isMatch = false
					
					-- check for search string in titleText
					if not listItem.isCategory then
						if listItem.titleText then
							local titleText = string.lower( listItem.titleText:getTextString() )
							
							if string.find( titleText, searchString ) then
								isMatch = true
							end
						end
						
						-- check for search string in subtitleText
						if listItem.subtitleText then
							local subtitleText = string.lower( listItem.subtitleText:getTextString() )
							
							if string.find( subtitleText, searchString ) then
								isMatch = true
							end
						end
					end
					
					-- if this item was a match, add it to resultsList
					if isMatch then
						local iconparams = {}
						local titleText, subtitleText, eventListener = "", "", nil
						
						if not listItem.iconName then
							iconparams = { icon="none" }
						else
							iconparams = {
								icon=listItem.iconName,
								width=listItem.iconWidth,
								height=listItem.iconHeight
							}
						end
						
						if listItem.titleText.textObject then
							titleText = listItem.titleText:getTextString()
						end
						
						if listItem.subtitleText.textObject then
							subtitleText = listItem.subtitleText:getTextString()
						end
						
						if listItem.myEvent then
							eventListener = listItem.myEvent
						end
						
						-- add new list item
						resultsList:addItem( iconparams, titleText, subtitleText, eventListener, false )
						resultsList:removeListeners()
					end
				end
			end
		end
	end
	
	-- create input box and show native keyboard
	local createSearchBox = function()
		searchBox = native.newTextField( 8, 74, width - 15, 27, fieldHandler )
		--searchBox.font = native.newFont( "Helvetica", 14 )
		searchBox:setReferencePoint( display.TopLeftReferencePoint )
		searchBox.x = 8; searchBox.y = 74
		
		-- create shade rectangle and monitor for touch events
		shadeRect = display.newRect( 0, 0, width, display.contentHeight )
		shadeRect:setFillColor( 0, 0, 0, 128 )
		
		searchScreen:insertUnderTitle( shadeRect )
		searchScreen:insertUnderTitle( searchBar )
		searchScreen:insertUnderTitle( fakeInput )
		
		function shadeRect:touch( event )
			if event.phase == "began" then
				native.setKeyboardFocus( nil )
				searchBox:removeSelf()
				searchBox = nil
				
				fakeInput.isVisible = true
				
				self:removeSelf()
				self = nil
			end
		end
		
		shadeRect:addEventListener( "touch", shadeRect )
	end
	
	function fakeInput:touch( event )
		if event.phase == "began" then
			self.isVisible = false
			
			if not searchBox then
				createSearchBox()
				native.setKeyboardFocus( searchBox )
			end
		end
	end
	
	fakeInput:addEventListener( "touch", fakeInput )
	
	-- add back button to search screen
	local gotoLastScreen = function( event )
		if event.phase == "release" then
			-- hide keyboard if it is visible
			native.setKeyboardFocus( nil )
			
			-- remove searchbox input field if it exists
			if searchBox then
				searchBox:removeSelf(); searchBox = nil
				
				if shadeRect then
					shadeRect:removeSelf(); shadeRect = nil
				end
				
				fakeInput.isVisible = true
			end
			
			-- re-activate enterframe listener for list object
			list:addListeners()
			
			local removeSearchScreen = function()
				resultsList:removeAllItems()
				resultsList:removeSelf()
				
				searchScreen:cleanUp()
				searchScreen = nil
			end
			
			-- go to specified "back to" screen
			searchScreen:slideToRight( backScreen, removeSearchScreen )
		end
	end
	searchScreen:addBackButton( gotoLastScreen, customBackImg, customBackWidth, customBackHeight, customBackOver )
	
	-- check to see if user wants search screen to start off visible (default: false)
	if startVisible then
		searchScreen.isVisible = true
	else
		searchScreen.isVisible = false
	end
	
	return searchScreen
end

--

-- ======================================================================================
--
-- ======================================================================================

function createButton( params )
	local x = params.x
	local y = params.y
	local width = params.width
	local onEvent = params.onEvent
	local id = params.id
	local textString = params.text
	local font = params.font
	local textColor = params.textColor
	local fontSize = params.size
	local embossOn = params.emboss
	
	local defaultSrc = params.imageFile
	local defaultWidth = params.buttonWidth
	local defaultHeight = params.buttonHeight
	local overSrc = params.overImage
	local overWidth = defaultWidth
	local overHeight = defaultHeight
	
	local buttonLeft = params.imageLeft
	local buttonMid = params.imageMid
	local buttonRight = params.imageRight
	local overLeft = params.overLeft
	local overMid = params.overMid
	local overRight = params.overRight
	
	local tabLeft = params.tabLeft
	local tabRight = params.tabRight
	local tabOverLeft = params.tabOverLeft
	local tabOverRight = params.tabOverRight
	
	local theButton = ui.newButton{
		defaultSrc = defaultSrc,
		defaultX = defaultWidth,
		defaultY = defaultHeight,
		overSrc = overSrc,
		overX = overWidth,
		overY = overHeight,
		imageLeft = buttonLeft,
		imageMid = buttonMid,
		imageRight = buttonRight,
		overLeft = overLeft,
		overMid = overMid,
		overRight = overRight,
		tabLeft = tabLeft,
		tabRight = tabRight,
		tabOverLeft = tabOverLeft,
		tabOverRight = tabOverRight,
		width = width,
		onEvent = onEvent,
		id = id,
		text = textString,
		font = font,
		textColor = textColor,
		size = fontSize,
		emboss = embossOn,
		x = x,
		y = y,
		isLeftTab = params.isLeftTab,
		isRightTab = params.isRightTab,
		isMidTab = params.isMidTab
	}
	
	return theButton
end

--

-- ======================================================================================
--
-- ======================================================================================

function createTabs( buttonsTable, x, y, customLeft, customMid, customRight, customOverLeft, customOverMid, customOverRight, tabLeft, tabRight, tabOverLeft, tabOverRight )
	if buttonsTable then
		-- example row: { "Button Text", width, eventHandler },
		
		local tabGroup = display.newGroup()
		tabGroup.buttonsList = {}
		tabGroup.myName = "tabGroup"
		
		local i
		local numRows = #buttonsTable
		local buttonWidth, lastWidth, nextX = nil, 0, 0
		
		local imageLeft = customLeft
		local imageMid = customMid
		local imageRight = customRight
		local overLeft = customOverLeft
		local overMid = customOverMid
		local overRight = customOverRight
		
		for i=1,numRows,1 do
			local row = buttonsTable[i]
			local leftRow, midRow, rightRow = false, false, false
			
			local buttonText, eventListener
			if row[1] then
				buttonText = row[1]
			else
				buttonText = ""
			end
			
			if buttonWidth then
				lastWidth = buttonWidth
			end
			
			if row[2] then
				buttonWidth = row[2]
			else
				buttonWidth = 75
			end
			
			if row[3] and type( row[3] ) == "function" then
				eventListener = row[3]
			end
			
			if i == 1 and i ~= numRows then
				leftRow = true
			end
			
			if i > 1 and i ~= numRows then
				midRow = true
			end
			
			if i > 1 and i == numRows then
				rightRow = true
			end
			
			local theID = "tabBtn" .. i
			
			local theButton = createButton{
				width = buttonWidth,
				imageLeft = imageLeft,
				imageMid = imageMid,
				imageRight = imageRight,
				overLeft = overLeft,
				overMid = overMid,
				overRight = overRight,
				tabLeft = tabLeft,
				tabRight = tabRight,
				tabOverLeft = tabOverLeft,
				tabOverRight = tabOverRight,
				onEvent = eventListener,
				id = theID,
				text = buttonText,
				font = "Helvetica-Bold",
				textColor = { 255, 255, 255, 255 },
				size = 12,
				emboss = true,
				x = 0,
				y = 0,
				isLeftTab = leftRow,
				isRightTab = rightRow,
				isMidTab = midRow
			}
			
			theButton:setReferencePoint( display.CenterLeftReferencePoint )
			theButton.x = nextX
			
			nextX = nextX + buttonWidth
			
			table.insert( tabGroup.buttonsList, theButton )
			tabGroup:insert( theButton )
		end
		
		tabGroup:setReferencePoint( display.CenterReferencePoint )
		if x and y then
			tabGroup.x = x
			tabGroup.y = y
		else
			tabGroup.x = 0
			tabGroup.y = 0
		end
		
		return tabGroup
	end
end

--

-- ======================================================================================
--
-- ======================================================================================

function newScreen( width, statusBarVisible, titleString, background, isHidden, titleBg, titleBgWidth, titleBgHeight, bgWidth, bgHeight )
	local screenGroup = display.newGroup()
	local top = 0
	
	if statusBarVisible then
		top = 40
		screenGroup.statusBarVisible = true
	else
		screenGroup.statusBarVisible = false
	end
	
	if not width then
		screenGroup.myWidth = display.contentWidth
	else
		screenGroup.myWidth = width
	end
	
	screenGroup.myHeight = display.contentHeight
	
	screenGroup.myName = "screenGroup"
	screenGroup.isTransitioning = false
	screenGroup.touchingControl = false
	screenGroup.selectedTableItem = nil		--> will hold a table that is individal item
	
	-- add a 1px border to left of pane
	screenGroup.borderLeft = display.newLine( 0, 0, 0, screenGroup.myHeight )
	screenGroup.borderLeft.width = 1
	screenGroup.borderLeft:setColor( 0, 0, 0, 255 )
	
	-- start background init
	if background and background ~= "none" then
		if background == "stripes" then
			screenGroup.background = display.newImageRect( "coronaui_stripesbg.png", screenGroup.myWidth, display.contentHeight )
			screenGroup.background.x = screenGroup.myWidth * .5; screenGroup.background.y = display.contentHeight * 0.5
			screenGroup:insert( screenGroup.background )
		elseif background == "alarm" then
			screenGroup.background = display.newImageRect( "coronaui_alarmbg.png", screenGroup.myWidth, display.contentHeight )
			screenGroup.background.x = screenGroup.myWidth * .5; screenGroup.background.y = display.contentHeight * 0.5
			screenGroup:insert( screenGroup.background )
		elseif background == "black" then
			screenGroup.background = display.newRect( 0, 0, screenGroup.myWidth, display.contentHeight )
			screenGroup.background:setFillColor( 0, 0, 0, 255 )
			screenGroup:insert( screenGroup.background )
		elseif background == "white" then
			screenGroup.background = display.newRect( 0, 0, screenGroup.myWidth, display.contentHeight )
			screenGroup.background:setFillColor( 255, 255, 255, 255 )
			screenGroup:insert( screenGroup.background )
		elseif background == "grey" then
			screenGroup.background = display.newRect( 0, 0, screenGroup.myWidth, display.contentHeight )
			screenGroup.background:setFillColor( 152, 152, 156, 255 )
			screenGroup:insert( screenGroup.background )
		else
			local backgroundWidth = screenGroup.myWidth
			local backgroundHeight = display.contentHeight
			
			if bgWidth then
				backgroundWidth = bgWidth
			end
			
			if bgHeight then
				backgroundHeight = bgHeight
			end
			
			screenGroup.background = display.newImageRect( background, backgroundWidth, backgroundHeight )
			screenGroup.background.x = screenGroup.myWidth * 0.5; screenGroup.background.y = display.contentHeight * 0.5
			screenGroup:insert( screenGroup.background )
		end
		
		screenGroup.backgroundFile = background
	else
		screenGroup.background = false
		screenGroup.backgroundFile = false
	end
	
	if screenGroup.background then
		screenGroup:insert( screenGroup.background )
	end
	-- end background init
	
	--
	
	-- START STATUS BAR RECT
	-- draw black rectangle above titlebar if status bar is showing
	if statusBarVisible then
		local statusBarRect = display.newRect( 0, 0, screenGroup.myWidth, 20 )
		statusBarRect:setFillColor( 0, 0, 0, 255 )
		screenGroup.statusBarRect = statusBarRect
	end
	-- END STATUS BAR RECT
	
	--
	
	-- START Title Header Object
	if not titleString then
		titleString = ""
	end
	
	if not titleBg then
		titleBg = "coronaui_titlebg.png"
	end
	
	screenGroup.titleBgFile = titleBg
	
	if not titleBgWidth then
		titleBgWidth = screenGroup.myWidth
	end
	
	if not titleBgHeight then
		titleBgHeight = 44
	end
	
	screenGroup.titleBgWidth = titleBgWidth
	screenGroup.titleBgHeight = titleBgHeight
	
	local titleObject = display.newImageRect( titleBg, titleBgWidth, titleBgHeight )
	titleObject:setReferencePoint( display.TopCenterReferencePoint )
	titleObject.x = screenGroup.myWidth * 0.5
	titleObject.y = 0
	
	
	local newText = titleString
	local font = "HelveticaNeue-Bold"
	local size = 40
	local xPos = screenGroup.myWidth * 0.5
	
	local titleText = newRetinaText( titleString, xPos, titleBgHeight * 0.5, font, 20, 255, 255, 255, "center", true )
	
	--[[
	local titleText = display.newGroup()
	
	local textColor={ 255, 255, 255, 255 }
	local xPos = screenGroup.myWidth * 0.5
	local yPos = titleBgHeight * 0.5
	
	local labelHighlight
	local labelShadow
	local labelText
	
	-- Make the label text look "embossed" (also adjusts effect for textColor brightness)
	local textBrightness = ( textColor[1] + textColor[2] + textColor[3] ) / 3
	
	labelHighlight = display.newText( newText, xPos, yPos, font, size )
	if ( textBrightness > 127) then
		labelHighlight:setTextColor( 255, 255, 255, 20 )
	else
		labelHighlight:setTextColor( 255, 255, 255, 140 )
	end
	titleText:insert( labelHighlight, true )
	labelHighlight.x = labelHighlight.x + 1.5; labelHighlight.y = labelHighlight.y + 1.5
	titleText.highlight = labelHighlight

	labelShadow = display.newText( newText, xPos, yPos, font, size )
	if ( textBrightness > 127) then
		labelShadow:setTextColor( 0, 0, 0, 128 )
	else
		labelShadow:setTextColor( 0, 0, 0, 20 )
	end
	titleText:insert( labelShadow, true )
	labelShadow.x = labelShadow.x - 1; labelShadow.y = labelShadow.y - 1
	titleText.shadow = labelShadow
	
	labelHighlight.xScale = .5; labelHighlight.yScale = .5
	labelShadow.xScale = .5; labelShadow.yScale = .5
	
	labelText = display.newText( newText, 0, 0, font, size )
	labelText:setTextColor( textColor[1], textColor[2], textColor[3], textColor[4] )
	titleText:insert( labelText, true )
	titleText.text = labelText
	
	labelText.xScale = .5; labelText.yScale = .5
	]]--
	
	
	screenGroup.titleBar = titleObject
	screenGroup.titleText = titleText
	screenGroup.titleBar:setReferencePoint( display.TopCenterReferencePoint )
	if statusBarVisible then
		screenGroup.titleBar.y = screenGroup.titleBar.height * 0.5 - 2
	else
		screenGroup.titleBar.y = 0
	end
	screenGroup.titleBar.width = screenGroup.myWidth
	screenGroup.titleText.textObject.defaultX = xPos
	screenGroup.titleText.textObject.defaultY = screenGroup.titleBar.y + screenGroup.titleBar.height * 0.5
	screenGroup.titleText:updateText( titleString )
	
	screenGroup.leftButtonGroup = display.newGroup()
	screenGroup.rightButtonGroup = display.newGroup()
	
	screenGroup.header = display.newGroup()
	screenGroup.header:insert( screenGroup.titleBar )
	screenGroup.header:insert( screenGroup.titleText )
	if screenGroup.statusBarRect then
		screenGroup.header:insert( screenGroup.statusBarRect )
	end
	screenGroup.header:insert( screenGroup.leftButtonGroup )
	screenGroup.header:insert( screenGroup.rightButtonGroup )
	screenGroup.header:insert( screenGroup.borderLeft )
	
	screenGroup:insert( screenGroup.header )
	-- END TITLE HEADER OBJECT
	
	--
	
	-- visibility
	if not isHidden then
		screenGroup.isVisible = true
	else
		screenGroup.isVisible = false
	end
	
	--
	
	-- ======================================================================================
	--
	-- ======================================================================================
	
	function screenGroup:cleanUp()
		--cleanGroups( self, 0 )
		
		self:removeSelf()
		self = nil
	end
	
	--
	
	-- ======================================================================================
	--
	-- ======================================================================================
	
	function screenGroup:enterFrame( event )
		
		if self.myHeight ~= display.contentHeight then
			
			self:resize( self.myWidth, self.backgroundFile )
		end
	end
	
	--Runtime:addEventListener( "enterFrame", screenGroup )
	
	--
	
	-- ======================================================================================
	--
	-- ======================================================================================
	
	function screenGroup:resize( newWidth, background )
		self.myWidth = newWidth
		self.myHeight = display.contentHeight
		
		if background and background ~= "none" then
			if background == "stripes" then
				self.background = display.newImageRect( "coronaui_stripesbg.png", self.myWidth, display.contentHeight )
				self.background.x = self.myWidth * .5; self.background.y = display.contentHeight * 0.5
				self:insert( self.background )
			elseif background == "alarm" then
				self.background = display.newImageRect( "coronaui_alarmbg.png", self.myWidth, display.contentHeight )
				self.background.x = self.myWidth * .5; self.background.y = display.contentHeight * 0.5
				self:insert( self.background )
			elseif background == "black" then
				self.background = display.newRect( 0, 0, self.myWidth, display.contentHeight )
				self.background:setFillColor( 0, 0, 0, 255 )
				self:insert( self.background )
			elseif background == "white" then
				self.background = display.newRect( 0, 0, self.myWidth, display.contentHeight )
				self.background:setFillColor( 255, 255, 255, 255 )
				self:insert( self.background )
			elseif background == "grey" then
				self.background = display.newRect( 0, 0, self.myWidth, display.contentHeight )
				self.background:setFillColor( 152, 152, 156, 255 )
				self:insert( self.background )
			else
				self.background = display.newImageRect( background, self.myWidth, display.contentHeight )
				self.background.x = self.myWidth * 0.5; self.background.y = display.contentHeight * 0.5
				self:insert( self.background )
			end
		else
			self.background = false
		end
		
		self:insert( self.background )
		self.background:toBack()
		
		if self.rightButtonGroup.button then
			self.rightButtonGroup.button.x = self.myWidth - 5;
		end
		
		if self.rightButtonGroup.doneButton then
			self.rightButtonGroup.doneButton.x = self.myWidth - 5;
		end
		
		if self.titleBar then
			self.titleBar:removeSelf()
			self.titleBar = nil
			
			self.titleBgWidth = self.myWidth
			
			self.titleBar = display.newImageRect( self.titleBgFile, self.titleBgWidth, self.titleBgHeight )
			self.titleBar:setReferencePoint( display.TopCenterReferencePoint )
			self.titleBar.x = self.myWidth * 0.5
			if self.statusBarVisible then
				self.titleBar.y = self.titleBar.height * 0.5 - 2
			else
				self.titleBar.y = 0
			end
			
			self.header:insert( self.titleBar )
			
			-- titlebar text
			local oldText = self.titleText.textObject.text
			self.titleText.textObject.defaultX = self.myWidth * 0.5
			self.titleText:updateText( oldText )
			
			self.titleText:toFront()
			
			-- bring existing buttons to front
			self.leftButtonGroup:toFront()
			self.rightButtonGroup:toFront()
		end
		
		if self.statusBarRect then
			self.statusBarRect:removeSelf(); self.statusBarRect = nil
			
			self.statusBarRect = display.newRect( 0, 0, screenGroup.myWidth, 20 )
			self.statusBarRect:setFillColor( 0, 0, 0, 255 )
		end
		
		-- background changes will go here
	end
	
	--
	
	-- ======================================================================================
	--
	-- ======================================================================================
	
	function screenGroup:addBackButton( eventListener, customImage, customWidth, customHeight, customOverImage )
		
		if not eventListener or type(eventListener) ~= "function" then
			eventListener = function( event )
				if event.phase == "release" then
					-- back button in left group always slides right
					self:slideToRight( lastScreen )
				end
			end
		end
		
		local buttonImage = "coronaui_backbtn.png"
		local overImage = "coronaui_backbtn-over.png"
		local btnWidth = 52
		local btnHeight = 30
		
		if customImage then
			buttonImage = customImage
			
			if customWidth then btnWidth = customWidth; end
			if customHeight then btnHeight = customHeight; end
			
			if customOverImage then overImage = customOverImage; end
		end
			
		
		-- first remove previous button if it exists
		if self.leftButtonGroup.backBtn then
			self.leftButtonGroup.backBtn:removeSelf()
			self.leftButtonGroup.backBtn = nil
		end
		
		local button = createButton{
			imageFile = buttonImage,
			buttonWidth = btnWidth,
			buttonHeight = btnHeight,
			overImage = overImage,
			onEvent = eventListener,
			id = "backButton",
			text = "",
			font = "Helvetica",
			textColor = { 255, 255, 255, 255 },
			size = 16,
			emboss = false
		}
		
		button:setReferencePoint( display.CenterLeftReferencePoint )
		self.leftButtonGroup:insert( button )
		self.leftButtonGroup:toFront()
		
		button.x = 5; button.y = self.titleBar.y + (self.titleBar.height * 0.5)
		self.leftButtonGroup.backBtn = button
	end
	
	--
	
	-- ======================================================================================
	--
	-- ======================================================================================
	
	function screenGroup:addRightButton( buttonText, eventListener, isLong, customImg, customOverImg, customWidth, customHeight, customLeft, customMid, customRight, customOverLeft, customOverMid, customOverRight )
		if not buttonText then
			-- if no arguments, just remove button that is there
			if self.rightButtonGroup.button then
				self.rightButtonGroup.button:removeSelf()
				self.rightButtonGroup.button = nil
			end
			
			-- first remove previous button if it exists
			if self.rightButtonGroup.doneButton then
				self.rightButtonGroup.doneButton:removeSelf()
				self.rightButtonGroup.doneButton = nil
			end
		else	
			if not eventListener or type(eventListener) ~= "function" then
				eventListener = function( event )
					if event.phase == "release" then
						print( "You never specified an event listener for this button." )
					end
				end
			end
			
			local buttonImage, overImage, width, height
			
			if not customImg then
				--[[
				if not isLong then
					buttonImage = "coronaui_rightbtn.png"
					overImage = "coronaui_rightbtn-over.png"
					width = 62
					height = 30
				else
					buttonImage = "coronaui_rightbtnlong.png"
					overImage = "coronaui_rightbtnlong-over.png"
					width = 94
					height = 30
				end
				]]--
				buttonImage = nil
				overImage = nil
			else
				buttonImage = customImg
				overImage = customOverImg
				if customWidth then width = customWidth; else
					if not isLong then width = 62; else width = 94; end
				end
				if customHeight then height = customHeight; else height = 30; end
			end
			
			if not buttonText then
				buttonText = "Done"
			end
			
			-- first remove previous button if it exists
			if self.rightButtonGroup.button then
				self.rightButtonGroup.button:removeSelf()
				self.rightButtonGroup.button = nil
			end
			
			-- first remove previous button if it exists
			if self.rightButtonGroup.doneButton then
				self.rightButtonGroup.doneButton:removeSelf()
				self.rightButtonGroup.doneButton = nil
			end
			
			local imageLeft = customLeft
			local imageMid = customMid
			local imageRight = customRight
			local overLeft = customOverLeft
			local overMid = customOverMid
			local overRight = customOverRight
			
			local button = createButton{
				imageFile = buttonImage,
				buttonWidth = width,
				buttonHeight = height,
				overImage = overImage,
				imageLeft = imageLeft,
				imageMid = imageMid,
				imageRight = imageRight,
				overLeft = overLeft,
				overMid = overMid,
				overRight = overRight,
				onEvent = eventListener,
				id = "rightButton",
				text = buttonText,
				font = "HelveticaNeue-Bold",
				textColor = { 255, 255, 255, 255 },
				size = 12,
				emboss = true
			}
			
			button:setReferencePoint( display.CenterRightReferencePoint )
			self.rightButtonGroup:insert( button )
			self.rightButtonGroup:toFront()
			
			button.x = self.myWidth - 5; button.y = self.titleBar.y + (self.titleBar.height * 0.5)
			self.rightButtonGroup.button = button
		end
	end
	
	--
	
	function screenGroup:addDoneButton( buttonText, eventListener, isLong, customImg, customOverImg, customWidth, customHeight, customLeft, customMid, customRight, customOverLeft, customOverMid, customOverRight )
		if not eventListener or type(eventListener) ~= "function" then
			eventListener = function( event )
				if event.phase == "release" then
					print( "You never specified an event listener for this button." )
				end
			end
		end
		
		local buttonImage, overImage, width, height
		
		if not customImg then
			--[[
			if not isLong then
				buttonImage = "coronaui_rightbtn.png"
				overImage = "coronaui_rightbtn-over.png"
				width = 62
				height = 30
			else
				buttonImage = "coronaui_rightbtnlong.png"
				overImage = "coronaui_rightbtnlong-over.png"
				width = 94
				height = 30
			end
			]]--
			buttonImage = nil
			overImage = nil
		else
			buttonImage = customImg
			overImage = customOverImg
			if customWidth then width = customWidth; else
				if not isLong then width = 62; else width = 94; end
			end
			if customHeight then height = customHeight; else height = 30; end
		end
		
		if not buttonText then
			buttonText = "Done"
		end
		
		-- first remove previous button if it exists
		if self.rightButtonGroup.doneButton then
			self.rightButtonGroup.doneButton:removeSelf()
			self.rightButtonGroup.doneButton = nil
		end
		
		local imageLeft = customLeft
		local imageMid = customMid
		local imageRight = customRight
		local overLeft = customOverLeft
		local overMid = customOverMid
		local overRight = customOverRight
		
		local doneButton = createButton{
			imageFile = buttonImage,
			buttonWidth = width,
			buttonHeight = height,
			overImage = overImage,
			imageLeft = imageLeft,
			imageMid = imageMid,
			imageRight = imageRight,
			overLeft = overLeft,
			overMid = overMid,
			overRight = overRight,
			onEvent = eventListener,
			id = "doneButton",
			text = buttonText,
			font = "HelveticaNeue-Bold",
			textColor = { 255, 255, 255, 255 },
			size = 12,
			emboss = true
		}
		
		doneButton:setReferencePoint( display.CenterRightReferencePoint )
		self.rightButtonGroup:insert( doneButton )
		self.rightButtonGroup:toFront()
		
		doneButton.x = self.myWidth - 5; doneButton.y = self.titleBar.y + (self.titleBar.height * 0.5)
		self.rightButtonGroup.doneButton = doneButton
	end
	
	-- ======================================================================================
	--
	-- ======================================================================================
	
	function screenGroup:addLeftButton( buttonText, eventListener, isLong, customImg, customOverImg, customWidth, customHeight, customLeft, customMid, customRight, customOverLeft, customOverMid, customOverRight )
		if not buttonText then
			-- if no arguments, just remove button that is there
			if self.leftButtonGroup.button then
				self.leftButtonGroup.button:removeSelf()
				self.leftButtonGroup.button = nil
			end
		else
			if not eventListener or type(eventListener) ~= "function" then
				eventListener = function( event )
					if event.phase == "release" then
						print( "You never specified an event listener for this button." )
					end
				end
			end
			
			local buttonImage, overImage, width, height
			
			if not customImg then
				--[[
				if not isLong then
					buttonImage = "coronaui_rightbtn.png"
					overImage = "coronaui_rightbtn-over.png"
					width = 62
					height = 30
				else
					buttonImage = "coronaui_rightbtnlong.png"
					overImage = "coronaui_rightbtnlong-over.png"
					width = 94
					height = 30
				end
				]]--
				buttonImage = nil
				overImage = nil
			else
				buttonImage = customImg
				overImage = customOverImg
				if customWidth then width = customWidth; else
					if not isLong then width = 62; else width = 94; end
				end
				if customHeight then height = customHeight; else height = 30; end
			end
			
			-- first remove previous button if it exists
			if self.leftButtonGroup.button then
				self.leftButtonGroup.button:removeSelf()
				self.leftButtonGroup.button = nil
			end
			
			-- then remove back button if it exists
			if self.leftButtonGroup.backBtn then
				self.leftButtonGroup.backBtn:removeSelf()
				self.leftButtonGroup.backBtn = nil
			end
			
			local imageLeft = customLeft
			local imageMid = customMid
			local imageRight = customRight
			local overLeft = customOverLeft
			local overMid = customOverMid
			local overRight = customOverRight
			
			local button = createButton{
				imageFile = buttonImage,
				buttonWidth = width,
				buttonHeight = height,
				overImage = overImage,
				imageLeft = imageLeft,
				imageMid = imageMid,
				imageRight = imageRight,
				overLeft = overLeft,
				overMid = overMid,
				overRight = overRight,
				onEvent = eventListener,
				id = "leftButton",
				text = buttonText,
				font = "HelveticaNeue-Bold",
				textColor = { 255, 255, 255, 255 },
				size = 12,
				emboss = true
			}
			
			button:setReferencePoint( display.CenterLeftReferencePoint )
			self.leftButtonGroup:insert( button )
			self.leftButtonGroup:toFront()
			
			button.x = 5; button.y = self.titleBar.y + (self.titleBar.height * 0.5)
			self.leftButtonGroup.button = button
		end
	end
	
	--
	
	-- ======================================================================================
	--
	-- ======================================================================================
	
	function screenGroup:slideToLeft( goToScreen, onComplete )
		if not goToScreen then return; end
		
		local screen1 = self
		local screen2 = goToScreen
		lastScreen = screen1
		currentScreen = screen2
		
		if not screen1.isTransitioning then
			screen1.isTransitioning = true
			screen2.isTransitioning = true
			if screen1.tween then transition.cancel( screen1.tween ); screen1.tween = nil; end
			if screen2.tween then transition.cancel( screen2.tween ); screen2.tween = nil; end
			
			local backX = -(self.myWidth)
			local forwardX = self.myWidth
			
			screen1.x = 0; screen1.y = 0
			screen2.x = forwardX; screen2.y = 0
			screen2.isVisible = true
			
			local hideScreen1 = function() screen1.isVisible = false; screen1.isTransitioning = false;
				if screen1.tween then transition.cancel( screen1.tween ); screen1.tween = nil; end
			end
			screen1.tween = transition.to( screen1, { time=450, x=backX, transition=easing.outQuad, onComplete=hideScreen1 } )
			
			local showScreen2 = function() screen2.isTransitioning = false;
				if screen2.tween then transition.cancel( screen2.tween ); screen2.tween = nil; end
				if onComplete and type(onComplete) == "function" then
					onComplete()
				end
			end
			screen2.tween = transition.to( screen2, { time=450, x=0, transition=easing.outQuad, onComplete=showScreen2 } )
			
			--back button alpha 0 to 1
			if screen2.leftButtonGroup.backBtn then
				local button = screen2.leftButtonGroup.backBtn
				button.alpha = 0
				
				if button.tween then transition.cancel( button.tween ); button.tween = nil; end
				button.tween = transition.to( button, { time=400, alpha=1.0, transition=easing.outQuad } )
			end
			
			--right button alpha 1 to 0 ( current screen )
			if screen1.rightButtonGroup.button then
				local button = screen1.rightButtonGroup.button
				button.alpha = 1.0
				
				if button.tween then transition.cancel( button.tween ); button.tween = nil; end
				button.tween = transition.to( button, { time=300, alpha=0, transition=easing.outQuad })
			end
		end
	end
	
	--
	
	-- ======================================================================================
	--
	-- ======================================================================================
	
	function screenGroup:slideToRight( goToScreen, onComplete )
		if not goToScreen then return; end
		
		local screen1 = self
		local screen2 = goToScreen
		lastScreen = screen1
		currentScreen = screen2
		
		if not screen1.isTransitioning then
			screen1.isTransitioning = true
			screen2.isTransitioning = true
			if screen1.tween then transition.cancel( screen1.tween ); screen1.tween = nil; end
			if screen2.tween then transition.cancel( screen2.tween ); screen2.tween = nil; end
			
			local backX = -(self.myWidth)
			local forwardX = self.myWidth
			
			screen1.x = 0; screen1.y = 0
			screen2.x = backX; screen2.y = 0
			screen2.isVisible = true
			
			local hideScreen1 = function() screen1.isVisible = false; screen1.isTransitioning = false;
				if screen1.tween then transition.cancel( screen1.tween ); screen1.tween = nil; end
			end
			screen1.tween = transition.to( screen1, { time=450, x=forwardX, transition=easing.outQuad, onComplete=hideScreen1 } )
			
			local showScreen2 = function() screen2.isTransitioning = false;
				if screen2.tween then transition.cancel( screen2.tween ); screen2.tween = nil; end
				if onComplete and type(onComplete) == "function" then
					onComplete()
				end
			end
			screen2.tween = transition.to( screen2, { time=450, x=0, transition=easing.outQuad, onComplete=showScreen2 } )
			
			--back button alpha 1 to 0
			if screen1.leftButtonGroup.backBtn then
				local button = screen1.leftButtonGroup.backBtn
				button.alpha = 1.0
				
				if button.tween then transition.cancel( button.tween ); button.tween = nil; end
				button.tween = transition.to( button, { time=300, alpha=0, transition=easing.outQuad } )
			end
			
			--right button alpha 1 to 0 ( next screen )
			if screen2.rightButtonGroup.button then
				local button = screen2.rightButtonGroup.button
				button.alpha = 0
				
				if button.tween then transition.cancel( button.tween ); button.tween = nil; end
				button.tween = transition.to( button, { time=300, alpha=1.0, transition=easing.outQuad })
			end
		end
	end
	
	--
	
	-- ======================================================================================
	--
	-- ======================================================================================
	
	function screenGroup:insertUnderTitle( displayObject )
		if displayObject and type(displayObject) == "table" then
			self:insert( displayObject )
			self:insert( self.header )
		end
	end
	
	--
	
	-- ======================================================================================
	--
	-- ======================================================================================
	
	function screenGroup:copyFromList( targetList, targetScreen, includeTouchEvents, selectionList )
		local selfList, onTouch, isSelection, hideArrow
		
		if selectionList then
			isSelection = true
			hideArrow = false
		else
			isSelection = false
			hideArrow = targetList.hideArrow
		end
		
		-- start new list
		-- top, bottom, hasTitle, hasStatusBar, rowHeight, selectionList, fillColor, hideLines, tearEffect, scrollDisabled, customTitleHeight
		selfList = targetScreen:newList( 0, 0, true, true, targetList.rowHeight, isSelection, targetList.fillColor, nil, targetList.tearEffect )
		
		-- copy each item from selection list to cart list
		local i
		local numItems
		
		if targetList.selectionList then
			numItems = table.getn( targetList.multiList )
		else
			numItems = table.getn( targetList.listItems )
		end
		
		if numItems > 0 then
			for i=1,numItems,1 do
				local j
				
				if targetList.selectionList then
					j = targetList.multiList[i]
				else
					j = targetList.listItems[i]
				end
				
				if includeTouchEvents then
					onTouch = j.myEvent
				else
					onTouch = nil
				end
				
				--( iconparams, mainTitle, subTitle, onTouch, hideArrow )
				
				local subtitleText
				
				if j.subtitleText then
					subtitleText = j.subtitleText.textObject.text
				end
				
				local isCategory = j.isCategory
				local categoryBg = j.categoryBg
				local categoryR = j.categoryR
				local categoryB = j.categoryB
				local categoryG = j.categoryG
				
				if j.icon then
				
					local icon = j.iconName
					local width = j.iconWidth
					local height = j.iconWidth
					
					selfList:addItem( { icon=icon, width=width, height=height }, j.titleText.textObject.text, subtitleText, onTouch, hideArrow, isCategory, categoryBg, categoryHeight, categoryR, categoryG, categoryB )
				else
					selfList:addItem( { icon="none" }, j.titleText.textObject.text, subtitleText, onTouch, hideArrow, isCategory, categoryBg, categoryHeight, categoryR, categoryG, categoryB )
				end
			end
		end
		
		return selfList
	end
	
	--
	
	-- ======================================================================================
	--
	-- ======================================================================================
	
	function screenGroup:newList( top, bottom, hasTitle, hasStatusBar, rowHeight, selectionList, fillColor, hideLines, tearEffect, scrollDisabled, customTitleHeight )	
		
		local titleBgHeight = 44
		
		if customTitleHeight then
			titleBgHeight = customTitleHeight
		end
		
		if not top then
			top = 0
		end
		
		if not bottom then
			bottom = 0
		end
		
		local listWidth = self.myWidth or display.contentWidth
		
		-- determine whether or not to add a title, to see if list should shift down
		local includeTitle = false
		
		if hasTitle then
			includeTitle = true
		end
		
		-- if statusbar is visible, shift everything down 40 pixels
		if statusBarVisible then
			statusBarVisible = true
			top = top + 20
		else
			statusBarVisible = false
		end
		
		-- set row height, or default
		if not rowHeight then
			rowHeight = 56
		else
			if rowHeight < 56 then
				rowHeight = 56
			end
		end
		
		-- set fill color, or default
		if not fillColor then
			-- default to white
			fillColor = "FFFFFF"
		end
		
		
		--setup top and bottom boundaries for the scrolling view
		local topBoundary = display.screenOriginY + top
		local bottomBoundary = display.screenOriginY + bottom
		
		if includeTitle then
			topBoundary = display.screenOriginY + top + titleBgHeight
		end
	 
		--setup a group into which you can insert anything that needs to scroll
		local scrollView = scrollView.new{ top=topBoundary, bottom=bottomBoundary, width=listWidth }
		
		-- determine whether or not list is a selection list
		if selectionList then
			scrollView.selectionList = true
		else
			scrollView.selectionList = false
		end
		
		scrollView.fillColor = fillColor
		
		-- determine if there should be a "tear" effect
		if tearEffect then
			scrollView.tearEffect = true
		else
			scrollView.tearEffect = false
		end
		
		-- determine whether lines are showing or not
		if hideLines then
			scrollView.linesHidden = true
		end
		
		if includeTitle then
			if not statusBarVisible then
				scrollView.upperLimit = titleBgHeight
			else
				scrollView.upperLimit = titleBgHeight + 22
			end
		else
			scrollView.upperLimit = 0
		end
		
		scrollView.rowHeight = rowHeight
		scrollView.nextRow = 0	--> holds y value of where next row should start
		scrollView.fillColor = fillColor
		local r, g, b = hex2rgb( fillColor )
		
		scrollView.fillR = r
		scrollView.fillG = g
		scrollView.fillB = b
		
		if scrollDisabled then
			scrollView.scrollDisabled = true
		else
			scrollView.scrollDisabled = false
		end
		
		-- add scroll bar
		scrollView:addScrollBar( 0, 0, 0, 120 )
		
		
		-- prepare to accept list items
		scrollView.listItems = {}
		
		-- prepare to accept multiple selection items
		scrollView.multiList = {}
		
		-- variable below to know which item to call listener
		scrollView.selectedItem = nil
		
		-- width
		scrollView.myWidth = self.myWidth
		
		-- height
		scrollView.myHeight = self.myHeight
		
		-- ======================================================================================
		--
		-- ======================================================================================
		
		function scrollView:addItem( iconparams, mainTitle, subTitle, onTouch, hideArrow, isCategory, categoryBg, categoryHeight, categoryTextR, categoryTextG, categoryTextB )
			
			local list = self
			
			local topY = list.nextRow
			local rowHeight = list.rowHeight
			local newListItem = display.newGroup()
			
			local r, g, b = hex2rgb( list.fillColor )
			
			-- CATEGORY ITEM STUFF
			if isCategory then
				newListItem.isCategory = true
				
				if not categoryBg then
					categoryBg = "coronaui_categorybg.png"
				end
				
				if not categoryHeight then
					categoryHeight = 24
				end
				
				rowHeight = categoryHeight - 1
				
				if not categoryTextR then categoryTextR = 255; end
				if not categoryTextG then categoryTextG = 255; end
				if not categoryTextB then categoryTextB = 255; end
				
				newListItem.categoryBg = categoryBg
				newListItem.categoryHeight = categoryHeight
				newListItem.categoryR = categoryTextR
				newListItem.categoryG = categoryTextG
				newListItem.categoryB = categoryTextB
				
			else
				newListItem.isCategory = false
			end
			-- END CATEGORY ITEM STUFF
			
			newListItem.rowHeight = rowHeight
			
			local bgRect
			
			if isCategory then
				bgRect = display.newImageRect( categoryBg, self.myWidth, categoryHeight )
				bgRect.x = bgRect.width * 0.5; bgRect.y = bgRect.height * 0.5
			else
				bgRect = display.newRect( 0, 0, self.myWidth, rowHeight )
				bgRect:setFillColor( r, g, b, 255 )
			end
			
			newListItem:insert( bgRect )
			
			newListItem.bgRect = bgRect
			
			if self.tearEffect and not isCategory then
				local maskFile = "coronaui_tornmask" .. math.random( 4 ) .. ".png"
				local xScale = self.myWidth / 320
				local yScale = rowHeight / 56
				local tearMask = graphics.newMask( maskFile )
				bgRect:setMask( tearMask )
				
				bgRect.maskScaleX = xScale
				bgRect.maskScaleY = yScale
			end
			
			local bottomLine = display.newLine( 0, bgRect.height, self.myWidth, bgRect.height )
			
			if not self.linesHidden and not self.tearEffect and not isCategory then
				bottomLine:setColor( 233, 233, 233, 255 )
			else
				bottomLine:setColor( r, g, b, 255 )
				
				if self.tearEffect then
					bottomLine.isVisible = false
				end
			end
			bottomLine.width = 2.0
			
			newListItem:insert( bottomLine )
			newListItem.bottomLine = bottomLine
			
			if isCategory then
				newListItem.bottomLine:removeSelf()
				newListItem.bottomLine = nil
			end
			
			-- LIST ITEM PROPERTIES
			
			newListItem.index = #list.listItems + 1
			
			if type(onTouch) == "function" or type(onTouch) == "string" then
				newListItem.myEvent = onTouch
				
				if not hideArrow and not self.selectionList and not isCategory then
					local rightArrow = display.newImageRect( "coronaui_rightArrow.png", 10, 14 )
					
					rightArrow:setReferencePoint( display.CenterRightReferencePoint )
					rightArrow.x = self.myWidth - 12
					rightArrow.y = rowHeight * 0.5
					
					newListItem.rightArrow = rightArrow
					newListItem:insert( newListItem.rightArrow )
				end
				
				if self.selectionList and not isCategory then
					local selectorIcon = display.newImageRect( "coronaui_blueaddicon.png", 30, 30 )
					
					selectorIcon:setReferencePoint( display.CenterRightReferencePoint )
					selectorIcon.x = self.myWidth - 12
					selectorIcon.y = rowHeight * 0.5
					
					newListItem.selectorIcon = selectorIcon
					newListItem:insert( newListItem.selectorIcon )
				end
			end	
			
			-- END LIST ITEM PROPERTIES
			
			--
			
			-- ICON HANDLING
			if not iconparams then
				iconparams.icon = "none"
			elseif iconparams.icon == "bullet" then
				iconparams.icon = "coronaui_bullet.png"
				iconparams.width = 10
				iconparams.height = 10
			end
			
			local startingX
			
			if iconparams.icon and iconparams.icon ~= "none" and not isCategory then
				local icon = display.newImageRect( iconparams.icon, iconparams.width, iconparams.height )
				local minHeight = icon.height + 10
				
				newListItem:insert( icon )
				
				if rowHeight < minHeight then
					local oldWidth = icon.width
					local oldHeight = icon.height
					local ratio = icon.height / icon.width
					
					icon.height = minHeight - 5
					icon.width = icon.height * ratio
				end
				
				icon:setReferencePoint( display.CenterLeftReferencePoint )
				icon.x = 10
				icon.y = rowHeight * 0.5
				
				startingX = icon.width + 25
				newListItem.icon = icon
				newListItem.iconName = iconparams.icon
				newListItem.iconWidth = iconparams.width
				newListItem.iconHeight = iconparams.height
			else
				startingX = 18
				
				if isCategory then
					startingX = 20
				end
			end
			
			-- END ICON HANDLING
			
			--
			
			-- START TEXT HANDLING (title text and subtitle text)
			local textGroup = display.newGroup()
			newListItem:insert( textGroup )
			
			-- main title
			
			if not mainTitle then
				mainTitle = ""
			end
			
			local shouldEmboss = false
			local theR, theG, theB = 0, 0, 0
			local titleFontSize = 18
			
			if isCategory then
				shouldEmboss = true
				theR = categoryTextR
				theG = categoryTextG
				theB = categoryTextB
				
				titleFontSize = 18
			end
			
			local titleText = newRetinaText( mainTitle, 0, 0, "HelveticaNeue-Bold", titleFontSize, theR, theG, theB, "left", shouldEmboss, textGroup )
			
			local titleY = 0 --rowHeight * 0.5
			titleText.textObject.defaultX = startingX
			titleText.textObject.defaultY = titleY
			titleText:updateText( mainTitle )
			
			newListItem.titleText = titleText
			
			-- subtitle
			
			if subTitle and not isCategory then
				-- "selected" grey color: 127, 127, 127
				local subtitleText = newRetinaText( subTitle, 0, 0, "HelveticaNeue", 14, 106, 115, 125, "left", false, textGroup )
				
				local subtitleY = titleText.y + 22
				subtitleText.textObject.defaultX = startingX
				subtitleText.textObject.defaultY = subtitleY
				subtitleText:updateText( subTitle )
				
				newListItem.subtitleText = subtitleText
			end
				
			textGroup:setReferencePoint( display.CenterReferencePoint )
			textGroup.y = rowHeight * 0.5
			
			-- END TEXT HANDLING
			
			--
			
			list:insert( newListItem )
			newListItem.y = topY;
			newListItem.initY = newListItem.y
			table.insert( list.listItems, newListItem )
			
			self.nextRow = topY + rowHeight
			
			-- refresh scrollbar
			list:addScrollBar( 0, 0, 0, 120 )
			
			function onBgTouch( self, event )
				if event.phase == "began"  and event.y > list.upperLimit then
					if self.myEvent then
						if type(self.myEvent) == "function" or type(self.myEvent) == "string" or self.parent.selectionList then
							self[1]:setFillColor( 67, 141, 241, 255 )
							list.selectedItem = self
							
							display.getCurrentStage():setFocus( self )
							self.isFocus = true
						end
					end
				else
					-- Allow touch events to be sent normally to the objects they "hit"
					display.getCurrentStage():setFocus( nil )
					self.isFocus = false
				end
			end
			
			newListItem.touch = onBgTouch
			
			if not isCategory then
				newListItem:addEventListener( "touch", newListItem )
				
				--******* OFFSCREEN VISIBILITY CULLING TO BOOST PERFORMANCE FOR LARGE LISTS *******--
				
				local spacingThresh = 10
				
				local moveCat = function( self, event )
					if -(self.parent.y) >= (self.initY - spacingThresh ) then
						if self.parent.y < (self.initY + spacingThresh ) then
							self.isVisible = false
						else
							self.isVisible = true
						end
					
					elseif -(self.parent.y) <= (self.initY - (contentH - spacingThresh)) then
						self.isVisible = false
					
					else
						self.isVisible = true
					end
				end
				
				function newListItem:enterFrame( event )
					self:repeatFunction( event )
				end
				
				newListItem.repeatFunction = moveCat
				Runtime:addEventListener( "enterFrame", newListItem )
				
				--******* END OFFSCREEN VISIBILITY CULLING TO BOOST PERFORMANCE FOR LARGE LISTS *******--
				
			else
				local moveCat = function( self, event )
					if -(self.parent.y) >= (self.initY - 64) then
						if self.parent.y < (self.initY + 64) then
							self:toFront()
							self.y = -(self.parent.y) + 64
						else
							self.y = self.initY
						end
					else
						self.y = self.initY
					end
				end
				
				function newListItem:enterFrame( event )
					self:repeatFunction( event )
				end
				
				newListItem.repeatFunction = moveCat
				Runtime:addEventListener( "enterFrame", newListItem )
				
			end
			
			-- right arrow
			if hideArrow and isCategory then
				newListItem.hideArrow = true
			else
				newListItem.hideArrow = false
			end
			
			list:refresh()
		end
		
		--
		
		-- ======================================================================================
		--
		-- ======================================================================================
		
		function scrollView:populateFromXml( xmlFileName )
			local xml = newXmlParser()
			local xTable = xml:ParseXmlFile( xmlFileName )
			local itemsList = xTable.ChildNodes
			local itemCount = table.getn( itemsList )
			local i
			
			--self.vList = {}
			
			for i=1,itemCount,1 do
				
				-- set item defaults
				local icon = "none"
				local iconWidth = nil
				local iconHeight = nil			
				local mainTitle = ""
				local subTitle = ""
				local onTouch = nil
				local hideArrow = false
				local isCategory = false
				local categoryBg = nil
				local categoryHeight = nil
				local categoryTextR = nil
				local categoryTextG = nil
				local categoryTextB = nil
				
				local j = itemsList[i].ChildNodes
				local jCount = table.getn( j )
				local k
				
				for k=1,jCount,1 do
					local name = j[k].Name
					local value = j[k].Value
					
					if name == "icon" then
						icon = value
					
					elseif name == "iconWidth" then
						iconWidth = value
					
					elseif name == "iconHeight" then
						iconHeight = value
					
					elseif name == "title" then
						mainTitle = value
						
					elseif name == "subtitle" then
						subTitle = value
						
					elseif name == "onTouch" then
						onTouch = value
						
					elseif name == "hideArrow" then
						if value == "true" then
							hideArrow = true
						else
							hideArrow = false
						end
					
					elseif name == "isCategory" then
						if value == "true" then
							isCategory = true
						end
					
					elseif name == "categoryBg" then
						categoryBg = value
					
					elseif name == "categoryHeight" then
						categoryHeight = tonumber(value)
					
					elseif name == "categoryTextR" then
						categoryTextR = tonumber(value)
					
					elseif name == "categoryTextG" then
						categoryTextG = tonumber(value)
					
					elseif name == "categoryTextB" then
						categoryTextB = tonumber(value)
						
					end
				end
				
				if icon == "none" or icon == "bullet" then
					iconWidth = nil
					iconHeight = nil
				end
				
				self:addItem( { icon=icon, width=iconWidth, height=iconHeight }, mainTitle, subTitle, onTouch, hideArrow, isCategory, categoryBg, categoryHeight, categoryTextR, categoryTextG, categoryTextB )
				
				--[[
				self.vTable = {
					iconparams={ icon, iconWidth, iconHeight },
					mainTitle = mainTitle,
					subTitle = subTitle,
					onTouch = onTouch,
					hideArrow = hideArrow,
					isCategory = isCategory,
					categoryBg = categoryBg,
					categoryHeight = categoryHeight,
					categoryTextR = categoryTextR,
					categoryTextG = categoryTextG,
					categoryTextB = categoryTextB
				}
				]]--
			end
			
			--[[
			for k=1,15,1 do
				self:addItem( { icon=self.vTable[i].iconparams.icon, width=self.vTable[i].iconparams.iconWidth, height=self.vTable[i].iconparams.iconHeight }, self.vTable[i].mainTitle, self.vTable[i].subTitle, self.vTable[i].onTouch, self.vTable[i].hideArrow, self.vTable[i].isCategory, self.vTable[i].categoryBg, self.vTable[i].categoryHeight, self.vTable[i].categoryTextR, self.vTable[i].categoryTextG, self.vTable[i].categoryTextB )
			end
			]]--
		end
		
		--
		
		-- ======================================================================================
		--
		-- ======================================================================================
		
		-- when item is touched
			
		function scrollView:refresh( forResizeCall )
			-- this function should be called whenever item is removed so that elements
			-- shift upward properly and there is no "gaps" between list items
			
			local i
			local list = self.listItems
			local maxItems = table.getn( list )
			local nextRow = 0
			
			for i=1,maxItems,1 do
				if i == 1 then
					self.listItems[i].y = nextRow - 1
					self.listItems[i].index = 1
				else
					nextRow = nextRow + self.listItems[i-1].rowHeight
					self.listItems[i].y = nextRow
					self.listItems[i].index = i
				end
					
				if forResizeCall then
					-- update list's myWidth property
					self.myWidth = self.parent.myWidth
					self.myHeight = self.parent.myHeight
					
					-- reposition right arrow (if there is one)
					if self.listItems[i].rightArrow then
						self.listItems[i].rightArrow.x = self.myWidth - 12
					end
					
					-- reposition selector icon (if there is one)
					if self.listItems[i].selectorIcon then
						self.listItems[i].selectorIcon.x = self.myWidth - 12
					end
					
					-- handle background rectangles (for individual list items)
					--local oldX = self.listItems[i].bgRect.x
					--local oldY = self.listItems[i].bgRect.y
					
					if self.listItems[i].bgRect then
						self.listItems[i].bgRect:removeSelf()
						self.listItems[i].bgRect = nil
					
					
						local r, g, b = hex2rgb( self.fillColor )
			
						self.listItems[i].bgRect = display.newRect( 0, 0, self.myWidth, self.rowHeight )
						self.listItems[i].bgRect:setReferencePoint( display.TopLeftReferencePoint )
						self.listItems[i].bgRect.x = 0
						self.listItems[i].bgRect.y = 0
						self.listItems[i].bgRect:setFillColor( r, g, b, 255 )
						
						self.listItems[i]:insert( self.listItems[i].bgRect )
						
						self.listItems[i].bgRect:toBack()
					end
					
					-- 1px bottom line to separate list items
					if self.listItems[i].bottomLine then
						self.listItems[i].bottomLine:removeSelf()
						self.listItems[i].bottomLine = nil
						
						self.listItems[i].bottomLine = display.newLine( 0, self.listItems[i].bgRect.height, self.myWidth, self.listItems[i].bgRect.height )
					
					
						if not self.linesHidden then
							self.listItems[i].bottomLine:setColor( 233, 233, 233, 255 )
						else
							self.listItems[i].bottomLine:setColor( r, g, b, 255 )
						end
						self.listItems[i].bottomLine.width = 2.0
					
						self.listItems[i]:insert( self.listItems[i].bottomLine )
					end
					
					-- add scroll bar
					self:addScrollBar( 0, 0, 0, 120 )
					
					self.parent.header:toFront()
				end
			end
			
			self.selectedItem = nil
			
			-- refresh scrollbar
			self:addScrollBar( 0, 0, 0, 120 )
		end
		
		--
		
		-- ======================================================================================
		--
		-- ======================================================================================
		
		function scrollView:clearSelection()
			if self.selectionList then
				
				local i
				local totalItems = table.getn( self.listItems )
				--local totalItems = table.getn( selectionList.multiList )
				
				-- clear the entire multiList (multi-list holds selected items)
				self.multiList = {}
				
				-- loop through selection list and reset the colors (selected items are grey)
				for i=1,totalItems,1 do
					local j = self.listItems[i]
					if not j.isCategory then
						j.titleText.textObject:setTextColor( 0, 0, 0, 255 )
						
						if j.subtitleText then
							j.subtitleText.textObject:setTextColor( 106, 115, 125, 255 )
						end
					end
				end
				
			else
				return
			end
		end
		
		--
		
		-- ======================================================================================
		--
		-- ======================================================================================
		
		function scrollView:removeItem( index )
			
			if type(index) == "table" then
				index = index.index
			end
			
			
			local list = self
			
			if list.listItems[index].touch then
				list.listItems[index]:removeEventListener( "touch", list.listItems[index] )
			end
			
			Runtime:removeEventListener( "enterFrame", list.listItems[index] )
			
			local i
			local maxItems = #list.listItems[index]
			
			for i=maxItems,1,-1 do
				local child = list.listItems[index][i]
				child.parent:remove( child )
				child = nil
			end
			
			list.listItems[index]:removeSelf()
			
			table.remove( list.listItems, index )
			list.nextRow = list.nextRow - list.rowHeight
			
			self:refresh()
		end
		
		-- ======================================================================================
		--
		-- ======================================================================================
		
		function scrollView:removeAllItems()
			local i
			local numItems = table.getn( self.listItems )
			
			for i=numItems,1,-1 do
				self:removeItem( i )
			end
		end
		
		-- ======================================================================================
		--
		-- ======================================================================================
		
		function scrollView:removeListeners()
			local i
			local numItems = table.getn( self.listItems )
			
			for i=numItems,1,-1 do
				--self:removeItem( i )
				local child = self.listItems[i]
				
				if child.repeatFunction then
					Runtime:removeEventListener( "enterFrame", child )
					--print( "enterframe removed from list entry" )
				end
			end
		end
		
		-- ======================================================================================
		--
		-- ======================================================================================
		
		function scrollView:addListeners()
			local i
			local numItems = table.getn( self.listItems )
			
			for i=numItems,1,-1 do
				--self:removeItem( i )
				local child = self.listItems[i]
				
				if child.repeatFunction then
					Runtime:addEventListener( "enterFrame", child )
					--print( "enterframe re-instated for list entry" )
				end
			end
		end
		
		-- ======================================================================================
		--
		-- ======================================================================================
		
		function scrollView:printItems()
			local i
			local array = self.listItems
			local maxItems = table.getn( array )
			
			for i=1,maxItems,1 do
				print( "List item: " .. tostring( array[i] ) )
			end
		end
		
		self:insert( scrollView )
		self.header:toFront()
		
		return scrollView
	end
	
	-- ======================================================================================
	--
	-- ======================================================================================
	
	function screenGroup:newPicker( wheelType, eventListener, startYear, endYear, selectedFirst, selectedSecond, selectedYear )
		
		-- first, remove any current picker if there is one
		if currentPicker then
			self:hidePicker( currentPicker )
		end
		
		if not wheelType then
			wheelType = "custom1"
		end
		
		-- top, bottom, hasTitle, hasStatusBar, rowHeight, selectionList, fillColor, hideLines, scrollDisabled, customTitleHeight
		local pickerGroup = display.newGroup(); pickerGroup.myName = "pickerGroup"
		local pickerTop = display.newGroup()
		local pickerBottom = display.newGroup()
		
		local top = 348 - 88
--		local top = 88

		local bottom = 0 --88
		
		local rowHeight = 44
		local fillColor = "FFFFFF"
		
		local wheelBgFile = "coronaui_ipadwheelborder.png"
		local wheelBgWidth = 336
		local wheelX = -7
		
		--[[
		if display.contentHeight <= 320 then
			wheelBgFile = "coronaui_ipadwheelborder-long.png"
			wheelBgWidth = 480
			wheelX = -display.contentWidth * 0.5
		end
		]]--
		
		local pickerBorder = display.newImageRect( wheelBgFile, wheelBgWidth, 276 )
		pickerBorder:setReferencePoint( display.TopLeftReferencePoint )
		pickerBorder.x = wheelX
		pickerBorder.y = 214
		pickerBorder.alpha = 0.9
		
		pickerGroup:insert( pickerBorder )
	 
		--setup picker(s):
		local pickerScroller = pickerScroller.new{ top=top, bottom=bottom }
		
		pickerScroller.rowHeight = rowHeight
		pickerScroller.nextRow = -132	--> holds y value of where next row should start
		pickerScroller.fillColor = fillColor
		local r, g, b = hex2rgb( fillColor )
		
		pickerScroller.fillR = r
		pickerScroller.fillG = g
		pickerScroller.fillB = b
		
		-- for capturing wheel input
		screenGroup.wheelInput = {}
		
		if eventListener and type(eventListener) == "function" then
			pickerGroup.onComplete = eventListener
		end
		
		if isInfinite then
			pickerScroller.isInfinite = true
		else
			pickerScroller.isInfinite = false
		end
		
		-- create a white background for list items
		local bgFill = display.newRect( 0, 252, 320, 251 )
			
		bgFill:setFillColor( r, g, b, 255 )
		
		pickerBottom:insert( bgFill )
		pickerBottom:insert( pickerScroller )
		
		local pickerScroller2	--> for day column
		local pickerScroller3	--> for year column
		
		-- date and/or time picker-related stuff
		if wheelType == "date" or wheelType == "time" then
			
			-- set up "day" column
			pickerScroller2 = daypickerScroller.new{ top=top, bottom=bottom }
			pickerScroller2.rowHeight = rowHeight
			pickerScroller2.nextRow = -132	--> holds y value of where next row should start
			pickerScroller2.fillColor = fillColor
			local r, g, b = hex2rgb( fillColor )
			
			pickerScroller2.fillR = r
			pickerScroller2.fillG = g
			pickerScroller2.fillB = b
			
			pickerScroller2.x = 158
			pickerBottom:insert( pickerScroller2 )
			
			-- set up "year" column
			pickerScroller3 = yearpickerScroller.new{ top=top, bottom=bottom }
			pickerScroller3.rowHeight = rowHeight
			pickerScroller3.nextRow = -132	--> holds y value of where next row should start
			pickerScroller3.fillColor = fillColor
			local r, g, b = hex2rgb( fillColor )
			
			pickerScroller3.fillR = r
			pickerScroller3.fillG = g
			pickerScroller3.fillB = b
			
			pickerScroller3.x = 220
			pickerBottom:insert( pickerScroller3 )
		end
		
		-- create top scroller overlay
		
		local scrollerTop
				
		if wheelType == "custom1" or wheelType == "custom2" then
			scrollerTop = display.newImageRect( "coronaui_picker1top.png", 320, 252 )
		elseif wheelType == "date" or wheelType == "time" then
			scrollerTop = display.newImageRect( "coronaui_picker1top-date.png", 320, 252 )
		end
		
		
		--scrollerTop:setReferencePoint( display.BottomCenterReferencePoint )
		
		-- found that the overlay was offset by 160 pixels.  if this is not the case, comment
		-- out the following line, and uncomment the self.myWidth * 0.5 line.
		scrollerTop.x = 160
		--scrollerTop.x = self.myWidth * 0.5
		
		
		
		--scrollerTop.y = display.contentHeight
		scrollerTop.y = 228 + scrollerTop.height * 0.5		

		pickerTop:insert( scrollerTop )
		
		-- end top scroller overlay
		
		--
		
		local pickerMask = graphics.newMask( "coronaui_pickermask.png" )
		
		local dimBg = display.newRect( 0, 23, 320, 400 )
		dimBg:setFillColor( 98, 98, 98, 150 )
		
		pickerBottom:insert( dimBg )
		dimBg:toBack()
		dimBg.isVisible = false
		
		--print( "width: " .. pickerBottom.width .. ", height: " .. pickerBottom.height )
		
		pickerBottom:setMask( pickerMask )
		
		pickerBottom.maskX = pickerBottom.maskX + pickerBottom.width * 0.5
		pickerBottom.maskY = pickerBottom.maskY + pickerBottom.height * 0.5
		
		-- prepare to accept list items
		pickerScroller.listItems = {}
		
		-- prepare to accept multiple selection items
		pickerScroller.multiList = {}
		
		-- variable below to know which item to call listener
		pickerScroller.selectedItem = nil
		
		-- set width
		pickerScroller.myWidth = self.myWidth
		
		if wheelType == "date" or wheelType == "time" then
			
			-- prepare to accept list items
			pickerScroller2.listItems = {}
			pickerScroller3.listItems = {}
			
			-- prepare to accept multiple selection items
			pickerScroller2.multiList = {}
			pickerScroller3.multiList = {}
			
			-- variable below to know which item to call listener
			pickerScroller2.selectedItem = nil
			pickerScroller3.selectedItem = nil
		end
		
		--
		
		-- ======================================================================================
		--
		-- ======================================================================================
		
		function pickerScroller:removeListeners()
			local i
			local numItems = table.getn( self.listItems )
			
			for i=numItems,1,-1 do
				--self:removeItem( i )
				local child = self.listItems[i]
				
				if child.repeatFunction then
					Runtime:removeEventListener( "enterFrame", child )
					--print( "enterframe removed from list entry" )
				end
			end
		end
		
		-- ======================================================================================
		--
		-- ======================================================================================
		
		function pickerScroller:addItem( textString )
			
			local list = self
			
			local topY = list.nextRow
			local rowHeight = list.rowHeight
			local newListItem = display.newGroup()
			
			local r, g, b = hex2rgb( list.fillColor )
			
			local bgRect
			
			if wheelType == "custom1" then
				bgRect = display.newRect( 0, 0, self.myWidth, list.rowHeight )
				
			elseif wheelType == "date" or wheelType == "time" then
				bgRect = display.newRect( 0, 0, 156, list.rowHeight )
			end
			
			bgRect:setFillColor( r, g, b, 255 )
			
			newListItem:insert( bgRect )
			
			newListItem.bgRect = bgRect
			
			
			-- LIST ITEM PROPERTIES
			
			newListItem.index = #list.listItems + 1
			
			-- END LIST ITEM PROPERTIES
			
			--
			
			local startingX = 26
			
			--
			
			-- START TEXT HANDLING
			local textGroup = display.newGroup()
			newListItem:insert( textGroup )
			
			local labelText
			
			if wheelType == "custom1" then
				labelText = newRetinaText( textString, 0, 0, "HelveticaNeue-Bold", 22, 0, 0, 0, "left", false, textGroup )
			
			elseif wheelType == "date" or wheelType == "time" then
				-- right-align text if it is a date picker
				startingX = 146
				labelText = newRetinaText( textString, 0, 0, "HelveticaNeue-Bold", 22, 0, 0, 0, "right", false, textGroup )
			end
			
			local titleY = 0 --list.rowHeight * 0.5
			labelText.textObject.defaultX = startingX
			labelText.textObject.defaultY = titleY
			labelText:updateText( textString )
			
			newListItem.textString = labelText
				
			textGroup:setReferencePoint( display.CenterReferencePoint )
			textGroup.y = list.rowHeight * 0.5
			
			-- END TEXT HANDLING
			
			--
			
			list:insert( newListItem )
			newListItem.y = topY
			newListItem.initY = newListItem.y
			table.insert( list.listItems, newListItem )
			
			self.nextRow = topY + rowHeight
			
			function onBgTouch( self, event )
				if event.phase == "began" then
					--display.getCurrentStage():setFocus( self )
					--self.isFocus = true
					
					--local theEx = newRetinaText( "x", self.x + 30, self.y + self.height *0.5, "Helvetica-Bold", 18, 0, 0, 0, "center", false, list )
					--theEx:toFront()
				end
			end
			
			newListItem.touch = onBgTouch
			newListItem:addEventListener( "touch", newListItem )
			
			
			--******* OFFSCREEN VISIBILITY CULLING TO BOOST PERFORMANCE FOR LARGE LISTS *******--
			
			local spacingThresh = 115	--> 115
			
			local moveCat = function( self, event )
				if list.y then
					if -(list.y) >= (self.initY - spacingThresh ) then
						if list.y < (self.initY + spacingThresh ) then
							self.isVisible = false
						else
							self.isVisible = true
						end
					
					elseif -(list.y) <= (self.initY - (display.contentHeight - spacingThresh)) then
						self.isVisible = false
					
					else
						self.isVisible = true
					end
				end
			end
			
			function newListItem:enterFrame( event )
				self:repeatFunction( event )
			end
			
			newListItem.repeatFunction = moveCat
			Runtime:addEventListener( "enterFrame", newListItem )
			
			--******* END OFFSCREEN VISIBILITY CULLING TO BOOST PERFORMANCE FOR LARGE LISTS *******--
		
			
			
			list:refresh()
		end
				
		-- FOR THE SECOND COLUMN IN DATE PICKER:
		
		if pickerScroller2 then
			--
			
			-- ======================================================================================
			--
			-- ======================================================================================
			
			function pickerScroller2:removeListeners()
				local i
				local numItems = table.getn( self.listItems )
				
				for i=numItems,1,-1 do
					--self:removeItem( i )
					local child = self.listItems[i]
					
					if child.repeatFunction then
						Runtime:removeEventListener( "enterFrame", child )
						--print( "enterframe removed from list entry" )
					end
				end
			end

			
			function pickerScroller2:addItem( textString )
				
				local list = self
				
				local topY = list.nextRow
				local rowHeight = list.rowHeight
				local newListItem = display.newGroup()
				
				local r, g, b = hex2rgb( list.fillColor )
				
				local bgRect = display.newRect( 0, 0, 60, list.rowHeight )
				bgRect:setFillColor( r, g, b, 255 )
				
				newListItem:insert( bgRect )
				
				newListItem.bgRect = bgRect
				
				
				-- LIST ITEM PROPERTIES
				
				newListItem.index = #list.listItems + 1
				
				-- END LIST ITEM PROPERTIES
				
				--
				
				local startingX = 18
				
				--
				
				-- START TEXT HANDLING
				local textGroup = display.newGroup()
				newListItem:insert( textGroup )
				
				local labelText = newRetinaText( textString, 0, 0, "HelveticaNeue-Bold", 22, 0, 0, 0, "left", false, textGroup )
				
				local titleY = 0 --list.rowHeight * 0.5
				labelText.textObject.defaultX = startingX
				labelText.textObject.defaultY = titleY
				labelText:updateText( textString )
				
				newListItem.textString = labelText
					
				textGroup:setReferencePoint( display.CenterReferencePoint )
				textGroup.y = list.rowHeight * 0.5
				
				-- END TEXT HANDLING
				
				--
				
				list:insert( newListItem )
				newListItem.y = topY
				newListItem.initY = newListItem.y
				table.insert( list.listItems, newListItem )
				
				self.nextRow = topY + rowHeight
				
				
				
				--******* OFFSCREEN VISIBILITY CULLING TO BOOST PERFORMANCE FOR LARGE LISTS *******--
			
				local spacingThresh = 115	--> 115
				
				local moveCat = function( self, event )
					if list.y then
						if -(list.y) >= (self.initY - spacingThresh ) then
							if list.y < (self.initY + spacingThresh ) then
								self.isVisible = false
							else
								self.isVisible = true
							end
						
						elseif -(list.y) <= (self.initY - (display.contentHeight - spacingThresh)) then
							self.isVisible = false
						
						else
							self.isVisible = true
						end
					end
				end
				
				function newListItem:enterFrame( event )
					self:repeatFunction( event )
				end
				
				newListItem.repeatFunction = moveCat
				Runtime:addEventListener( "enterFrame", newListItem )
				
				--******* END OFFSCREEN VISIBILITY CULLING TO BOOST PERFORMANCE FOR LARGE LISTS *******--
				
				
				list:refresh()
			end
			
			-- year column:
			
			--
			
			-- ======================================================================================
			--
			-- ======================================================================================
			
			function pickerScroller3:removeListeners()
				local i
				local numItems = table.getn( self.listItems )
				
				for i=numItems,1,-1 do
					--self:removeItem( i )
					local child = self.listItems[i]
					
					if child.repeatFunction then
						Runtime:removeEventListener( "enterFrame", child )
						--print( "enterframe removed from list entry" )
					end
				end
			end
			
			function pickerScroller3:addItem( textString )
				
				local list = self
				
				local topY = list.nextRow
				local rowHeight = list.rowHeight
				local newListItem = display.newGroup()
				
				local r, g, b = hex2rgb( list.fillColor )
				
				local bgRect = display.newRect( 0, 0, 102, list.rowHeight )
				bgRect:setFillColor( r, g, b, 255 )
				
				newListItem:insert( bgRect )
				
				newListItem.bgRect = bgRect
				
				
				-- LIST ITEM PROPERTIES
				
				newListItem.index = #list.listItems + 1
				
				-- END LIST ITEM PROPERTIES
				
				--
				
				local startingX = 18
				
				--
				
				-- START TEXT HANDLING
				local textGroup = display.newGroup()
				newListItem:insert( textGroup )
				
				local labelText = newRetinaText( textString, 0, 0, "HelveticaNeue-Bold", 22, 0, 0, 0, "left", false, textGroup )
				
				local titleY = 0 --list.rowHeight * 0.5
				labelText.textObject.defaultX = startingX
				labelText.textObject.defaultY = titleY
				labelText:updateText( textString )
				
				newListItem.textString = labelText
					
				textGroup:setReferencePoint( display.CenterReferencePoint )
				textGroup.y = list.rowHeight * 0.5
				
				-- END TEXT HANDLING
				
				--
				
				list:insert( newListItem )
				newListItem.y = topY
				newListItem.initY = newListItem.y
				table.insert( list.listItems, newListItem )
				
				self.nextRow = topY + rowHeight
				
				
				--******* OFFSCREEN VISIBILITY CULLING TO BOOST PERFORMANCE FOR LARGE LISTS *******--
			
				local spacingThresh = 115	--> 115
				
				local moveCat = function( self, event )
					if list.y then
						if -(list.y) >= (self.initY - spacingThresh ) then
							if list.y < (self.initY + spacingThresh ) then
								self.isVisible = false
							else
								self.isVisible = true
							end
						
						elseif -(list.y) <= (self.initY - (display.contentHeight - spacingThresh)) then
							self.isVisible = false
						
						else
							self.isVisible = true
						end
					end
				end
				
				function newListItem:enterFrame( event )
					self:repeatFunction( event )
				end
				
				newListItem.repeatFunction = moveCat
				Runtime:addEventListener( "enterFrame", newListItem )
				
				--******* END OFFSCREEN VISIBILITY CULLING TO BOOST PERFORMANCE FOR LARGE LISTS *******--
				
				
				list:refresh()
			end
		end
		
		-- ======================================================================================
		--
		-- ======================================================================================
		
		function pickerScroller:addItemsFromData( dataTable )
			if dataTable and type(dataTable) == "table" then
				-- first, remove all existing data
				self:removeAllItems()
				
				-- add initial blank items
				if not self.isInfinite then
					self:addItem( "" )
					self:addItem( "" )
				end
				
				-- re-populate data from provided table
				local i
				local numItems = table.getn( dataTable )
				
				for i=1,numItems,1 do
					if type( dataTable[i] ) == "number" then
						self:addItem( tostring(dataTable[i]) )
						
					elseif type( dataTable[i] ) == "string" then
						self:addItem( dataTable[i] )
					
					else
						print( "ERROR: Each entry of dataTable must be type number or string" )
					end
				end
				
				-- add trailing blank items
				if not self.isInfinite then
					self:addItem( "" )
					self:addItem( "" )
				end
				
				-- start at the first item
				self.y = 260
			end
		end
		
		--
		
		if pickerScroller2 then
			function pickerScroller2:addItemsFromData( dataTable )
				if dataTable and type(dataTable) == "table" then
					-- first, remove all existing data
					self:removeAllItems()
					
					-- add initial blank items
					if not self.isInfinite then
						self:addItem( "" )
						self:addItem( "" )
					end
					
					-- re-populate data from provided table
					local i
					local numItems = table.getn( dataTable )
					
					for i=1,numItems,1 do
						if type( dataTable[i] ) == "number" then
							self:addItem( tostring(dataTable[i]) )
							
						elseif type( dataTable[i] ) == "string" then
							self:addItem( dataTable[i] )
						
						else
							print( "ERROR: Each entry of dataTable must be type number or string" )
						end
					end
					
					-- add trailing blank items
					if not self.isInfinite then
						self:addItem( "" )
						self:addItem( "" )
					end
					
					-- start at the first item
					self.y = 260
				end
			end
			
			-- year column:
			
			function pickerScroller3:addItemsFromData( dataTable )
				if dataTable and type(dataTable) == "table" then
					-- first, remove all existing data
					self:removeAllItems()
					
					-- add initial blank items
					if not self.isInfinite then
						self:addItem( "" )
						self:addItem( "" )
					end
					
					-- re-populate data from provided table
					local i
					local numItems = table.getn( dataTable )
					
					for i=1,numItems,1 do
						if type( dataTable[i] ) == "number" then
							self:addItem( tostring(dataTable[i]) )
							
						elseif type( dataTable[i] ) == "string" then
							self:addItem( dataTable[i] )
						
						else
							print( "ERROR: Each entry of dataTable must be type number or string" )
						end
					end
					
					-- add trailing blank items
					if not self.isInfinite then
						self:addItem( "" )
						self:addItem( "" )
					end
					
					-- start at the first item
					self.y = 260
				end
			end
		end
		
		-- ======================================================================================
		--
		-- ======================================================================================
		
		-- when item is touched
			
		function pickerScroller:refresh()
			-- this function should be called whenever item is removed so that elements
			-- shift upward properly and there is no "gaps" between list items
			
			local i
			local list = self.listItems
			local maxItems = table.getn( list )
			local nextRow = 0
			
			for i=1,maxItems,1 do
				if i == 1 then
					list[i].y = nextRow
					list[i].index = 1
				else
					nextRow = nextRow + self.rowHeight
					list[i].y = nextRow
					list[i].index = i
				end
			end
			
			self.selectedItem = nil
		end
		
		--
		
		if pickerScroller2 then
			function pickerScroller2:refresh()
				-- this function should be called whenever item is removed so that elements
				-- shift upward properly and there is no "gaps" between list items
				
				local i
				local list = self.listItems
				local maxItems = table.getn( list )
				local nextRow = 0
				
				for i=1,maxItems,1 do
					if i == 1 then
						list[i].y = nextRow
						list[i].index = 1
					else
						nextRow = nextRow + self.rowHeight
						list[i].y = nextRow
						list[i].index = i
					end
				end
				
				self.selectedItem = nil
			end
			
			-- year column:
			
			function pickerScroller3:refresh()
				-- this function should be called whenever item is removed so that elements
				-- shift upward properly and there is no "gaps" between list items
				
				local i
				local list = self.listItems
				local maxItems = table.getn( list )
				local nextRow = 0
				
				for i=1,maxItems,1 do
					if i == 1 then
						list[i].y = nextRow
						list[i].index = 1
					else
						nextRow = nextRow + self.rowHeight
						list[i].y = nextRow
						list[i].index = i
					end
				end
				
				self.selectedItem = nil
			end
		end
		
		-- ======================================================================================
		--
		-- ======================================================================================
		
		function pickerScroller:removeItem( index )
			
			if type(index) == "table" then
				index = index.index
			end
			
			
			local list = self
			
			if list.listItems[index].touch then
				list.listItems[index]:removeEventListener( "touch", list.listItems[index] )
			end
			
			local i
			local maxItems = #list.listItems[index]
			
			for i=maxItems,1,-1 do
				local child = list.listItems[index][i]
				child.parent:remove( child )
				child = nil
			end
			
			list.listItems[index]:removeSelf()
			
			table.remove( list.listItems, index )
			list.nextRow = list.nextRow - list.rowHeight
			
			self:refresh()
		end
		
		--
		
		if pickerScroller2 then
			function pickerScroller2:removeItem( index )
				
				if type(index) == "table" then
					index = index.index
				end
				
				
				local list = self
				
				if list.listItems[index].touch then
					list.listItems[index]:removeEventListener( "touch", list.listItems[index] )
				end
				
				local i
				local maxItems = #list.listItems[index]
				
				for i=maxItems,1,-1 do
					local child = list.listItems[index][i]
					child.parent:remove( child )
					child = nil
				end
				
				list.listItems[index]:removeSelf()
				
				table.remove( list.listItems, index )
				list.nextRow = list.nextRow - list.rowHeight
				
				self:refresh()
			end
			
			-- year column
			
			function pickerScroller3:removeItem( index )
				
				if type(index) == "table" then
					index = index.index
				end
				
				
				local list = self
				
				if list.listItems[index].touch then
					list.listItems[index]:removeEventListener( "touch", list.listItems[index] )
				end
				
				local i
				local maxItems = #list.listItems[index]
				
				for i=maxItems,1,-1 do
					local child = list.listItems[index][i]
					child.parent:remove( child )
					child = nil
				end
				
				list.listItems[index]:removeSelf()
				
				table.remove( list.listItems, index )
				list.nextRow = list.nextRow - list.rowHeight
				
				self:refresh()
			end
		end
		
		-- ======================================================================================
		--
		-- ======================================================================================
		
		function pickerScroller:removeAllItems()			
			local i
			local numItems = table.getn( self.listItems )
			
			for i=numItems,1,-1 do
				self:removeItem( i )
			end
		end
		
		--
		
		if pickerScroller2 then
			function pickerScroller2:removeAllItems()
				local i
				local numItems = table.getn( self.listItems )
				
				for i=numItems,1,-1 do
					self:removeItem( i )
				end
			end
			
			-- year column:
			
			function pickerScroller3:removeAllItems()
				local i
				local numItems = table.getn( self.listItems )
				
				for i=numItems,1,-1 do
					self:removeItem( i )
				end
			end
		end
		
		--
		
		-- ======================================================================================
		--
		-- ======================================================================================
		
		-- AUTO-POPULATE COLUMNS IF IT IS A DATE PICKER
		
		if wheelType == "date" then
			local dataTable = {}
			
			table.insert( dataTable, "January" )
			table.insert( dataTable, "February" )
			table.insert( dataTable, "March" )
			table.insert( dataTable, "April" )
			table.insert( dataTable, "May" )
			table.insert( dataTable, "June" )
			table.insert( dataTable, "July" )
			table.insert( dataTable, "August" )
			table.insert( dataTable, "September" )
			table.insert( dataTable, "October" )
			table.insert( dataTable, "November" )
			table.insert( dataTable, "December" )
			
			pickerScroller:addItemsFromData( dataTable )
			
			-- second (day) column
			local i
			local days31 = {}
			
			for i=1,31,1 do
				local insertString = i .. ""
				if i < 10 then
					insertString = "0" .. i
				end
				table.insert( days31, insertString )
			end
			
			pickerScroller2:addItemsFromData( days31 )
			
			-- third (year) column
			local yearsTable = {}
			
			if startYear and endYear then
				
				endYear = endYear + 1
				
				pickerScroller3.startYear = startYear
				pickerScroller3.endYear = endYear
				
				local numYears = endYear - startYear
				
				for i=1,numYears,1 do
					local j = i - 1
					local k = j + startYear
					local insertString = tostring( k )
					table.insert( yearsTable, insertString )
				end
				
				pickerScroller3.input = startYear
				
			else
				pickerScroller3.startYear = 1985
				pickerScroller3.endYear = 2025
				
				pickerScroller3.input = pickerScroller3.startYear
				
				for i=1,41,1 do
					local j = i - 1
					local k = j + 1985
					local insertString = tostring( k )
					table.insert( yearsTable, insertString )
				end
			end
			
			pickerScroller3:addItemsFromData( yearsTable )
			
			-- determine starting spot for selected year
			if selectedYear then
				local startYear = pickerScroller3.startYear
				local yearDiff = selectedYear - startYear
				
				local amountToScroll = 44 * yearDiff
				local endY = 260 - amountToScroll
				
				pickerScroller3.tween = transition.to( pickerScroller3, { time=400, y=endY, transition=easing.outQuad } )
				
				pickerScroller3.input = selectedYear
			else
				pickerScroller3.input = pickerScroller3.startYear
			end
			
			-- determine starting spot for selected second column
			if selectedSecond then
				local secondCol = selectedSecond - 1
				local amountToScroll = 44 * secondCol
				local endY = 260 - amountToScroll
				
				pickerScroller2.tween = transition.to( pickerScroller2, { time=400, y=endY, transition=easing.outQuad } )
				
				pickerScroller2.input = selectedSecond
			else
				pickerScroller2.input = 1
			end
		
		-- auto populate if wheel type is time
		elseif wheelType == "time" then
			local dataTable = {}
			local i
			for i=1,12,1 do
				local insertString = i .. " :"
				if i < 10 then
					insertString = "0" .. i .. " :"
				end
				table.insert( dataTable, insertString )
			end
			
			pickerScroller:addItemsFromData( dataTable )
			
			-- second (minute) column
			local minutes60 = {}
			
			for i=1,60,1 do
				local j = i -1
				local insertString = j
				if j < 10 then
					insertString = "0" .. j
				end
				table.insert( minutes60, insertString )
			end
			
			pickerScroller2:addItemsFromData( minutes60 )
			
			-- third (year) column
			local amPmTable = {}
			
			table.insert( amPmTable, "AM" )
			table.insert( amPmTable, "PM" )
			
			pickerScroller3:addItemsFromData( amPmTable )
			
			-- set default input values

			-- there is only two selections for AM or PM.
			if selectedYear < 0 or selectedYear > 1 then
				selectedYear = 0
			end
			
			-- adjust from 24hour clock to 12 hour.
			if selectedFirst > 12 then
				selectedFirst = selectedFirst - 12
			end

			pickerScroller.input = selectedFirst
			pickerScroller2.input = selectedSecond
			pickerScroller3.input = selectedYear
			pickerScroller3.startYear = 1
			
			
			
		--lastly if it is custom 1 or single column.
		elseif wheelType == "custom1" then
		
			-- we will use startYear as the input table..
			if  type(startYear) == "table" then		
				pickerScroller:addItemsFromData( startYear )
			end
			
			-- for custom use, we want to use the endYear entry to move to the offset.
			-- we have to bump endYear count by one to get to the correct entry.  
			-- The listing is indexed off by one.
			selectedFirst = endYear + 1
		end
		
		
		
		
		
		
		
		-- determine starting spot for selected first column
	--	if selectedFirst and wheelType ~= "custom1" then
		if selectedFirst  then

			local firstCol = selectedFirst - 1

			local amountToScroll = 44 * firstCol
			local endY = 260 - amountToScroll
			
			pickerScroller.tween = transition.to( pickerScroller, { time=400, y=endY, transition=easing.outQuad } )
			
			pickerScroller.input = selectedFirst
		else
			pickerScroller.input = 1
		end

		if wheelType == "date" or wheelType == "time" then
			if selectedSecond  then
				local SecondCol = selectedSecond - 1
				local amountToScroll = 44 * SecondCol
				local endY = 260 - amountToScroll
			
				pickerScroller2.tween = transition.to( pickerScroller2, { time=400, y=endY, transition=easing.outQuad } )
			
				pickerScroller2.input = selectedFirst
			else
				pickerScroller2.input = 1
			end
		end
		-- ======================================================================================
		--
		-- ======================================================================================
		
		pickerGroup.picker = pickerScroller
		if wheelType == "date" or wheelType == "time" then
			pickerGroup.daypicker = pickerScroller2
			pickerGroup.yearpicker = pickerScroller3
			
			pickerGroup.daypicker.wheelType = wheelType
			pickerGroup.yearpicker.wheelType = wheelType
		end
		
		pickerGroup:insert( pickerBottom )
		pickerGroup:insert( pickerTop )
		
		--pickerScroller:addItem( "" )
		--pickerScroller:addItem( "" )
		--[[
		if wheelType == "date" then
			pickerGroup.daypicker:addItem( "" )
			pickerGroup.daypicker:addItem( "" )
			
			pickerGroup.yearpicker:addItem( "" )
			pickerGroup.yearpicker:addItem( "" )
		end
		]]--
		
		if wheelType ~= "date" and wheelType ~= "time" then
			pickerScroller:addItem( "" )
			pickerScroller:addItem( "" )
		end
		
		pickerGroup.isVisible = false
		pickerGroup.y = pickerGroup.y + 504
		pickerGroup.isVisible = true
		
		function pickerGroup:moveTo( x, y )
			pickerGroup.x = x - 160
			pickerGroup.y = y - 348
		end
		
		if display.contentHeight <= 480 then
			local endY = 0
			
			if display.contentHeight <= 320 then
				endY = display.contentHeight * 0.5 - 342 --endY - 160
				pickerGroup.x = display.contentWidth * 0.5 - 160
			end
			
			transition.to( pickerGroup, { time=500, y=endY, transition=easing.outExpo } )
		end
		
		-- ipad/tabelet specific stuff
		if system.getInfo("model") == "iPad" or display.contentHeight > 480 then
			pickerGroup:moveTo( display.contentWidth * 0.5, display.contentHeight * 0.5 )
		end
		
		-- ======================================================================================
		--
		-- ======================================================================================
		
		-- ADD 'DONE' BUTTON TO TOP OF SCREEN
		
		local doneButton
		local cancelButton
		
		local captureInput = function( event )
			if event.phase == "release" then
				local eventListener
				if pickerGroup.onComplete then
					eventListener = pickerGroup.onComplete
				end
				
				--remove event listeners
				if pickerScroller then
					pickerScroller:removeListeners()
				end
				
				if pickerScroller2 then
					pickerScroller2:removeListeners()
				end
				
				if pickerScroller3 then
					pickerScroller3:removeListeners()
				end
				
				-- remove existing done button
				--screenGroup:addRightButton()
				
				-- restore previous buttons
				if self.leftButtonGroup then
					self.leftButtonGroup.isVisible = true
				end
				
				if self.rightButtonGroup.button then
					self.rightButtonGroup.button.isVisible = true
				end
				
				-- remove groups and buttons associated with the picker
				--[[
				if currentPicker then
					currentPicker:removeSelf()
					currentPicker = nil
				end
				]]--
				
				if doneButton then
					doneButton:removeSelf()
					doneButton = nil
				end
				
				if cancelButton then
					cancelButton:removeSelf()
					cancelButton = nil
				end
				
				if currentPicker then
					currentPicker:removeSelf()
					currentPicker = nil
				end
				
				
				local m, d, y = screenGroup:hidePicker( pickerGroup )
				
				if m then screenGroup.wheelInput[1] = m; else screenGroup.wheelInput[1] = 1; end
				if d then screenGroup.wheelInput[2] = d; else screenGroup.wheelInput[2] = 1; end
				if y then screenGroup.wheelInput[3] = y; else screenGroup.wheelInput[3] = 1; end
				
				if eventListener then
				
					-- added that if this is a custom picker there is only one return.  hence M...
					if wheelType == "custom1" then
						eventListener( m )
					else
						eventListener( m, d, y )
					end
				end
			end
		end
		
		local cancelInput = function( event )
			if event.phase == "release" then
				
				-- restore previous buttons
				if self.leftButtonGroup then
					self.leftButtonGroup.isVisible = true
				end
				
				if self.rightButtonGroup.button then
					self.rightButtonGroup.button.isVisible = true
				end
				
				--remove event listeners
				if pickerScroller then
					pickerScroller:removeListeners()
				end
				
				if pickerScroller2 then
					pickerScroller2:removeListeners()
				end
				
				if pickerScroller3 then
					pickerScroller3:removeListeners()
				end
				
				-- remove groups and buttons associated with the picker
				--[[
				if currentPicker then
					currentPicker:removeSelf()
					currentPicker = nil
				end
				]]--
				
				if doneButton then
					doneButton:removeSelf()
					doneButton = nil
				end
				
				if cancelButton then
					cancelButton:removeSelf()
					cancelButton = nil
				end
				
				--[[
				if currentPicker then
					currentPicker:removeSelf()
					currentPicker = nil
				end
				]]--
				
				screenGroup:hidePicker( pickerGroup, true )
				
				
				-- the cancel was selected from the picker and this will return to the caller
				-- three zeros if a time/date picker or just a single zero if a custom picker.
				if eventListener then
					if wheelType == "custom1" then
						eventListener( 0)
					else
						eventListener( 0, 0, 0 )
					end
				end

			end
		end
		
		-- first, copy existing left buttons
		if self.leftButtonGroup then
			self.leftButtonGroup.isVisible = false
		end
		
		if self.rightButtonGroup.button then
			self.rightButtonGroup.button.isVisible = false
		end
		
		-- show a "Done" button
		--self:addDoneButton( "Done", captureInput )
		
		
		local addDoneButton = function( buttonText, eventListener, isLong, customImg, customOverImg, customWidth, customHeight )
			if not eventListener or type(eventListener) ~= "function" then
				eventListener = function( event )
					if event.phase == "release" then
						print( "You never specified an event listener for this button." )
					end
				end
			end
			
			local buttonImage, overImage, width, height
			
			if not customImg then
				if not isLong then
					buttonImage = "coronaui_rightbtn.png"
					overImage = "coronaui_rightbtn-over.png"
					width = 62
					height = 30
				else
					buttonImage = "coronaui_rightbtnlong.png"
					overImage = "coronaui_rightbtnlong-over.png"
					width = 94
					height = 30
				end
			else
				buttonImage = customImg
				overImage = customOverImg
				if customWidth then width = customWidth; else
					if not isLong then width = 62; else width = 94; end
				end
				if customHeight then height = customHeight; else height = 30; end
			end
			
			if not buttonText then
				buttonText = "Done"
			end
			
			doneButton = ui.newButton{
				defaultSrc = buttonImage,
				defaultX = width,
				defaultY = height,
				overSrc = overImage,
				overX = width,
				overY = height,
				onEvent = eventListener,
				id = "doneButton",
				text = buttonText,
				font = "HelveticaNeue-Bold",
				textColor = { 255, 255, 255, 255 },
				size = 13,
				emboss = true
			}
			
			doneButton:setReferencePoint( display.CenterRightReferencePoint )
			pickerGroup:insert( doneButton )
			
			doneButton.x = 316; doneButton.y = 239
		end
		
		local addCancelButton = function( buttonText, eventListener, isLong, customImg, customOverImg, customWidth, customHeight )
			if not eventListener or type(eventListener) ~= "function" then
				eventListener = function( event )
					if event.phase == "release" then
						print( "You never specified an event listener for this button." )
					end
				end
			end
			
			local buttonImage, overImage, width, height
			
			if not customImg then
				if not isLong then
					buttonImage = "coronaui_rightbtn.png"
					overImage = "coronaui_rightbtn-over.png"
					width = 62
					height = 30
				else
					buttonImage = "coronaui_rightbtnlong.png"
					overImage = "coronaui_rightbtnlong-over.png"
					width = 94
					height = 30
				end
			else
				buttonImage = customImg
				overImage = customOverImg
				if customWidth then width = customWidth; else
					if not isLong then width = 62; else width = 94; end
				end
				if customHeight then height = customHeight; else height = 30; end
			end
			
			if not buttonText then
				buttonText = "Cancel"
			end
			
			cancelButton = ui.newButton{
				defaultSrc = buttonImage,
				defaultX = width,
				defaultY = height,
				overSrc = overImage,
				overX = width,
				overY = height,
				onEvent = eventListener,
				id = "doneButton",
				text = buttonText,
				font = "HelveticaNeue-Bold",
				textColor = { 255, 255, 255, 255 },
				size = 13,
				emboss = true
			}
			
			cancelButton:setReferencePoint( display.CenterLeftReferencePoint )
			pickerGroup:insert( cancelButton )
			
			cancelButton.x = 4; cancelButton.y = 239
		end
		
		addDoneButton( "Done", captureInput )
		addCancelButton( "Cancel", cancelInput )
		
		--currentPicker = pickerGroup
		currentPicker = pickerGroup
		
		return pickerGroup
	end
	
	-- ======================================================================================
	--
	-- ======================================================================================
	
	function screenGroup:hidePicker( pickerObject, noInput )
		if pickerObject then
			if not noInput then
				local first, second, third
				
				first = pickerObject.picker.input
				
				if pickerObject.yearpicker then
					third = pickerObject.yearpicker.input
					--print( third )
				end
				
				if pickerObject.daypicker then
					second = pickerObject.daypicker.input
					
					-- determine if the day is valid based on selected month
					-- in other words, check if month is february and/or leap year
					
					if first == 2 then	--> if second month...
						local year = pickerObject.yearpicker.input
						local maxDays = 28
						
						-- if(year%400 ==0 || (year%100 != 0 && year%4 == 0))
						if (year % 400) == 0 or (year %100) ~=0 and (year % 4) == 0 then
							maxDays = 29
						end
						
						if second > maxDays then
							second = maxDays
						end
					end
				end
				
				--cleanGroups( pickerObject, 0 )
				if pickerObject.parent then
					pickerObject:removeSelf()
				else
					pickerObject = nil
				end
					
				
				if second and not third then
					return first, second
				elseif second and third then
					return first, second, third
				else
					return first
				end
				
				--currentPicker = nil
				
				if currentPicker then
					--currentPicker:removeSelf()
					currentPicker = nil
				end
			else
				--cleanGroups( pickerObject, 0 )
				pickerObject:removeSelf()
				
				--currentPicker = nil
				
				if currentPicker then
					--currentPicker:removeSelf()
					currentPicker = nil
				end
			end
		end
	end
	
	-- ======================================================================================
	--
	-- ======================================================================================
	
	function screenGroup:newOnOffSwitch( x, y, startingValue, SwitchTextEventListener, SwitchIntEventListener)
		-- Staring value can either be "on" or "off"
		
		-- declare groups
		local onOffSwitch = display.newGroup()	--> holds entire switch
		self:insert( onOffSwitch )
		
		
		-- START DEFAULT VAUES:
		
		if not x then x = 0; end
		if not y then y = 0; end
		
		if not startingValue then
			onOffSwitch.value = "on"
		else
			onOffSwitch.value = startingValue
		end
		
		-- // END DEFAULT VALUES
		
		-- create the actual on/off switch graphic
		local onOffSwitchGraphic = display.newImageRect( "coronaui_onoffslider.png", 156, 36 )
		
		-- if onOffSwitch is set to "off", change it's position
		if onOffSwitch.value == "off" then
			onOffSwitchGraphic.x = -54
		end
		
		onOffSwitchGraphic.prevPos = onOffSwitchGraphic.x
		
		onOffSwitch:insert( onOffSwitchGraphic )
		
		-- create a bitmap mask and set it on the whole group
		local onOffMask = graphics.newMask( "coronaui_onoffslidermask.png" )
		onOffSwitch:setMask( onOffMask )
		
		onOffSwitch.maskScaleX, onOffSwitch.maskScaleY = .5, .5
		
		-- START TOUCH LISTENER FOR ACTUAL ON/OFF SLIDER:
		
		function onOffSwitchGraphic:touch( event )

			if event.phase == "began"  and event.y > 64 and not currentPicker then
				
				--[[
				if screenGroup.tableView then
					print( "it exists!" )
				end
				]]--
				
				screenGroup.touchingControl = true
				
				display.getCurrentStage():setFocus( self )
				self.isFocus = true
				

				self.delta = 0
			
			elseif( self.isFocus ) then
				if event.phase == "moved" then
					
					--self.x = event.x - event.xStart
					self.delta = event.x - self.prevPos
					self.prevPos = event.x
					
					self.x = self.x + self.delta
					
					print("moved it")
					
					if self.x < -54 then self.x = -54; end
					if self.x > 0 then self.x = 0; end
				
				elseif event.phase == "ended" or event.phase == "cancelled" then
					display.getCurrentStage():setFocus( nil )
					self.isFocus = false
					
					screenGroup.touchingControl = false
					
					if self.tween then transition.cancel( self.tween ); self.tween = nil; end
										
					local assessSwitch = function()
						if self.x > -23 then
							self.parent.value = "on"
							SwitchInt = 1
											
						else
							self.parent.value = "off"
							SwitchInt = 0
						end
						
						if SwitchTextEventListener and type(SwitchTextEventListener) == "function" then
								SwitchTextEventListener(self.parent.value)
						end
						
						if SwitchIntEventListener and type(SwitchIntEventListener) == "function" then
								SwitchIntEventListener(SwitchInt)
						end
						
					end
					
					
					
					if self.parent.value == "off" then
						self.tween = transition.to( self, { time=200, x=0, transition=easing.outQuad, onComplete=assessSwitch } )
					else
						self.tween = transition.to( self, { time=200, x=-54, transition=easing.outQuad, onComplete=assessSwitch } )
					end
				end
			end
		end
		
		onOffSwitchGraphic:addEventListener( "touch", onOffSwitchGraphic )
		
		-- // END TOUCH LISTENER FOR ON/OFF SLIDER
		
		-- finally, position entire group:
		onOffSwitch.x = x
		onOffSwitch.y = y
		
		return onOffSwitch
	end
	
	-- ======================================================================================
	--
	-- ======================================================================================
	
	function screenGroup:newSliderControl( x, y, startingValue, callbackListener, tableItem )
		-- Staring value is a value between 1-100
		
		-- declare groups
		local sliderControl = display.newGroup()	--> holds entire switch
		local maskGroup = display.newGroup()		--> will mask everything within
		
		sliderControl:insert( maskGroup )
		
		self:insert( sliderControl )
		
		-- START DEFAULT VAUES:
		
		if not x then x = self.myWidth * 0.5; end
		if not y then y = display.contentHeight * 0.5; end
		
		if not startingValue then
			sliderControl.value = 50
		else
			sliderControl.value = startingValue
		end
		
		-- // END DEFAULT VALUES
		
		-- create the actual on/off switch graphic
		local sliderGraphic = display.newImageRect( "coronaui_slider.png", 480, 28 )
		
		-- determine position and adjust accordingly
		local pixelPosition = ((sliderControl.value * 220) / 100) - 110
		sliderGraphic:setReferencePoint( display.CenterReferencePoint )
		sliderGraphic.x = pixelPosition
		
		maskGroup:insert( sliderGraphic )
		sliderControl.graphic = sliderGraphic
		
		-- create the slider handle
		local sliderHandle = display.newImageRect( "coronaui_sliderhandle.png", 480, 28 )
		
		-- determine position and adjust accordingly
		sliderHandle:setReferencePoint( display.CenterReferencePoint )
		sliderHandle.x = pixelPosition
		
		sliderControl:insert( sliderHandle )
		sliderControl.handle = sliderHandle
		
		-- create a bitmap mask and set it on the whole group
		local sliderMask = graphics.newMask( "coronaui_slidermask.png" )
		maskGroup:setMask( sliderMask )
		maskGroup.maskScaleX, maskGroup.maskScaleY = .5, .5
		
		-- START TOUCH LISTENER FOR ACTUAL SLIDER CONTROL:
		
		function sliderHandle:touch( event )
			if event.phase == "began" and event.y > 64 and not currentPicker then
				
				screenGroup.touchingControl = true
				
				display.getCurrentStage():setFocus( self )
				self.isFocus = true
				
				--theParent = self.parent.parent
				theParent = self.parent
				self.x = event.x - 160
				theParent.graphic.x = self.x
				
				if self.x < -110 then self.x = -110; theParent.graphic.x = self.x; end
				if self.x > 111 then self.x = 111; theParent.graphic.x = self.x; end
				
				-- adjust value depending on where slider control was touched
				if self.x > -112 and self.x < 112 then
					local newValue = mFloor((((112 + self.x) * 100) / 220))
					theParent.value = newValue
					
					if theParent.value < 0 then theParent.value = 0; end
					if theParent.value > 100 then theParent.value = 100; end
					
					--print( theParent.value )
				end
				
			elseif event.phase == "moved" and self.isFocus then
				
				--local theParent = self.parent.parent
				local theParent = self.parent
				
				self.x = event.x - 160
				theParent.graphic.x = self.x
				
				-- keep it within slider bounds
				if self.x < -110 then self.x = -110; theParent.graphic.x = self.x; end
				if self.x > 111 then self.x = 111; theParent.graphic.x = self.x; end
				
				-- change value as slider is moved
				if self.x > -112 and self.x < 112 then
					local newValue = mFloor((((112 + self.x) * 100) / 220))
					theParent.value = newValue
					
					if theParent.value < 0 then theParent.value = 0; end
					if theParent.value > 100 then theParent.value = 100; end
					
					--print( theParent.value )
				end
				
				-- call the listener (if it exists)
				if callbackListener and type( callbackListener ) == "function" then
					local theEvent = {
						item = tableItem,
						value = theParent.value
					}
					callbackListener( theEvent )
				end
				
			elseif event.phase == "ended" or event.phase == "cancelled" and self.isFocus then
				
				screenGroup.touchingControl = false
				
				display.getCurrentStage():setFocus( nil )
				self.isFocus = false
				
			end
		end
		
		sliderHandle:addEventListener( "touch", sliderHandle )
		
		-- // END TOUCH LISTENER FOR SLIDER CONTROL
		
		-- finally, position entire group:
		sliderControl.x = x
		sliderControl.y = y
		
		return sliderControl
	end
	
	-- ======================================================================================
	--
	-- ======================================================================================
	
	function screenGroup:createTableList( rowsTable )
		if rowsTable and type(rowsTable) == "table" then
			local i
			
			for i=1,4,1 do
				table.insert( rowsTable, { "nobg", "" } )
			end
			
			-- list table attribtues
			--local tableView = display.newGroup()
			
			local tableView = self:newList( 0, 0, false, false, nil, false, nil, true, false )
			tableView.listItems = {}
			tableView.upperLimit = 66
			
			tableView.selectionTables = {}	--> for multiple item selection (checkmarks)
			tableView.selectionValues = {}	--> for single item selection (checkmarks)
			
			-- go through each of the rows and create a new list item
			local entryCount = #rowsTable
			
			
			for i=1,entryCount,1 do
				local itemGroup = display.newGroup()
				tableView:insert( itemGroup )
								
				local item = rowsTable[i]
				local prevItem, nextItem
				if i > 1 then prevItem = i-1; end
				if i < entryCount then nextItem = i+1; end
				
				itemGroup.rowType = item[1]
				
				local icon
				local labelText
				local secondLabelText
				local onOffSwitch
				local eventListener
				
				local theY = 43 * i
				
				if itemGroup.rowType == "nobg" then
				
				-- **********************************************************
				-- **********************************************************
				--
				-- NO BACKGROUND TABLEVIEW ITEM
				--
				-- **********************************************************
				-- **********************************************************
					
					if item[2] and type(item[2]) == "string" then
						labelText = item[2]
					end
					
					if not labelText or type(labelText) ~= "string" then
						labelText = ""
					end
					
					if labelText ~= "" then
						itemGroup.labelText = newRetinaText( labelText, 20, 0, "HelveticaNeue-Bold", 18, 76, 86, 108, "left", true, itemGroup )
						itemGroup.labelText.y = 26
						itemGroup.labelText:updateText( labelText )
					end
				
				elseif itemGroup.rowType == "whitebg" then
				
				-- **********************************************************
				-- **********************************************************
				--
				-- WHITE BACKGROUND TABLEVIEW ITEM
				--
				-- **********************************************************
				-- **********************************************************
					
					local bgFile, bgOverFile
					local bgW, bgH
					local nextX = 20
					local labelY
					
					if i == 1 or tableView.listItems[prevItem].rowType == "nobg" or tableView.listItems[prevItem].rowType == "spacer" then
						
						-- top item should be rounded
						bgFile = "coronaui_tabletop.png"
						bgOverFile = "coronaui_tabletop-selected.png"
						
						if rowsTable[nextItem] then
							if rowsTable[nextItem][1] == "nobg" or rowsTable[nextItem][1] == "spacer" then
								bgFile = "coronaui_tabletopbottom.png"
								bgOverFile = "coronaui_tabletopbottom-selected.png"
							end
						end
						
						bgW = 302; bgH = 46
						bgW = self.myWidth - 18
						labelY = 26
					elseif i == entryCount then
						
						bgFile = "coronaui_tablebottom.png"
						bgOverFile = "coronaui_tablebottom-selected.png"
						
						if i == 1 or tableView.listItems[prevItem].rowType == "nobg" or tableView.listItems[prevItem].rowType == "spacer" then
							bgFile = "coronaui_tabletopbottom.png"
							bgOverFile = "coronaui_tabletopbottom-selected.png"
						end
						
						bgW = 302; bgH = 46
						labelY = 23
					
					else
						
						if rowsTable[nextItem] then
							if rowsTable[nextItem][1] == "nobg" or rowsTable[nextItem][1] == "spacer" then
								bgFile = "coronaui_tablebottom.png"
								bgOverFile = "coronaui_tablebottom-selected.png"
								bgW = 302; bgH = 46
								labelY = 23
							else
								bgFile = "coronaui_tablemid.png"
								bgOverFile = "coronaui_tablemid-selected.png"
								bgW = 302; bgH = 46
								labelY = 23
							end
						else
							bgFile = "coronaui_tablemid.png"
							bgOverFile = "coronaui_tablemid-selected.png"
							bgW = 302; bgH = 46
							labelY = 24
						end
					end
					
					-- create background for row item
					--itemGroup.background = display.newImageRect( bgFile, bgW, bgH )
					itemGroup.background = mc.newAnim( { bgFile, bgOverFile }, bgW, bgH )
					itemGroup.background.x = self.myWidth * 0.5
					itemGroup.background.y = 22
					
					itemGroup:insert( itemGroup.background )
					
					function itemGroup.background:touch( event )
					
						if event.phase == "began" and not self.parent.parent.parent.currentPicker then
							local theScreen = self.parent.parent.parent
							
							if not theScreen.selectedItem then
								self:stopAtFrame( 2 )
								theScreen.selectedTableItem = self
							end
						end
					end
					
					-- check to see if the 4th or 5th argument is a function, if so, assign touch event to it.
					
					if type(rowsTable[i][4]) == "function" or type(rowsTable[i][5]) == "function" then
						
						if type(rowsTable[i][4]) == "function" then
							itemGroup.myEvent = rowsTable[i][4]
						elseif type(rowsTable[i][5]) == "function" then
							itemGroup.myEvent = rowsTable[i][5]
						end
						
						itemGroup.background:addEventListener( "touch", itemGroup.background )
						
						-- create the right arrow
						local rightArrow = display.newImageRect( "coronaui_rightArrow.png", 10, 14 )
						itemGroup:insert( rightArrow )
						rightArrow:setReferencePoint( display.CenterRightReferencePoint )
						rightArrow.x = 301
						rightArrow.y = labelY
						
					end
					
					-- check to see if there's an icon for this label
					if item[2] and item[2] ~= "noicon" then
						-- include icon
						--print( item[2] )
						itemGroup.icon = display.newImageRect( item[2], 30, 30 )
						itemGroup.icon:setReferencePoint( display.CenterLeftReferencePoint )
						itemGroup.icon.x = nextX; nextX = nextX + 40   --> 30 + 10
						itemGroup.icon.y = 22
						
						itemGroup:insert( itemGroup.icon )
					end
					
						
					if item[3] and type(item[3]) == "string" then
						labelText = item[3]
					end
					
					if not labelText or type(labelText) ~= "string" then
						labelText = "Label"
					end
					
					-- create the label
					itemGroup.labelText = newRetinaText( labelText, nextX, 0, "HelveticaNeue-Bold", 17, 0, 0, 0, "left", false, itemGroup )
					itemGroup.labelText.y = labelY
					itemGroup.labelText:updateText( labelText )
					
					-- check to see if there is a secondary label (non bold), an "onOff" switch, or an event
					if item[4] and type(item[4]) == "string" and item[4] ~= "onOff" then
						-- BLUE TEXT LABEL
						secondLabelText = item[4]
						
						itemGroup.secondLabelText = newRetinaText( secondLabelText, 284, 0, "Helvetica", 16, 56, 84, 135, "right", false, itemGroup )
						itemGroup.secondLabelText.y = labelY
						itemGroup.secondLabelText:updateText( secondLabelText )
						
					elseif item[4] and type(item[4]) == "string" and item[4] == "onOff" then
						-- ON/OFF SWITCH
						local preSetting = "on"
						
						if item[5] then
							preSetting = item[5]
						end
						
						onOffSwitch = self:newOnOffSwitch( 278, 20, preSetting )
						itemGroup:insert( onOffSwitch )
						itemGroup.onOffSwitch = onOffSwitch
					
					elseif item[4] and type(item[4]) == "function" then
						-- EVENT LISTENER (make sure to display right arrow)
						itemGroup.onPress = item[4]
					end
				
				elseif itemGroup.rowType == "slider" then
				
				-- **********************************************************
				-- **********************************************************
				--
				-- SLIDER CONTROL ON WHITE BACKGROUND
				--
				-- **********************************************************
				-- **********************************************************
				
					-- SLIDER CONTROL
					local bgFile
					local bgW, bgH
					local nextX = 20
					local labelY
					
					if i == 1 or tableView.listItems[prevItem].rowType == "nobg" or tableView.listItems[prevItem].rowType == "spacer" then
						
						-- top item should be rounded
						bgFile = "coronaui_tabletop.png"
						
						if rowsTable[nextItem] then
							if rowsTable[nextItem][1] == "nobg" or rowsTable[nextItem][1] == "spacer" then
								bgFile = "coronaui_tabletopbottom.png"
							end
						end
						
						bgW = 302; bgH = 46
						labelY = 26
					elseif i == entryCount then
						
						bgFile = "coronaui_tablebottom.png"
						
						if i == 1 or tableView.listItems[prevItem].rowType == "nobg" or tableView.listItems[prevItem].rowType == "spacer" then
							bgFile = "coronaui_tabletopbottom.png"
						end
						
						bgW = 302; bgH = 46
						labelY = 23
					else
						
						if rowsTable[nextItem] then
							if rowsTable[nextItem][1] == "nobg" or rowsTable[nextItem][1] == "spacer" then
								bgFile = "coronaui_tablebottom.png"
								bgW = 302; bgH = 46
								labelY = 23
							else
								bgFile = "coronaui_tablemid.png"
								bgW = 302; bgH = 46
								labelY = 23
							end
						else
							bgFile = "coronaui_tablemid.png"
							bgW = 302; bgH = 46
							labelY = 24
						end
					end
					
					-- create background for row item
					itemGroup.background = display.newImageRect( bgFile, bgW, bgH )
					itemGroup.background.x = self.myWidth * 0.5
					itemGroup.background.y = 22
					
					itemGroup:insert( itemGroup.background )
					
					itemGroup.background:addEventListener( "touch", itemGroup.background )
					
					------>>>
					
					local preSetting = 50
					
					if item[2] then
						preSetting = item[2]
					end
					
					local callbackListener
					
					if item[3] and type(item[3]) == "function" then
						callbackListener = item[3]
					end
					
					sliderControl = self:newSliderControl( (self.myWidth * 0.5) - 5, 20, preSetting, callbackListener, itemGroup )
					itemGroup:insert( sliderControl )
					itemGroup.sliderControl = sliderControl
				
				elseif itemGroup.rowType == "centertext" then
				
				-- **********************************************************
				-- **********************************************************
				--
				-- CENTERED TEXT AND WHITE BACKGROUND TABLEVIEW ITEM
				--
				-- **********************************************************
				-- **********************************************************
					
					local bgFile, bgOverFile
					local bgW, bgH
					local nextX = 20
					local labelY
					
					if i == 1 or tableView.listItems[prevItem].rowType == "nobg" or tableView.listItems[prevItem].rowType == "spacer" then
						
						-- top item should be rounded
						bgFile = "coronaui_tabletop.png"
						bgOverFile = "coronaui_tabletop-selected.png"
						
						if rowsTable[nextItem] then
							if rowsTable[nextItem][1] == "nobg" or rowsTable[nextItem][1] == "spacer" then
								bgFile = "coronaui_tabletopbottom.png"
								bgOverFile = "coronaui_tabletopbottom-selected.png"
							end
						end
						
						bgW = 302; bgH = 46
						labelY = 26
					elseif i == entryCount then
						
						bgFile = "coronaui_tablebottom.png"
						bgOverFile = "coronaui_tablebottom-selected.png"
						
						if i == 1 or tableView.listItems[prevItem].rowType == "nobg" or tableView.listItems[prevItem].rowType == "spacer" then
							bgFile = "coronaui_tabletopbottom.png"
							bgOverFile = "coronaui_tabletopbottom-selected.png"
						end
						
						bgW = 302; bgH = 46
						labelY = 23
					else
						
						if rowsTable[nextItem] then
							if rowsTable[nextItem][1] == "nobg" or rowsTable[nextItem][1] == "spacer" then
								bgFile = "coronaui_tablebottom.png"
								bgOverFile = "coronaui_tablebottom-selected.png"
								bgW = 302; bgH = 46
								labelY = 23
							else
								bgFile = "coronaui_tablemid.png"
								bgOverFile = "coronaui_tablemid-selected.png"
								bgW = 302; bgH = 46
								labelY = 23
							end
						else
							bgFile = "coronaui_tablemid.png"
							bgOverFile = "coronaui_tablemid-selected.png"
							bgW = 302; bgH = 46
							labelY = 24
						end
					end
					
					-- create background for row item
					--itemGroup.background = display.newImageRect( bgFile, bgW, bgH )
					itemGroup.background = mc.newAnim( { bgFile, bgOverFile }, bgW, bgH )
					itemGroup.background.x = self.myWidth * 0.5
					itemGroup.background.y = 22
					
					itemGroup:insert( itemGroup.background )
					
					function itemGroup.background:touch( event )
						if event.phase == "began" and not self.parent.parent.parent.currentPicker then
							local theScreen = self.parent.parent.parent
							
							if not theScreen.selectedItem then
								self:stopAtFrame( 2 )
								theScreen.selectedTableItem = self
							end
						end
					end
					
					-- check to see if the 4th or 5th argument is a function, if so, assign touch event to it.
					
					if type(rowsTable[i][3]) == "function" then
						
						if type(rowsTable[i][3]) == "function" then
							itemGroup.myEvent = rowsTable[i][3]
						end
						
						itemGroup.background:addEventListener( "touch", itemGroup.background )
					end
					
					if item[2] and type(item[2]) == "string" then
						labelText = item[2]
					end
					
					if not labelText or type(labelText) ~= "string" then
						labelText = "Label"
					end
					
					-- create the label
					itemGroup.labelText = newRetinaText( labelText, self.myWidth * 0.5, 0, "HelveticaNeue-Bold", 17, 0, 0, 0, "center", false, itemGroup )
					itemGroup.labelText.y = labelY
					itemGroup.labelText:updateText( labelText )
				
				elseif itemGroup.rowType == "multipleitemselection" then
				
				-- **********************************************************
				-- **********************************************************
				--
				-- MULTIPLE SELECTION ITEM (checkmark or checkboxes)
				--
				-- **********************************************************
				-- **********************************************************
					
					local bgFile, bgOverFile
					local bgW, bgH
					local nextX = 20
					local labelY
					
					if i == 1 or tableView.listItems[prevItem].rowType == "nobg" or tableView.listItems[prevItem].rowType == "spacer" then
						
						-- top item should be rounded
						if item[6] then
							bgFile = "coronaui_tabletopCheck.png"
						else
							bgFile = "coronaui_tabletop.png"
						end
						
						bgOverFile = "coronaui_tabletop-selected.png"
						
						if rowsTable[nextItem] then
							if rowsTable[nextItem][1] == "nobg" or rowsTable[nextItem][1] == "spacer" then
								if item[6] then
									bgFile = "coronaui_tabletopbottomCheck.png"
								else
									bgFile = "coronaui_tabletopbottom.png"
								end
								bgOverFile = "coronaui_tabletopbottom-selected.png"
							end
						end
						
						bgW = 302; bgH = 46
						labelY = 26
					elseif i == entryCount then
						
						if item[6] then
							bgFile = "coronaui_tablebottomCheck.png"
						else
							bgFile = "coronaui_tablebottom.png"
						end
						bgOverFile = "coronaui_tablebottom-selected.png"
						
						if i == 1 or tableView.listItems[prevItem].rowType == "nobg" or tableView.listItems[prevItem].rowType == "spacer" then
							if item[6] then
								bgFile = "coronaui_tabletopbottomCheck.png"
							else
								bgFile = "coronaui_tabletopbottom.png"
							end
							bgOverFile = "coronaui_tabletopbottom-selected.png"
						end
						
						bgW = 302; bgH = 46
						labelY = 23
					else
						
						if rowsTable[nextItem] then
							if rowsTable[nextItem][1] == "nobg" or rowsTable[nextItem][1] == "spacer" then
								if item[6] then
									bgFile = "coronaui_tablebottomCheck.png"
								else
									bgFile = "coronaui_tablebottom.png"
								end
								bgOverFile = "coronaui_tablebottom-selected.png"
								bgW = 302; bgH = 46
								labelY = 23
							else
								if item[6] then
									bgFile = "coronaui_tablemidCheck.png"
								else
									bgFile = "coronaui_tablemid.png"
								end
								bgOverFile = "coronaui_tablemid-selected.png"
								bgW = 302; bgH = 46
								labelY = 23
							end
						else
							if item[6] then
								bgFile = "coronaui_tablemidCheck.png"
							else
								bgFile = "coronaui_tablemid.png"
							end
							bgOverFile = "coronaui_tablemid-selected.png"
							bgW = 302; bgH = 46
							labelY = 24
						end
					end
					
					-- create background for row item
					--itemGroup.background = display.newImageRect( bgFile, bgW, bgH )
					itemGroup.background = mc.newAnim( { bgFile, bgOverFile }, bgW, bgH )
					itemGroup.background.x = self.myWidth * 0.5
					itemGroup.background.y = 22
					
					itemGroup:insert( itemGroup.background )
					
					function itemGroup.background:touch( event )
						if event.phase == "began" and not self.parent.parent.parent.currentPicker then
							local theScreen = self.parent.parent.parent
							
							if not theScreen.selectedItem then
								self:stopAtFrame( 2 )
								theScreen.selectedTableItem = self
							end
						end
					end
					
					itemGroup.background:addEventListener( "touch", itemGroup.background )
					
					-- check to see if there's an icon for this label
					if item[2] and item[2] ~= "noicon" then
						-- include icon
						--print( item[2] )
						itemGroup.icon = display.newImageRect( item[2], 30, 30 )
						itemGroup.icon:setReferencePoint( display.CenterLeftReferencePoint )
						itemGroup.icon.x = nextX; nextX = nextX + 40   --> 30 + 10
						itemGroup.icon.y = 22
						
						itemGroup:insert( itemGroup.icon )
					end
					
					-- label text stuff
					if item[3] and type(item[3]) == "string" then
						labelText = item[3]
					end
					
					if not labelText or type(labelText) ~= "string" then
						labelText = "Label"
					end
					
					-- create the label
					itemGroup.labelText = newRetinaText( labelText, nextX, 0, "HelveticaNeue-Bold", 17, 0, 0, 0, "left", false, itemGroup )
					itemGroup.labelText.y = labelY
					itemGroup.labelText:updateText( labelText )
					
					-- set the value for this item
					if item[4] then
						itemGroup.value = item[4]
					else
						itemGroup.value = ""
					end
					
					-- set other attributes for multiple item selection
					if item[5] then
						itemGroup.myID = item[5]
						
						if not itemGroup.parent.selectionTables[ itemGroup.myID ] then
							itemGroup.parent.selectionTables[ itemGroup.myID ] = {}
						end
					end
					
					itemGroup.isChecked = false
					
					-- create checkmark graphic
					if item[6] then
						itemGroup.checkMark = display.newImageRect( "coronaui_checkedbox.png", 28, 28 )
					else
						itemGroup.checkMark = display.newImageRect( "coronaui_checkmark.png", 14, 14 )
					end
					itemGroup:insert( itemGroup.checkMark )
					itemGroup.checkMark:setReferencePoint( display.CenterRightReferencePoint )
					
					if item[6] then
						itemGroup.checkMark.x = 299
						labelY = labelY - 1
					else
						itemGroup.checkMark.x = 301
					end
					itemGroup.checkMark.y = labelY
					
					itemGroup.checkMark.isVisible = false
				
				elseif itemGroup.rowType == "singleitemselection" then
				
				-- **********************************************************
				-- **********************************************************
				--
				-- SINGLE SELECTION ITEM (checkmark or radio buttons)
				--
				-- **********************************************************
				-- **********************************************************
					
					local bgFile, bgOverFile
					local bgW, bgH
					local nextX = 20
					local labelY
					
					if i == 1 or tableView.listItems[prevItem].rowType == "nobg" or tableView.listItems[prevItem].rowType == "spacer" then
						
						-- top item should be rounded
						if item[6] then
							bgFile = "coronaui_tabletopRadio.png"
						else
							bgFile = "coronaui_tabletop.png"
						end
						bgOverFile = "coronaui_tabletop-selected.png"
						
						if rowsTable[nextItem] then
							if rowsTable[nextItem][1] == "nobg" or rowsTable[nextItem][1] == "spacer" then
								if item[6] then
									bgFile = "coronaui_tabletopbottomRadio.png"
								else
									bgFile = "coronaui_tabletopbottom.png"
								end
								bgOverFile = "coronaui_tabletopbottom-selected.png"
							end
						end
						
						bgW = 302; bgH = 46
						labelY = 26
					elseif i == entryCount then
						if item[6] then
							bgFile = "coronaui_tablebottomRadio.png"
						else
							bgFile = "coronaui_tablebottom.png"
						end
						bgOverFile = "coronaui_tablebottom-selected.png"
						
						if i == 1 or tableView.listItems[prevItem].rowType == "nobg" or tableView.listItems[prevItem].rowType == "spacer" then
							if item[6] then
								bgFile = "coronaui_tabletopbottomRadio.png"
							else
								bgFile = "coronaui_tabletopbottom.png"
							end
							bgOverFile = "coronaui_tabletopbottom-selected.png"
						end
						
						bgW = 302; bgH = 46
						labelY = 23
					else
						
						if rowsTable[nextItem] then
							if rowsTable[nextItem][1] == "nobg" or rowsTable[nextItem][1] == "spacer" then
								if item[6] then
									bgFile = "coronaui_tablebottomRadio.png"
								else
									bgFile = "coronaui_tablebottom.png"
								end
								bgOverFile = "coronaui_tablebottom-selected.png"
								bgW = 302; bgH = 46
								labelY = 23
							else
								if item[6] then
									bgFile = "coronaui_tablemidRadio.png"
								else
									bgFile = "coronaui_tablemid.png"
								end
								bgOverFile = "coronaui_tablemid-selected.png"
								bgW = 302; bgH = 46
								labelY = 23
							end
						else
							if item[6] then
								bgFile = "coronaui_tablemidRadio.png"
							else
								bgFile = "coronaui_tablemid.png"
							end
							bgOverFile = "coronaui_tablemid-selected.png"
							bgW = 302; bgH = 46
							labelY = 24
						end
					end
					
					-- create background for row item
					--itemGroup.background = display.newImageRect( bgFile, bgW, bgH )
					itemGroup.background = mc.newAnim( { bgFile, bgOverFile }, bgW, bgH )
					itemGroup.background.x = self.myWidth * 0.5
					itemGroup.background.y = 22
					
					itemGroup:insert( itemGroup.background )
					
					function itemGroup.background:touch( event )
						if event.phase == "began" and not self.parent.parent.parent.currentPicker then
							local theScreen = self.parent.parent.parent
							
							if not theScreen.selectedItem then
								self:stopAtFrame( 2 )
								theScreen.selectedTableItem = self
							end
						end
					end
					
					itemGroup.background:addEventListener( "touch", itemGroup.background )
					
					-- check to see if there's an icon for this label
					if item[2] and item[2] ~= "noicon" then
						-- include icon
						--print( item[2] )
						itemGroup.icon = display.newImageRect( item[2], 30, 30 )
						itemGroup.icon:setReferencePoint( display.CenterLeftReferencePoint )
						itemGroup.icon.x = nextX; nextX = nextX + 40   --> 30 + 10
						itemGroup.icon.y = 22
						
						itemGroup:insert( itemGroup.icon )
					end
					
					-- label text stuff
					if item[3] and type(item[3]) == "string" then
						labelText = item[3]
					end
					
					if not labelText or type(labelText) ~= "string" then
						labelText = "Label"
					end
					
					-- create the label
					itemGroup.labelText = newRetinaText( labelText, nextX, 0, "HelveticaNeue-Bold", 17, 0, 0, 0, "left", false, itemGroup )
					itemGroup.labelText.y = labelY
					itemGroup.labelText:updateText( labelText )
					
					-- set the value for this item
					if item[4] then
						itemGroup.value = item[4]
					else
						itemGroup.value = ""
					end
					
					-- set other attributes for multiple item selection
					if item[5] then
						itemGroup.myID = item[5]
						
						if not itemGroup.parent.selectionValues[ itemGroup.myID ] then
							itemGroup.parent.selectionValues[ itemGroup.myID ] = {}
						end
					end
					
					itemGroup.isChecked = false
					
					-- create checkmark graphic
					if item[6] then
						itemGroup.checkMark = display.newImageRect( "coronaui_radio.png", 28, 28 )
					else
						itemGroup.checkMark = display.newImageRect( "coronaui_checkmark.png", 14, 14 )
					end
					itemGroup:insert( itemGroup.checkMark )
					itemGroup.checkMark:setReferencePoint( display.CenterRightReferencePoint )
					if item[6] then
						itemGroup.checkMark.x = 300
						labelY = labelY - 1
					else
						itemGroup.checkMark.x = 301
					end
					itemGroup.checkMark.y = labelY
					
					itemGroup.checkMark.isVisible = false
					
					-- add item to selectionValues table
					table.insert( itemGroup.parent.selectionValues[ itemGroup.myID ], itemGroup )
				
				end
				
				-- **********************************************************
				-- **********************************************************
				
				itemGroup.y = theY
				tableView.listItems[i] = itemGroup
			end
			
			-- ======================================================================================
			--
			-- ======================================================================================
			
			function tableView:removeMe()
				
				self.listItems = nil
				self.selectionTables = nil
				self.selectionValues = nil
				
				--cleanGroups( self, 0 )
				self:removeSelf()
				self = nil
			end
			
			-- ======================================================================================
			--
			-- ======================================================================================
			
			tableView:addScrollBar( 0, 0, 0, 120 )
			self:insertUnderTitle( tableView )
			self:insertUnderTitle( tableView.scrollBar )
			self.tableView = tableView
			tableView.y = 20
			
			return tableView
		end
	end
	
	-- ======================================================================================
	--
	-- ======================================================================================
	
	return screenGroup
end