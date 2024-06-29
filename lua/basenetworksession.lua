-- DAHM by DorentuZ` -- http://steamcommunity.com/id/dorentuz/
--
-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at http://mozilla.org/MPL/2.0/.

Hooks:PostHook(BaseNetworkSession, "create_local_peer", "RL:BaseNetworkSession:create_local_peer", function(self)
	self._local_peer:set_local_user(true)
end)

function BaseNetworkSession:peer_by_account_id(account_id)
	for _, peer in pairs(self._peers_all) do
		if peer:account_id() == account_id then
			return peer
		end
	end
end
