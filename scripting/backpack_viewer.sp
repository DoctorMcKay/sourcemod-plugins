#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <clientprefs>
#include <advanced_motd>

#define PLUGIN_VERSION		"1.1.3"

public Plugin:myinfo = {
	name		= "[TF2] Custom Backpack Viewer",
	author		= "Dr. McKay",
	description	= "Opens players' backpacks in a backpack viewer chosen by the client",
	version		= PLUGIN_VERSION,
	url			= "http://www.doctormckay.com"
};

new Handle:g_cookieBackpackPreference;
new Handle:g_cvarDefaultPreference;
new Handle:g_cvarAllowTracking;
new Handle:g_BackpackViewers;

new String:g_ServerIP[32];

#define UPDATE_FILE		"backpack_viewer.txt"
#define CONVAR_PREFIX	"backpack_viewer"

#include "mckayupdater.sp"

public OnPluginStart() {
	g_cookieBackpackPreference = RegClientCookie("backpack_viewer_preference", "Backpack viewer preference", CookieAccess_Protected);
	g_cvarDefaultPreference = CreateConVar("backpack_viewer_default", "backpacktf", "Default backpack viewer to use");
	g_cvarAllowTracking = CreateConVar("backpack_viewer_allow_tracking", "1", "Allow the server IP to be sent to the backpack viewer (if configured as such) for analytics purposes", _, true, 0.0, true, 1.0);
	
	HookConVarChange(g_cvarAllowTracking, OnTrackingChanged);
	OnTrackingChanged(g_cvarAllowTracking, "", "");
	
	decl String:path[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, path, sizeof(path), "configs/backpack_viewer.txt");
	if(!FileExists(path)) {
		BuildPath(Path_SM, path, sizeof(path), "data/backpack_viewer.txt");
	}
	
	if(!FileExists(path)) {
		SetFailState("backpack_viewer.txt not found in configs or data");
	}
	
	g_BackpackViewers = CreateKeyValues("");
	FileToKeyValues(g_BackpackViewers, path);
	
	SetCookieMenuItem(Handler_CookieMenu, 0, "Backpack Viewer Preference");
	
	RegConsoleCmd("sm_backpack", Command_Backpack, "View a player's backpack");
	RegConsoleCmd("sm_bp", Command_Backpack, "View a player's backpack");
	
	LoadTranslations("common.phrases");
}

public OnTrackingChanged(Handle:convar, const String:oldValue[], const String:newValue[]) {
	if(GetConVarBool(convar)) {
		// Tracking allowed
		new ip = GetConVarInt(FindConVar("hostip"));
		Format(g_ServerIP, sizeof(g_ServerIP), "%d.%d.%d.%d:%d",
			((ip & 0xFF000000) >> 24) & 0xFF,
			((ip & 0x00FF0000) >> 16) & 0xFF,
			((ip & 0x0000FF00) >> 8) & 0xFF,
			((ip & 0x000000FF) >> 0) & 0xFF,
			GetConVarInt(FindConVar("hostport"))
		);
	} else {
		// Tracking not allowed
		strcopy(g_ServerIP, sizeof(g_ServerIP), "anonymous");
	}
}

public Handler_CookieMenu(client, CookieMenuAction:action, any:info, String:buffer[], maxlen) {
	switch(action) {
		case CookieMenuAction_DisplayOption: {
			strcopy(buffer, maxlen, "Backpack Viewer Preference");
		}
		
		case CookieMenuAction_SelectOption: {
			new Handle:menu = CreateMenu(Handler_ViewerPreference);
			SetMenuTitle(menu, "Backpack Viewer Preference");
			
			KvRewind(g_BackpackViewers);
			KvGotoFirstSubKey(g_BackpackViewers);
			decl String:key[32], String:name[64];
			do {
				KvGetSectionName(g_BackpackViewers, key, sizeof(key));
				KvGetString(g_BackpackViewers, "name", name, sizeof(name));
				AddMenuItem(menu, key, name);
			} while(KvGotoNextKey(g_BackpackViewers));
			
			DisplayMenu(menu, client, 30);
		}
	}
}

public Handler_ViewerPreference(Handle:menu, MenuAction:action, client, param) {
	if(action == MenuAction_End) {
		CloseHandle(menu);
	}
	
	if(action != MenuAction_Select) {
		return;
	}
	
	decl String:selection[32];
	GetMenuItem(menu, param, selection, sizeof(selection));
	SetClientCookie(client, g_cookieBackpackPreference, selection);
	
	KvRewind(g_BackpackViewers);
	KvJumpToKey(g_BackpackViewers, selection);
	decl String:name[64];
	KvGetString(g_BackpackViewers, "name", name, sizeof(name));
	PrintToChat(client, "\x04[SM] \x01Backpack viewer preference changed to \x04%s\x01.", name);
}

public Action:Command_Backpack(client, args) {
	new target = -1;
	
	if(args > 0) {
		decl String:name[MAX_NAME_LENGTH];
		GetCmdArgString(name, sizeof(name));
		StripQuotes(name);
		TrimString(name);
		
		target = FindTarget(client, name, true, false);
		if(target == -1) {
			return Plugin_Handled;
		}
	} else {
		target = GetClientAimTarget(client);
	}
	
	if(target == -1) {
		ShowNameMenu(client);
	} else {
		ShowBackpack(client, target);
	}
	
	return Plugin_Handled;
}

ShowNameMenu(client) {
	new Handle:menu = CreateMenu(Handler_NameMenu);
	SetMenuTitle(menu, "Choose a player");
	
	decl String:userid[16], String:name[MAX_NAME_LENGTH];
	for(new i = 1; i <= MaxClients; i++) {
		if(!IsClientConnected(i) || !IsClientAuthorized(i) || IsFakeClient(i)) {
			continue;
		}
		
		IntToString(GetClientUserId(i), userid, sizeof(userid));
		GetClientName(i, name, sizeof(name));
		AddMenuItem(menu, userid, name);
	}
	
	DisplayMenu(menu, client, 30);
}

public Handler_NameMenu(Handle:menu, MenuAction:action, client, param) {
	if(action == MenuAction_End) {
		CloseHandle(menu);
	}
	
	if(action != MenuAction_Select) {
		return;
	}
	
	decl String:userid[16];
	GetMenuItem(menu, param, userid, sizeof(userid));
	new target = GetClientOfUserId(StringToInt(userid));
	if(target == 0) {
		PrintToChat(client, "\x04[SM] \x01That player has left the server.");
	} else {
		ShowBackpack(client, target);
	}
}

ShowBackpack(client, target) {
	decl String:viewer[32];
	GetClientCookie(client, g_cookieBackpackPreference, viewer, sizeof(viewer));
	KvRewind(g_BackpackViewers);
	if(strlen(viewer) == 0 || !KvJumpToKey(g_BackpackViewers, viewer)) {
		GetConVarString(g_cvarDefaultPreference, viewer, sizeof(viewer));
		if(StrEqual(viewer, "traderep")) {
			// traderep is gone, so overwrite cvar to backpacktf if someone put the default value in their server.cfg
			strcopy(viewer, sizeof(viewer), "backpacktf");
			SetConVarString(g_cvarDefaultPreference, "backpacktf");
		}
		
		if(!KvJumpToKey(g_BackpackViewers, viewer)) {
			PrintToChat(client, "\x04[SM] \x01The server administrator has not configured the backpack viewer properly so it cannot display \x03%N\x01's backpack.", target);
			return;
		}
	}
	
	decl String:url[1024], String:buffer[MAX_NAME_LENGTH], String:buffer2[MAX_NAME_LENGTH * 3 + 1];
	KvGetString(g_BackpackViewers, "url", url, sizeof(url));
	
	GetClientName(target, buffer, sizeof(buffer));
	UrlEncodeString(buffer2, sizeof(buffer2), buffer);
	ReplaceString(url, sizeof(url), "{NAME}", buffer2);
	
	GetClientAuthId(target, AuthIdType:KvGetNum(g_BackpackViewers, "idtype", 3), buffer, sizeof(buffer));
	UrlEncodeString(buffer2, sizeof(buffer2), buffer);
	ReplaceString(url, sizeof(url), "{ID}", buffer2);
	
	UrlEncodeString(buffer2, sizeof(buffer2), g_ServerIP);
	ReplaceString(url, sizeof(url), "{SERVER_IP}", buffer2);
	
	AdvMOTD_ShowMOTDPanel(client, "Backpack", url, MOTDPANEL_TYPE_URL, true, true, true, OnMOTDFailure);
}

public OnMOTDFailure(client, MOTDFailureReason:reason) {
	switch(reason) {
		case MOTDFailure_Disabled:     PrintToChat(client, "\x04[SM] \x01You must enable HTML MOTDs in Advanced Options to view backpacks.");
		case MOTDFailure_Matchmaking:  PrintToChat(client, "\x04[SM] \x01You cannot view backpacks after joining the server via matchmaking.");
		case MOTDFailure_QueryFailed:  PrintToChat(client, "\x04[SM] \x01Unable to verify that you can view backpacks. Please try again later.");
		default:                     PrintToChat(client, "\x04[SM] \x01An unknown error occurred when trying to display the backpack.");
	}
}

// Stolen from Dynamic MOTD
// loosely based off of PHP's urlencode
UrlEncodeString(String:output[], size, const String:input[])
{
	new icnt = 0;
	new ocnt = 0;
	
	for(;;)
	{
		if (ocnt == size)
		{
			output[ocnt-1] = '\0';
			return;
		}
		
		new c = input[icnt];
		if (c == '\0')
		{
			output[ocnt] = '\0';
			return;
		}
		
		// Use '+' instead of '%20'.
		// Still follows spec and takes up less of our limited buffer.
		if (c == ' ')
		{
			output[ocnt++] = '+';
		}
		else if ((c < '0' && c != '-' && c != '.') ||
			(c < 'A' && c > '9') ||
			(c > 'Z' && c < 'a' && c != '_') ||
			(c > 'z' && c != '~')) 
		{
			output[ocnt++] = '%';
			Format(output[ocnt], size-strlen(output[ocnt]), "%x", c);
			ocnt += 2;
		}
		else
		{
			output[ocnt++] = c;
		}
		
		icnt++;
	}
}