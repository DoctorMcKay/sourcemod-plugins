#pragma semicolon 1

#include <sourcemod>
#include <steamtools>

#undef REQUIRE_PLUGIN
#include <updater>

#define UPDATE_URL    "http://hg.doctormckay.com/public-plugins/raw/default/game_desc_override.txt"
#define PLUGIN_VERSION "1.1.3"

new Handle:descriptionCvar = INVALID_HANDLE;
new Handle:updaterCvar = INVALID_HANDLE;

public Plugin:myinfo = {
	name        = "[Any] SteamTools Game Description Override",
	author      = "Dr. McKay",
	description = "Overrides the default game description (i.e. \"Team Fortress\") in the server browser using SteamTools",
	version     = PLUGIN_VERSION,
	url         = "http://www.doctormckay.com"
};

public APLRes:AskPluginLoad2(Handle:myself, bool:late, String:error[], err_max) { 
	MarkNativeAsOptional("Updater_AddPlugin"); 
	return APLRes_Success;
} 

public OnPluginStart() {
	descriptionCvar = CreateConVar("st_gamedesc_override", "", "What to override your game description to");
	updaterCvar = CreateConVar("st_gamedesc_override_auto_update", "1", "Enables automatic updating. Has no effect if Updater is not installed.");
	decl String:description[128];
	GetConVarString(descriptionCvar, description, sizeof(description));
	HookConVarChange(descriptionCvar, CvarChanged);
	Steam_SetGameDescription(description);
}

public CvarChanged(Handle:cvar, const String:oldVal[], const String:newVal[]) {
	decl String:description[128];
	GetConVarString(descriptionCvar, description, sizeof(description));
	Steam_SetGameDescription(description);
}

public OnAllPluginsLoaded() {
	new Handle:buffer;
	if(LibraryExists("updater")) {
		Updater_AddPlugin(UPDATE_URL);
		new String:newVersion[10];
		Format(newVersion, sizeof(newVersion), "%sA", PLUGIN_VERSION);
		buffer = CreateConVar("st_gamedesc_override_version", newVersion, "SteamTools Game Description Override Version", FCVAR_DONTRECORD|FCVAR_NOTIFY|FCVAR_CHEAT);
	} else {
		buffer = CreateConVar("st_gamedesc_override_version", PLUGIN_VERSION, "SteamTools Game Description Override Version", FCVAR_DONTRECORD|FCVAR_NOTIFY|FCVAR_CHEAT);
	}
	HookConVarChange(buffer, Callback_VersionConVarChanged);
}

public Callback_VersionConVarChanged(Handle:convar, const String:oldValue[], const String:newValue[]) {
	ResetConVar(convar);
}

public Action:Updater_OnPluginDownloading() {
	if(!GetConVarBool(updaterCvar)) {
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