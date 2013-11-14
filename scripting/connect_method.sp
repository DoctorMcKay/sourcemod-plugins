#pragma semicolon 1

#include <sourcemod>

#define PLUGIN_VERSION		"1.1.0"

public Plugin:myinfo = {
	name		= "[ANY] Connection Method Viewer",
	author		= "Dr. McKay",
	description	= "Shows you how in-game players connected to the server",
	version		= PLUGIN_VERSION,
	url			= "http://www.doctormckay.com"
};

new String:g_ConnectMethod[MAXPLAYERS + 1][64];

#define UPDATE_FILE		"connect_method.txt"
#define CONVAR_PREFIX	"connect_method"

#include "mckayupdater.sp"

public OnPluginStart() {
	for(new i = 1; i <= MaxClients; i++) {
		if(IsClientInGame(i) && !IsFakeClient(i)) {
			OnClientConnected(i);
		}
	}
	
	RegAdminCmd("sm_connectmethod", Command_ConnectMethod, ADMFLAG_GENERIC, "Displays how all in-game players connected");
}

public OnClientConnected(client) {
	if(IsFakeClient(client)) {
		return;
	}
	
	if(!GetClientInfo(client, "cl_connectmethod", g_ConnectMethod[client], sizeof(g_ConnectMethod[]))) {
		strcopy(g_ConnectMethod[client], sizeof(g_ConnectMethod[]), "Unknown");
	}
}

public Action:Command_ConnectMethod(client, args) {
	new ReplySource:source = GetCmdReplySource();
	if(client != 0 && source == SM_REPLY_TO_CHAT) {
		PrintToChat(client, "\x04[SM] \x01See console for output.");
		SetCmdReplySource(SM_REPLY_TO_CONSOLE);
	}
	
	ReplyToCommand(client, "[SM] Displaying connection method for all players...");
	for(new i = 1; i <= MaxClients; i++) {
		if(!IsClientInGame(i) || IsFakeClient(i)) {
			continue;
		}
		
		ReplyToCommand(client, "  - %-32N  %s", i, g_ConnectMethod[i]);
	}
	
	SetCmdReplySource(source);
	return Plugin_Handled;
}