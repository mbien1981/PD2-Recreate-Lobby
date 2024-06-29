-- DAHM by DorentuZ` -- http://steamcommunity.com/id/dorentuz/
--
-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at http://mozilla.org/MPL/2.0/.

function MenuCallbackHandler:can_see_recreate_button()
	-- if managers.network and managers.network.matchmake and managers.network.matchmake:lobby_is_invalid() then
	-- 	return true
	-- end

	return true
end

function MenuCallbackHandler:recreate_lobby()
	if not Network:is_server() then
		return
	end

	managers.system_menu:show({
		title = managers.localization:text("dialog_warning_title"),
		text = managers.localization:text("menu_recreate_lobby_confirm"),
		button_list = {
			{
				text = managers.localization:text("dialog_yes"),
				callback_func = function()
					managers.network.matchmake:recreate_lobby()
				end,
			},
			{
				text = managers.localization:text("dialog_no"),
				cancel_button = true,
			},
		},
	})
end

local insert_recreate_lobby_button = function(node)
	table.insert(
		node._items,
		node:create_item({
			type = "MenuItemDivider",
			size = 24,
			no_text = true,
		}, { id = "recreate_lobby_divider" })
	)

	local item = node:create_item({ type = "CoreMenuItem.Item" }, {
		name = "recreate_lobby",
		text_id = "menu_recreate_lobby",
		help_id = "menu_recreate_lobby_help",
		callback = "recreate_lobby",
		visible_callback = "is_multiplayer can_see_recreate_button",
		localize = true,
	})
	item:set_callback_handler(node.callback_handler)

	table.insert(node._items, item)
end

Hooks:Add("MenuManagerBuildCustomMenus", "RL:MenuManagerBuildCustomMenus", function(_, nodes)
	local node = nodes.edit_game_settings
	if not node then
		return
	end

	insert_recreate_lobby_button(node)
end)

local locale_path = ModPath .. "loc/en.json"
Hooks:Add("LocalizationManagerPostInit", "LocalizationManagerPostInit_LIES", function(loc)
	loc:load_localization_file(locale_path)
end)
