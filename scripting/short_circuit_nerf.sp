#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <tf2>

#define PLUGIN_VERSION			"1.0.0"
#define WEAPON_SHORT_CIRCUIT	528

public Plugin:myinfo = {
	name		= "[TF2] Nerf Short Circuit NAO",
	author		= "Dr. McKay",
	description	= "Nerfs the now hilariously-overpowered Short Circuit",
	version		= PLUGIN_VERSION,
	url			= "http://www.doctormckay.com"
};

new Handle:g_cvarFiringDelay;
new Handle:g_cvarMetalCost;

new g_RestrictedTicks[MAXPLAYERS + 1];
new g_LastFire[MAXPLAYERS + 1];

#define UPDATE_FILE		"short_circuit_nerf.txt"
#define CONVAR_PREFIX	"short_circuit_nerf"

#include "mckayupdater.sp"

public OnPluginStart() {
	g_cvarFiringDelay = CreateConVar("short_circuit_nerf_delay", "50", "Number of ticks to restrict Short Circuit firing after an attack", _, true, 10.0);
	g_cvarMetalCost = CreateConVar("short_circuit_nerf_metal_cost", "20", "Metal the Short Circuit should cost per fire", _, true, 0.0);
	
	HookEvent("player_spawn", Event_PlayerSpawn);
	
	AddNormalSoundHook(OnNormalSound);
}

public Event_PlayerSpawn(Handle:event, const String:name[], bool:dontBroadcast) {
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	g_RestrictedTicks[client] = 0;
}

public Action:OnPlayerRunCmd(client, &buttons, &impulse, Float:vel[3], Float:angles[3], &weapon, &subtype, &cmdnum, &tickcount, &seed, mouse[2]) {
	if(!IsPlayerAlive(client)) {
		return Plugin_Continue;
	}
	
	new wep = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");
	if(GetEntProp(wep, Prop_Send, "m_iItemDefinitionIndex") != WEAPON_SHORT_CIRCUIT) {
		return Plugin_Continue;
	}
	
	if(g_RestrictedTicks[client] > 0) {
		g_RestrictedTicks[client]--;
		buttons &= ~IN_ATTACK;
		return Plugin_Changed;
	}
	
	return Plugin_Continue;
}

public Action:OnNormalSound(clients[64], &numClients, String:sample[PLATFORM_MAX_PATH], &entity, &channel, &Float:volume, &level, &pitch, &flags) {
	// This is the only way I could find to hook when the player fires the Short Circuit
	if(entity < 1 || entity > MaxClients || StrContains(sample, "barret_arm_shot.wav") == -1 || g_LastFire[entity] == GetGameTickCount()) {
		return;
	}
	
	g_LastFire[entity] = GetGameTickCount();
	new difference = GetConVarInt(g_cvarMetalCost) - 5;
	new metal = GetEntProp(entity, Prop_Data, "m_iAmmo", 4, 3);
	if(metal - difference < 0) {
		difference = metal;
	}
	SetEntProp(entity, Prop_Data, "m_iAmmo", metal - difference, 4, 3);
	
	g_RestrictedTicks[entity] = GetConVarInt(g_cvarFiringDelay);
}