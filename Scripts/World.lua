World = {
	jam = love.graphics.newImage("Graphics/Character/Jam.png"),
	music = love.audio.newSource("Sounds/Tune of Longing.mp3", "stream")
}
World.__index = World

function World.new()
	local world = {
		images = {
			
		},
		timer = 0,
		color_factor = 0,
		music_volume = 0,
		music_timer = 0,
	}
		
	setmetatable(world, World)
	
	return world
end

function World:load_map(map_id)
	self.current_map = Map.load(map_id)
	self.current_map.image = love.graphics.newCanvas()
	self.current_map:begin_loading()
	GameController.player:reset_position()
	self.timer = 0
	self.music_timer = 0
	self.music_volume = 0
	self.music_pitch = 1
	self.tutorial_timer = 5
	self.tutorial = ""
	World.music:stop()
	World.music:setVolume(0)
	World.music:seek(16.5)
	World.music:play()
	Camera.reset()
	
	if map_id == 1 then self.tutorial = "WASD to move" end
	if map_id == 2 then self.tutorial = "Left and Right keys to control the passage of time" end
end

function World:update(dt)
	self.music_volume = math.max(0, self.music_volume - dt)
	self.tutorial_timer = math.max(0, self.tutorial_timer - dt)
	self.music_timer = self.music_timer + dt
	
	if not (GameController.player.rewind or GameController.player.forward or GameController.level_no == 1) then
		self.music_volume = math.max(0, self.music_volume - 2*dt)
	end
	
	if GameController.player.forward or GameController.level_no == 1 then
		self:update_objects(dt/5)
		self.music_volume = math.min(1, self.music_volume + 2*dt)
	elseif GameController.player.rewind then
		self.music_volume = math.min(1, self.music_volume + 2*dt)
		self:update_objects(-dt/5)
		self.music_pitch = 5
		self.music:setPitch(self.music_pitch)
	end
	
	if not GameController.player.rewind and self.music_pitch == 5 then
		self.music_pitch = 1
		self.music:setPitch(self.music_pitch)
		World.music:seek(16.5 + self.music_timer)
	end
	
	World.music:setVolume(self.music_volume)
	if self.music_timer > 48.5 then
		World.music:seek(16.5)
		self.music_timer = self.music_timer - 48.5
	end
	
	self:update_jam_collision()
	
	GameController.player:update_position(dt)
	Camera.update(dt)
	
	if GameController.player.rewind then
		GameController.player.rewind_alpha = math.min(1,GameController.player.rewind_alpha + 5*dt)
	else
		GameController.player.rewind_alpha = math.max(0,GameController.player.rewind_alpha - 5*dt)
	end
	
	if GameController.player.forward or level_no == 1 then
		self.color_factor = math.min(1,self.color_factor + 5*dt)
	else
		self.color_factor = math.max(0,self.color_factor - 5*dt)
	end
end

function World:keypress(key)
	if MyLib.key_list.escape then
		MyLib.FadeToColor(0.3,{"LuaCall>GameController.go_to_main_menu()"},{},"fill",{0,0,0,1},true)
	else
		if GameController.state == Constants.EnumGameState.IN_GAME then
			if key == "w" then GameController.player.jump_timer = 1/12 end
		else
			GameController.state = Constants.EnumGameState.IN_GAME
		end
	end
end

function World:draw()
	if not QueueManager.is_loading then
		love.graphics.translate(self.current_map.origin.x, self.current_map.origin.y)
		love.graphics.translate(Camera.x, Camera.y)
		
		self.current_map:draw()
		
		love.graphics.translate(-Camera.x, -Camera.y)
		love.graphics.translate(-self.current_map.origin.x, -self.current_map.origin.y)
		
		if GameController.player.rewind_alpha > 0 then
			love.graphics.setColor(1,1,1,GameController.player.rewind_alpha)
			local frame = math.floor(GameController.player.animation_timer)%6 + 1
			love.graphics.draw(GameController.player.rewind_sprite.image, GameController.player.rewind_sprite.quads[frame],0,0,0,2.64,2)
		end
		
		if self.tutorial_timer > 0 and self.tutorial ~= "" then
			local alpha = 1
			if self.tutorial_timer > 4 then alpha = math.abs(self.tutorial_timer - 5) end
			if self.tutorial_timer < 1 then alpha = self.tutorial_timer end
			
			love.graphics.setColor(0,0,0,alpha)
						
			love.graphics.printf(self.tutorial,0,380,1280,"center")
			
			love.graphics.setColor(1,1,1)
		end
	end
end

function World:update_jam_collision()
	for _, object in ipairs(self.current_map.objects) do
		if object.type == "jam" then
			local py = GameController.player.position.y + GameController.player.sprite_border
			local px = GameController.player.position.x + GameController.player.sprite_border
			local ox = object.position.x*Constants.MapUnitToPixelRatio
			local oy = object.position.y*Constants.MapUnitToPixelRatio + object.dy

			if px + GameController.player.width > ox and px < ox + 2*Constants.MapUnitToPixelRatio then
				if py < oy + 2*Constants.MapUnitToPixelRatio and GameController.player.position.y + GameController.player.height > oy then
					GameController.next_level()
				end
			end
		end
	end
end

function World:update_objects(dt)
	if GameController.level_no == 1 then
		self.timer = (self.timer + dt)%1
	else
		self.timer = math.max(self.timer + dt, 0)
		self.timer = math.min(self.timer, 1)
	end
	local object_timer
	
	for index, object in ipairs(self.current_map.objects) do
		
		if object.type ~= "jam" then
			object_timer = (self.timer - object.initialTime) / (object.finalTime - object.initialTime)
		
			if object.finalTime < self.timer then object_timer = 1 end
			if object.initialTime > self.timer then object_timer = 0 end
		else
			object.dy = math.sin(math.pi*((self.timer*10)%10))*10
		end

		if object.type == "disappearing_platform" then
			local cycle_time = (object.finalTime - object.initialTime) / object.numberOfCycles
			local visible_cycle_time = object.visibleTimePercentage * cycle_time
			object_timer = self.timer % cycle_time

			if self.timer < object.initialTime or self.timer > object.finalTime or object_timer > visible_cycle_time then
				object.visible = false
			else
				object.visible = true
			end
		end
		
		if object.type == "mv_platform" then
			local dx = object.position.x
			local dy = object.position.y

			object.position.x = ( object.initialPosition.x + (object.finalPosition.x - object.initialPosition.x ) * Utils.smooth( (object_timer * object.numberOfCycles) % 2) ) * Constants.MapUnitToPixelRatio
    		object.position.y = (object.initialPosition.y + (object.finalPosition.y - object.initialPosition.y ) * Utils.smooth( (object_timer * object.numberOfCycles) % 2) ) * Constants.MapUnitToPixelRatio
			
			dx = object.position.x - dx
			dy = object.position.y - dy
			
			local feet_pos = GameController.player.position.y + GameController.player.height
			if feet_pos > object.position.y and feet_pos < object.position.y - dy then
				if (GameController.player.position.x + GameController.player.width + GameController.player.sprite_border > object.position.x
					and GameController.player.position.x + GameController.player.sprite_border < object.position.x + object.width*Constants.MapUnitToPixelRatio) then
					self.on_floor = true
					self.on_platform = index
					GameController.player.position.y = object.position.y - GameController.player.height
				end
			end
			
			if index == GameController.player.on_platform then
				GameController.player:update_position_on_platform({x = dx, y = dy}, dt)
			end
		end
	end
end
