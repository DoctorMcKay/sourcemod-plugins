#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <tf2>
#include <tf2_stocks>
#include <tf2items_giveweapon>

#undef REQUIRE_PLUGIN
#include <updater>

#define UPDATE_URL			"http://public-plugins.doctormckay.com/latest/itemserver.txt"
#define PLUGIN_VERSION		"1.1.1"

public Plugin:myinfo = {
	name        = "[TF2] Local Item Server",
	author      = "Dr. McKay",
	description = "Gives players their last known loadout when the item server goes down",
	version     = PLUGIN_VERSION,
	url         = "http://www.doctormckay.com"
};

#define QUALITY_NORMAL 0

new Handle:db = INVALID_HANDLE;

new Handle:classes = INVALID_HANDLE;

new Handle:updaterCvar = INVALID_HANDLE;

public OnPluginStart() {
	updaterCvar = CreateConVar("local_item_server_auto_update", "1", "Enables automatic updating (has no effect if Updater is not installed)");
	new Handle:dbInfo = CreateKeyValues("LocalItemServer", "driver", "sqlite");
	KvSetString(dbInfo, "database", "LocalItemServer");
	decl String:error[256];
	db = SQL_ConnectCustom(dbInfo, error, sizeof(error), true);
	if(db == INVALID_HANDLE) {
		SetFailState("Couldn't connect to SQLite database: %s", error);
	}
	HookEvent("post_inventory_application", Event_InventoryApplication);
	new String:qry[1024];
	qry="CREATE TABLE IF NOT EXISTS `players` (steamid varchar(32), scout_slot_0 int(8), scout_slot_1 int(8), scout_slot_2 int(8), scout_slot_3 int(8), scout_slot_4 int(8), soldier_slot_0 int(8), soldier_slot_1 int(8), soldier_slot_2 int(8), soldier_slot_3 int(8), soldier_slot_4 int(8), pyro_slot_0 int(8), pyro_slot_1 int(8), pyro_slot_2 int(8), pyro_slot_3 int(8), pyro_slot_4 int(8), demo_slot_0 int(8), demo_slot_1 int(8), demo_slot_2 int(8), demo_slot_3 int(8), demo_slot_4 int(8), heavy_slot_0 int(8), heavy_slot_1 int(8), heavy_slot_2 int(8), heavy_slot_3 int(8), heavy_slot_4 int(8), engineer_slot_0 int(8), engineer_slot_1 int(8), engineer_slot_2 int(8), engineer_slot_3 int(8), engineer_slot_4 int(8), medic_slot_0 int(8), medic_slot_1 int(8), medic_slot_2 int(8), medic_slot_3 int(8), medic_slot_4 int(8), sniper_slot_0 int(8), sniper_slot_1 int(8), sniper_slot_2 int(8), sniper_slot_3 int(8), sniper_slot_4 int(8), spy_slot_0 int(8), spy_slot_1 int(8), spy_slot_2 int(8), spy_slot_3 int(8), spy_slot_4 int(8))";
	SQL_TQuery(db, OnTableCreated, qry);
	classes = CreateTrie();
	SetTrieValue(classes, "scout", 1);
	SetTrieValue(classes, "soldier", 6);
	SetTrieValue(classes, "pyro", 11);
	SetTrieValue(classes, "demo", 16);
	SetTrieValue(classes, "heavy", 21);
	SetTrieValue(classes, "engineer", 26);
	SetTrieValue(classes, "medic", 31);
	SetTrieValue(classes, "sniper", 36);
	SetTrieValue(classes, "spy", 41);
}

public OnTableCreated(Handle:parent, Handle:hndl, const String:error[], any:data) {
	if(strlen(error) > 0) {
		SetFailState("Problem creating the table: %s", error);
	}
	decl String:auth[32];
	for(new i = 1; i <= MaxClients; i++) {
		if(!IsClientConnected(i) || !IsClientAuthorized(i) || IsFakeClient(i)) {
			continue;
		}
		GetClientAuthString(i, auth, sizeof(auth));
		OnClientAuthorized(i, auth);
	}
}

public OnClientAuthorized(client, const String:auth[]) {
	decl String:qry[256];
	Format(qry, sizeof(qry), "SELECT * FROM `players` WHERE steamid = '%s'", auth);
	SQL_TQuery(db, OnRowChecked, qry, client);
}

public OnRowChecked(Handle:parent, Handle:hndl, const String:error[], any:client) {
	if(strlen(error) > 0) {
		LogError("Problem checking row for %L: %s", client, error);
		return;
	}
	if(SQL_GetRowCount(hndl) == 0) {
		decl String:qry[256], String:auth[32];
		GetClientAuthString(client, auth, sizeof(auth));
		Format(qry, sizeof(qry), "INSERT INTO `players` VALUES ('%s', -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1, -1)", auth);
		SQL_TQuery(db, OnQueryExecuted, qry);
	}
}

public Event_InventoryApplication(Handle:event, const String:name[], bool:dontBroadcast) {
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	new weapons[5], defindexes[5];
	new bool:allStock = true;
	for(new i = 0; i <= 4; i++) {
		weapons[i] = GetPlayerWeaponSlot(client, i);
		if(weapons[i] == -1) {
			defindexes[i] = -1;
			continue; // no weapon
		}
		defindexes[i] = GetEntProp(weapons[i], Prop_Send, "m_iItemDefinitionIndex");
		if(GetEntProp(weapons[i], Prop_Send, "m_iEntityQuality") != QUALITY_NORMAL) {
			allStock = false;
		}
	}
	decl String:auth[32], String:qry[256];
	GetClientAuthString(client, auth, sizeof(auth));
	decl String:className[16];
	switch(TF2_GetPlayerClass(client)) {
		case TFClass_Scout: {
			className = "scout";
		}
		case TFClass_Soldier: {
			className = "soldier";
		}
		case TFClass_Pyro: {
			className = "pyro";
		}
		case TFClass_DemoMan: {
			className = "demo";
		}
		case TFClass_Heavy: {
			className = "heavy";
		}
		case TFClass_Engineer: {
			className = "engineer";
		}
		case TFClass_Medic: {
			className = "medic";
		}
		case TFClass_Sniper: {
			className = "sniper";
		}
		case TFClass_Spy: {
			className = "spy";
		}
	}
	if(!allStock) {
		Format(qry, sizeof(qry), "UPDATE `players` SET %s_slot_0 = '%i', %s_slot_1 = '%i', %s_slot_2 = '%i', %s_slot_3 = '%i', %s_slot_4 = '%i' WHERE steamid = '%s'", className, defindexes[0], className, defindexes[1], className, defindexes[2], className, defindexes[3], className, defindexes[4], auth);
		SQL_TQuery(db, OnQueryExecuted, qry);
	} else {
		if(GetEntProp(client, Prop_Send, "m_bLoadoutUnavailable") == 1) {
			new Handle:pack = CreateDataPack();
			WritePackString(pack, className);
			WritePackCell(pack, client);
			ResetPack(pack);
			Format(qry, sizeof(qry), "SELECT * FROM `players` WHERE steamid = '%s'", auth);
			SQL_TQuery(db, OnItemsReceived, qry, pack);
		}
	}
}

public OnItemsReceived(Handle:parent, Handle:hndl, const String:error[], any:pack) {
	decl String:className[16];
	ReadPackString(pack, className, sizeof(className));
	new client = ReadPackCell(pack);
	CloseHandle(pack);
	if(strlen(error) > 0) {
		LogError("Problem receiving items for %L: %s", client, error);
		return;
	}
	new col;
	if(!GetTrieValue(classes, className, col)) {
		LogError("Problem getting trie value for %L: class is %s", client, className);
		return;
	}
	if(!SQL_FetchRow(hndl)) {
		LogError("Problem fetching a row of items for %L", client);
		return;
	}
	new weapon;
	new TFClassType:class = TF2_GetPlayerClass(client);
	for(new i = 0; i < 5; i++) {
		if(class == TFClass_Engineer && i == 2) {
			continue; // don't give them a wrench
		}
		weapon = SQL_FetchInt(hndl, col + i);
		if(TF2Items_CheckWeapon(weapon)) {
			TF2Items_GiveWeapon(client, weapon); // only give them a weapon if TF2Items is capable of giving it
		}
	}
	CreateTimer(2.0, Timer_GivenHint, client);
}

public Action:Timer_GivenHint(Handle:timer, any:client) {
	PrintHintText(client, "We have detected your loadout is unavailable.\nYou have been given your last known loadout.");
}

public OnQueryExecuted(Handle:parent, Handle:hndl, const String:error[], any:data) {
	if(strlen(error) > 0) {
		LogError("Problem with query: %s", error);
	}
}

/////////////////////////////////

public OnAllPluginsLoaded() {
	new Handle:convar;
	if(LibraryExists("updater")) {
		Updater_AddPlugin(UPDATE_URL);
		new String:newVersion[10];
		Format(newVersion, sizeof(newVersion), "%sA", PLUGIN_VERSION);
		convar = CreateConVar("local_item_server_version", newVersion, "Local Item Server Version", FCVAR_DONTRECORD|FCVAR_NOTIFY|FCVAR_CHEAT);
	} else {
		convar = CreateConVar("local_item_server_version", PLUGIN_VERSION, "Local Item Server Version", FCVAR_DONTRECORD|FCVAR_NOTIFY|FCVAR_CHEAT);	
	}
	HookConVarChange(convar, Callback_VersionConVarChanged);
}

public Callback_VersionConVarChanged(Handle:convar, const String:oldValue[], const String:newValue[]) {
	decl String:defaultValue[32];
	GetConVarDefault(convar, defaultValue, sizeof(defaultValue));
	if(!StrEqual(newValue, defaultValue)) {
		SetConVarString(convar, defaultValue);
	}
}

public Action:Updater_OnPluginDownloading() {
	if(!GetConVarBool(updaterCvar)) {
		return Plugin_Handled;
	}
	return Plugin_Continue;
}

public Updater_OnPluginUpdated() {
	ReloadPlugin();
}