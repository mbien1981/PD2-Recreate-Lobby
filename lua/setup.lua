-- DAHM by DorentuZ` -- http://steamcommunity.com/id/dorentuz/
--
-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at http://mozilla.org/MPL/2.0/.

core:import("CoreEngineAccess")
core:import("CoreLinkedStackMap")
core:import("CoreTable")
core:import("CoreUnit")
core:import("CoreClass")

local table = table
local unpack = unpack

local DelayedCallbacksManager = class()

function DelayedCallbacksManager:init()
	self._time_callback_map = CoreLinkedStackMap.LinkedStackMap:new()
	self._callback_map = {}
	self._last_callback_id = 0
	self._latest_update = 0
end

function DelayedCallbacksManager:add_time_callback(func, delay, repeat_nr, fire_when_paused, ...)
	local time_callback = {}
	time_callback.func = func

	if type(delay) == "table" then
		delay[1] = tonumber(delay[1]) or 0
		delay[2] = tonumber(delay[2])
		if not delay[2] then
			delay = delay[1]
		end
		time_callback.delay = delay

		-- determine delay for the initial callback
		if type(delay) == "table" then
			delay = math.random(delay[1], delay[2])
		end
	else
		delay = tonumber(delay) or 0
		time_callback.delay = delay
	end

	local TM = _G.TimerManager
	time_callback.fire_when_paused = fire_when_paused or false
	time_callback.time = (fire_when_paused and TM:wall():time() or TM:game():time()) + delay
	time_callback.repeat_nr = tonumber(repeat_nr) or 1
	time_callback.params = { n = select("#", ...), ... }

	return self._time_callback_map:add(time_callback)
end

function DelayedCallbacksManager:remove_time_callback(id)
	if self._currently_running_tc == id then
		-- cannot directly remove running functions
		self._time_callback_map:get(id).value.repeat_nr = 0
	else
		self._time_callback_map:remove(id)
	end
end

function DelayedCallbacksManager:add_retry_callback(callback_type, func, try_immediately)
	if not try_immediately or not func() then
		local retry_callbacks, retry_callback_indices = self._retry_callback_list, self._retry_callback_indices
		if not retry_callbacks then
			retry_callbacks, retry_callback_indices = {}, {}
			self._retry_callback_list, self._retry_callback_indices = retry_callbacks, retry_callback_indices
		end

		if not retry_callbacks[callback_type] then
			retry_callbacks[callback_type] = {}
			retry_callback_indices[callback_type] = 0
		end

		local index = retry_callback_indices[callback_type] - 1
		if index < 1 then
			index, retry_callback_indices[callback_type] = 1, 1
		end

		table.insert(retry_callbacks[callback_type], index, func)
	end
end

function DelayedCallbacksManager:add_callback(func)
	self._last_callback_id = self._last_callback_id + 1
	self._callback_map[self._last_callback_id] = func
	return self._last_callback_id
end

function DelayedCallbacksManager:remove_callback(id)
	self._callback_map[id] = nil
end

function DelayedCallbacksManager:update(time, delta_time, is_game_paused)
	-- regular callbacks should run on every update
	for id, func in pairs(self._callback_map) do
		func(time, delta_time)
	end

	local TimerManager = _G.TimerManager
	local retry_callback_list = self._retry_callback_list
	if retry_callback_list then
		local retry_callback_indices = self._retry_callback_indices
		for callback_type in pairs(retry_callback_list) do
			if next(retry_callback_list[callback_type]) then
				local retry_callback_list_for_type = retry_callback_list[callback_type]
				local retry_callback_idx = retry_callback_indices[callback_type]
				local retry_func = retry_callback_list_for_type[retry_callback_idx]
				local idx = retry_callback_indices[callback_type]
				if retry_func() then
					table.remove(retry_callback_list_for_type, idx)
				else
					idx = idx + 1
				end
				if idx > #retry_callback_list_for_type then
					-- wrap
					idx = 1
				end
				retry_callback_indices[callback_type] = idx
			else
				retry_callback_list[callback_type] = nil
				retry_callback_indices[callback_type] = nil
			end
		end

		if not next(retry_callback_list) then
			self._retry_callback_list = nil
			self._retry_callback_indices = nil
		end
	end

	-- no need to check the rest on every update; they're delayed callbacks
	local wt = TimerManager:wall():time()
	if self._latest_update + 0.01 > wt then
		return
	end

	local gt = TimerManager:game():time()
	local remove_time_callback_list
	for id, time_callback in self._time_callback_map:bottom_top_iterator() do
		-- the 'time' variable has a different value when the game is paused, so use the wall clock instead
		if
			(not is_game_paused and not time_callback.fire_when_paused and time >= time_callback.time)
			or (time_callback.fire_when_paused and wt >= time_callback.time)
		then
			self._currently_running_tc = id

			local result
			if time_callback.params.n == 0 then
				result = time_callback.func()
			else
				result = time_callback.func(unpack(time_callback.params, 1, time_callback.params.n))
			end
			self._currently_running_tc = nil

			if not result and time_callback.repeat_nr > 1 then
				local t = (time_callback.fire_when_paused and wt or gt)
				local delay = time_callback.delay
				if type(delay) == "table" then
					delay = math.random(delay[1], delay[2])
				end
				time_callback.time = t + delay + (t - time_callback.time)
				time_callback.repeat_nr = time_callback.repeat_nr - 1
			else
				remove_time_callback_list = remove_time_callback_list or {}
				remove_time_callback_list[#remove_time_callback_list + 1] = id
			end
		end
	end

	if remove_time_callback_list then
		for i = 1, #remove_time_callback_list do
			local id = remove_time_callback_list[i]
			self._time_callback_map:remove(id)
		end
	end

	self._latest_update = wt
end

Hooks:PostHook(Setup, "init_managers", "RL:Setup:init_managers", function(_, managers)
	managers.delayed_callbacks = managers.delayed_callbacks or DelayedCallbacksManager:new()
end)
