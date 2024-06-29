-- DAHM by DorentuZ` -- http://steamcommunity.com/id/dorentuz/
--
-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at http://mozilla.org/MPL/2.0/.

local class_name = ({
	["lib/network/matchmaking/networkmatchmakingepic"] = "NetworkMatchMakingEPIC",
	["lib/network/matchmaking/networkmatchmakingsteam"] = "NetworkMatchMakingSTEAM",
})[RequiredScript:lower()]

if not class_name then
	return
end

local NetworkMatchMakingClass = _G[class_name]
if not NetworkMatchMakingClass then
	return
end

local network_class_name = ({
	["NetworkMatchMakingEPIC"] = "EpicMM",
	["NetworkMatchMakingSTEAM"] = "Steam",
})[class_name]

local NetworkClass = _G[network_class_name]

local table_get = function(t, ...)
	if not t then
		return nil
	end

	local v, keys = t, { ... }
	for i = 1, #keys do
		v = v[keys[i]]
		if v == nil then
			break
		end
	end

	return v
end

function NetworkMatchMakingClass:_keep_lobby_alive()
	if self.lobby_handler then
		self.lobby_handler:set_lobby_data(self._lobby_attributes)
	end
end

function NetworkMatchMakingClass:_initiate_lobby_keep_alive_callback()
	self._lobby_status = "ok"
	if self._keep_alive_tcid then
		return
	end

	self._keep_alive_tcid =
		managers.delayed_callbacks:add_time_callback(self._keep_lobby_alive, 300, 2147483008, true, self)
end

local callbacks = {
	NetworkMatchMakingClass._on_memberstatus_change,
	NetworkMatchMakingClass._on_data_update,
}

if class_name == "NetworkMatchMakingSTEAM" then
	table.insert(callbacks, NetworkMatchMakingClass._on_chat_message)
end

function NetworkMatchMakingClass:create_lobby(settings)
	self._num_players = nil
	local dialog_data = {
		title = managers.localization:text("dialog_creating_lobby_title"),
		text = managers.localization:text("dialog_wait"),
		id = "create_lobby",
		no_buttons = true,
	}

	managers.system_menu:show(dialog_data)

	local function f(result, handler)
		-- print("Create lobby callback!!", result, handler)

		if result == "success" then
			self.lobby_handler = handler

			self:set_attributes(settings)
			if self.lobby_handler.publish_server_details then
				self.lobby_handler:publish_server_details()
			end

			self._server_joinable = true

			self.lobby_handler:set_joinable(true)
			self.lobby_handler:setup_callbacks(unpack(callbacks))
			managers.system_menu:close("create_lobby")
			managers.menu:created_lobby()
			self:_initiate_lobby_keep_alive_callback()
		else
			managers.system_menu:close("create_lobby")

			local title = managers.localization:text("dialog_error_title")
			local dialog_data = {
				title = title,
				text = managers.localization:text("dialog_err_failed_creating_lobby"),
				button_list = {
					{ text = managers.localization:text("dialog_ok") },
				},
			}

			managers.system_menu:show(dialog_data)
		end
	end

	return NetworkClass:create_lobby(f, NetworkMatchMakingClass.OPEN_SLOTS, "invisible")
end

function NetworkMatchMakingClass:recreate_lobby()
	if table_get(Global.game_settings, "single_player") or not self.lobby_handler then
		return
	end

	managers.system_menu:show({
		title = managers.localization:text("dialog_creating_lobby_title"),
		text = managers.localization:text("dialog_wait"),
		id = "create_lobby",
		no_buttons = true,
		cancelable = true,
	})

	-- try to set the old one to private
	if self.lobby_handler then
		self._server_joinable = false

		self.lobby_handler:set_lobby_type("private")
		self.lobby_handler:set_joinable(false)
	end

	local function f(result, handler)
		-- print("Recreate lobby callback!!", result, handler)

		if result == "success" then
			local attrs = self._lobby_attributes
			self.lobby_handler = handler

			self:set_attributes({
				numbers = {
					attrs.level,
					attrs.difficulty,
					attrs.permission,
					attrs.state,
					nil,
					attrs.drop_in,
					attrs.min_level,
					attrs.kick_option,
					attrs.job_class_min,
					attrs.job_class_max,
				},
			})
			if self.lobby_handler.publish_server_details then
				self.lobby_handler:publish_server_details()
			end

			self._server_joinable = true

			self.lobby_handler:set_joinable(true)
			self.lobby_handler:setup_callbacks(unpack(callbacks))
			managers.system_menu:close("create_lobby")
			--managers.menu:created_lobby()
			self:_initiate_lobby_keep_alive_callback()
		else
			managers.system_menu:close("create_lobby")

			local title = managers.localization:text("dialog_error_title")
			local dialog_data = {
				title = title,
				text = managers.localization:text("dialog_err_failed_creating_lobby"),
				button_list = {
					{ text = managers.localization:text("dialog_ok") },
				},
			}

			managers.system_menu:show(dialog_data)
		end
	end

	return NetworkClass:create_lobby(f, NetworkMatchMakingClass.OPEN_SLOTS, "invisible")
end

local hook_id = "RL:%s._on_memberstatus_change"
Hooks:PreHook(NetworkMatchMakingClass, "_on_memberstatus_change", hook_id:format(class_name), function(memberstatus)
	local self = managers.network.matchmake
	if not self or self._lobby_status ~= "ok" then
		return
	end

	if not Network:is_server() then
		return
	end

	local user, status = unpack(string.split(memberstatus, ":"))
	local session = managers.network:session()
	if not session or session:closing() then
		return
	end

	local peer = session:peer_by_account_id(user)
	if not peer or not peer:is_local_user() then
		return
	end

	self._lobby_status = "invalid"
end)

function NetworkMatchMakingClass:lobby_is_invalid()
	if not Network:is_server() then
		return false
	end

	return self._lobby_status ~= "ok"
end

hook_id = "RL:%s._on_data_update"
Hooks:PostHook(NetworkMatchMakingClass, "_on_data_update", hook_id:format(class_name), function(data)
	if Network:is_server() and data then
		managers.network.matchmake._lobby_status = "ok"
	end
end)
