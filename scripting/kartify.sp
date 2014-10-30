#pragma semicolon 1

#include <sourcemod>
#include <tf2>

#define PLUGIN_VERSION		"1.0.0"

public Plugin:myinfo = {
	name		= "[TF2] Kartify",
	author		= "Dr. McKay",
	description	= "Put players into karts!",
	version		= PLUGIN_VERSION,
	url			= "http://www.doctormckay.com"
};

public OnPluginStart() {
	RegAdminCmd("sm_kartify", Command_Kartify, ADMFLAG_SLAY, "Put players into karts!");
	RegAdminCmd("sm_kart", Command_Kartify, ADMFLAG_SLAY, "Put players into karts!");
	RegAdminCmd("sm_unkartify", Command_Unkartify, ADMFLAG_SLAY, "Remove players from karts");
	RegAdminCmd("sm_unkart", Command_Unkartify, ADMFLAG_SLAY, "Remove players from karts");
	
	LoadTranslations("common.phrases");
}

public Action:Command_Kartify(client, args) {
	if(args == 0) {
		ReplyToCommand(client, "\x04[SM] \x01Usage: sm_kartify <name|#userid>");
		return Plugin_Handled;
	}
	
	decl String:argString[MAX_NAME_LENGTH];
	GetCmdArgString(argString, sizeof(argString));
	
	decl targets[MaxClients], String:target_name[MAX_NAME_LENGTH], bool:tn_is_ml;
	new result = ProcessTargetString(argString, client, targets, MaxClients, COMMAND_FILTER_ALIVE, target_name, sizeof(target_name), tn_is_ml);
	if(result <= 0) {
		ReplyToTargetError(client, result);
		return Plugin_Handled;
	}
	
	ShowActivity2(client, "\x04[SM] \x03", "\x01Kartified \x03%s\x01!", target_name);
	for(new i = 0; i < result; i++) {
		LogAction(client, targets[i], "\"%L\" kartified \"%L\"", client, targets[i]);
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
	
	decl targets[MaxClients], String:target_name[MAX_NAME_LENGTH], bool:tn_is_ml;
	new result = ProcessTargetString(argString, client, targets, MaxClients, COMMAND_FILTER_ALIVE, target_name, sizeof(target_name), tn_is_ml);
	if(result <= 0) {
		ReplyToTargetError(client, result);
		return Plugin_Handled;
	}
	
	ShowActivity2(client, "\x04[SM] \x03", "\x01Unkartified \x03%s\x01!", target_name);
	for(new i = 0; i < result; i++) {
		LogAction(client, targets[i], "\"%L\" unkartified \"%L\"", client, targets[i]);
		Unkartify(targets[i]);
	}
	
	return Plugin_Handled;
}

Kartify(client) {
	TF2_AddCondition(client, TFCond:82, 9999999.9);
	SetEntProp(client, Prop_Send, "m_iKartState", 1);
}

Unkartify(client) {
	TF2_RemoveCondition(client, TFCond:82);
	SetEntProp(client, Prop_Send, "m_iKartState", 0);
}