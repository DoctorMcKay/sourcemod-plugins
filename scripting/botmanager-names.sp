#pragma semicolon 1

#include <sourcemod>
#include <botmanager>

#define PLUGIN_VERSION			"1.0.0"

public Plugin:myinfo = {
	name		= "[TF2] Bot Names",
	author		= "Dr. McKay",
	description	= "Randomly assigns a name from a predetermined list to joining bots",
	version		= PLUGIN_VERSION,
	url			= "http://www.doctormckay.com"
};

#define UPDATE_FILE		"botmanager-names.txt"
#define CONVAR_PREFIX	"bot_manager_names"

#include "mckayupdater.sp"

new Handle:names;

public APLRes:AskPluginLoad2(Handle:myself, bool:late, String:error[], err_max) {
	decl String:path[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, path, sizeof(path), "configs/botnames.ini");
	new Handle:file = OpenFile(path, "r");
	if(file == INVALID_HANDLE) {
		strcopy(error, err_max, "Unable to open configs/botnames.ini");
		return APLRes_Failure;
	}
	
	names = CreateArray(MAX_NAME_LENGTH);
	decl String:name[MAX_NAME_LENGTH];
	while(ReadFileLine(file, name, sizeof(name))) {
		new pos = StrContains(name, ";");
		if(pos != -1) {
			strcopy(name, pos + 1, name);
		}
		
		TrimString(name);
		if(strlen(name) == 0) {
			continue;
		}
		
		PushArrayString(names, name);
	}
	CloseHandle(file);
	
	if(GetArraySize(names) == 0) {
		strcopy(error, err_max, "No names were found in configs/botnames.ini");
		return APLRes_Failure;
	}
	
	return APLRes_Success;
}

public Bot_OnBotAdd(&TFClassType:class, &TFTeam:team, &difficulty, String:name[MAX_NAME_LENGTH]) {
	new iterations = 0;
	do {
		GetArrayString(names, GetRandomInt(0, GetArraySize(names) - 1), name, sizeof(name));
		iterations++;
		if(iterations >= MaxClients) {
			LogError("Unable to find a name that isn't already taken in the server. You might want to add more names to botnames.ini.");
			name[0] = '\0';
			return;
		}
	} while(PlayerIsInGame(name));
}

bool:PlayerIsInGame(const String:name[]) {
	decl String:buffer[MAX_NAME_LENGTH];
	for(new i = 1; i <= MaxClients; i++) {
		if(!IsClientInGame(i)) {
			continue;
		}
		GetClientName(i, buffer, sizeof(buffer));
		if(StrEqual(name, buffer)) {
			return true;
		}
	}
	return false;
}