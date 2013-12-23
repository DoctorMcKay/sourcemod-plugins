#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <tf2>

#define PLUGIN_VERSION			"1.0.2"
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

new g_LastFire[MAXPLAYERS + 1];

#define UPDATE_FILE		"short_circuit_nerf.txt"
#define CONVAR_PREFIX	"short_circuit_nerf"

#include "mckayupdater.sp"

public OnPluginStart() {
	g_cvarFiringDelay = CreateConVar("short_circuit_nerf_delay_seconds", "0.8", "Number of seconds to restrict Short Circuit firing after an attack", _, true, 0.1);
	g_cvarMetalCost = CreateConVar("short_circuit_nerf_metal_cost", "20", "Metal the Short Circuit should cost per fire", _, true, 5.0);
	
	AddNormalSoundHook(OnNormalSound);
}

public Action:OnPlayerRunCmd(client, &buttons, &impulse, Float:vel[3], Float:angles[3], &weapon, &subtype, &cmdnum, &tickcount, &seed, mouse[2]) {
	if(!IsPlayerAlive(client)) {
		return Plugin_Continue;
	}
	
	new wep = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");
	if(wep == -1 || !IsValidEntity(wep)) {
		return Plugin_Continue;
	}
	
	if(GetEntProp(wep, Prop_Send, "m_iItemDefinitionIndex") != WEAPON_SHORT_CIRCUIT) {
		return Plugin_Continue;
	}
	
	if(GetEntPropFloat(wep, Prop_Send, "m_flNextPrimaryAttack") > GetGameTime()) {
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
	metal -= difference;
	if(metal < 0) {
		metal = 0;
	}
	SetEntProp(entity, Prop_Data, "m_iAmmo", metal, 4, 3);
	
	if(metal > 0) {
		CreateTimer(0.0, Timer_UpdateAttackTime, GetClientUserId(entity));
	}
}

public Action:Timer_UpdateAttackTime(Handle:timer, any:userid) {
	new client = GetClientOfUserId(userid);
	if(client != 0) {
		SetEntPropFloat(GetPlayerWeaponSlot(client, 1), Prop_Send, "m_flNextPrimaryAttack", GetGameTime() + GetConVarFloat(g_cvarFiringDelay));
	}
}