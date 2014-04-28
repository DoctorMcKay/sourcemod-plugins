#pragma semicolon 1

#include <sourcemod>

#define PLUGIN_VERSION		"1.3.0"

new Handle:cvarVotekick;
new Handle:cvarVotekickMvM;

public Plugin:myinfo = {
	name        = "[TF2/CS:GO] Votekick Switcher",
	author      = "Dr. McKay",
	description = "Disables the built-in votekick when there are admins present",
	version     = PLUGIN_VERSION,
	url         = "http://www.doctormckay.com"
};

#define UPDATE_FILE		"votekick_switcher.txt"
#define CONVAR_PREFIX	"votekick_switcher"
#define RELOAD_ON_UPDATE

#include "mckayupdater.sp"

public APLRes:AskPluginLoad2(Handle:myself, bool:late, String:error[], err_max) {
	MarkNativeAsOptional("Updater_AddPlugin");
	
	cvarVotekick = FindConVar("sv_vote_issue_kick_allowed");
	cvarVotekickMvM = FindConVar("sv_vote_issue_kick_allowed_mvm");
	
	if(cvarVotekick == INVALID_HANDLE) {
		strcopy(error, err_max, "sv_vote_issue_kick_allowed cvar not found");
		return APLRes_Failure;
	}
	
	return APLRes_Success;
} 

public OnPluginStart() {
	new Handle:sv_allow_votes = FindConVar("sv_allow_votes");
	if(sv_allow_votes != INVALID_HANDLE && !GetConVarBool(sv_allow_votes)) {
		LogError("WARNING: sv_allow_votes is set to 0, so no players will be able to call votes regardless of sv_vote_issue_kick_allowed!");
	}
}

public OnMapStart() {
	CheckAdmins();
}

public OnClientPostAdminCheck(client) {
	if(CheckCommandAccess(client, "sm_kick", ADMFLAG_KICK)) {
		SetConVarBool(cvarVotekick, false);
		
		if(cvarVotekickMvM != INVALID_HANDLE) {
			SetConVarBool(cvarVotekickMvM, false);
		}
	}
}

public OnClientDisconnect(client) {
	CheckAdmins();
}

CheckAdmins() {
	new bool:newState = true;
	for(new i = 1; i <= MaxClients; i++) {
		if(IsClientInGame(i) && CheckCommandAccess(i, "sm_kick", ADMFLAG_KICK)) {
			newState = false;
			break;
		}
	}
	SetConVarBool(cvarVotekick, newState);
	
	if(cvarVotekickMvM != INVALID_HANDLE) {
		SetConVarBool(cvarVotekickMvM, newState);
	}
}