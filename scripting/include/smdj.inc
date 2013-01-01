#if defined _smdj_included
  #endinput
#endif
#define _smdj_included

/**
 * Called when a client starts to listen to a song.
 * 
 * @param client		Client index
 * @param title			Song title
 * @noreturn
 */
forward SMDJ_OnStartListen(client, const String:title[]);


public SharedPlugin:__pl_smdj = {
	name = "smdj",
	file = "smdj.smx",
#if defined REQUIRE_PLUGIN
	required = 1
#else
	required = 0
#endif
};