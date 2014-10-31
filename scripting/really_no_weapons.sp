#pragma semicolon 1

#include <sourcemod>
#include <tf2>
#include <tf2_stocks>

#define PLUGIN_VERSION		"1.0.0"

public Plugin:myinfo = {
	name		= "[TF2] Really, no weapons",
	author		= "Dr. McKay",
	description	= "Disables sentries during Merasmus' no-weapons curse",
	version		= PLUGIN_VERSION,
	url			= "http://www.doctormckay.com"
};

#define UPDATE_FILE		"really_no_weapons.txt"
#define CONVAR_PREFIX	"really_no_weapons"

#include "mckayupdater.sp"

public TF2_OnConditionAdded(client, TFCond:condition) {
	if(condition == TFCond:85) {
		// See if everyone is melee-only
		for(new i = 1; i <= MaxClients; i++) {
			if(IsClientInGame(i) && IsPlayerAlive(i) && !TF2_IsPlayerInCondition(i, TFCond:85)) {
				return;
			}
		}
		
		// Everyone is melee-only, disable all sentries
		SetSentryDisabled(true);
	}
}

public TF2_OnConditionRemoved(client, TFCond:condition) {
	if(condition == TFCond:85) {
		SetSentryDisabled(false);
	}
}

SetSentryDisabled(bool:disabled) {
	new ent = -1;
	while((ent = FindEntityByClassname(ent, "obj_sentrygun")) != -1) {
		SetEntProp(ent, Prop_Send, "m_bDisabled", disabled);
	}
}