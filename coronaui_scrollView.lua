-- coronaui_scrollView.lua (modified scrollView.lua for coronaui.lua)
-- 
-- Version 1.1
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
 
module(..., package.seeall)

-- set some global values for width and height of the screen
local screenW, screenH = display.contentWidth, display.contentHeight
local viewableScreenW, viewableScreenH = display.viewableContentWidth, display.viewableContentHeight
local screenOffsetW, screenOffsetH = display.contentWidth -  display.viewableContentWidth, display.contentHeight - display.viewableContentHeight

local prevTime = 0

local function findfunction(x)
  assert(type(x) == "string")
  local f=_G
  for v in x:gmatch("[^%.]+") do
    if type(f) ~= "table" then
       return nil, "looking for '"..v.."' expected table, not "..type(f)
    end
    f=f[v]
  end
  if type(f) == "function" then
    return f
  else
    return nil, "expected function, not "..type(f)
  end
end


function new(params)
	
	-- setup a group to be the scrolling screen
	local scrollView = display.newGroup()
		
	scrollView.top = params.top or 0
	scrollView.bottom = params.bottom or 0
	
	if params.width then
		screenW = params.width
		viewableScreenW = params.width
	end
	
	scrollView.isTracking = false
	scrollView.isScrolling = false

	function scrollView:touch(event) 
		if not self.scrollDisabled then
	        local phase = event.phase
	        --print(phase)
	        			        
	        if( phase == "began" ) and not coronaui.currentPicker then
				--print(self.y)
					if self.upperLimit and event.y > self.upperLimit then
						if not self.parent.touchingControl then
							self.startPos = event.y
							self.prevPos = event.y        
							self.delta, self.velocity = 0, 0
							if self.tween then transition.cancel(self.tween) end
							
							self.isScrolling = false
							--Runtime:removeEventListener("enterFrame", self ) 
		
							self.prevTime = 0
							self.prevY = 0
		
							transition.to(self.scrollBar,  { time=200, alpha=1 } )									
		
							-- Start tracking velocity
							--Runtime:addEventListener("enterFrame", trackVelocity)
							self.isTracking = true
							
							-- Subsequent touch events will target button even if they are outside the stageBounds of button
							--[[
							if self.parent.tableView then
								print( "it exists here!" )
							end
							]]--
							
							
							display.getCurrentStage():setFocus( self )
							self.isFocus = true
						end
	 				end
	        elseif( self.isFocus ) then
	 
	                if( phase == "moved" ) and not coronaui.currentPicker then
					        local bottomLimit = screenH - self.height - self.bottom
	            
	                        self.delta = event.y - self.prevPos
	                        self.prevPos = event.y
	                        if ( self.y > self.top or self.y < bottomLimit ) then 
                                self.y  = self.y + self.delta/2
	                        else
                                self.y = self.y + self.delta   
	                        end
	                        
	                        self:moveScrollBar()
	                        
	                        if self.selectedItem then
	                        	if event.y > self.upperLimit then
									local r, g, b
									r = self.fillR
									g = self.fillG
									b = self.fillB
									self.selectedItem[1]:setFillColor( r, g, b, 255 )
									self.selectedItem = nil
								end
	                        end
	                        
	                        -- for tableview touch events:
	                        if self.parent.selectedTableItem then
	                        	local theItem = self.parent.selectedTableItem
	                        	theItem:stopAtFrame( 1 )
	                        	
	                        	self.parent.selectedTableItem = nil
	                        end

	                elseif( phase == "ended" or phase == "cancelled" ) and not coronaui.currentPicker then
	                		
	                        local dragDistance = event.y - self.startPos
							self.lastTime = event.time
	                        
	                        --Runtime:addEventListener("enterFrame", self )  	 			
	                        --Runtime:removeEventListener("enterFrame", trackVelocity)
	                        self.isScrolling = true
	                        self.isTracking = false
	        	                	        
	                        -- Allow touch events to be sent normally to the objects they "hit"
	                       	display.getCurrentStage():setFocus( nil )
	                        self.isFocus = false
	                        
	                        if self.selectedItem then
	                        	if event.y > self.upperLimit then
									
									-- reset item's fill color
									local r, g, b
									r = self.fillR
									g = self.fillG
									b = self.fillB
									self.selectedItem[1]:setFillColor( r, g, b, 255 )
									
									if self.selectedItem.myEvent and not self.selectionList then
										if type(self.selectedItem.myEvent) == "function" then
											self.selectedItem.myEvent( self.selectedItem )
										
										elseif type(self.selectedItem.myEvent) == "string" then

											local x = self.selectedItem.myEvent
											
											assert(findfunction(x))( self.selectedItem )
										end
										
										-- hide keyboard (if necessary)
										native.setKeyboardFocus( nil )
										
									elseif self.selectionList then
										-- first, add item to multiList (for multiple item selection)
										table.insert( self.multiList, self.selectedItem )
										
										-- then, make title and subtitle text of selection list item grey
										self.selectedItem.titleText.textObject:setTextColor( 140, 140, 140, 255 )
										self.selectedItem.subtitleText.textObject:setTextColor( 140, 140, 140, 255 )
									end
									self.selectedItem = nil
								end
	                        end
	                        -- end "if self.selectedItem" ...
	                        
	                        -- for tableview touch events:
	                        if self.parent.selectedTableItem then
	                        	
	                        	local theItem = self.parent.selectedTableItem
	                        	theItem:stopAtFrame( 1 )
	                        	
	                        	-- call the event (if there is one)
	                        	if theItem.parent.myEvent and type(theItem.parent.myEvent) == "function" then
	                        		theItem.parent.myEvent( theItem.parent )
	                        	end
	                        	
	                        	-- multiple item selection
	                        	if theItem.parent.rowType == "multipleitemselection" then
	                        		if theItem.parent.isChecked then
	                        			theItem.parent.isChecked = false
	                        			theItem.parent.checkMark.isVisible = false
	                        			
	                        			-- remove item from the table
	                        			local i
	                        			local numItems = #theItem.parent.parent.selectionTables[ theItem.parent.myID ]
	                        			
	                        			-- search for it
	                        			for i=1,numItems,1 do
	                        				if theItem.parent.parent.selectionTables[ theItem.parent.myID ][i] == theItem.parent.value then
	                        					-- match found! remove it
	                        					table.remove( theItem.parent.parent.selectionTables[ theItem.parent.myID ], i )
	                        				end
	                        			end
	                        		else
	                        			theItem.parent.isChecked = true
	                        			theItem.parent.checkMark.isVisible = true
	                        			
	                        			table.insert( theItem.parent.parent.selectionTables[ theItem.parent.myID ], theItem.parent.value )
	                        		end
	                        		
	                        		-- for debugging purposes, go through and print each item of the table
	                        		--[[
	                        		local i
	                        		local numItems = #theItem.parent.parent.selectionTables[ theItem.parent.myID ]
	                        		
	                        		for i=1,numItems,1 do
	                        			print( "Selection Table: " .. theItem.parent.myID .. ", Item: " .. i .. ", Value: " .. theItem.parent.value )
	                        		end
	                        		]]--
	                        	
	                        	-- END multiple item selection
	                        	
	                        	--
	                        	
	                        	-- single item selection
	                        	elseif theItem.parent.rowType == "singleitemselection" then
	                        		
	                        		local i
	                        		local numItems = #theItem.parent.parent.selectionValues[ theItem.parent.myID ]
									
									-- loop through all items and uncheck all of them
									for i=1,numItems,1 do
										if theItem.parent.parent.selectionValues[ theItem.parent.myID][i] ~= theItem.parent then
											theItem.parent.parent.selectionValues[ theItem.parent.myID ][i].isChecked = false
											theItem.parent.parent.selectionValues[ theItem.parent.myID ][i].checkMark.isVisible = false
										end
									end
									
									-- go and check the item that was tapped
									if not theItem.parent.isChecked then
										theItem.parent.isChecked = true
										theItem.parent.checkMark.isVisible = true
										theItem.parent.parent.selectionValues[ theItem.parent.myID ].value = theItem.parent.value
									else
										theItem.parent.isChecked = false
										theItem.parent.checkMark.isVisible = false
										theItem.parent.parent.selectionValues[ theItem.parent.myID ].value = ""
									end
	                        		
	                        		-- for debug purposes, show what the selection value is
	                        		--print( theItem.parent.parent.selectionValues[ theItem.parent.myID ].value .. ", checked? " .. tostring( theItem.parent.isChecked) )
	                        	end
	                        	
	                        	self.parent.selectedTableItem = nil
	                        end
	                        -- END multiple item selection
	                end
	        end
	        
	        return true
		end
	end
	 
	function scrollView:enterFrame(event) 
		if self.isScrolling and not self.scrollDisabled then
			local friction = 0.953
			local timePassed = event.time - self.lastTime
			self.lastTime = self.lastTime + timePassed       
	
			--turn off scrolling if velocity is near zero
			if math.abs(self.velocity) < .01 then
					self.velocity = 0
					--Runtime:removeEventListener("enterFrame", self )
					self.isScrolling = false
					transition.to(self.scrollBar,  { time=400, alpha=0 } )									
			end
			
	
			self.velocity = self.velocity*friction
			
			self.y = (math.floor(self.y + self.velocity*timePassed))
			
			local upperLimit = self.top 
			local bottomLimit = screenH - self.height - self.bottom
			
			if ( self.y > upperLimit ) then
					self.velocity = 0
					--Runtime:removeEventListener("enterFrame", self )          
					self.isScrolling = false
					self.tween = transition.to(self, { time=400, y=upperLimit, transition=easing.outQuad})
					transition.to(self.scrollBar,  { time=400, alpha=0 } )
					
			elseif ( self.y < bottomLimit and bottomLimit < 0 ) then 
					self.velocity = 0
					--Runtime:removeEventListener("enterFrame", self )          
					self.isScrolling = false
					self.tween = transition.to(self, { time=400, y=bottomLimit, transition=easing.outQuad})
					transition.to(self.scrollBar,  { time=400, alpha=0 } )									
			elseif ( self.y < bottomLimit ) then 
					self.velocity = 0
					--Runtime:removeEventListener("enterFrame", self )          
					self.isScrolling = false
					self.tween = transition.to(self, { time=400, y=upperLimit, transition=easing.outQuad})        
					transition.to(self.scrollBar,  { time=400, alpha=0 } )
			end
	
			self:moveScrollBar()
						
			return true
		end
		
		if self.isTracking and not self.scrollDisabled then
			local timePassed = event.time - self.prevTime
			self.prevTime = self.prevTime + timePassed
		
			if self.prevY then 
				self.velocity = (self.y - self.prevY)/timePassed 
			end
			self.prevY = self.y
		end
	end
	
	function scrollView:moveScrollBar()
		if self.scrollBar then						
			local scrollBar = self.scrollBar
			
			scrollBar.y = -self.y*self.yRatio + scrollBar.height*0.5 + self.top
			
			if scrollBar.y <  5 + self.top + scrollBar.height*0.5 then
				scrollBar.y = 5 + self.top + scrollBar.height*0.5
			end
			if scrollBar.y > screenH - self.bottom  - 5 - scrollBar.height*0.5 then
				scrollBar.y = screenH - self.bottom - 5 - scrollBar.height*0.5
			end
			
		end
	end
	
	--[[
	function scrollView:trackVelocity(event)
		local timePassed = event.time - self.prevTime
		self.prevTime = self.prevTime + timePassed
	
		if self.prevY then 
			self.velocity = (self.y - self.prevY)/timePassed 
		end
		self.prevY = self.y
	end
	]]--
	    
	scrollView.y = scrollView.top
	
	-- setup the touch listener 
	scrollView:addEventListener( "touch", scrollView )
	
	function scrollView:addScrollBar(r,g,b,a)
		if self.scrollBar then self.scrollBar:removeSelf() end
		
		local viewableScreenW = viewableScreenW
		
		if self.myWidth then
			viewableScreenW = self.myWidth + self.parent.x
		end
		
		local screenH = self.myHeight or screenH

		local scrollColorR = r or 0
		local scrollColorG = g or 0
		local scrollColorB = b or 0
		local scrollColorA = a or 120
						
		local viewPortH = screenH - self.top - self.bottom 
		local scrollH = viewPortH*self.height/(self.height*2 - viewPortH)		
		local scrollBar = display.newRoundedRect(viewableScreenW-7,0,4,scrollH,2)
		scrollBar:setFillColor(scrollColorR, scrollColorG, scrollColorB, scrollColorA)

		local yRatio = scrollH/self.height
		self.yRatio = yRatio		

		scrollBar.y = -self.y*self.yRatio + scrollBar.height*0.5 + self.top

		self.scrollBar = scrollBar

		transition.to(scrollBar,  { time=400, alpha=0 } )			
	end

	function scrollView:cleanUp()
        --Runtime:removeEventListener("enterFrame", trackVelocity)
		Runtime:removeEventListener( "touch", scrollView )
		--Runtime:removeEventListener("enterFrame", scrollView ) 
		self.isScrolling = false
		self.isTracking = false
		if self.scrollBar then self.scrollBar:removeSelf() end
	end
	
	Runtime:addEventListener("enterFrame", scrollView )
	
	return scrollView
end
