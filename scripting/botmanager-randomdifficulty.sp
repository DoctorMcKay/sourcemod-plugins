#pragma semicolon 1

#include <sourcemod>
#include <botmanager>

#define PLUGIN_VERSION			"1.0.0"

public Plugin:myinfo = {
	name		= "[TF2] Random Bot Difficulty",
	author		= "Dr. McKay",
	description	= "Randomizes the difficulty of joining bots",
	version		= PLUGIN_VERSION,
	url			= "http://www.doctormckay.com"
};

#define UPDATE_FILE		"botmanager-randomdifficulty.txt"
#define CONVAR_PREFIX	"bot_manager_random_difficulty"

#include "mckayupdater.sp"

public Bot_OnBotAdd(&TFClassType:class, &TFTeam:team, &difficulty, String:name[MAX_NAME_LENGTH]) {
	difficulty = GetRandomInt(0, 3);
}