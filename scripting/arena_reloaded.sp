#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <tf2>
#include <dhooks>

#define PLUGIN_VERSION		"1.0.0"

public Plugin:myinfo = {
	name		= "[TF2] Arena: Reloaded",
	author		= "Dr. McKay",
	description	= "Capturing the point in arena maps respawns the entire capping team",
	version		= PLUGIN_VERSION,
	url			= "http://www.doctormckay.com"
};

new Handle:g_SetWinningTeam;
new Handle:g_ChangeLevel;

new Handle:g_cvarMarkForDeathTimeout;

new bool:g_BlockNextIntermission;

new Handle:g_UnmarkForDeathTimer[MAXPLAYERS + 1];

#define UPDATE_FILE		"arena_reloaded.txt"
#define CONVAR_PREFIX	"arena_reloaded"

#include "mckayupdater.sp"

public OnPluginStart() {
	g_cvarMarkForDeathTimeout = CreateConVar("arena_reloaded_mark_for_death_fade", "2.0", "Time, in seconds, it takes for the marked-for-death status to fade after stepping off the point. -1 to disable mark for death entirely.", FCVAR_NOTIFY, true, -1.0, true, 30.0);
	
	HookEvent("controlpoint_starttouch", Event_StartTouchCP);
	HookEvent("controlpoint_endtouch", Event_EndTouchCP);
	HookEvent("teamplay_point_captured", Event_PointCaptured);
	
	new Handle:conf = LoadGameConfigFile("arena-reloaded.games");
	if(conf == INVALID_HANDLE) {
		SetFailState("Gamedata file is missing or corrupt");
	}
	
	new offset = GameConfGetOffset(conf, "SetWinningTeam");
	g_SetWinningTeam = DHookCreate(offset, HookType_GameRules, ReturnType_Void, ThisPointer_Ignore, OnSetWinningTeam);
	DHookAddParam(g_SetWinningTeam, HookParamType_Int);
	DHookAddParam(g_SetWinningTeam, HookParamType_Int);
	DHookAddParam(g_SetWinningTeam, HookParamType_Bool);
	DHookAddParam(g_SetWinningTeam, HookParamType_Bool);
	DHookAddParam(g_SetWinningTeam, HookParamType_Bool);
	
	// Blocking SetWinningTeam causes GoToIntermission to be called, ending the map. We need to block that too.
	offset = GameConfGetOffset(conf, "GoToIntermission");
	g_ChangeLevel = DHookCreate(offset, HookType_GameRules, ReturnType_Void, ThisPointer_Ignore, OnGoToIntermission);
	CloseHandle(conf);
	
	// Blocking SetWinningTeam also causes a HUD message of "<Team> Wins the Game!", so let's block that as well.
	HookUserMessage(GetUserMessageId("HudMsg"), OnHudText, true);
}

public OnMapStart() {
	if(g_SetWinningTeam == INVALID_HANDLE) {
		SetFailState("Unable to hook SetWinningTeam");
	}
	
	decl String:map[32];
	GetCurrentMap(map, sizeof(map));
	if(StrContains(map, "arena_") != 0) {
		SetFailState("Arena: Reloaded can only run on arena maps");
	}
	
	DHookGamerules(g_SetWinningTeam, false);
	DHookGamerules(g_ChangeLevel, false);
	
	g_BlockNextIntermission = false;
}

public MRESReturn:OnSetWinningTeam(Handle:params) {
	if(DHookGetParam(params, 2) == 1) {
		return MRES_Supercede; // Win due to point capture
	}
	
	return MRES_Ignored;
}

public MRESReturn:OnGoToIntermission(Handle:params) {
	if(g_BlockNextIntermission) {
		return MRES_Supercede;
	}
	
	return MRES_Ignored;
}

public Event_StartTouchCP(Handle:event, const String:name[], bool:dontBroadcast) {
	if(GetConVarFloat(g_cvarMarkForDeathTimeout) >= 0.0) {
		new client = GetEventInt(event, "player");
		ClearHandle(g_UnmarkForDeathTimer[client]);
		TF2_AddCondition(client, TFCond_MarkedForDeathSilent, 9999999.9);
	}
}

public Event_EndTouchCP(Handle:event, const String:name[], bool:dontBroadcast) {
	new client = GetEventInt(event, "player");
	ClearHandle(g_UnmarkForDeathTimer[client]);
	if(IsClientInGame(client)) {
		g_UnmarkForDeathTimer[client] = CreateTimer(GetConVarFloat(g_cvarMarkForDeathTimeout), Timer_UnmarkForDeath, GetClientUserId(client));
	}
}

public Action:Timer_UnmarkForDeath(Handle:timer, any:userid) {
	new client = GetClientOfUserId(userid);
	TF2_RemoveCondition(client, TFCond_MarkedForDeathSilent);
	g_UnmarkForDeathTimer[client] = INVALID_HANDLE;
}

public Event_PointCaptured(Handle:event, const String:name[], bool:dontBroadcast) {
	new team = GetEventInt(event, "team");
	for(new i = 1; i <= MaxClients; i++) {
		if(IsClientInGame(i) && !IsPlayerAlive(i) && GetClientTeam(i) == team) {
			TF2_RespawnPlayer(i);
		}
	}
	
	PrintToChatAll("Team %s has been respawned.", (team == 2) ? "RED" : "BLU");
}

public Action:OnHudText(UserMsg:msg_id, Handle:msg, const players[], playersNum, bool:reliable, bool:init) {
	BfReadByte(msg);
	BfReadFloat(msg);
	BfReadFloat(msg);
	BfReadByte(msg);
	BfReadByte(msg);
	BfReadByte(msg);
	BfReadByte(msg);
	BfReadByte(msg);
	BfReadByte(msg);
	BfReadByte(msg);
	BfReadByte(msg);
	BfReadByte(msg);
	BfReadFloat(msg);
	BfReadFloat(msg);
	BfReadFloat(msg);
	BfReadFloat(msg);
	// Holy crap this message has a lot of parameters
	
	decl String:message[64];
	BfReadString(msg, message, sizeof(message));
	if(StrEqual(message, "Red Wins the Game!") || StrEqual(message, "Blue Wins the Game!")) {
		g_BlockNextIntermission = true;
		return Plugin_Handled;
	}
	
	return Plugin_Continue;
}

ClearHandle(&Handle:handle) {
	if(handle == INVALID_HANDLE) {
		return;
	}
	
	CloseHandle(handle);
	handle = INVALID_HANDLE;
}