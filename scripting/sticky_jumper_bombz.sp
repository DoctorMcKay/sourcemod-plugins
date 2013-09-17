#pragma semicolon 1

#include <sourcemod>
#include <tf2items>

#define PLUGIN_VERSION			"1.0.1"
#define WEAPON_JUMPER			265
#define ATTRIBUTE_ADD_BOMBS		88
#define ATTRIBUTE_MINUS_BOMBS	89

public Plugin:myinfo = {
	name		= "[TF2] Sticky Jumper Bombz",
	author		= "Dr. McKay",
	description	= "Allows you to customize the number of sticky jumper bombs that can be out",
	version		= PLUGIN_VERSION,
	url			= "http://www.doctormckay.com"
};

new Handle:cvarMaxBombz;
new Handle:newItem;

#define UPDATE_FILE		"sticky_jumper_bombz.txt"
#define CONVAR_PREFIX	"sticky_jumper"

#include "mckayupdater.sp"

public OnPluginStart() {
	cvarMaxBombz = CreateConVar("sticky_jumper_max_bombs", "2", "Maximum number of bombs that a player can lay out at once", _, true, 1.0, true, 10.0);
	HookConVarChange(cvarMaxBombz, OnConVarChanged);
}

public OnConVarChanged(Handle:convar, const String:oldValue[], const String:newValue[]) {
	OnConfigsExecuted();
}

public OnConfigsExecuted() {
	if(newItem != INVALID_HANDLE) {
		CloseHandle(newItem);
	}
	
	newItem = TF2Items_CreateItem(OVERRIDE_ATTRIBUTES);
	
	new Float:diff = GetConVarFloat(cvarMaxBombz) - 8.0;
	if(diff <= 0.0) {
		TF2Items_SetAttribute(newItem, 0, ATTRIBUTE_MINUS_BOMBS, diff);
		TF2Items_SetNumAttributes(newItem, 1);
	} else {
		TF2Items_SetAttribute(newItem, 0, ATTRIBUTE_ADD_BOMBS, diff);
		TF2Items_SetAttribute(newItem, 1, ATTRIBUTE_MINUS_BOMBS, 0.0);
		TF2Items_SetNumAttributes(newItem, 2);
	}
}

public Action:TF2Items_OnGiveNamedItem(client, String:classname[], defindex, &Handle:item) {
	if(defindex == WEAPON_JUMPER) {
		item = newItem;
		return Plugin_Changed;
	}
	
	return Plugin_Continue;
}