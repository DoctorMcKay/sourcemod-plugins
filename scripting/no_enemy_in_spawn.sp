#pragma semicolon 1

#include <sourcemod>
#include <sdkhooks>
#include <sdktools>

#define PLUGIN_VERSION		"1.1.0"

public Plugin:myinfo = {
	name = "[TF2] No Enemies In Spawn",
	author = "Dr. McKay",
	description = "Slays anyone who manages to get into the enemy spawn",
	version = PLUGIN_VERSION,
	url = "http://www.doctormckay.com"
};

new Handle:cvarMessage;

new bool:roundRunning = true;

#define UPDATE_FILE		"no_enemy_in_spawn.txt"
#define CONVAR_PREFIX	"no_enemy_in_spawn"

#include "mckayupdater.sp"

public OnPluginStart() {
	cvarMessage = CreateConVar("no_enemy_in_spawn_message", "You may not enter the enemy team's spawn.", "Message to display when a player is slayed for entering the enemy spawn (blank for none)");
	HookEvent("teamplay_round_start", Event_RoundStart);
	HookEvent("teamplay_round_win", Event_RoundEnd);
	HookEvent("teamplay_round_stalemate", Event_RoundEnd);
}

public OnMapStart() {
	new i = -1;
	while((i = FindEntityByClassname(i, "func_respawnroom")) != -1) {
		SDKHook(i, SDKHook_TouchPost, OnTouchRespawnRoom);
	}
}

public Event_RoundStart(Handle:event, const String:name[], bool:dontBroadcast) {
	roundRunning = true;
}

public Event_RoundEnd(Handle:event, const String:name[], bool:dontBroadcast) {
	roundRunning = false;
}

public OnTouchRespawnRoom(entity, other) {
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