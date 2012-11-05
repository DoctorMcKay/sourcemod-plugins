#if defined _ccc_included
  #endinput
#endif
#define _ccc_included

/**
 * Gets a client's name color and returns it as a color code that can be prefixed to text
 * 
 * @param client		Client index
 * @param buffer		Buffer to store the color code
 * @param maxlen		Maximum length of buffer
 * @noreturn
 * 
 * On error/errors:		Invalid client index or client is not in game
 */
native CCC_GetNameColor(client, String:buffer[], maxlen);

/**
 * Gets a client's chat color and returns it as a color code that can be prefixed to text
 * 
 * @param client		Client index
 * @param buffer		Buffer to store the color code
 * @param maxlen		Maximum length of buffer
 * @noreturn
 * 
 * On error/errors:		Invalid client index or client is not in game
 */
native CCC_GetChatColor(client, String:buffer[], maxlen);

/**
 * Gets a client's tag color and returns it as a color code that can be prefixed to text
 * 
 * @param client		Client index
 * @param buffer		Buffer to store the color code
 * @param maxlen		Maximum length of buffer
 * @noreturn
 * 
 * On error/errors:		Invalid client index or client is not in game
 */
native CCC_GetTagColor(client, String:buffer[], maxlen);

/**
 * Gets a client's tag
 * 
 * @param client		Client index
 * @param buffer		Buffer to store the tag in
 * @param maxlen		Maximum buffer length
 * @noreturn
 * 
 * On error/errors:		Invalid client index or client is not in game
 */
native CCC_GetTag(client, String:buffer[], maxlen);

/**
 * Sets a client's name color
 * 
 * @param client		Client index
 * @param color			String containing the color in hex format, or "O" or "G"
 * @return				true if color was updated successfully, false otherwise
 * 
 * On error/errors:		Invalid client index or client is not in game
 */
native bool:CCC_SetNameColor(client, const String:color[]);

/**
 * Sets a client's chat color
 * 
 * @param client		Client index
 * @param color			String containing the color in hex format, or "O" or "G" or "T"
 * @return				true if color was updated successfully, false otherwise
 * 
 * On error/errors:		Invalid client index or client is not in game
 */
native bool:CCC_SetChatColor(client, const String:color[]);

/**
 * Sets a client's tag color
 * 
 * @param client		Client index
 * @param color			String containing the color in hex format, or "O" or "G" or "T"
 * @return				true if color was updated successfully, false otherwise
 * 
 * On error/errors:		Invalid client index or client is not in game
 */
native bool:CCC_SetTagColor(client, const String:color[]);

/**
 * Sets a client's tag
 * 
 * @param client		Client index
 * @param tag			String containing the new tag
 * @noreturn
 * 
 * On error/errors:		Invalid client index or client is not in game
 */
native bool:CCC_SetTag(client, const String:tag[]);

/**
 * Called when a cilent's name is about to be colored
 * DO NOT START A NEW USERMESSAGE (i.e. PrintToChat, PrintToChatAll) WITHIN THIS FORWARD
 * 
 * @param client		Client index
 * @return				Plugin_Handled or Plugin_Stop to prevent coloring, Plugin_Continue or Plugin_Changed to allow coloring
 */
forward Action:CCC_OnNameColor(client);

/**
 * Called when a client's chat is about to be colored
 * DO NOT START A NEW USERMESSAGE (i.e. PrintToChat, PrintToChatAll) WITHIN THIS FORWARD
 * 
 * @param client		Client index
 * @return				Plugin_Handled or Plugin_Stop to prevent coloring, Plugin_Continue or Plugin_Changed to allow coloring
 */
forward Action:CCC_OnChatColor(client);

/**
 * Called when a client's name is about to be tagged
 * DO NOT START A NEW USERMESSAGE (i.e. PrintToChat, PrintToChatAll) WITHIN THIS FORWARD
 * 
 * @param client		Client index
 * @return				Plugin_Handled or Plugin_Stop to prevent coloring, Plugin_Continue or Plugin_Changed to allow coloring
 */
forward Action:CCC_OnTagApplied(client);

/**
 * Called when a client's colors and tag have been loaded from the config file
 * 
 * @param client		Client index
 * @noreturn
 */
forward CCC_OnUserConfigLoaded(client);

public SharedPlugin:_pl_ccc = {
	name = "ccc",
	file = "custom-chatcolors.smx",
#if defined REQUIRE_PLUGIN
	required = 1
#else
	required = 0
#endif
};

#if !defined REQUIRE_PLUGIN
public _pl_ccc_SetNTVOptional() {
	MarkNativeAsOptional("CCC_GetNameColor");
	MarkNativeAsOptional("CCC_GetChatColor");
	MarkNativeAsOptional("CCC_GetTagColor");
	MarkNativeAsOptional("CCC_GetTag");
}
#endif