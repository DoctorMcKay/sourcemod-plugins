#pragma semicolon 1

#include <sourcemod>
#include <ccc>
#include <clientprefs>

#define PLUGIN_VERSION	"2.0.0"

public Plugin:myinfo = {
	name        = "[Source 2013] Custom Chat Colors Toggle Module",
	author      = "Dr. McKay, Mini",
	description = "Allows admins to toggle their chat colors",
	version     = PLUGIN_VERSION,
	url         = "http://www.doctormckay.com"
};

new Handle:cookieTag;
new Handle:cookieName;
new Handle:cookieChat;
new Handle:cvarDefaultTag;
new Handle:cvarDefaultName;
new Handle:cvarDefaultChat;

#define UPDATE_FILE		"chatcolorstogglemodule.txt"
#define CONVAR_PREFIX	"custom_chat_colors_toggle"

#include "mckayupdater.sp"

public APLRes:AskPluginLoad2(Handle:myself, bool:late, String:error[], err_max) {
	MarkNativeAsOptional("Updater_AddPlugin"); 
	return APLRes_Success;
}

public OnPluginStart() {
	RegConsoleCmd("sm_togglecolors", Command_ToggleColors, "Toggles your chat colors");
	RegConsoleCmd("sm_tc", Command_ToggleColors, "Toggles your chat colors");
	cvarDefaultTag = CreateConVar("ccc_default_tag", "0", "When a user joins for the first time, should tags be disabled?");
	cvarDefaultName = CreateConVar("ccc_default_name", "0", "When a user joins for the first time, should name colors be disabled?");
	cvarDefaultChat = CreateConVar("ccc_default_chat", "0", "When a user joins for the first time, should chat colors be disabled?");
	
	cookieTag = RegClientCookie("ccc_toggle_tag", "Custom Chat Colors Toggle - Tag", CookieAccess_Private);
	cookieName = RegClientCookie("ccc_toggle_name_color", "Custom Chat Colors Toggle - Name Color", CookieAccess_Private);
	cookieChat = RegClientCookie("ccc_toggle_chat_color", "Custom Chat Colors Toggle - Chat Color", CookieAccess_Private);
	SetCookieMenuItem(CustomChatColorMenu, 0, "Custom Chat Color Settings");
}

public CustomChatColorMenu(client, CookieMenuAction:action, any:info, String:buffer[], maxlen) {
	if (action == CookieMenuAction_SelectOption) {
		ShowMenu(client);
	}
}

bool:GetCookieValue(client, Handle:cookie, Handle:defaultCvar) {
	decl String:value[8];
	GetClientCookie(client, cookie, value, sizeof(value));
	
	if(strlen(value) == 0) {
		return GetConVarBool(defaultCvar);
	} else {
		return bool:StringToInt(value);
	}
}

public MenuHandler_CPrefs(Handle:menu, MenuAction:action, client, param2) {
	if(action == MenuAction_End) {
		CloseHandle(menu);
	}
	
	else if(action == MenuAction_Select) {
		switch(param2) {
			case 0: {
				// tag
				new bool:value = GetCookieValue(client, cookieTag, cvarDefaultTag);
				SetClientCookie(client, cookieTag, value ? "0" : "1");
			}
			case 1: {
				// name
				new bool:value = GetCookieValue(client, cookieName, cvarDefaultName);
				SetClientCookie(client, cookieName, value ? "0" : "1");
			}
			case 2: {
				// chat
				new bool:value = GetCookieValue(client, cookieChat, cvarDefaultChat);
				SetClientCookie(client, cookieChat, value ? "0" : "1");
			}
			case 3: {
				// allow all
				SetClientCookie(client, cookieTag, "0");
				SetClientCookie(client, cookieName, "0");
				SetClientCookie(client, cookieChat, "0");
			}
		}
		
		ShowMenu(client);
	}
}

public Action:Command_ToggleColors(client, args) {
	if(client == 0) {
		ReplyToCommand(client, "[SM] This command can only be used in-game.");
		return Plugin_Handled;
	}
	
	ShowMenu(client);
	return Plugin_Handled;
}

ShowMenu(client) {
	new Handle:menu = CreateMenu(MenuHandler_CPrefs);
	SetMenuTitle(menu, "Choose Your Custom Chat Colors Settings");
	decl String:buffer[64];
	new bool:value, bool:allAllowed = true;
	
	value = GetCookieValue(client, cookieTag, cvarDefaultTag);
	if(value) allAllowed = false;
	Format(buffer, sizeof(buffer), value ? "Hide my Tag (Selected)" : "Hide my Tag");
	AddMenuItem(menu, "tag", buffer);
	
	value = GetCookieValue(client, cookieName, cvarDefaultName);
	if(value) allAllowed = false;
	Format(buffer, sizeof(buffer), value ? "Hide my Name Color (Selected)" : "Hide my Name Color");
	AddMenuItem(menu, "name", buffer);
	
	value = GetCookieValue(client, cookieChat, cvarDefaultChat);
	if(value) allAllowed = false;
	Format(buffer, sizeof(buffer), value ? "Hide my Chat Color (Selected)" : "Hide my Chat Color");
	AddMenuItem(menu, "chat", buffer);
	
	Format(buffer, sizeof(buffer), allAllowed ? "Allow All (Selected)" : "Allow All");
	AddMenuItem(menu, "allowall", buffer, allAllowed ? ITEMDRAW_DISABLED : ITEMDRAW_DEFAULT);
	
	SetMenuExitButton(menu, true);
	DisplayMenu(menu, client, MENU_TIME_FOREVER);
}

public Action:CCC_OnColor(client, const String:message[], CCC_ColorType:type) {
	new Handle:cookie, Handle:cvar;
	
	switch(type) {
		case CCC_TagColor: {
			cookie = cookieTag;
			cvar = cvarDefaultTag;
		}
		case CCC_NameColor: {
			cookie = cookieName;
			cvar = cvarDefaultName;
		}
		case CCC_ChatColor: {
			cookie = cookieChat;
			cvar = cvarDefaultChat;
		}
	}
	
	return GetCookieValue(client, cookie, cvar) ? Plugin_Handled : Plugin_Continue;
}