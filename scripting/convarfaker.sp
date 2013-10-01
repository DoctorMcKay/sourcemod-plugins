#pragma semicolon 1

#include <sourcemod>

#define PLUGIN_VERSION		"1.0.0"

public Plugin:myinfo = {
	name		= "[ANY] ConVar Faker",
	author		= "Dr. McKay",
	description	= "Fakes the values of cvars to clients",
	version		= PLUGIN_VERSION,
	url			= "http://www.doctormckay.com"
};

new Handle:kv;
new Handle:cache;

#define UPDATE_FILE		"convarfaker.txt"
#define CONVAR_PREFIX	"cvar_faker"

#include "mckayupdater.sp"

public OnPluginStart() {
	cache = CreateTrie();
	LoadConfig();
	
	RegAdminCmd("sm_cvar_faker_reload", Command_ReloadConfig, ADMFLAG_ROOT, "Reloads ConVar Faker's configuration");
}

public Action:Command_ReloadConfig(client, args) {
	LogAction(client, -1, "%L reloaded ConVar Faker's configuration", client);
	ReplyToCommand(client, "\x04[SM] \x01Reloaded configuration");
	LoadConfig();
	return Plugin_Handled;
}

LoadConfig() {
	if(kv != INVALID_HANDLE) {
		CloseHandle(kv);
	}
	
	kv = CreateKeyValues("ConVar_Faker");
	decl String:path[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, path, sizeof(path), "configs/cvar_faker.cfg");
	
	if(!FileToKeyValues(kv, path)) {
		SetFailState("Configuration file is missing or invalid");
	}
	
	for(new i = 1; i <= MaxClients; i++) {
		if(IsClientInGame(i)) {
			OnClientPostAdminCheck(i);
		}
	}
}

public OnClientPostAdminCheck(client) {
	if(IsFakeClient(client)) {
		return;
	}
	
	KvRewind(kv);
	KvGotoFirstSubKey(kv);
	decl String:cvarName[64], String:flags[16], String:flagType[16], String:value[128];
	new Handle:cvar, AdminId:admin, AdminFlag:flag, bool:access;
	do {
		KvGetSectionName(kv, cvarName, sizeof(cvarName));
		if(!GetTrieValue(cache, cvarName, cvar)) {
			cvar = FindConVar(cvarName);
			SetTrieValue(cache, cvarName, cvar);
			
			if(cvar == INVALID_HANDLE) {
				LogError("ConVar '%s' is invalid", cvarName);
				continue;
			} else if(!(GetConVarFlags(cvar) & FCVAR_REPLICATED)) {
				LogError("ConVar '%s' is not replicated", cvarName);
				SetTrieValue(cache, cvarName, INVALID_HANDLE);
				continue;
			}
		}
		
		if(cvar == INVALID_HANDLE) {
			continue;
		}
		
		KvGetString(kv, "flags", flags, sizeof(flags));
		if(strlen(flags) > 0) {
			KvGetString(kv, "flagtype", flagType, sizeof(flagType));
			admin = GetUserAdmin(client);
			
			if(StrEqual(flagType, "all", false)) {
				access = true;
				for(new i = 0; i < strlen(flags); i++) {
					FindFlagByChar(flags[i], flag);
					if(!GetAdminFlag(admin, flag)) {
						access = false;
						break; // Breaks out of flag loop
					}
				}
			} else if(StrEqual(flagType, "not", false)) {
				access = true;
				for(new i = 0; i < strlen(flags); i++) {
					FindFlagByChar(flags[i], flag);
					if(GetAdminFlag(admin, flag)) {
						access = false;
						break;
					}
				}
			} else {
				// any
				access = false;
				for(new i = 0; i < strlen(flags); i++) {
					FindFlagByChar(flags[i], flag);
					if(GetAdminFlag(admin, flag)) {
						access = true;
						break; // Breaks out of flag loop
					}
				}
			}
			
			if(!access) {
				continue;
			}
		}
		
		KvGetString(kv, "value", value, sizeof(value));
		SendConVarValue(client, cvar, value);
	} while(KvGotoNextKey(kv));
}