#pragma semicolon 1

#include <sourcemod>
#include <sdktools>

#define PLUGIN_VERSION		"1.0.0"

public Plugin myinfo = {
	name		= "[TF2] Name Change Oddities Fix",
	author		= "Dr. McKay",
	description	= "Fixes some oddities relating to name changes created by TF2 update",
	version		= PLUGIN_VERSION,
	url			= "http://www.doctormckay.com"
};

#define UPDATE_FILE		"namechange_fix.txt"
#define CONVAR_PREFIX	"namechange_fix"

#include "mckayupdater.sp"

#pragma newdecls required

char g_PlayerName[MAXPLAYERS + 1][MAX_NAME_LENGTH];

public void OnPluginStart() {
	// Account for late-loads
	for(int i = 1; i <= MaxClients; i++) {
		if(IsClientConnected(i)) {
			GetClientName(i, g_PlayerName[i], sizeof(g_PlayerName[]));
		}
	}
}

public void OnClientConnected(int client) {
	GetClientName(client, g_PlayerName[client], sizeof(g_PlayerName[]));
}

public void OnGameFrame() {
	char infoName[MAX_NAME_LENGTH];
	
	for(int i = 1; i <= MaxClients; i++) {
		if(!IsClientConnected(i)) {
			continue;
		}
		
		// This isn't updated until any applicable sv_namechange_cooldown_seconds limit expires, so we're fine to just check it
		GetClientInfo(i, "name", infoName, sizeof(infoName));
		if(!StrEqual(g_PlayerName[i], infoName)) {
			// Name changed
			SetEntPropString(i, Prop_Data, "m_szNetname", infoName);
			
			// Fire the event
			Event event = CreateEvent("player_changename");
			event.SetInt("userid", GetClientUserId(i));
			event.SetString("oldname", g_PlayerName[i]);
			event.SetString("newname", infoName);
			event.Fire();
			
			// Send the chat message
			Handle bf = StartMessageAll("SayText2", USERMSG_RELIABLE);
			BfWriteByte(bf, i);
			BfWriteByte(bf, true);
			BfWriteString(bf, "#TF_Name_Change");
			BfWriteString(bf, g_PlayerName[i]);
			BfWriteString(bf, infoName);
			EndMessage();
			
			strcopy(g_PlayerName[i], sizeof(g_PlayerName[]), infoName);
		}
	}
}