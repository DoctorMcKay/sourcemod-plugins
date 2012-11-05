#pragma semicolon 1

#include <sourcemod>

#undef REQUIRE_PLUGIN
#include <updater>

#define UPDATE_URL    "http://public-plugins.doctormckay.com/latest/anyteleporter.txt"
#define PLUGIN_VERSION "1.2.0"

public Plugin:myinfo = 
{
	name = "[TF2] AnyTeleporter",
	author = "Dr. McKay",
	description = "Toggles whether anybody can use anybody's teleporter",
	version = PLUGIN_VERSION,
	url = "http://www.doctormckay.com"
}

new Handle:defaultStateCvar;
new bool:currentState = true;

public OnPluginStart() {
	CreateConVar("anyteleporter_version", PLUGIN_VERSION, "AnyTeleporter version", FCVAR_DONTRECORD);
	defaultStateCvar = CreateConVar("anyteleporter_default", "1", "AnyTeleporter default state (0 = no team restrictions)");
	RegAdminCmd("sm_anyteleporter", Command_AnyTeleporter, ADMFLAG_BAN, "Toggles the ability for teleporters to be used by everyone");
}

public OnMapStart() {
	currentState = GetConVarBool(defaultStateCvar);
}

public Action:Command_AnyTeleporter(client, args) {
	if(args != 0) {
		ReplyToCommand(client, "[SM] Usage: sm_anyteleporter");
		return Plugin_Handled;
	}
	if(currentState) {
		currentState = false;
		ShowActivity2(client, "[SM] ", "Disabled teleporter team-restrictions");
		LogAction(client, -1, "%L disabled teleporter restrictions", client);
	} else {
		currentState = true;
		ShowActivity2(client, "[SM] ", "Enabled teleporter team-restrictions");
		LogAction(client, -1, "%L enabled teleporter restrictions", client);
	}
	return Plugin_Handled;
}

public Action:TF2_OnPlayerTeleport(client, teleporter, &bool:result) {
	if(currentState) {
		return Plugin_Continue;
	} else {
		result = true;
		return Plugin_Changed;
	}
}