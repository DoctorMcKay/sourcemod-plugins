#pragma semicolon 1

#include <sourcemod>
#include <tf2>
#include <tf2_stocks>

#define PLUGIN_VERSION		"1.2.0"

public Plugin:myinfo = {
	name		= "[TF2] Kartify",
	author		= "Dr. McKay",
	description	= "Put players into karts!",
	version		= PLUGIN_VERSION,
	url			= "http://www.doctormckay.com"
};

new Handle:g_cvarSpawnKart;

new bool:g_KartSpawn[MAXPLAYERS + 1];

#define UPDATE_FILE		"kartify.txt"
#define CONVAR_PREFIX	"kartify"

#include "mckayupdater.sp"

public OnPluginStart() {
	g_cvarSpawnKart = CreateConVar("kartify_spawn", "0", "0 = do nothing, 1 = put all players into karts when they spawn, 2 = put players into karts when they spawn only if sm_kartify was used on them", _, true, 0.0, true, 2.0);
	
	RegAdminCmd("sm_kartify", Command_Kartify, ADMFLAG_SLAY, "Put players into karts!");
	RegAdminCmd("sm_kart", Command_Kartify, ADMFLAG_SLAY, "Put players into karts!");
	RegAdminCmd("sm_unkartify", Command_Unkartify, ADMFLAG_SLAY, "Remove players from karts");
	RegAdminCmd("sm_unkart", Command_Unkartify, ADMFLAG_SLAY, "Remove players from karts");
	RegAdminCmd("sm_kartifyme", Command_KartifyMe, ADMFLAG_SLAY, "Puts you into a kart!");
	RegAdminCmd("sm_kartme", Command_KartifyMe, ADMFLAG_SLAY, "Puts you into a kart!");
	RegAdminCmd("sm_unkartifyme", Command_UnkartifyMe, ADMFLAG_SLAY, "Removes you from a kart");
	RegAdminCmd("sm_unkartme", Command_UnkartifyMe, ADMFLAG_SLAY, "Removes you from a kart");
	
	LoadTranslations("common.phrases");
	
	HookEvent("player_spawn", Event_PlayerSpawn);
}

public OnMapStart() {
	PrecacheModel("models/player/items/taunts/bumpercar/parts/bumpercar.mdl");
	PrecacheModel("models/player/items/taunts/bumpercar/parts/bumpercar_nolights.mdl");
}

public OnClientConnected(client) {
	g_KartSpawn[client] = false;
}

public Action:Command_Kartify(client, args) {
	if(args == 0) {
		ReplyToCommand(client, "\x04[SM] \x01Usage: sm_kartify <name|#userid>");
		return Plugin_Handled;
	}
	
	decl String:argString[MAX_NAME_LENGTH];
	GetCmdArgString(argString, sizeof(argString));
	StripQuotes(argString);
	TrimString(argString);
	
	decl targets[MaxClients], String:target_name[MAX_NAME_LENGTH], bool:tn_is_ml;
	new result = ProcessTargetString(argString, client, targets, MaxClients, COMMAND_FILTER_ALIVE, target_name, sizeof(target_name), tn_is_ml);
	if(result <= 0) {
		ReplyToTargetError(client, result);
		return Plugin_Handled;
	}
	
	if(result == 1 && TF2_IsPlayerInCondition(targets[0], TFCond:82)) {
		// Only one player chosen and they're in a kart
		ShowActivity2(client, "\x04[SM] \x03", "\x01Unkartified \x03%s\x01!", target_name);
		LogAction(client, targets[0], "\"%L\" unkartified \"%L\"", client, targets[0]);
		g_KartSpawn[targets[0]] = false;
		Unkartify(targets[0]);
		return Plugin_Handled;
	}
	
	ShowActivity2(client, "\x04[SM] \x03", "\x01Kartified \x03%s\x01!", target_name);
	for(new i = 0; i < result; i++) {
		LogAction(client, targets[i], "\"%L\" kartified \"%L\"", client, targets[i]);
		g_KartSpawn[targets[i]] = true;
		Kartify(targets[i]);
	}
	
	return Plugin_Handled;
}

public Action:Command_Unkartify(client, args) {
	if(args == 0) {
		ReplyToCommand(client, "\x04[SM] \x01Usage: sm_unkartify <name|#userid>");
		return Plugin_Handled;
	}
	
	decl String:argString[MAX_NAME_LENGTH];
	GetCmdArgString(argString, sizeof(argString));
	StripQuotes(argString);
	TrimString(argString);
	
	decl targets[MaxClients], String:target_name[MAX_NAME_LENGTH], bool:tn_is_ml;
	new result = ProcessTargetString(argString, client, targets, MaxClients, COMMAND_FILTER_ALIVE, target_name, sizeof(target_name), tn_is_ml);
	if(result <= 0) {
		ReplyToTargetError(client, result);
		return Plugin_Handled;
	}
	
	ShowActivity2(client, "\x04[SM] \x03", "\x01Unkartified \x03%s\x01!", target_name);
	for(new i = 0; i < result; i++) {
		LogAction(client, targets[i], "\"%L\" unkartified \"%L\"", client, targets[i]);
		g_KartSpawn[targets[i]] = false;
		Unkartify(targets[i]);
	}
	
	return Plugin_Handled;
}

public Action:Command_KartifyMe(client, args) {
	if(TF2_IsPlayerInCondition(client, TFCond:82)) {
		Command_UnkartifyMe(client, 0);
		return Plugin_Handled;
	}
	
	ShowActivity2(client, "\x04[SM] \x03", "\x01Put self into a kart");
	LogAction(client, client, "\"%L\" put themself into a kart", client);
	g_KartSpawn[client] = true;
	Kartify(client);
	return Plugin_Handled;
}

public Action:Command_UnkartifyMe(client, args) {
	ShowActivity2(client, "\x04[SM] \x03", "\x01Removed self from a kart");
	LogAction(client, client, "\"%L\" removed themself from a kart", client);
	g_KartSpawn[client] = false;
	Unkartify(client);
	return Plugin_Handled;
}

public Event_PlayerSpawn(Handle:event, const String:name[], bool:dontBroadcast) {
	new mode = GetConVarInt(g_cvarSpawnKart);
	if(mode == 0) {
		return;
	}
	
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	if(mode == 1 || (mode == 2 && g_KartSpawn[client])) {
		Kartify(client);
	}
}

Kartify(client) {
	TF2_AddCondition(client, TFCond:82, TFCondDuration_Infinite);
}

Unkartify(client) {
	TF2_RemoveCondition(client, TFCond:82);
}