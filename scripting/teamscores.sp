#pragma semicolon 1

#include <sourcemod>
#include <sdktools>

#undef REQUIRE_PLUGIN
#include <updater>

#define UPDATE_URL    "http://hg.doctormckay.com/public-plugins/raw/default/teamscores.txt"
#define PLUGIN_VERSION "1.3.1"

new Handle:timeCvar = INVALID_HANDLE;
new Handle:team2Cvar = INVALID_HANDLE;
new Handle:team3Cvar = INVALID_HANDLE;
new Handle:updaterCvar = INVALID_HANDLE;

public Plugin:myinfo = {
	name        = "[ANY] Team Scores",
	author      = "Dr. McKay",
	description = "Sets team scores to a specified value at certain times, and on demand",
	version     = PLUGIN_VERSION,
	url         = "http://www.doctormckay.com"
};

public APLRes:AskPluginLoad2(Handle:myself, bool:late, String:error[], err_max) { 
	MarkNativeAsOptional("Updater_AddPlugin"); 
	return APLRes_Success;
} 

public OnPluginStart() {
	RegAdminCmd("sm_setscore", Command_SetScore, ADMFLAG_ROOT, "Usage: sm_setscore <team> <score>");
	timeCvar = CreateConVar("teamscores_time", "1", "0 = never, 1 = on map start, 2 = on round start");
	team2Cvar = CreateConVar("teamscores_team2", "37", "RED or Terrorists");
	team3Cvar = CreateConVar("teamscores_team3", "13", "BLU or Counter-Terrorists");
	updaterCvar = CreateConVar("teamscores_auto_update", "1", "Should automatic updating be enabled? Has no effect if Updater is not installed.");
	HookEventEx("teamplay_round_start", Event_RoundStart);
	HookEventEx("round_start", Event_RoundStart);
}

public OnAllPluginsLoaded() {
	if(LibraryExists("updater")) {
		Updater_AddPlugin(UPDATE_URL);
		new String:newVersion[10];
		Format(newVersion, sizeof(newVersion), "%sA", PLUGIN_VERSION);
		CreateConVar("teamscores_version", newVersion, "Team Scores Version", FCVAR_DONTRECORD|FCVAR_SPONLY|FCVAR_REPLICATED|FCVAR_NOTIFY);
	} else {
		CreateConVar("teamscores_version", PLUGIN_VERSION, "Team Scores Version", FCVAR_DONTRECORD|FCVAR_SPONLY|FCVAR_REPLICATED|FCVAR_NOTIFY);	
	}
}

public OnMapStart() {
	if(GetConVarInt(timeCvar) == 1) {
		SetScores();
	}
}

public Event_RoundStart(Handle:event, const String:name[], bool:dontBroadcast) {
	if(GetConVarInt(timeCvar) == 2) {
		SetScores();
	}
}

SetScores() {
	SetTeamScore(2, GetConVarInt(team2Cvar));
	SetTeamScore(3, GetConVarInt(team3Cvar));
}

public Action:Command_SetScore(client, args) {
	if(args != 2) {
		ReplyToCommand(client, "[SM] Usage: sm_setscore <team> <score>");
		return Plugin_Handled;
	}
	new String:arg1[30];
	new team;
	GetCmdArg(1, arg1, sizeof(arg1));
	if(strcmp(arg1, "2") || strcmp(arg1, "3")) {
		team = StringToInt(arg1);
	} else {
		team = FindTeamByName(arg1);
		if(team != 2 && team != 3) {
			ReplyToCommand(client, "[SM] An invalid team name or index was specified.");
			return Plugin_Handled;
		}
	}
	new String:arg2[30];
	new score;
	GetCmdArg(2, arg2, sizeof(arg2));
	score = StringToInt(arg2);
	SetTeamScore(team, score);
	ReplyToCommand(client, "[SM] The score was set.");
	return Plugin_Handled;
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