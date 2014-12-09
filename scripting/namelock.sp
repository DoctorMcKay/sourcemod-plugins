#pragma semicolon 1

#include <sourcemod>

#define PLUGIN_VERSION		"1.0.0"

public Plugin:myinfo = {
	name		= "[TF2] Name Lock",
	author		= "Dr. McKay",
	description	= "Prevents name changes from certain players",
	version		= PLUGIN_VERSION,
	url			= "http://www.doctormckay.com"
};

#define UPDATE_FILE		"namelock.txt"
#define CONVAR_PREFIX	"name_lock"

#include "mckayupdater.sp"

public OnPluginStart() {
	RegAdminCmd("sm_namelock", Command_NameLock, ADMFLAG_BAN, "Prevents certain players from changing their name");
	LoadTranslations("common.phrases");
}

public Action:Command_NameLock(client, args) {
	if(args != 2) {
		ReplyToCommand(client, "\x04[SM] \x01Usage: sm_namelock <target> <1|0>");
		return Plugin_Handled;
	}
	
	decl String:arg1[MAX_NAME_LENGTH], String:arg2[2];
	GetCmdArg(1, arg1, sizeof(arg1));
	GetCmdArg(2, arg2, sizeof(arg2));
	
	new bool:lock = bool:StringToInt(arg2);
	new targets[MaxClients], String:target_name[MAX_NAME_LENGTH], bool:tn_is_ml;
	new numTargets = ProcessTargetString(arg1, client, targets, MaxClients, COMMAND_FILTER_NO_BOTS, target_name, sizeof(target_name), tn_is_ml);
	if(numTargets <= 0) {
		ReplyToTargetError(client, numTargets);
		return Plugin_Handled;
	}
	
	for(new i = 0; i < numTargets; i++) {
		LogAction(client, targets[i], "\"%L\" %s name changes for \"%L\"", client, lock ? "locked" : "unlocked", targets[i]);
		DoNameLock(targets[i], lock);
	}
	
	ShowActivity2(client, "\x04[SM] \x03", "\x01%s name changes for \x03%s\x01.", lock ? "Locked" : "Unlocked", target_name);
	return Plugin_Handled;
}

DoNameLock(client, bool:lock) {
	ServerCommand("namelockid %d %d", GetClientUserId(client), lock ? 1 : 0);
}