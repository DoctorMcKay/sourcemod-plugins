#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <steamtools>

#undef REQUIRE_PLUGIN
#include <ccc>
#include <scp>
#include <sourcebans>
#include <updater>

#define UPDATE_URL			"http://hg.doctormckay.com/public-plugins/raw/default/steamrep.txt"
#define PLUGIN_VERSION		"1.1.2"
#define STEAMREP_URL		"http://steamrep.com/id2rep.php"
#define STEAM_API_URL		"http://api.steampowered.com/ISteamUser/GetPlayerBans/v1/"

enum LogLevel {
	Log_Error = 0,
	Log_Info,
	Log_Debug
}

enum TagType {
	TagType_None = 0,
	TagType_Scammer,
	TagType_TradeBanned,
	TagType_TradeProbation
}

public Plugin:myinfo = {
	name        = "[TF2] SteamRep Checker (Redux)",
	author      = "Dr. McKay",
	description = "Checks a user's SteamRep upon connection",
	version     = PLUGIN_VERSION,
	url         = "http://www.doctormckay.com"
};

new Handle:cvarDealMethod;
new Handle:cvarSteamIDBanLength;
new Handle:cvarIPBanLength;
new Handle:cvarKickTaggedScammers;
new Handle:cvarValveBanDealMethod;
new Handle:cvarValveCautionDealMethod;
new Handle:cvarSteamAPIKey;
new Handle:cvarSendIP;
new Handle:cvarExcludedTags;
new Handle:cvarSpawnMessage;
new Handle:cvarLogLevel;
new Handle:cvarUpdater;

new Handle:sv_visiblemaxplayers;

new TagType:clientTag[MAXPLAYERS + 1];
new bool:messageDisplayed[MAXPLAYERS + 1];

public OnPluginStart() {
	cvarDealMethod = CreateConVar("steamrep_checker_deal_method", "2", "How to deal with reported scammers.\n0 = Disabled\n1 = Prefix chat with [SCAMMER] tag and warn users in chat (requires Custom Chat Colors)\n2 = Kick\n3 = Ban Steam ID\n4 = Ban IP\n5 = Ban Steam ID + IP", _, true, 0.0, true, 5.0);
	cvarSteamIDBanLength = CreateConVar("steamrep_checker_steamid_ban_length", "0", "Duration in minutes to ban Steam IDs for if steamrep_checker_deal_method = 3 or 5 (0 = permanent)", _, true, 0.0);
	cvarIPBanLength = CreateConVar("steamrep_checker_ip_ban_length", "0", "Duration in minutes to ban IP addresses for if steamrep_checker_deal_method = 4 or 5 (0 = permanent)");
	cvarKickTaggedScammers = CreateConVar("steamrep_checker_kick_tagged_scammers", "1", "Kick chat-tagged scammers if the server gets full?", _, true, 0.0, true, 1.0);
	cvarValveBanDealMethod = CreateConVar("steamrep_checker_valve_ban_deal_method", "2", "How to deal with Valve trade-banned players (requires API key to be set)\n0 = Disabled\n1 = Prefix chat with [TRADE BANNED] tag and warn users in chat (requires Custom Chat Colors)\n2 = Kick\n3 = Ban Steam ID\n4 = Ban IP\n5 = Ban Steam ID + IP", _, true, 0.0, true, 5.0);
	cvarValveCautionDealMethod = CreateConVar("steamrep_checker_valve_probation_deal_method", "1", "How to deal with Valve trade-probation players (requires API key to be set)\n0 = Disabled\n1 = Prefix chat with [TRADE PROBATION] tag and warn users in chat (requires Custom Chat Colors)\n2 = Kick\n3 = Ban Steam ID\n4 = Ban IP\n5 = Ban Steam ID + IP", _, true, 0.0, true, 5.0);
	cvarSteamAPIKey = CreateConVar("steamrep_checker_steam_api_key", "", "API key obtained from http://steamcommunity.com/dev (only required for Valve trade-ban or trade-probation detection", FCVAR_PROTECTED);
	cvarSendIP = CreateConVar("steamrep_checker_send_ip", "0", "Send IP addresses of connecting players to SteamRep?", _, true, 0.0, true, 1.0);
	cvarExcludedTags = CreateConVar("steamrep_checker_untrusted_tags", "", "Input the tags of any community whose bans you do not trust here.");
	cvarSpawnMessage = CreateConVar("steamrep_checker_spawn_message", "1", "Display messages upon first spawn that this server is protected by SteamRep?", _, true, 0.0, true, 1.0);
	cvarLogLevel = CreateConVar("steamrep_checker_log_level", "1", "Level of logging\n0 = Errors only\n1 = Info + errors\n2 = Info, errors, and debug", _, true, 0.0, true, 2.0);
	cvarUpdater = CreateConVar("steamrep_checker_auto_update", "1", "Enables automatic updating (has no effect if Updater is not installed)");
	HookConVarChange(cvarUpdater, Callback_VersionConVarChanged); // For purposes of removing the "A" if updater is disabled
	AutoExecConfig();
	
	sv_visiblemaxplayers = FindConVar("sv_visiblemaxplayers");
	
	HookEvent("player_spawn", Event_PlayerSpawn);
	HookEvent("player_changename", Event_PlayerChangeName);
	
	RegConsoleCmd("sm_rep", Command_Rep, "Checks a user's SteamRep");
	RegConsoleCmd("sm_sr", Command_Rep, "Checks a user's SteamRep");
}

public OnClientConnected(client) {
	clientTag[client] = TagType_None;
}

public OnClientPostAdminCheck(client) {
	PerformKicks();
	if(IsFakeClient(client) || CheckCommandAccess(client, "SkipSR", ADMFLAG_ROOT)) {
		return;
	}
	decl String:auth[32];
	GetClientAuthString(client, auth, sizeof(auth));
	new String:excludedTags[64], String:ip[64];
	GetConVarString(cvarExcludedTags, excludedTags, sizeof(excludedTags));
	if(GetConVarBool(cvarSendIP)) {
		GetClientIP(client, ip, sizeof(ip));
	}
	new HTTPRequestHandle:request = Steam_CreateHTTPRequest(HTTPMethod_GET, STEAMREP_URL);
	Steam_SetHTTPRequestGetOrPostParameter(request, "steamID32", auth);
	Steam_SetHTTPRequestGetOrPostParameter(request, "ignore", excludedTags);
	Steam_SetHTTPRequestGetOrPostParameter(request, "IP", ip);
	Steam_SendHTTPRequest(request, OnSteamRepChecked, GetClientUserId(client));
	LogItem(Log_Debug, "Sending HTTP request for %L", client);
}

PerformKicks() {
	if(GetClientCount(false) >= (GetConVarInt(sv_visiblemaxplayers) - 1) && GetConVarBool(cvarKickTaggedScammers)) {
		if(GetConVarInt(cvarDealMethod) == 1) {
			for(new i = 1; i <= MaxClients; i++) {
				if(IsClientInGame(i) && clientTag[i] == TagType_Scammer) {
					KickClient(i, "You were kicked to free a slot because you are a reported scammer");
					return;
				}
			}
		}
		if(GetConVarInt(cvarValveBanDealMethod) == 1) {
			for(new i = 1; i <= MaxClients; i++) {
				if(IsClientInGame(i) && clientTag[i] == TagType_TradeBanned) {
					KickClient(i, "You were kicked to free a slot because you are trade banned");
					return;
				}
			}
		}
		if(GetConVarInt(cvarValveCautionDealMethod) == 1) {
			for(new i = 1; i <= MaxClients; i++) {
				if(IsClientInGame(i) && clientTag[i] == TagType_TradeProbation) {
					KickClient(i, "You were kicked to free a slot because you are on trade probation");
					return;
				}
			}
		}
	}
}

public OnSteamRepChecked(HTTPRequestHandle:request, bool:successful, HTTPStatusCode:code, any:userid) {
	new client = GetClientOfUserId(userid);
	if(client == 0) {
		LogItem(Log_Debug, "Client with User ID %d left.", userid);
		Steam_ReleaseHTTPRequest(request);
		return;
	}
	if(!successful || code != HTTPStatusCode_OK) {
		LogItem(Log_Error, "Error checking SteamRep for client %L. Status code: %d, Successful: %s", client, _:code, successful ? "true" : "false");
		Steam_ReleaseHTTPRequest(request);
		return;
	}
	decl String:data[128];
	Steam_GetHTTPResponseBodyData(request, data, sizeof(data));
	Steam_ReleaseHTTPRequest(request);
	LogItem(Log_Debug, "Received rep for %L: '%s'", client, data);
	decl String:exploded[3][35];
	ExplodeString(data, "&", exploded, sizeof(exploded), sizeof(exploded[]));
	if(StrContains(exploded[1], "SCAMMER", false) != -1) {
		LogItem(Log_Debug, "%L is a scammer, handling", client);
		HandleScammer(client, exploded[2]);
	} else {
		decl String:apiKey[64];
		GetConVarString(cvarSteamAPIKey, apiKey, sizeof(apiKey));
		if(strlen(apiKey) != 0) {
			LogItem(Log_Debug, "%L is not a SR scammer, checking Steam...", client);
			decl String:steamid[64];
			Steam_GetCSteamIDForClient(client, steamid, sizeof(steamid));
			request = Steam_CreateHTTPRequest(HTTPMethod_GET, STEAM_API_URL);
			Steam_SetHTTPRequestGetOrPostParameter(request, "key", apiKey);
			Steam_SetHTTPRequestGetOrPostParameter(request, "steamids", steamid);
			Steam_SetHTTPRequestGetOrPostParameter(request, "format", "vdf");
			Steam_SendHTTPRequest(request, OnSteamAPI, userid);
		}
	}
}

HandleScammer(client, const String:auth[]) {
	decl String:clientAuth[32];
	GetClientAuthString(client, clientAuth, sizeof(clientAuth));
	if(!StrEqual(auth, clientAuth)) {
		LogItem(Log_Error, "Steam ID for %L (%s) didn't match SteamRep's response (%s)", client, clientAuth, auth);
		return;
	}
	switch(GetConVarInt(cvarDealMethod)) {
		case 0: {
			// Disabled
		}
		case 1: {
			// Chat tag
			if(!LibraryExists("scp")) {
				LogItem(Log_Info, "Simple Chat Processor (Redux) is not loaded, so tags will not be colored in chat.", client);
				return;
			}
			LogItem(Log_Info, "Tagged %L as a scammer", client);
			SetClientTag(client, TagType_Scammer);
		}
		case 2: {
			// Kick
			LogItem(Log_Info, "Kicked %L as a scammer", client);
			KickClient(client, "You are a reported scammer. Visit http://www.steamrep.com for more information");
		}
		case 3: {
			// Ban Steam ID
			LogItem(Log_Info, "Banned %L by Steam ID as a scammer", client);
			if(LibraryExists("sourcebans")) {
				SBBanPlayer(0, client, GetConVarInt(cvarSteamIDBanLength), "Player is a reported scammer via SteamRep.com");
			} else {
				BanClient(client, GetConVarInt(cvarSteamIDBanLength), BANFLAG_AUTHID, "Player is a reported scammer via SteamRep.com", "You are a reported scammer. Visit http://www.steamrep.com for more information", "steamrep_checker");
			}
		}
		case 4: {
			// Ban IP
			LogItem(Log_Info, "Banned %L by IP as a scammer", client);
			if(LibraryExists("sourcebans")) {
				// SourceBans doesn't currently expose a native to ban an IP!
				decl String:ip[64];
				GetClientIP(client, ip, sizeof(ip));
				ServerCommand("sm_banip \"%s\" %d A scammer has connected from this IP. Steam ID: %s", ip, GetConVarInt(cvarIPBanLength), clientAuth);
			} else {
				decl String:banMessage[256];
				Format(banMessage, sizeof(banMessage), "A scammer has connected from this IP. Steam ID: %s", clientAuth);
				BanClient(client, GetConVarInt(cvarIPBanLength), BANFLAG_IP, banMessage, "You are a reported scammer. Visit http://www.steamrep.com for more information", "steamrep_checker");
			}
		}
		case 5: {
			// Ban Steam ID + IP
			LogItem(Log_Info, "Banned %L by Steam ID and IP as a scammer", client);
			if(LibraryExists("sourcebans")) {
				decl String:ip[64];
				GetClientIP(client, ip, sizeof(ip));
				SBBanPlayer(0, client, GetConVarInt(cvarSteamIDBanLength), "Player is a reported scammer via SteamRep.com");
				ServerCommand("sm_banip \"%s\" %d A scammer has connected from this IP. Steam ID: %s", ip, GetConVarInt(cvarIPBanLength), clientAuth);
			} else {
				BanClient(client, GetConVarInt(cvarSteamIDBanLength), BANFLAG_AUTHID, "Player is a reported scammer via SteamRep.com", "You are a reported scammer. Visit http://www.steamrep.com for more information", "steamrep_checker");
				BanClient(client, GetConVarInt(cvarIPBanLength), BANFLAG_IP, "Player is a reported scammer via SteamRep.com", "You are a reported scammer. Visit http://www.steamrep.com for more information", "steamrep_checker");
			}
		}
	}
}

public OnSteamAPI(HTTPRequestHandle:request, bool:successful, HTTPStatusCode:code, any:userid) {
	new client = GetClientOfUserId(userid);
	if(client == 0) {
		LogItem(Log_Debug, "Client with User ID %d left when checking Valve status.", userid);
		Steam_ReleaseHTTPRequest(request);
		return;
	}
	if(!successful || code != HTTPStatusCode_OK) {
		LogItem(Log_Error, "Error checking Steam for client %L. Status code: %d, Successful: %s", client, _:code, successful ? "true" : "false");
		Steam_ReleaseHTTPRequest(request);
		return;
	}
	decl String:path[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, path, sizeof(path), "data/steamrep_checker.txt");
	Steam_WriteHTTPResponseBody(request, path);
	Steam_ReleaseHTTPRequest(request);
	new Handle:kv = CreateKeyValues("response");
	if(!FileToKeyValues(kv, path)) {
		LogItem(Log_Error, "Steam returned invalid KeyValues for %L.", client);
		CloseHandle(kv);
		return;
	}
	KvJumpToKey(kv, "players");
	KvJumpToKey(kv, "0");
	decl String:banStatus[64];
	KvGetString(kv, "EconomyBan", banStatus, sizeof(banStatus));
	CloseHandle(kv);
	if(StrEqual(banStatus, "banned")) {
		LogItem(Log_Debug, "%L is trade-banned, handling...", client);
		HandleValvePlayer(client, true);
	} else if(StrEqual(banStatus, "probation")) {
		LogItem(Log_Debug, "%L is on trade probation, handling...", client);
		HandleValvePlayer(client, false);
	} else {
		LogItem(Log_Debug, "Steam reports that %L is OK", client);
	}
}

HandleValvePlayer(client, bool:banned) {
	decl String:clientAuth[32];
	GetClientAuthString(client, clientAuth, sizeof(clientAuth));
	switch((banned) ? GetConVarInt(cvarValveBanDealMethod) : GetConVarInt(cvarValveCautionDealMethod)) {
		case 0: {
			// Disabled
		}
		case 1: {
			// Chat tag
			if(!LibraryExists("scp")) {
				LogItem(Log_Info, "Simple Chat Processor (Redux) is not loaded, so tags will not be colored in chat.", client);
				return;
			}
			LogItem(Log_Info, "Tagged %L as %s", client, banned ? "trade banned" : "trade probation");
			SetClientTag(client, banned ? TagType_TradeBanned : TagType_TradeProbation);
		}
		case 2: {
			// Kick
			LogItem(Log_Info, "Kicked %L as %s", client, banned ? "trade banned" : "trade probation");
			KickClient(client, "You are %s", banned ? "trade banned" : "on trade probation");
		}
		case 3: {
			// Ban Steam ID
			LogItem(Log_Info, "Banned %L by Steam ID as %s", client, banned ? "trade banned" : "trade probation");
			if(LibraryExists("sourcebans")) {
				decl String:message[256];
				Format(message, sizeof(message), "Player is %s", banned ? "trade banned" : "on trade probation");
				SBBanPlayer(0, client, GetConVarInt(cvarSteamIDBanLength), message);
			} else {
				decl String:message[256], String:kickMessage[256];
				Format(message, sizeof(message), "Player is %s", banned ? "trade banned" : "on trade probation");
				Format(kickMessage, sizeof(kickMessage), "You are %s", banned ? "trade banned" : "on trade probation");
				BanClient(client, GetConVarInt(cvarSteamIDBanLength), BANFLAG_AUTHID, message, kickMessage, "steamrep_checker");
			}
		}
		case 4: {
			// Ban IP
			LogItem(Log_Info, "Banned %L by IP as %s", client, banned ? "trade banned" : "trade probation");
			if(LibraryExists("sourcebans")) {
				// SourceBans doesn't currently expose a native to ban an IP!
				ServerCommand("sm_banip #%d %d A %s has connected from this IP. Steam ID: %s", banned ? "trade banned player" : "player on trade probation", GetClientUserId(client), GetConVarInt(cvarIPBanLength), clientAuth);
			} else {
				decl String:message[256], String:kickMessage[256];
				Format(message, sizeof(message), "A %s has connected from this IP. Steam ID: %s", banned ? "trade banned player" : "player on trade probation", clientAuth);
				Format(kickMessage, sizeof(kickMessage), "You are %s", banned ? "trade banned" : "on trade probation");
				BanClient(client, GetConVarInt(cvarIPBanLength), BANFLAG_IP, message, kickMessage, "steamrep_checker");
			}
		}
		case 5: {
			// Ban Steam ID + IP
			LogItem(Log_Info, "Banned %L by Steam ID and IP as %s", client, banned ? "trade banned" : "trade probation");
			if(LibraryExists("sourcebans")) {
				decl String:message[256];
				Format(message, sizeof(message), "Player is %s", banned ? "trade banned" : "on trade probation");
				SBBanPlayer(0, client, GetConVarInt(cvarSteamIDBanLength), message);
				ServerCommand("sm_banip #%d %d A %s has connected from this IP. Steam ID: %s", banned ? "trade banned player" : "player on trade probation", GetClientUserId(client), GetConVarInt(cvarIPBanLength), clientAuth);
			} else {
				decl String:message[256], String:kickMessage[256];
				Format(message, sizeof(message), "A %s has connected from this IP. Steam ID: %s", banned ? "trade banned player" : "player on trade probation", clientAuth);
				Format(kickMessage, sizeof(kickMessage), "You are %s", banned ? "trade banned" : "on trade probation");
				BanClient(client, GetConVarInt(cvarSteamIDBanLength), BANFLAG_AUTHID, message, kickMessage, "steamrep_checker");
				BanClient(client, GetConVarInt(cvarIPBanLength), BANFLAG_IP, message, kickMessage, "steamrep_checker");
			}
		}
	}
}

SetClientTag(client, TagType:type) {
	decl String:name[MAX_NAME_LENGTH];
	switch(type) {
		case TagType_Scammer: {
			PrintToChatAll("\x07FF0000WARNING: \x03%N \x01is a reported scammer at SteamRep.com", client);
			Format(name, sizeof(name), "[SCAMMER] %N", client);
			SetClientInfo(client, "name", name);
		}
		case TagType_TradeBanned: {
			PrintToChatAll("\x07FF0000WARNING: \x03%N \x01is trade banned", client); 
			Format(name, sizeof(name), "[TRADE BANNED] %N", client);
			SetClientInfo(client, "name", name);
		}
		case TagType_TradeProbation: {
			PrintToChatAll("\x07FF7F00CAUTION: \x03%N \x01is on trade probation", client);
			Format(name, sizeof(name), "[TRADE PROBATION] %N", client);
			SetClientInfo(client, "name", name);
		}
	}
	clientTag[client] = type;
}

public Action:OnChatMessage(&author, Handle:recipients, String:name[], String:message[]) {
	switch(clientTag[author]) {
		case TagType_None: return Plugin_Continue;
		case TagType_Scammer: ReplaceString(name, MAXLENGTH_NAME, "[SCAMMER]", "\x07FF0000[SCAMMER]\x03");
		case TagType_TradeBanned: ReplaceString(name, MAXLENGTH_NAME, "[TRADE BANNED]", "\x07FF0000[TRADE BANNED]\x03");
		case TagType_TradeProbation: ReplaceString(name, MAXLENGTH_NAME, "[TRADE PROBATION]", "\x07FF7F00[TRADE PROBATION]\x03");
	}
	return Plugin_Changed;
}

public Action:CCC_OnTagApplied(client) {
	if(clientTag[client] != TagType_None) {
		return Plugin_Handled;
	}
	return Plugin_Continue;
}

public Event_PlayerSpawn(Handle:event, const String:name[], bool:dontBroadcast) {
	if(!GetConVarBool(cvarSpawnMessage)) {
		return;
	}
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	if(GetClientTeam(client) < 2 || messageDisplayed[client]) {
		return;
	}
	PrintToChat(client, "\x04[SR] \x01This server is protected by \x04SteamRep\x01. Visit \x04SteamRep.com\x01 for more information.");
	messageDisplayed[client] = true;
}

public Event_PlayerChangeName(Handle:event, const String:name[], bool:dontBroadcast) {
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	if(clientTag[client] == TagType_None) {
		return;
	}
	decl String:clientName[MAX_NAME_LENGTH];
	GetEventString(event, "newname", clientName, sizeof(clientName));
	if(clientTag[client] == TagType_Scammer && StrContains(clientName, "[SCAMMER]") != 0) {
		KickClient(client, "Kicked from server\n\nDo not attempt to remove the [SCAMMER] tag");
	} else if(clientTag[client] == TagType_TradeBanned && StrContains(clientName, "[TRADE BANNED]") != 0) {
		KickClient(client, "Kicked from server\n\nDo not attempt to remove the [TRADE BANNED] tag");
	} else if(clientTag[client] == TagType_TradeProbation && StrContains(clientName, "[TRADE PROBATION]") != 0) {
		KickClient(client, "Kicked from server\n\nDo not attempt to remove the [TRADE PROBATION] tag");
	}
}

public Action:Command_Rep(client, args) {
	new target;
	if(args == 0) {
		target = GetClientAimTarget(client);
		if(target <= 0) {
			DisplayClientMenu(client);
			return Plugin_Handled;
		}
	} else {
		decl String:arg1[MAX_NAME_LENGTH];
		GetCmdArg(1, arg1, sizeof(arg1));
		target = FindTargetEx(client, arg1, true, false, false);
		if(target == -1) {
			DisplayClientMenu(client);
			return Plugin_Handled;
		}
	}
	decl String:steamID[64];
	Steam_GetCSteamIDForClient(target, steamID, sizeof(steamID));
	decl String:url[256];
	Format(url, sizeof(url), "http://steamrep.com/profiles/%s", steamID);
	new Handle:Kv = CreateKeyValues("data");
	KvSetString(Kv, "title", "");
	KvSetString(Kv, "type", "2");
	KvSetString(Kv, "msg", url);
	KvSetNum(Kv, "customsvr", 1);
	ShowVGUIPanel(client, "info", Kv);
	CloseHandle(Kv);
	return Plugin_Handled;
}

DisplayClientMenu(client) {
	new Handle:menu = CreateMenu(Handler_ClientMenu);
	SetMenuTitle(menu, "Select Player");
	decl String:name[MAX_NAME_LENGTH], String:index[8];
	for(new i = 1; i <= MaxClients; i++) {
		if(!IsClientInGame(i) || IsFakeClient(i)) {
			continue;
		}
		GetClientName(i, name, sizeof(name));
		IntToString(GetClientUserId(i), index, sizeof(index));
		AddMenuItem(menu, index, name);
	}
	DisplayMenu(menu, client, 0);
}

public Handler_ClientMenu(Handle:menu, MenuAction:action, client, param) {
	if(action == MenuAction_End) {
		CloseHandle(menu);
	}
	if(action != MenuAction_Select) {
		return;
	}
	decl String:selection[32];
	GetMenuItem(menu, param, selection, sizeof(selection));
	FakeClientCommand(client, "sm_rep #%s", selection);
}

FindTargetEx(client, const String:target[], bool:nobots = false, bool:immunity = true, bool:replyToError = true) {
	decl String:target_name[MAX_TARGET_LENGTH];
	decl target_list[1], target_count, bool:tn_is_ml;
	
	new flags = COMMAND_FILTER_NO_MULTI;
	if(nobots) {
		flags |= COMMAND_FILTER_NO_BOTS;
	}
	if(!immunity) {
		flags |= COMMAND_FILTER_NO_IMMUNITY;
	}
	
	if((target_count = ProcessTargetString(
			target,
			client, 
			target_list, 
			1, 
			flags,
			target_name,
			sizeof(target_name),
			tn_is_ml)) > 0)
	{
		return target_list[0];
	} else {
		if(replyToError) {
			ReplyToTargetError(client, target_count);
		}
		return -1;
	}
}

LogItem(LogLevel:level, const String:format[], any:...) {
	new logLevel = GetConVarInt(cvarLogLevel);
	if(logLevel < _:level) {
		return;
	}
	new String:logPrefixes[][] = {"[ERROR]", "[INFO]", "[DEBUG]"};
	decl String:buffer[512], String:file[PLATFORM_MAX_PATH];
	VFormat(buffer, sizeof(buffer), format, 3);
	BuildPath(Path_SM, file, sizeof(file), "logs/steamrep_checker.log");
	LogToFileEx(file, "%s %s", logPrefixes[_:level], buffer);
}

/////////////////////////////////

public OnAllPluginsLoaded() {
	new Handle:convar;
	if(LibraryExists("updater")) {
		Updater_AddPlugin(UPDATE_URL);
		decl String:newVersion[12];
		Format(newVersion, sizeof(newVersion), "%sA", PLUGIN_VERSION);
		convar = CreateConVar("steamrep_checker_version", newVersion, "SteamRep Checker (Redux) Version", FCVAR_DONTRECORD|FCVAR_NOTIFY|FCVAR_CHEAT);
	} else {
		convar = CreateConVar("steamrep_checker_version", PLUGIN_VERSION, "SteamRep Checker (Redux) Version", FCVAR_DONTRECORD|FCVAR_NOTIFY|FCVAR_CHEAT);	
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
	if(LibraryExists("updater") && GetConVarBool(cvarUpdater)) {
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