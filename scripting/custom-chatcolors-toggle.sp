#pragma semicolon 1

#include <sourcemod>
#include <ccc>
#include <clientprefs>

#undef REQUIRE_PLUGIN
#include <updater>

#define UPDATE_URL		"http://hg.doctormckay.com/public-plugins/raw/default/chatcolorstogglemodule.txt"
#define PLUGIN_VERSION	"1.4.4"

public Plugin:myinfo = {
	name        = "[Source 2009] Custom Chat Colors Toggle Module",
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
new Handle:cvarUpdater;

public APLRes:AskPluginLoad2(Handle:myself, bool:late, String:error[], err_max) {
	MarkNativeAsOptional("Updater_AddPlugin"); 
	return APLRes_Success;
}

public OnPluginStart() {
	RegAdminCmd("sm_togglecolors", Command_ToggleColors, 0, "Toggles your chat colors");
	RegAdminCmd("sm_tc", Command_ToggleColors, 0, "Toggles your chat colors");
	cvarUpdater = CreateConVar("ccc_toggle_auto_update", "1", "Enables automatic updating (has no effect if Updater is not installed)");
	cvarDefaultTag = CreateConVar("ccc_default_tag", "0", "When a user joins for the first time, should tags be disabled?");
	cvarDefaultName = CreateConVar("ccc_default_name", "0", "When a user joins for the first time, should name colors be disabled?");
	cvarDefaultChat = CreateConVar("ccc_default_chat", "0", "When a user joins for the first time, should chat colors be disabled?");
	
	cookieTag = RegClientCookie("ccc_toggle_tag", "Custom Chat Colors Toggle - Tag", CookieAccess_Private);
	cookieName = RegClientCookie("ccc_toggle_name_color", "Custom Chat Colors Toggle - Name Color", CookieAccess_Private);
	cookieChat = RegClientCookie("ccc_toggle_chat_color", "Custom Chat Colors Toggle - Chat Color", CookieAccess_Private);
	SetCookieMenuItem(CustomChatColorMenu, 0, "Custom Chat Color Settings");
}

public OnClientCookiesCached(client) {
	decl String:cookie[8];
	GetClientCookie(client, cookieTag, cookie, sizeof(cookie));
	if(StrEqual(cookie, "")) {
		SetClientCookie(client, cookieTag, GetConVarBool(cvarDefaultTag) ? "1" : "0");
	}
	
	GetClientCookie(client, cookieName, cookie, sizeof(cookie));
	if(StrEqual(cookie, "")) {
		SetClientCookie(client, cookieName, GetConVarBool(cvarDefaultName) ? "1" : "0");
	}
	
	GetClientCookie(client, cookieChat, cookie, sizeof(cookie));
	if(StrEqual(cookie, "")) {
		SetClientCookie(client, cookieChat, GetConVarBool(cvarDefaultChat) ? "1" : "0");
	}
}

public CustomChatColorMenu(client, CookieMenuAction:action, any:info, String:buffer[], maxlen) {
	if (action == CookieMenuAction_SelectOption) {
		ShowMenu(client);
	}
}

public MenuHandler_CPrefs(Handle:menu, MenuAction:action, client, param2) {
	if(action == MenuAction_End) {
		CloseHandle(menu);
	}
	else if(action == MenuAction_Select) {
		decl String:cookie[32];
		switch(param2) {
			case 0: {
				// tag
				GetClientCookie(client, cookieTag, cookie, sizeof(cookie));
				SetClientCookie(client, cookieTag, bool:StringToInt(cookie) ? "0" : "1");
			}
			case 1: {
				// name
				GetClientCookie(client, cookieName, cookie, sizeof(cookie));
				SetClientCookie(client, cookieName, bool:StringToInt(cookie) ? "0" : "1");
			}
			case 2: {
				// chat
				GetClientCookie(client, cookieChat, cookie, sizeof(cookie));
				SetClientCookie(client, cookieChat, bool:StringToInt(cookie) ? "0" : "1");
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
	decl String:cookie[8], String:buffer[64];
	new bool:value, bool:allAllowed = true;
	
	GetClientCookie(client, cookieTag, cookie, sizeof(cookie));
	value = bool:StringToInt(cookie);
	if(value) allAllowed = false;
	Format(buffer, sizeof(buffer), value ? "Hide my Tag (Selected)" : "Hide my Tag");
	AddMenuItem(menu, "tag", buffer);
	
	GetClientCookie(client, cookieName, cookie, sizeof(cookie));
	value = bool:StringToInt(cookie);
	if(value) allAllowed = false;
	Format(buffer, sizeof(buffer), value ? "Hide my Name Color (Selected)" : "Hide my Name Color");
	AddMenuItem(menu, "name", buffer);
	
	GetClientCookie(client, cookieChat, cookie, sizeof(cookie));
	value = bool:StringToInt(cookie);
	if(value) allAllowed = false;
	Format(buffer, sizeof(buffer), value ? "Hide my Chat Color (Selected)" : "Hide my Chat Color");
	AddMenuItem(menu, "chat", buffer);
	
	Format(buffer, sizeof(buffer), allAllowed ? "Allow All (Selected)" : "Allow All");
	AddMenuItem(menu, "allowall", buffer, allAllowed ? ITEMDRAW_DISABLED : ITEMDRAW_DEFAULT);
	
	SetMenuExitButton(menu, true);
	DisplayMenu(menu, client, MENU_TIME_FOREVER);
}

public Action:CCC_OnTagApplied(client) {
	decl String:cookie[32];
	GetClientCookie(client, cookieTag, cookie, sizeof(cookie));
	return bool:StringToInt(cookie) ? Plugin_Handled : Plugin_Continue;
}

public Action:CCC_OnNameColor(client) {
	decl String:cookie[32];
	GetClientCookie(client, cookieName, cookie, sizeof(cookie));
	return bool:StringToInt(cookie) ? Plugin_Handled : Plugin_Continue;
}

public Action:CCC_OnChatColor(client) {
	decl String:cookie[32];
	GetClientCookie(client, cookieChat, cookie, sizeof(cookie));
	return bool:StringToInt(cookie) ? Plugin_Handled : Plugin_Continue;
}

/////////////////////////////////

public OnAllPluginsLoaded() {
	if(!LibraryExists("ccc")) {
		SetFailState("Custom Chat Colors is not installed. Please visit https://forums.alliedmods.net/showthread.php?t=186695 and install it.");
	}
	new Handle:convar;
	if(LibraryExists("updater")) {
		Updater_AddPlugin(UPDATE_URL);
		new String:newVersion[10];
		Format(newVersion, sizeof(newVersion), "%sA", PLUGIN_VERSION);
		convar = CreateConVar("custom_chat_colors_toggle_version", newVersion, "Custom Chat Colors Toggle Module Version", FCVAR_DONTRECORD|FCVAR_NOTIFY|FCVAR_CHEAT);
	} else {
		convar = CreateConVar("custom_chat_colors_toggle_version", PLUGIN_VERSION, "Custom Chat Colors Toggle Module Version", FCVAR_DONTRECORD|FCVAR_NOTIFY|FCVAR_CHEAT);	
	}
	HookConVarChange(convar, Callback_VersionConVarChanged);
}

public Callback_VersionConVarChanged(Handle:convar, const String:oldValue[], const String:newValue[]) {
	ResetConVar(convar);
}

public Action:Updater_OnPluginDownloading() {
	if(!GetConVarBool(cvarUpdater)) {
		return Plugin_Handled;
	}
	return Plugin_Continue;
}

public OnLibraryAdded(const String:name[]) {
	if(StrEqual(name, "updater")) {
		Updater_AddPlugin(UPDATE_URL);
	}
}

public Updater_OnPluginUpdated() {
	ReloadPlugin();
}