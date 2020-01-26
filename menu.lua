local CHAR_WIDTH = 4
local LINE_HEIGHT = 5
local H_PADDING = 6
local V_PADDING = LINE_HEIGHT
local ITEM_V_PADDING = 2

local KEY = {
	UP = 2,
	DOWN = 3,
	SELECT = 4,
	CANCEL = 5
}

local api = nil
local Menu = {}
Menu.__index = Menu

function Menu:new(targetCanvas, resolution, title, entries, closeCallback)
	if api == nil then
		api = require("api")
	end

	local menu = {}
	menu.__index = Menu
	setmetatable(menu, Menu)

	menu.closeCallback = closeCallback
	menu.targetWidth = resolution[1]
	menu.targetHeight = resolution[2]
	menu.lastScreen = love.graphics.newCanvas(menu.targetWidth, menu.targetHeight)
	local target = love.graphics.getCanvas()
	menu.lastScreen:renderTo(
		function()
			love.graphics.draw(target)
		end
	)

	menu.entries = {}
	menu.lastKeypresses = {}
	menu.title = title
	menu.selected = 1
	if menu.title == nil then
		menu.height = 0
		menu.width = 0
	else
		menu.height = 2 * LINE_HEIGHT + ITEM_V_PADDING
		menu.titleWidth = menu.title:len() * CHAR_WIDTH
		menu.width = menu.titleWidth
	end

	for k, v in ipairs(entries) do
		local entry = v
		entry.width = entry.label:len() * CHAR_WIDTH
		if entry.width > menu.width then
			menu.width = entry.width
		end
		menu.height = menu.height + LINE_HEIGHT + ITEM_V_PADDING
		table.insert(menu.entries, entry)
	end

	menu.width = menu.width + 2 * H_PADDING
	menu.height = menu.height + 2 * V_PADDING
	menu.x = math.floor((menu.targetWidth - menu.width) / 2)
	menu.y = math.floor((menu.targetHeight - menu.height) / 2)

	return menu
end

function Menu:drawText(str, width, y, color)
	api.print(str:upper(), math.floor((self.targetWidth - width) / 2), y, color)
end

function Menu:draw(time)
	api.rectfill(self.x - 1, self.y - 1, self.x + self.width + 1, self.y + self.height + 1, 12)
	api.rectfill(self.x, self.y, self.x + self.width, self.y + self.height, 1)

	local y = self.y + V_PADDING

	if (self.title) then
		self:drawText(self.title, self.titleWidth, y, 6)
		y = y + 2 * LINE_HEIGHT + ITEM_V_PADDING
	end

	for i, entry in ipairs(self.entries) do
		self:drawText(entry.label, entry.width, y, (time * 30) % 8 < 4 and (self.selected == i) and 7 or 13)
		y = y + LINE_HEIGHT + ITEM_V_PADDING
	end
end

function Menu:input(keypresses)
	if keypresses[KEY.UP] and not self.lastKeypresses[KEY.UP] then
		self.selected = self.selected - 1
	end
	self.lastKeypresses[KEY.UP] = keypresses[KEY.UP]

	if keypresses[KEY.DOWN] and not self.lastKeypresses[KEY.DOWN] then
		self.selected = self.selected + 1
	end
	self.lastKeypresses[KEY.DOWN] = keypresses[KEY.DOWN]

	if self.selected < 1 then
		self.selected = 1
	end

	if self.selected > #self.entries then
		self.selected = #self.entries
	end

	if keypresses[KEY.CANCEL] and not self.lastKeypresses[KEY.CANCEL] then
		if self.closeCallback then
			self.closeCallback(self.selected, self.entries[self.selected], self)
		end
	end
	self.lastKeypresses[KEY.CANCEL] = keypresses[KEY.CANCEL]

	if keypresses[KEY.SELECT] and not self.lastKeypresses[KEY.SELECT] then
		if self.entries[self.selected].callback then
			self.entries[self.selected].callback(self.selected, self.entries[self.selected], self)
		end
	end
	self.lastKeypresses[KEY.SELECT] = keypresses[KEY.SELECT]
end

function Menu:restore()
	love.graphics.draw(self.lastScreen)
end

local MenuStack = {}
MenuStack.__index = MenuStack

function MenuStack:new(targetCanvas, resolution)
	local stack = {}
	stack.__index = MenuStack
	setmetatable(stack, MenuStack)

	stack.targetCanvas = targetCanvas
	stack.resolution = resolution
	stack.menus = {}
	stack.lastClosedMenu = nil

	return stack
end

function MenuStack:active()
	return self.menus[#self.menus]
end

function MenuStack:push(title, entries)
	local menu =
		Menu:new(
		self.targetCanvas,
		self.resolution,
		title,
		entries,
		function()
			self:back()
		end
	)
	table.insert(self.menus, menu)
end

function MenuStack:back()
	local menu = self:active()
	if not menu then
		return
	end
	self.lastClosedMenu = menu
	table.remove(self.menus)
end

function MenuStack:input(keypresses)
	local menu = self:active()
	if not menu then
		return
	end
	menu:input(keypresses)
end

function MenuStack:draw(time)
	local menu = self:active()
	if not menu then
		return
	end
	menu:draw(time)
end

function MenuStack:confirm(prompt, callback)
	self:push(
		prompt,
		{
			{label = "yes", callback = callback},
			{label = "no", callback = function()
					self:back()
				end}
		}
	)
end

function MenuStack:toggleEntry(label, value, callback)
	local toggleEntry = {
		label = "",
		callback = function(_, entry, _2, skipCallback)
			value = not value
			entry.label = label .. ": " .. (value and "yes" or "no")
			if not skipCallback then
				callback(value)
			end
		end
	}
	toggleEntry.callback(nil, toggleEntry, true)
	return toggleEntry
end

function MenuStack:restore()
	if self.lastClosedMenu then
		self.lastClosedMenu.restore()
		self.lastClosedMenu = nil
	end
end

return MenuStack
