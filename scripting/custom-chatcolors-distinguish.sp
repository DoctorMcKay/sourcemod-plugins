#pragma semicolon 1

#include <sourcemod>
#include <ccc>

#define PLUGIN_VERSION		"1.0.0"

public Plugin:myinfo = {
	name		= "[Source 2009] Custom Chat Colors Distinguish Module",
	author		= "Dr. McKay",
	description	= "Controls what CCC aspects are visible based on a chat prefix",
	version		= PLUGIN_VERSION,
	url			= "http://www.doctormckay.com"
};

#define UPDATE_FILE		"chatcolorsdistinguishmodule.txt"
#define CONVAR_PREFIX	"custom_chat_colors_distinguish"

#include "mckayupdater.sp"

new Handle:cvarPrefix;
new Handle:cvarTag;
new Handle:cvarNameColor;
new Handle:cvarChatColor;

public OnPluginStart() {
	cvarPrefix = CreateConVar("sm_ccc_distinguish_prefix", "#", "Character or string that must be prefixed to a chat message to make it distinguished (case-sensitive)");
	cvarTag = CreateConVar("sm_ccc_distinguish_tag", "-1", "-1 = display tag always, 0 = only display tag when not distinguished, 1 = only display tag when distinguished", _, true, -1.0, true, 1.0);
	cvarNameColor = CreateConVar("sm_ccc_distinguish_name", "-1", "-1 = color name always, 0 = only color name when not distinguished, 1 = only color name when distinguished", _, true, -1.0, true, 1.0);
	cvarChatColor = CreateConVar("sm_ccc_distinguish_chat", "-1", "-1 = color chat always, 0 = only color chat when not distinguished, 1 = only color chat when distinguished", _, true, -1.0, true, 1.0);
}

public Action:CCC_OnColor(client, const String:message[], CCC_ColorType:type) {
	new value = -1;
	
	switch(type) {
		case CCC_TagColor: value = GetConVarInt(cvarTag);
		case CCC_NameColor: value = GetConVarInt(cvarNameColor);
		case CCC_ChatColor: value = GetConVarInt(cvarChatColor);
	}
	
	if(value == -1) {
		return Plugin_Continue;
	}
	
	if(!IsMessageDistinguished(client, message)) {
		// Message is not distinguished
		if(value == 0) {
			return Plugin_Continue;
		} else {
			return Plugin_Handled;
		}
	} else {
		// Message is distinguished
		if(value == 0) {
			return Plugin_Handled;
		} else {
			return Plugin_Continue;
		}
	}
}

public CCC_OnChatMessage(client, String:message[], maxlen) {
	if(!IsMessageDistinguished(client, message)) {
		return;
	}
	
	new firstChar = FindFirstCharacter(message);
	decl String:prefix[64];
	GetConVarString(cvarPrefix, prefix, sizeof(prefix));
	for(new i = 0; i < strlen(prefix); i++) {
		RemoveChar(message, firstChar);
	}
}

bool:IsMessageDistinguished(client, const String:message[]) {
	if(!CheckCommandAccess(client, "sm_ccc_distinguish", 0, true)) {
		return false;
	}
	
	new firstChar = FindFirstCharacter(message);
	decl String:prefix[64];
	GetConVarString(cvarPrefix, prefix, sizeof(prefix));
	return (StrContains(message[firstChar], prefix) == 0);
}

FindFirstCharacter(const String:message[]) {
	new pos = 0;
	while(!IsValidCharacter(message[pos])) {
		if(message[pos] == '\x07') {
			pos += 7;
		} else if(message[pos] == '\x08') {
			pos += 9;
		} else {
			pos++;
		}
	}
	
	return pos;
}

bool:IsValidCharacter(char) {
	return !(char == '"' || char == ' ' || char == '\x01' || char == '\x02' || char == '\x03' || char == '\x04' || char == '\x05' || char == '\x06' || char == '\x07' || char == '\x08' || char == '\x09' || char == '\x10');
}

RemoveChar(String:message[], index) {
	new len = strlen(message);
	for(new i = index; i < len; i++) {
		message[i] = message[i + 1];
	}
	message[len - 1] = '\0';
}