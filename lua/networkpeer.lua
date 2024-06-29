-- DAHM by DorentuZ` -- http://steamcommunity.com/id/dorentuz/
--
-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at http://mozilla.org/MPL/2.0/.

Hooks:PreHook(NetworkPeer, "init", "RL:NetworkPeer:init", function(self)
	self._is_local_user = false
end)

-- pre-eos version support
function NetworkPeer:account_id()
	return self._account_id or self._user_id
end

function NetworkPeer:is_local_user()
	return self._is_local_user
end

function NetworkPeer:set_local_user(is_local_user)
	self._is_local_user = is_local_user
end
