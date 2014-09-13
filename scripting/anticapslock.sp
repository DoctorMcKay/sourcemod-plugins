#pragma semicolon 1

#include <sourcemod>
#include <scp>

#define PLUGIN_VERSION		"1.0.0"

public Plugin:myinfo = {
	name		= "[ANY] Anti Caps Lock",
	author		= "Dr. McKay",
	description	= "Forces text to lowercase when too many caps are used",
	version		= PLUGIN_VERSION,
	url			= "http://www.doctormckay.com"
};

new Handle:g_cvarPctRequired;
new Handle:g_cvarMinLength;

#define UPDATE_FILE		"anticapslock.txt"
#define CONVAR_PREFIX	"anti_caps_lock"

#include "mckayupdater.sp"

public OnPluginStart() {
	g_cvarPctRequired = CreateConVar("anti_caps_lock_percent", "0.9", "Force all letters to lowercase when this percent of letters is uppercase (not counting symbols)", _, true, 0.0, true, 1.0);
	g_cvarMinLength = CreateConVar("anti_caps_lock_min_length", "5", "Only force letters to lowercase when a message has at least this many letters (not counting symbols)", _, true, 0.0);
}

public Action:OnChatMessage(&author, Handle:recipients, String:name[], String:message[]) {
	new letters, uppercase, length = strlen(message);
	for(new i = 0; i < length; i++) {
		if(message[i] >= 'A' && message[i] <= 'Z') {
			uppercase++;
			letters++;
		} else if(message[i] >= 'a' && message[i] <= 'z') {
			letters++;
		}
	}
	
	if(letters >= GetConVarInt(g_cvarMinLength) && float(uppercase) / float(letters) >= GetConVarFloat(g_cvarPctRequired)) {
		// Force to lowercase
		for(new i = 0; i < length; i++) {
			if(message[i] >= 'A' && message[i] <= 'Z') {
				message[i] = CharToLower(message[i]);
			}
		}
		
		return Plugin_Changed;
	}
	
	return Plugin_Continue;
}