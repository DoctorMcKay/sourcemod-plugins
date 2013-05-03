#pragma semicolon 1

#include <sourcemod>
#include <tf2>

#define PLUGIN_VERSION		"1.0.0"

#define COND_UBERCHARGED	1
#define COND_UBERFADING		2		// Requires both TFCond_Ubercharged + TFCond_UberchargeFading
#define COND_TELEGLOW		4
#define COND_BUFFED			8		// Rings and glowing, Buff Banner effect
#define COND_DEFBUFFED		16		// Rings and glowing, Battalion's Backup effect
#define COND_CRITACOLA		32		// Mini-crits
#define COND_JARATED		64
#define COND_MILKED			128
#define COND_MEGAHEAL		256		// Quick-fix effect, no healing
#define COND_MARKFORDEATH	512
#define COND_SPEEDBUFF		1024	// Effect of Disciplinary Action

public Plugin:myinfo = {
	name		= "[TF2] Humiliation Conditions",
	author		= "Dr. McKay",
	description	= "Applies conditions to players during humiliation round",
	version		= PLUGIN_VERSION,
	url			= "http://www.doctormckay.com"
};

new Handle:cvarWinningTeam;
new Handle:cvarLosingTeam;
new Handle:cvarWinningTeamAdmin;
new Handle:cvarLosingTeamAdmin;

new Handle:mp_bonusroundtime;

#define CONVAR_PREFIX	"humiliation_conditions"
#define UPDATE_FILE		"humiliationconditions.txt"
#include "mckayupdater.sp"

public OnPluginStart() {
	cvarWinningTeam = CreateConVar("humiliation_conditions_winning_team", "0", "Sum of condition codes to be applied to winning team");
	cvarLosingTeam = CreateConVar("humiliation_conditions_losing_team", "0", "Sum of condition codes to be applied to losing team");
	cvarWinningTeamAdmin = CreateConVar("humiliation_conditions_winning_team_admin", "0", "Sum of condition codes to be applied to admins on winning team (controlled by humiliation_conditions_admin override");
	cvarLosingTeamAdmin = CreateConVar("humiliation_conditions_losing_team_admin", "0", "Sum of condition codes to be applied to admins on losing team (controlled by humiliation_conditions_admin override");
	AutoExecConfig();
	
	mp_bonusroundtime = FindConVar("mp_bonusroundtime");
	
	HookEvent("teamplay_round_win", Event_RoundEnd);
}

public Event_RoundEnd(Handle:event, const String:name[], bool:dontBroadcast) {
	new winningTeam = GetEventInt(event, "team");
	
	new team;
	for(new i = 1; i <= MaxClients; i++) {
		if(!IsClientInGame(i) || (team = GetClientTeam(i)) < 2) {
			continue;
		}
		if(team == winningTeam) {
			ApplyEffects(i, true, false);
			if(CheckCommandAccess(i, "humiliation_conditions_admin", ADMFLAG_RESERVATION, true)) {
				ApplyEffects(i, true, true);
			}
		} else {
			ApplyEffects(i, false, false);
			if(CheckCommandAccess(i, "humiliation_conditions_admin", ADMFLAG_RESERVATION, true)) {
				ApplyEffects(i, false, true);
			}
		}
	}
}

ApplyEffects(client, winner, admin) {
	new bits;
	if(winner) {
		bits = (!admin) ? GetConVarInt(cvarWinningTeam) : GetConVarInt(cvarWinningTeamAdmin);
	} else {
		bits = (!admin) ? GetConVarInt(cvarLosingTeam) : GetConVarInt(cvarLosingTeamAdmin);
	}
	new Float:time = GetConVarFloat(mp_bonusroundtime);
	if(bits & COND_UBERCHARGED) {
		TF2_AddCondition(client, TFCond_Ubercharged, time);
	}
	if(bits & COND_UBERFADING) {
		TF2_AddCondition(client, TFCond_UberchargeFading, time);
	}
	if(bits & COND_TELEGLOW) {
		TF2_AddCondition(client, TFCond_TeleportedGlow, time);
	}
	if(bits & COND_BUFFED) {
		TF2_AddCondition(client, TFCond_Buffed, time);
	}
	if(bits & COND_DEFBUFFED) {
		TF2_AddCondition(client, TFCond_DefenseBuffed, time);
	}
	if(bits & COND_CRITACOLA) {
		TF2_AddCondition(client, TFCond_CritCola, time);
	}
	if(bits & COND_JARATED) {
		TF2_AddCondition(client, TFCond_Jarated, time);
	}
	if(bits & COND_MILKED) {
		TF2_AddCondition(client, TFCond_Milked, time);
	}
	if(bits & COND_MEGAHEAL) {
		TF2_AddCondition(client, TFCond_MegaHeal, time);
	}
	if(bits & COND_MARKFORDEATH) {
		TF2_AddCondition(client, TFCond_MarkedForDeath, time);
	}
	if(bits & COND_SPEEDBUFF) {
		TF2_AddCondition(client, TFCond_SpeedBuffAlly, time);
	}
}