#pragma semicolon 1

#include <sourcemod>

#undef REQUIRE_PLUGIN
#include <updater>

#define UPDATE_URL			"http://hg.doctormckay.com/public-plugins/raw/default/humiliationglow.txt"
#define PLUGIN_VERSION		"1.1.2"

public Plugin:myinfo = {
    name = "[TF2] Humiliation Glow",
    author = "Dr. McKay",
    description = "Makes the losing team glow during humiliation",
    version = PLUGIN_VERSION,
    url = "http://www.doctormckay.com"
}

new Handle:updaterCvar;

public APLRes:AskPluginLoad2(Handle:myself, bool:late, String:error[], err_max) {
	MarkNativeAsOptional("Updater_AddPlugin"); 
	return APLRes_Success;
} 

public OnPluginStart() {
	HookEvent("teamplay_round_start", Event_RoundStart);
	HookEvent("teamplay_round_win", Event_RoundWin);
	updaterCvar = CreateConVar("humiliation_glow_auto_update", "1", "Enables automatic updating (has no effect if Updater is not installed)");
}

public Event_RoundStart(Handle:event, const String:name[], bool:dontBroadcast) {
	for(new i = 1; i <= MaxClients; i++) {
		if(IsClientInGame(i)) {
			SetEntProp(i, Prop_Send, "m_bGlowEnabled", 0, 1);
		}
	}
}

public Event_RoundWin(Handle:event, const String:name[], bool:dontBroadcast) {
	new winners = GetEventInt(event, "team");
	new losers;
	if(winners == 2) {
		losers = 3;
	} else {
		losers = 2;
	}
	for(new i = 1; i <= MaxClients; i++) {
		if(IsClientInGame(i) && IsPlayerAlive(i) && GetClientTeam(i) == losers) {
			SetEntProp(i, Prop_Send, "m_bGlowEnabled", 1, 1);
		}
	}
}

/////////////////////////////////

public OnAllPluginsLoaded() {
	new Handle:convar;
	if(LibraryExists("updater")) {
		Updater_AddPlugin(UPDATE_URL);
		new String:newVersion[10];
		Format(newVersion, sizeof(newVersion), "%sA", PLUGIN_VERSION);
		convar = CreateConVar("humiliation_glow_version", newVersion, "Humiliation Glow Version", FCVAR_DONTRECORD|FCVAR_NOTIFY|FCVAR_CHEAT);
	} else {
		convar = CreateConVar("humiliation_glow_version", PLUGIN_VERSION, "Humiliation Glow Version", FCVAR_DONTRECORD|FCVAR_NOTIFY|FCVAR_CHEAT);
	}
	HookConVarChange(convar, Callback_VersionConVarChanged);
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