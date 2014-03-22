#pragma semicolon 1

#include <sourcemod>
#include <geoip>
#undef REQUIRE_EXTENSIONS
#include <steamtools>
#include <geoipcity>

#define PLUGIN_VERSION		"1.1.1"

enum OS {
	OS_Unknown = -1,
	OS_Windows = 0,
	OS_Mac = 1,
	OS_Linux = 2,
	OS_Total = 3
};	

public Plugin:myinfo = {
	name		= "[ANY] Player Analytics",
	author		= "Dr. McKay",
	description	= "Logs analytical data about connecting players",
	version		= PLUGIN_VERSION,
	url			= "http://www.doctormckay.com"
};

//#define DEBUG

#if !defined DEBUG
new Handle:g_DB;
#endif
new bool:g_SteamTools;
new String:g_IP[64];
new String:g_GameFolder[64];
new Handle:g_OSGamedata;
new String:g_OSConVar[OS_Total][64];

new g_ConnectTime[MAXPLAYERS + 1];
new g_NumPlayers[MAXPLAYERS + 1];
new g_RowID[MAXPLAYERS + 1] = {-1, ...};
new String:g_ConnectMethod[MAXPLAYERS + 1][64];
new g_MOTDDisabled[MAXPLAYERS + 1] = {-1, ...};
new Handle:g_MOTDTimer[MAXPLAYERS + 1];
new OS:g_OS[MAXPLAYERS + 1];
new Handle:g_OSTimer[MAXPLAYERS + 1];
new g_OSQueries[MAXPLAYERS + 1];

#if !defined DEBUG
#define UPDATE_FILE		"player_analytics.txt"
#define CONVAR_PREFIX	"player_analytics"

#include "mckayupdater.sp"
#endif

public APLRes:AskPluginLoad2(Handle:myself, bool:late, String:error[], err_max) {
	MarkNativeAsOptional("Steam_GetNumClientSubscriptions");
	MarkNativeAsOptional("Steam_GetClientSubscription");
	MarkNativeAsOptional("Steam_GetNumClientDLCs");
	MarkNativeAsOptional("Steam_GetClientDLC");
	MarkNativeAsOptional("Steam_GetPublicIP");
	MarkNativeAsOptional("Steam_IsConnected");
	
#if !defined DEBUG
	if(SQL_CheckConfig("player_analytics")) {
		g_DB = SQL_Connect("player_analytics", true, error, err_max);
	} else {
		g_DB = SQL_Connect("default", true, error, err_max);
	}
	
	if(g_DB == INVALID_HANDLE) {
		return APLRes_Failure;
	}
	
	SQL_TQuery(g_DB, OnTableCreated, "CREATE TABLE IF NOT EXISTS `player_analytics` (id int(11) NOT NULL AUTO_INCREMENT, server_ip varchar(32) NOT NULL, name varchar(32), auth varchar(32), connect_time int(11) NOT NULL, connect_date date NOT NULL, connect_method varchar(64) DEFAULT NULL, numplayers tinyint(4) NOT NULL, map varchar(64) NOT NULL, duration int(11) DEFAULT NULL, flags varchar(32) NOT NULL, ip varchar(32) NOT NULL, city varchar(45), region varchar(45), country varchar(45), country_code varchar(2), country_code3 varchar(3), premium tinyint(1), html_motd_disabled tinyint(1), os varchar(32), PRIMARY KEY (id)) ENGINE=InnoDB  DEFAULT CHARSET=utf8");
#endif
	
	return APLRes_Success;
}

#if !defined DEBUG
public OnTableCreated(Handle:owner, Handle:hndl, const String:error[], any:data) {
	if(hndl == INVALID_HANDLE) {
		SetFailState("Unable to create table. %s", error);
	}
}
#endif

public OnPluginStart() {
	if(!g_SteamTools || !Steam_IsConnected()) {
		new ip = GetConVarInt(FindConVar("hostip"));
		Format(g_IP, sizeof(g_IP), "%d.%d.%d.%d:%d", ((ip & 0xFF000000) >> 24) & 0xFF, ((ip & 0x00FF0000) >> 16) & 0xFF, ((ip & 0x0000FF00) >>  8) & 0xFF, ((ip & 0x000000FF) >>  0) & 0xFF, GetConVarInt(FindConVar("hostport")));
	}
	
	GetGameFolderName(g_GameFolder, sizeof(g_GameFolder));
	g_OSGamedata = LoadGameConfigFile("detect_os.games");
	if(g_OSGamedata == INVALID_HANDLE) {
		LogError("Failed to load gamedata file detect_os.games.txt: client operating system data will be unavailable.");
	} else {
		GameConfGetKeyValue(g_OSGamedata, "Convar_Windows", g_OSConVar[OS_Windows], sizeof(g_OSConVar[]));
		GameConfGetKeyValue(g_OSGamedata, "Convar_Mac", g_OSConVar[OS_Mac], sizeof(g_OSConVar[]));
		GameConfGetKeyValue(g_OSGamedata, "Convar_Linux", g_OSConVar[OS_Linux], sizeof(g_OSConVar[]));
	}
}

public Steam_SteamServersConnected() {
	new octets[4];
	Steam_GetPublicIP(octets);
	Format(g_IP, sizeof(g_IP), "%d.%d.%d.%d:%d", octets[0], octets[1], octets[2], octets[3], GetConVarInt(FindConVar("hostport")));
}

public Steam_FullyLoaded() {
	g_SteamTools = true;
}

public Steam_Shutdown() {
	g_SteamTools = false;
}

public OnClientConnected(client) {
	if(IsFakeClient(client)) {
		return;
	}
	
	g_MOTDDisabled[client] = -1;
	g_ConnectTime[client] = GetTime();
	g_NumPlayers[client] = GetRealClientCount();
	g_RowID[client] = -1;
	g_OS[client] = OS_Unknown;
	
	decl String:buffer[30];
	if(GetClientInfo(client, "cl_connectmethod", buffer, sizeof(buffer))) {
#if !defined DEBUG
		SQL_EscapeString(g_DB, buffer, g_ConnectMethod[client], sizeof(g_ConnectMethod[]));
#else
		strcopy(g_ConnectMethod[client], sizeof(g_ConnectMethod[]), buffer);
#endif
		Format(g_ConnectMethod[client], sizeof(g_ConnectMethod[]), "'%s'", g_ConnectMethod[client]);
	} else {
		strcopy(g_ConnectMethod[client], sizeof(g_ConnectMethod[]), "NULL");
	}
}

public OnClientPutInServer(client) {
	if(IsFakeClient(client)) {
		return;
	}
	
	QueryClientConVar(client, "cl_disablehtmlmotd", OnMOTDQueried);
	g_MOTDTimer[client] = CreateTimer(30.0, Timer_MOTDTimeout, GetClientUserId(client));
	
	for(new i = 0; i < _:OS_Total; i++) {
		QueryClientConVar(client, g_OSConVar[i], OnOSQueried);
	}
	g_OSTimer[client] = CreateTimer(30.0, Timer_OSTimeout, GetClientUserId(client));
}

public OnMOTDQueried(QueryCookie:cookie, client, ConVarQueryResult:result, const String:cvarName[], const String:cvarValue[]) {
	if(g_MOTDTimer[client] == INVALID_HANDLE) {
		return; // Timed out
	}
	
	if(result == ConVarQuery_Okay) {
		g_MOTDDisabled[client] = (bool:StringToInt(cvarValue)) ? 1 : 0;
	} else {
		g_MOTDDisabled[client] = -1;
	}
	
	CloseHandle(g_MOTDTimer[client]);
	g_MOTDTimer[client] = INVALID_HANDLE;
}

public Action:Timer_MOTDTimeout(Handle:timer, any:userid) {
	new client = GetClientOfUserId(userid);
	if(client == 0) {
		return;
	}
	
	g_MOTDDisabled[client] = -1;
	g_MOTDTimer[client] = INVALID_HANDLE;
}

public OnOSQueried(QueryCookie:cookie, client, ConVarQueryResult:result, const String:cvarName[], const String:cvarValue[]) {
	if(g_OSTimer[client] == INVALID_HANDLE) {
		return; // Timed out
	}
	
	if(result == ConVarQuery_NotFound) {
		g_OSQueries[client]++;
		if(g_OSQueries[client] >= _:OS_Total) {
			CloseHandle(g_OSTimer[client]);
			g_OSTimer[client] = INVALID_HANDLE;
		}
		return;
	} else {
		for(new i = 0; i < _:OS_Total; i++) {
			if(StrEqual(cvarName, g_OSConVar[i])) {
				g_OS[client] = OS:i;
				break;
			}
		}
		
		CloseHandle(g_OSTimer[client]);
		g_OSTimer[client] = INVALID_HANDLE;
	}
}

public Action:Timer_OSTimeout(Handle:timer, any:userid) {
	new client = GetClientOfUserId(userid);
	if(client == 0) {
		return;
	}
	
	g_OSTimer[client] = INVALID_HANDLE;
}

public OnClientPostAdminCheck(client) {
	if(IsFakeClient(client)) {
		return;
	}
	
	CreateTimer(1.0, Timer_HandleConnect, GetClientUserId(client), TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
}

public Action:Timer_HandleConnect(Handle:timer, any:userid) {
	new client = GetClientOfUserId(userid);
	if(client == 0) {
		return Plugin_Stop;
	}
	
	if(g_MOTDTimer[client] != INVALID_HANDLE || g_OSTimer[client] != INVALID_HANDLE || g_ConnectTime[client] == 0) {
		return Plugin_Continue;
	}
	
	new String:date[64], String:map[64], AdminFlag:flags[32], String:flagstring[64], String:ip[64], String:city[45], String:region[45], String:country_name[45], String:country_code[3], String:country_code3[4];
	
	new String:buffers[10][256];
	FormatTime(date, sizeof(date), "%Y-%m-%d");
	GetCurrentMap(map, sizeof(map));
	GetClientName(client, buffers[0], sizeof(buffers[]));
	GetClientAuthString(client, buffers[1], sizeof(buffers[]));
	new num = FlagBitsToArray(GetUserFlagBits(client), flags, sizeof(flags));
	for(new i = 0; i < num; i++) {
		new char;
		FindFlagChar(flags[i], char);
		flagstring[i] = char;
	}
	flagstring[num] = '\0';
	GetClientIP(client, ip, sizeof(ip));
	
	if(GetFeatureStatus(FeatureType_Native, "GeoipGetRecord") != FeatureStatus_Available || !GeoipGetRecord(ip, city, region, country_name, country_code, country_code3)) {
		GeoipCountry(ip, country_name, sizeof(country_name));
	}
	
	strcopy(buffers[2], sizeof(buffers[]), city);
	strcopy(buffers[3], sizeof(buffers[]), region);
	strcopy(buffers[4], sizeof(buffers[]), country_name);
	strcopy(buffers[5], sizeof(buffers[]), country_code);
	strcopy(buffers[6], sizeof(buffers[]), country_code3);
	
	if(g_SteamTools && StrEqual(g_GameFolder, "tf")) {
		if(Steam_CheckClientSubscription(client, 0) && !Steam_CheckClientDLC(client, 459)) {
			strcopy(buffers[7], sizeof(buffers[]), "0");
		} else {
			strcopy(buffers[7], sizeof(buffers[]), "1");
		}
	}
	
	if(g_MOTDDisabled[client] != -1) {
		IntToString(g_MOTDDisabled[client], buffers[8], sizeof(buffers[]));
	}
	
	if(g_OS[client] == OS_Windows) {
		strcopy(buffers[9], sizeof(buffers[]), "Windows");
	} else if(g_OS[client] == OS_Mac) {
		strcopy(buffers[9], sizeof(buffers[]), "MacOS");
	} else if(g_OS[client] == OS_Linux) {
		strcopy(buffers[9], sizeof(buffers[]), "Linux");
	}
	
	for(new i = 0; i < sizeof(buffers); i++) {
		if(strlen(buffers[i]) == 0) {
			strcopy(buffers[i], sizeof(buffers[]), "NULL");
		} else {
#if !defined DEBUG
			SQL_EscapeString(g_DB, buffers[i], buffers[i], sizeof(buffers[]));
#endif
			Format(buffers[i], sizeof(buffers[]), "'%s'", buffers[i]);
		}
	}
	
	decl String:query[512];
	Format(query, sizeof(query), "INSERT INTO `player_analytics` SET server_ip = '%s', name = %s, auth = %s, connect_time = %d, connect_date = '%s', connect_method = %s, numplayers = %d, map = '%s', flags = '%s', ip = '%s', city = %s, region = %s, country = %s, country_code = %s, country_code3 = %s, premium = %s, html_motd_disabled = %s, os = %s",
		g_IP, buffers[0], buffers[1], g_ConnectTime[client], date, g_ConnectMethod[client], g_NumPlayers[client], map, flagstring, ip, buffers[2], buffers[3], buffers[4], buffers[5], buffers[6], buffers[7], buffers[8], buffers[9]);
	
#if !defined DEBUG
	SQL_TQuery(g_DB, OnRowInserted, query, GetClientUserId(client));
#else
	PrintToServer("%s", query);
#endif
	return Plugin_Stop;
}

GetRealClientCount() {
	new total = 0;
	for(new i = 1; i <= MaxClients; i++) {
		if(IsClientConnected(i) && !IsFakeClient(i)) {
			total++;
		}
	}
	return total; // Note that this value will include the client who's connecting. If you want to get the number of players in-game when they actually initiated their connection, decrement this by one.
}

#if !defined DEBUG
public OnRowInserted(Handle:owner, Handle:hndl, const String:error[], any:userid) {
	new client = GetClientOfUserId(userid);
	if(client == 0) {
		return;
	}
	
	if(hndl == INVALID_HANDLE) {
		LogError("Unable to insert row for client %L. %s", client, error);
		return;
	}
	
	g_RowID[client] = SQL_GetInsertId(hndl);
}
#endif

public OnClientDisconnect(client) {
	if(g_RowID[client] == -1 || g_ConnectTime[client] == 0) {
		g_ConnectTime[client] = 0;
		return;
	}
	
	decl String:query[256];
	Format(query, sizeof(query), "UPDATE `player_analytics` SET duration = %d WHERE id = %d", GetTime() - g_ConnectTime[client], g_RowID[client]);
#if !defined DEBUG
	SQL_TQuery(g_DB, OnRowUpdated, query, g_RowID[client]);
#else
	PrintToServer("%s", query);
#endif
	
	g_ConnectTime[client] = 0;
}

#if !defined DEBUG
public OnRowUpdated(Handle:owner, Handle:hndl, const String:error[], any:id) {
	if(hndl == INVALID_HANDLE) {
		LogError("Unable to update row %d. %s", id, error);
	}
}
#endif