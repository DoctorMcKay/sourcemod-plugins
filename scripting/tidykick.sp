#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <connect>

#undef REQUIRE_PLUGIN
#include <updater>

#define UPDATE_URL			"http://public-plugins.doctormckay.com/latest/tidykick.txt"
#define PLUGIN_VERSION		"1.1.4"

public Plugin:myinfo = {
	name        = "[ANY] Tidy Kick",
	author      = "Dr. McKay",
	description = "Allows kick messages that aren't prefixed with Disconnect:",
	version     = PLUGIN_VERSION,
	url         = "http://www.doctormckay.com"
};

new Handle:trie;
new bool:kicked[MAXPLAYERS + 1];
new Handle:updaterCvar = INVALID_HANDLE;

public APLRes:AskPluginLoad2(Handle:myself, bool:late, String:error[], err_max) {
	CreateNative("TidyKickClient", Native_TidyKick);
	MarkNativeAsOptional("Updater_AddPlugin");
	return APLRes_Success;
}

public OnPluginStart() {
	updaterCvar = CreateConVar("tidykick_auto_update", "1", "Enables automatic updating (has no effect if Updater is not installed)");
	trie = CreateTrie();
	RegAdminCmd("sm_tidykick", Command_Kick, ADMFLAG_KICK, "Tidy kicks a client");
	HookEvent("player_disconnect", Event_Disconnect, EventHookMode_Pre);
	LoadTranslations("common.phrases");
}

public OnClientConnected(client) {
	kicked[client] = false;
}

public Action:Command_Kick(client, args) {
	if(args < 1) {
		ReplyToCommand(client, "[SM] Usage: sm_tidykick <client> [reason]");
		return Plugin_Handled;
	}
	decl String:argString[512];
	GetCmdArgString(argString, sizeof(argString));
	decl String:target[MAX_NAME_LENGTH];
	new pos = BreakString(argString, target, sizeof(target));
	new tgt = FindTarget(client, target, true);
	if(tgt == -1) {
		return Plugin_Handled;
	}
	if(pos == -1) {
		decl String:reason[255];
		Format(reason, sizeof(reason), "%T", "Kicked by admin", tgt);
		DoKick(tgt, reason);
	} else {
		DoKick(tgt, argString[pos]);
	}
	return Plugin_Handled;
}

DoKick(target, const String:reason[255]) {
	decl String:auth[32];
	GetClientAuthString(target, auth, sizeof(auth));
	SetTrieString(trie, auth, reason);
	kicked[target] = true;
	CreateTimer(5.0, Timer_FallbackKick, GetClientUserId(target));
	ClientCommand(target, "retry");
}

public Action:Timer_FallbackKick(Handle:timer, any:userid) {
	new client = GetClientOfUserId(userid);
	if(client != 0) {
		decl String:auth[32], String:reason[255];
		GetClientAuthString(client, auth, sizeof(auth));
		if(GetTrieString(trie, auth, reason, sizeof(reason))) {
			KickClient(client, reason);
			RemoveFromTrie(trie, auth);
		}
	}
}

public bool:OnClientPreConnect(const String:name[], String:password[255], const String:ip[], const String:steamID[], String:rejectReason[255]) {
	decl String:reason[255];
	if(!GetTrieString(trie, steamID, reason, sizeof(reason))) {
		return true;
	}
	StrCat(reason, sizeof(reason), ".");
	strcopy(rejectReason, sizeof(rejectReason), reason);
	RemoveFromTrie(trie, steamID);
	return false;
}

public Native_TidyKick(Handle:plugin, numParams) {
	// client, format, ...
	new client = GetNativeCell(1);
	if(client < 1 || client > MaxClients || !IsClientInGame(client)) {
		ThrowNativeError(1, "Client index %i is invalid or not in game", client);
		return;
	}
	decl String:reason[255];
	new written;
	FormatNativeString(0, 2, 3, sizeof(reason), written, reason);
	DoKick(client, reason);
}

public Action:Event_Disconnect(Handle:event, const String:eventName[], bool:dontBroadcast) {
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	if(kicked[client]) {
		decl String:auth[32];
		GetClientAuthString(client, auth, sizeof(auth));
		decl String:reason[255];
		GetTrieString(trie, auth, reason, sizeof(reason));
		SetEventString(event, "reason", reason);
		kicked[client] = false;
	}
}

/////////////////////////////////

public OnAllPluginsLoaded() {
	new Handle:convar;
	if(LibraryExists("updater")) {
		Updater_AddPlugin(UPDATE_URL);
		new String:newVersion[10];
		Format(newVersion, sizeof(newVersion), "%sA", PLUGIN_VERSION);
		convar = CreateConVar("tidykick_version", newVersion, "Tidy Kick Version", FCVAR_DONTRECORD|FCVAR_NOTIFY|FCVAR_CHEAT);
	} else {
		convar = CreateConVar("tidykick_version", PLUGIN_VERSION, "Tidy Kick Version", FCVAR_DONTRECORD|FCVAR_NOTIFY|FCVAR_CHEAT);	
	}
	HookConVarChange(convar, Callback_VersionConVarChanged);
}

public Callback_VersionConVarChanged(Handle:convar, const String:oldValue[], const String:newValue[]) {
	decl String:defaultValue[32];
	GetConVarDefault(convar, defaultValue, sizeof(defaultValue));
	if(!StrEqual(newValue, defaultValue)) {
		SetConVarString(convar, defaultValue);
	}
}

public Action:Updater_OnPluginDownloading() {
	if(!GetConVarBool(updaterCvar)) {
		return Plugin_Handled;
	}
	return Plugin_Continue;
}