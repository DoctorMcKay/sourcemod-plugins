#if defined _player_analytics_included
 #endinput
#endif
#define _player_analytics_included

/**
 * Gets a client's connection ID in the database
 * 
 * @param client		Client index to get connection ID for
 * @return				Client's connection ID or -1 if unavailable
 * @error				If the client is not connected an error will be thrown.
 */
native int PA_GetConnectionID(int client);

/**
 * Called when a client's connection has been logged to the database
 * 
 * @param client		Client index for whom the connection was logged
 * @param connID		Connection ID for the client (same as ID returned by PA_GetConnectionID)
 * @noreturn
 */
forward void PA_OnConnectionLogged(int client, int connID);

public SharedPlugin:__pl_player_analytics = {
	name = "player_analytics",
	file = "player_analyics.smx",
#if defined REQUIRE_PLUGIN
	required = 1
#else
	required = 0
#endif
};

#if !defined REQUIRE_PLUGIN
public __pl_player_analytics_SetNTVOptional() {
	MarkNativeAsOptional("PA_GetConnectionID");
}
#endif