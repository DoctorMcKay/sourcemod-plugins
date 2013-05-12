#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <tf2>
#include <clientprefs>
#include <easy_commands>

#define PLUGIN_VERSION	"1.1.0"

public Plugin:myinfo = {
	name		= "[ANY] Unrestricted FOV",
	author		= "Dr. McKay",
	description	= "Allows players to choose their own FOV",
	version		= PLUGIN_VERSION,
	url			= "http://www.doctormckay.com"
};

new Handle:cookieFOV;
new Handle:cvarFOVMin;
new Handle:cvarFOVMax;

#define UPDATE_FILE		"unrestricted_fov.txt"
#define CONVAR_PREFIX	"ufov"
#include "mckayupdater.sp"

public OnPluginStart() {
	cookieFOV = RegClientCookie("unrestricted_fov", "Client Desired FOV", CookieAccess_Private);
	
	cvarFOVMin = CreateConVar("ufov_min", "20", "Minimum FOV a client can set with the !fov command", _, true, 20.0, true, 180.0);
	cvarFOVMax = CreateConVar("ufov_max", "130", "Maximum FOV a client can set with the !fov command", _, true, 20.0, true, 180.0);
	
	RegEasyConCmd("sm_fov <FOV>", Command_FOV, {Cmd_Cell}, 1, 0);
	HookEvent("player_spawn", Event_PlayerSpawn);
}

public Command_FOV(client, fov) {
	if(!AreClientCookiesCached(client)) {
		ReplyToCommand(client, "\x04[SM] \x01This command is currently unavailable. Please try again later.");
		return;
	}
	if(fov == 0) {
		QueryClientConVar(client, "fov_desired", OnFOVQueried);
		ReplyToCommand(client, "\x04[SM] \x01Your FOV has been reset.");
		return;
	}
	if(fov < GetConVarInt(cvarFOVMin)) {
		QueryClientConVar(client, "fov_desired", OnFOVQueried);
		ReplyToCommand(client, "\x04[SM] \x01The minimum FOV you can set with !fov is %d.", GetConVarInt(cvarFOVMin));
		return;
	}
	if(fov > GetConVarInt(cvarFOVMax)) {
		QueryClientConVar(client, "fov_desired", OnFOVQueried);
		ReplyToCommand(client, "\x04[SM] \x01The maximum FOV you can set with !fov is %d.", GetConVarInt(cvarFOVMax));
		return;
	}
	decl String:cookie[12];
	IntToString(fov, cookie, sizeof(cookie));
	SetClientCookie(client, cookieFOV, cookie);
	
	SetEntProp(client, Prop_Send, "m_iFOV", fov);
	SetEntProp(client, Prop_Send, "m_iDefaultFOV", fov);
	
	ReplyToCommand(client, "\x04[SM] \x01Your FOV has been set to %d on this server.", fov);
}

public Event_PlayerSpawn(Handle:event, const String:name[], bool:dontBroadcast) {
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	if(!AreClientCookiesCached(client)) {
		return;
	}
	
	decl String:cookie[12];
	GetClientCookie(client, cookieFOV, cookie, sizeof(cookie));
	new fov = StringToInt(cookie);
	if(fov < GetConVarInt(cvarFOVMin) || fov > GetConVarInt(cvarFOVMax)) {
		return;
	}
	SetEntProp(client, Prop_Send, "m_iFOV", fov);
	SetEntProp(client, Prop_Send, "m_iDefaultFOV", fov);
}

public TF2_OnConditionRemoved(client, TFCond:condition) {
	if(condition != TFCond_Zoomed) {
		return;
	}
	decl String:cookie[12];
	GetClientCookie(client, cookieFOV, cookie, sizeof(cookie));
	new fov = StringToInt(cookie);
	if(fov < GetConVarInt(cvarFOVMin) || fov > GetConVarInt(cvarFOVMax)) {
		return;
	}
	SetEntProp(client, Prop_Send, "m_iFOV", fov);
	SetEntProp(client, Prop_Send, "m_iDefaultFOV", fov);
}

public OnFOVQueried(QueryCookie:cookie, client, ConVarQueryResult:result, const String:cvarName[], const String:cvarValue[]) {
	if(result != ConVarQuery_Okay) {
		return;
	}
	SetClientCookie(client, cookieFOV, "");
	SetEntProp(client, Prop_Send, "m_iFOV", StringToInt(cvarValue));
	SetEntProp(client, Prop_Send, "m_iDefaultFOV", StringToInt(cvarValue));
}