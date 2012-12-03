#pragma semicolon 1

#include <sourcemod>
#include <sdkhooks>
#include <sdktools>

#undef REQUIRE_PLUGIN
#include <updater>

#define UPDATE_URL			"http://hg.doctormckay.com/public-plugins/raw/default/no_enemy_in_spawn.txt"
#define PLUGIN_VERSION		"1.0.0"

public Plugin:myinfo = {
	name = "[TF2] No Enemies In Spawn",
	author = "Dr. McKay",
	description = "Slays anyone who manages to get into the enemy spawn",
	version = PLUGIN_VERSION,
	url = "http://www.doctormckay.com"
};

new Handle:cvarMessage;
new Handle:cvarUpdater;

new bool:roundRunning = true;

public OnPluginStart() {
	cvarMessage = CreateConVar("no_enemy_in_spawn_message", "You may not enter the enemy team's spawn", "Message to display when a player is slayed for entering the enemy spawn (blank for none)");
	cvarUpdater = CreateConVar("no_enemy_in_spawn_auto_update", "1", "Enables automatic updating (has no effect if Updater is not installed)");
	HookEvent("teamplay_round_start", Event_RoundStart);
	HookEvent("teamplay_round_win", Event_RoundEnd);
	HookEvent("teamplay_round_stalemate", Event_RoundEnd);
}

public OnMapStart() {
	new i = -1;
	while((i = FindEntityByClassname(i, "func_respawnroom")) != -1) {
		SDKHook(i, SDKHook_StartTouchPost, OnStartTouchRespawnRoom);
	}
}

public Event_RoundStart(Handle:event, const String:name[], bool:dontBroadcast) {
	roundRunning = true;
}

public Event_RoundEnd(Handle:event, const String:name[], bool:dontBroadcast) {
	roundRunning = false;
}

public OnStartTouchRespawnRoom(entity, other) {
	if(other < 1 || other > MaxClients || !IsPlayerAlive(other) || !roundRunning) {
		return;
	}
	if(GetEntProp(entity, Prop_Send, "m_iTeamNum") != GetClientTeam(other) && !CheckCommandAccess(other, "sm_admin", ADMFLAG_GENERIC)) {
		ForcePlayerSuicide(other);
		decl String:message[512];
		GetConVarString(cvarMessage, message, sizeof(message));
		if(!StrEqual(message, "")) {
			PrintCenterText(other, message);
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
		convar = CreateConVar("no_enemy_in_spawn_version", newVersion, "No Enemy In Spawn Version", FCVAR_DONTRECORD|FCVAR_NOTIFY|FCVAR_CHEAT);
	} else {
		convar = CreateConVar("no_enemy_in_spawn_version", PLUGIN_VERSION, "No Enemy In Spawn Version", FCVAR_DONTRECORD|FCVAR_NOTIFY|FCVAR_CHEAT);	
	}
	HookConVarChange(convar, Callback_VersionConVarChanged);
}

public OnLibraryAdded(const String:name[]) {
	if(StrEqual(name, "updater")) {
		Updater_AddPlugin(UPDATE_URL);
	}
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

public Updater_OnPluginUpdated() {
	ReloadPlugin();
}