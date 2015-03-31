#pragma semicolon 1

#include <sourcemod>
#include <sdktools>

#define PLUGIN_VERSION		"1.1.0"

public Plugin myinfo = {
	name		= "[TF2] Name Change Oddities Fix",
	author		= "Dr. McKay",
	description	= "Deletes self",
	version		= PLUGIN_VERSION,
	url			= "http://www.doctormckay.com"
};

#define UPDATE_FILE		"namechange_fix.txt"
#define CONVAR_PREFIX	"namechange_fix"

#include "mckayupdater.sp"

#pragma newdecls required

public void OnPluginStart() {
	char path[PLATFORM_MAX_PATH];
	char filename[PLATFORM_MAX_PATH];
	GetPluginFilename(null, filename, sizeof(filename));
	BuildPath(Path_SM, path, sizeof(path), "plugins/%s", filename);
	
	DeleteFile(path);
	ServerCommand("sm plugins unload \"%s\"", filename);
}