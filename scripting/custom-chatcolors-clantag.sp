#pragma semicolon 1

#include <sourcemod>
#include <cstrike>
#include <ccc>

#undef REQUIRE_PLUGIN
#include <updater>

#define UPDATE_URL			"http://hg.doctormckay.com/public-plugins/raw/default/chatcolorsclantagmodule.txt"
#define PLUGIN_VERSION		"1.0.1"

public Plugin:myinfo = {
	name        = "[CS] Custom Chat Colors Clan Tag Module",
	author      = "Dr. McKay",
	description = "Automatically gives players a chat tag based on their current clan tag",
	version     = PLUGIN_VERSION,
	url         = "http://www.doctormckay.com"
};

new Handle:cvarUsersOnly;
new Handle:cvarColor;
new Handle:cvarUpdater;

public OnPluginStart() {
	cvarUsersOnly = CreateConVar("ccc_clantag_users_only", "1", "If 1, then only clients who aren't assigned a tag by custom-chatcolors.cfg (or the MySQL module) are given a clan tag");
	cvarColor = CreateConVar("ccc_clantag_color", "G", "The color to give clan tags, in hexadecimal form (RRGGBB or RRGGBBAA). Special colors can be used: G for green, T for team color, O for olive, and blank for default");
	cvarUpdater = CreateConVar("ccc_clantag_auto_update", "1", "Enables automatic updating (has no effect if Updater is not installed)");
}

public CCC_OnUserConfigLoaded(client) {
	CreateTimer(5.0, Timer_SetClanTag, GetClientUserId(client)); // Delay so that the MySQL module can do its thing
}

public Action:Timer_SetClanTag(Handle:timer, any:userid) {
	new client = GetClientOfUserId(userid);
	if(client == 0) {
		return;
	}
	decl String:tag[64];
	if(GetConVarBool(cvarUsersOnly)) {
		CCC_GetTag(client, tag, sizeof(tag));
		if(strlen(tag) > 0) {
			return; // client already has a tag
		}
	}
	CS_GetClientClanTag(client, tag, sizeof(tag));
	if(strlen(tag) == 0) {
		return; // Doesn't have a tag
	}
	decl String:color[16];
	GetConVarString(cvarColor, color, sizeof(color));
	if(StrEqual(color, "G", false)) {
		CCC_SetColor(client, CCC_TagColor, COLOR_GREEN, false);
	} else if(StrEqual(color, "O", false)) {
		CCC_SetColor(client, CCC_TagColor, COLOR_OLIVE, false);
	} else if(StrEqual(color, "T", false)) {
		CCC_SetColor(client, CCC_TagColor, COLOR_TEAM, false);
	} else if(strlen(color) == 6 || strlen(color) == 8) {
		CCC_SetColor(client, CCC_TagColor, StringToInt(color, 16), strlen(color) == 8);
	} else {
		CCC_SetColor(client, CCC_TagColor, COLOR_NONE, false);
	}
	
	StrCat(tag, sizeof(tag), " ");
	CCC_SetTag(client, tag);
}

/////////////////////////////////

public OnAllPluginsLoaded() {
	new Handle:convar;
	if(LibraryExists("updater")) {
		Updater_AddPlugin(UPDATE_URL);
		decl String:version[12];
		Format(version, sizeof(version), "%sA", PLUGIN_VERSION);
		convar = CreateConVar("custom_chat_colors_clantag_version", version, "Custom Chat Colors Clan Tag Module Version", FCVAR_DONTRECORD|FCVAR_NOTIFY|FCVAR_CHEAT);
	} else {
		convar = CreateConVar("custom_chat_colors_clantag_version", PLUGIN_VERSION, "Custom Chat Colors Clan Tag Module Version", FCVAR_DONTRECORD|FCVAR_NOTIFY|FCVAR_CHEAT);	
	}
	HookConVarChange(convar, Callback_VersionConVarChanged);
	Callback_VersionConVarChanged(convar, "", ""); // Check the cvar value
}

public OnLibraryAdded(const String:name[]) {
	if(StrEqual(name, "updater")) {
		Updater_AddPlugin(UPDATE_URL);
	}
}

public Callback_VersionConVarChanged(Handle:convar, const String:oldValue[], const String:newValue[]) {
	if(LibraryExists("updater")) {
		decl String:version[12];
		Format(version, sizeof(version), "%sA", PLUGIN_VERSION);
		SetConVarString(convar, version);
	} else {
		SetConVarString(convar, PLUGIN_VERSION);
	}
}

public Action:Updater_OnPluginDownloading() {
	if(!GetConVarBool(cvarUpdater)) {
		return Plugin_Handled;
	}
	return Plugin_Continue;
}

public Updater_OnPluginUpdated() {
	ReloadPlugin();
}