#pragma semicolon 1

#include <sourcemod>

#define PLUGIN_VERSION "1.5.0"

new impersonateClient[MAXPLAYERS + 1];

public Plugin:myinfo = {
	name        = "[ANY] Impersonate",
	author      = "Dr. McKay",
	description = "Allows an admin to impersonate another player",
	version     = PLUGIN_VERSION,
	url         = "http://www.doctormckay.com"
};

public OnPluginStart() {
	RegAdminCmd("sm_impersonate", Command_Impersonate, ADMFLAG_BAN, "Usage: sm_impersonate [target]");
	AddCommandListener(Command_Say, "say");
	AddCommandListener(Command_SayTeam, "say_team");
	LoadTranslations("common.phrases");
	CreateConVar("impersonate_version", PLUGIN_VERSION, "Impersonate Version", FCVAR_DONTRECORD|FCVAR_NOTIFY|FCVAR_CHEAT);
}

public OnClientPutInServer(client) {
	impersonateClient[client] = 0;
}

public OnClientDisconnect_Post(client) {
	impersonateClient[client] = 0;
}

public Action:Command_Impersonate(client, args) {
	if(impersonateClient[client] != 0) {
		ShowActivity2(client, "\x04[\x03SM\x04] \x05", "\x01No longer impersonating \x05%N", impersonateClient[client]);
		LogAction(client, impersonateClient[client], "%L stopped impersonating %L", client, impersonateClient[client]);
		impersonateClient[client] = 0;
		return Plugin_Handled;
	}
	if(args != 1) {
		ReplyToCommand(client, "[SM] Usage: sm_impersonate [target]");
		return Plugin_Handled;
	}
	decl target, String:argString[MAX_NAME_LENGTH];
	GetCmdArg(1, argString, sizeof(argString));
	target = FindTarget(client, argString);
	if(target == -1) {
		return Plugin_Handled;
	}
	if(target == client) {
		ReplyToCommand(client, "[SM] You cannot impersonate yourself!");
		return Plugin_Handled;
	}
	if(impersonateClient[target] != 0) {
		ReplyToCommand(client, "\x04[\x03SM\x04] \x01%N is impersonating someone; you cannot impersonate them at this time", target);
		return Plugin_Handled;
	}
	impersonateClient[client] = target;
	LogAction(client, impersonateClient[client], "%L began impersonating %L", client, impersonateClient[client]);
	ShowActivity2(client, "\x04[\x03SM\x04] \x05", "\x01Now impersonating \x05%N", impersonateClient[client]);
	return Plugin_Handled;
}

public Action:Command_Say(client, const String:command[], argc) {
	if(impersonateClient[client] == 0) {
		return Plugin_Continue;
	}
	if(!IsClientInGame(impersonateClient[client])) {
		impersonateClient[client] = 0;
		return Plugin_Continue;
	}
	decl String:buffer[255];
	GetCmdArgString(buffer, sizeof(buffer));
	if(IsChatTrigger()) {
		return Plugin_Continue;
	}
	LogAction(client, impersonateClient[client], "%L said a message as %L - %s", client, impersonateClient[client], buffer);
	ShowActivity2(client, "\x04[\x03SM\x04] \x05", "\x01Said a message as \x05%N \x01using Impersonate", impersonateClient[client]);
	FakeClientCommandEx(impersonateClient[client], "say %s", buffer);
	return Plugin_Handled;
}

public Action:Command_SayTeam(client, const String:command[], argc) {
	if(impersonateClient[client] == 0) {
		return Plugin_Continue;
	}
	if(!IsClientInGame(impersonateClient[client])) {
		impersonateClient[client] = 0;
		return Plugin_Continue;
	}
	decl String:buffer[255];
	GetCmdArgString(buffer, sizeof(buffer));
	if(IsChatTrigger()) {
		return Plugin_Continue;
	}
	LogAction(client, impersonateClient[client], "%L said a message as %L - %s", client, impersonateClient[client], buffer);
	ShowActivity2(client, "\x04[\x03SM\x04] \x05", "\x01Said a message as \x05%N \x01using Impersonate", impersonateClient[client]);
	FakeClientCommandEx(impersonateClient[client], "say_team %s", buffer);
	return Plugin_Handled;
}