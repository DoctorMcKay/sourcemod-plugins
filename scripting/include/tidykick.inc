#if defined _tidykick_included
 #endinput
#endif
#define _tidykick_included

/**
 * Kicks a client without a "Disconnect: " prefix on the kick message
 * 
 * @param client		Client index to kick
 * @param reason		Reason string (formatting rules)
 * @param ...			Variable number of format parameters
 * @noreturn
 * @error				If the client is not connected an error will be thrown.
 */
native TidyKickClient(client, const String:reason[], any:...);

public SharedPlugin:__pl_tidykick = {
	name = "tidykick",
	file = "tidykick.smx",
#if defined REQUIRE_PLUGIN
	required = 1
#else
	required = 0
#endif
};

#if !defined REQUIRE_PLUGIN
public __pl_tidykick_SetNTVOptional() {
	MarkNativeAsOptional("TidyKickClient");
}
#endif