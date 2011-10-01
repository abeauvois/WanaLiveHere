-- coronaui_pickerscrollView.lua (modified scrollView.lua for coronaui.lua)
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
--local screenW, screenH = display.contentWidth, display.contentHeight
local screenW, screenH = 320, 480
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
	
	scrollView.isTracking = false
	scrollView.isScrolling = false
	scrollView.isGrabbed = false
	scrollView.isFixed = true

	function scrollView:touch(event)
		if not scrollView.scrollDisabled and event.y > 64 then
	        local phase = event.phase
	        local scrollGroup = self.parent.parent
	        
	        if( phase == "began" ) and event.y > (scrollGroup.y + 258) and event.y < (scrollGroup.y + 510) then
				--print(scrollView.y)
					self.startPos = event.y
					self.prevPos = event.y                                       
					self.delta, self.velocity = 0, 0
					
					self.isScrolling = false
					self.isGrabbed = true
					--Runtime:removeEventListener("enterFrame", scrollView ) 

					self.prevTime = 0
					self.prevY = 0

					transition.to(self.scrollBar,  { time=200, alpha=1 } )									

					-- Start tracking velocity
					--Runtime:addEventListener("enterFrame", trackVelocity)
					self.isTracking = true
					
					-- Subsequent touch events will target button even if they are outside the stageBounds of button
					display.getCurrentStage():setFocus( self )
					self.isFocus = true
	        elseif( self.isFocus ) then
	 
	                if( phase == "moved" ) then
					        local bottomLimit = screenH - self.height - self.bottom
	            
	                        self.delta = event.y - self.prevPos
	                        self.prevPos = event.y
	                        if ( self.y > self.top or self.y < bottomLimit ) then 
                                self.y  = self.y + self.delta/2
	                        else
                                self.y = self.y + self.delta   
	                        end
	                        
	                        --scrollView:moveScrollBar()
	                        
	                        if scrollView.selectedItem then
	                        	if event.y > scrollView.upperLimit then
									local r, g, b
									r = scrollView.fillR
									g = scrollView.fillG
									b = scrollView.fillB
									scrollView.selectedItem[1]:setFillColor( r, g, b, 255 )
									scrollView.selectedItem = nil
								end
	                        end
	                        
	                        if event.y < 64 then
	                       		self.isScrolling = true
	                        	self.isGrabbed = false
	                        	self.isFixed = false
	                        	self.isTracking = false
	                        end

	                elseif( phase == "ended" or phase == "cancelled" ) then 
	                        local dragDistance = event.y - self.startPos
							self.lastTime = event.time
	                        
	                        --Runtime:addEventListener("enterFrame", scrollView )  	 			
	                        --Runtime:removeEventListener("enterFrame", trackVelocity)
	                        self.isScrolling = true
	                        self.isGrabbed = false
	                        self.isFixed = false
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
	                end
	        end
	        
	        return true
		else
			local yPosition = self.y
			local bottomLimit = screenH - self.height - self.bottom
			
			if self.y > self.top then
				yPosition = self.top
			elseif self.y < bottomLimit then
				yPosition = bottomLimit
			end
			
			yPosition = yPosition
			
			local shouldBePosition
			
			local a, b = math.modf((yPosition - 348) / 44)
			
			b = b * -1
			
			if b <= 0.5 then
				shouldBePosition = ((math.ceil( (yPosition - 348) / 44 ) * 44) + 44) + 304
			else
				shouldBePosition = ((math.floor( (yPosition - 348) / 44 ) * 44) + 44) + 304
			end
			
			local otherBottomLimit = screenH - self.bottom
			
			local selectedItem = (((self.top + (otherBottomLimit - shouldBePosition) -40)) / 44) - 9
			
			if self.tween then transition.cancel( self.tween ); end
			self.tween = transition.to( self, { time=100, y=shouldBePosition, transition=easing.outQuad})
		end
	end
	 
	function scrollView:enterFrame(event) 
		if self.isScrolling and not scrollView.scrollDisabled then
			local friction = 0.84 --0.953
			local timePassed
			if self.lastTime then
				timePassed = event.time - self.lastTime
				self.lastTime = self.lastTime + timePassed
			else
				timePassed = event.time
				self.lastTime = timePassed
			end
	
			--turn off scrolling if velocity is near zero
			if math.abs(self.velocity) < .01 then
					self.velocity = 0
					--Runtime:removeEventListener("enterFrame", scrollView )
					self.isScrolling = false
					transition.to(self.scrollBar,  { time=400, alpha=0 } )									
			end
	
			self.velocity = self.velocity*friction
			
			self.y = (math.floor(self.y + self.velocity*timePassed))
			
			local upperLimit = self.top
			local bottomLimit = screenH - self.height - self.bottom
			
			if not self.isInfinite then
				if ( self.y > upperLimit ) then
						self.velocity = 0
						--Runtime:removeEventListener("enterFrame", scrollView )          
						self.isScrolling = false
						self.tween = transition.to(self, { time=400, y=upperLimit, transition=easing.outQuad})
						transition.to(self.scrollBar,  { time=400, alpha=0 } )
						
				elseif ( self.y < bottomLimit and bottomLimit < 0 ) then 
						self.velocity = 0
						--Runtime:removeEventListener("enterFrame", scrollView )          
						self.isScrolling = false
						self.tween = transition.to(self, { time=400, y=bottomLimit, transition=easing.outQuad})
						transition.to(self.scrollBar,  { time=400, alpha=0 } )									
				elseif ( self.y < bottomLimit ) then 
						self.velocity = 0
						--Runtime:removeEventListener("enterFrame", scrollView )          
						self.isScrolling = false
						self.tween = transition.to(self, { time=400, y=bottomLimit, transition=easing.outQuad})        
						transition.to(self.scrollBar,  { time=400, alpha=0 } )
				end
			end
	
			--scrollView:moveScrollBar()
						
			return true
		end
		
		if self.isTracking and not scrollView.scrollDisabled then
			local timePassed = event.time - self.prevTime
			self.prevTime = self.prevTime + timePassed
		
			if self.prevY then 
				self.velocity = (self.y - self.prevY)/timePassed 
			end
			self.prevY = self.y
		end
		
		if not self.isFixed and not self.isInfinite then
			self.isFixed = true
			
			local yPosition = self.y
			local bottomLimit = screenH - self.height - self.bottom
			
			if self.y > self.top then
				yPosition = self.top
			elseif self.y < bottomLimit then
				yPosition = bottomLimit
			end
			
			yPosition = yPosition
			
			local shouldBePosition
			
			local a, b = math.modf((yPosition - 348) / 44)
			
			b = b * -1
			
			if b <= 0.5 then
				shouldBePosition = ((math.ceil( (yPosition - 348) / 44 ) * 44) + 44) + 304
			else
				shouldBePosition = ((math.floor( (yPosition - 348) / 44 ) * 44) + 44) + 304
			end
			
			local otherBottomLimit = screenH - self.bottom
			
			local selectedItem = (((self.top + (otherBottomLimit - shouldBePosition) -40)) / 44) - 9
			
			self.input = selectedItem
			
			if self.wheelType == "time" then
				self.input = self.input -1
			end
			
			--print( "Selected item: " .. self.input .. "" )
			
			if self.tween then transition.cancel( self.tween ); end
			self.tween = transition.to( self, { time=100, y=shouldBePosition, transition=easing.outQuad})
			--self.y=shouldBePosition
		end
	end
	    
	scrollView.y = scrollView.top
	
	-- setup the touch listener 
	scrollView:addEventListener( "touch", scrollView )
	
	function scrollView:addScrollBar(r,g,b,a)
		if self.scrollBar then self.scrollBar:removeSelf() end

		local scrollColorR = r or 0
		local scrollColorG = g or 0
		local scrollColorB = b or 0
		local scrollColorA = a or 120
						
		local viewPortH = screenH - self.top - self.bottom 
		local scrollH = viewPortH*self.height/(self.height*2 - viewPortH)		
		local scrollBar = display.newRoundedRect(viewableScreenW-8,0,5,scrollH,2)
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
