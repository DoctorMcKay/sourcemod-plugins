#pragma semicolon 1

#include <sourcemod>

#undef REQUIRE_PLUGIN
#tryinclude <updater>

#define UPDATE_URL    "http://hg.doctormckay.com/public-plugins/raw/default/votekick_switcher.txt"
#define PLUGIN_VERSION "1.2.2"

new Handle:votekickCvar;
new Handle:votekickMvMCvar;
new Handle:updaterCvar;

public Plugin:myinfo = {
	name        = "[TF2] Votekick Switcher",
	author      = "Dr. McKay",
	description = "Disables TF2's built-in votekick when there are admins present",
	version     = PLUGIN_VERSION,
	url         = "http://www.doctormckay.com"
};

public APLRes:AskPluginLoad2(Handle:myself, bool:late, String:error[], err_max) {
	MarkNativeAsOptional("Updater_AddPlugin");
	
	votekickCvar = FindConVar("sv_vote_issue_kick_allowed");
	votekickMvMCvar = FindConVar("sv_vote_issue_kick_allowed_mvm");
	
	if(votekickCvar == INVALID_HANDLE) {
		strcopy(error, err_max, "sv_vote_issue_kick_allowed cvar not found");
		return APLRes_Failure;
	}
	
	if(votekickMvMCvar == INVALID_HANDLE) {
		strcopy(error, err_max, "sv_vote_issue_kick_allowed_mvm cvar not found");
		return APLRes_Failure;
	}
	
	return APLRes_Success;
} 

public OnPluginStart() {
	updaterCvar = CreateConVar("votekick_switcher_auto_update", "1", "Allow Votekick Switcher to update itself? Has no effect if Updater is not installed.");
	if(!GetConVarBool(FindConVar("sv_allow_votes"))) {
		LogError("WARNING: sv_allow_votes is set to 0, so no players will be able to call votes regardless of sv_vote_issue_kick_allowed!");
	}
}

public OnMapStart() {
	CheckAdmins();
}

public OnClientPostAdminCheck(client) {
	if(CheckCommandAccess(client, "sm_kick", ADMFLAG_KICK)) {
		SetConVarBool(votekickCvar, false);
		SetConVarBool(votekickMvMCvar, false);
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
	SetConVarBool(votekickCvar, newState);
	SetConVarBool(votekickMvMCvar, newState);
}

/////////////////////////////////

public OnAllPluginsLoaded() {
	new Handle:convar;
	if(LibraryExists("updater")) {
		Updater_AddPlugin(UPDATE_URL);
		decl String:newVersion[10];
		Format(newVersion, sizeof(newVersion), "%sA", PLUGIN_VERSION);
		convar = CreateConVar("votekick_switcher_version", newVersion, "Votekick Switcher Version", FCVAR_DONTRECORD|FCVAR_NOTIFY|FCVAR_CHEAT);
	} else {
		convar = CreateConVar("votekick_switcher_version", PLUGIN_VERSION, "Votekick Switcher Version", FCVAR_DONTRECORD|FCVAR_NOTIFY|FCVAR_CHEAT);
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