#pragma semicolon 1

#include <sourcemod>

#undef REQUIRE_PLUGIN
#include <updater>

#define UPDATE_URL    "http://hg.doctormckay.com/public-plugins/raw/default/anyteleporter.txt"
#define PLUGIN_VERSION "1.3.0"

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

/////////////////////////////////

public OnAllPluginsLoaded() {
	new Handle:convar;
	if(LibraryExists("updater")) {
		Updater_AddPlugin(UPDATE_URL);
		new String:newVersion[10];
		Format(newVersion, sizeof(newVersion), "%sA", PLUGIN_VERSION);
		convar = CreateConVar("anyteleporter_version", newVersion, "AnyTeleporter Version", FCVAR_DONTRECORD|FCVAR_NOTIFY|FCVAR_CHEAT);
	} else {
		convar = CreateConVar("anyteleporter_version", PLUGIN_VERSION, "AnyTeleporter Version", FCVAR_DONTRECORD|FCVAR_NOTIFY|FCVAR_CHEAT);	
	}
	HookConVarChange(convar, Callback_VersionConVarChanged);
}

public Callback_VersionConVarChanged(Handle:convar, const String:oldValue[], const String:newValue[]) {
	ResetConVar(convar);
}

public OnLibraryAdded(const String:name[]) {
	if(StrEqual(name, "updater")) {
		Updater_AddPlugin(UPDATE_URL);
	}
}

public Updater_OnPluginUpdated() {
	ReloadPlugin();
}