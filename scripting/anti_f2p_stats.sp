#pragma semicolon 1

#include <sourcemod>

#define AUTOLOAD_EXTENSIONS
#define REQUIRE_EXTENSIONS
#include <steamtools>

#define PLUGIN_VERSION "1.5.2"

new String:logFile[1024];
new Handle:enabled = INVALID_HANDLE;
new Handle:log = INVALID_HANDLE;
new Handle:kickMessage = INVALID_HANDLE;
new Handle:db = INVALID_HANDLE;
new Handle:query = INVALID_HANDLE;

public Plugin:myinfo = {
	name        = "[TF2] Free2BeKicked with Stats",
	author      = "Dr. McKay",
	description = "Automatically kicks non-premium players and logs stats.",
	version     = PLUGIN_VERSION,
	url         = "http://www.doctormckay.com"
};

public OnPluginStart() {
	enabled = CreateConVar("anti_f2p_stats_enable", "1", "Free2BeKicked Stats enabled");
	log = CreateConVar("anti_f2p_stats_log", "1", "Should Free2BeKicked Stats log to a file?");
	kickMessage = CreateConVar("anti_f2p_stats_message", "You need a Premium TF2 account to play on this server", "Message displayed when an F2P is kicked");
	CreateConVar("anti_f2p_stats_version", PLUGIN_VERSION, "Free2BeKicked Stats", FCVAR_DONTRECORD|FCVAR_NOTIFY|FCVAR_CHEAT);
	RegAdminCmd("anti_f2p_stats", Command_PrintStats, ADMFLAG_ROOT, "Displays F2P kicking statistics");
	AutoExecConfig(true, "anti_f2p_stats");
	BuildPath(Path_SM, logFile, sizeof(logFile), "logs/anti_f2p_stats.log");
	new Handle:dbInfo = CreateKeyValues("anti_f2p_db_info", "driver", "sqlite");
	KvSetString(dbInfo, "database", "anti_f2p_stats");
	new String:error[255];
	db = SQL_ConnectCustom(dbInfo, error, sizeof(error), false);
	CloseHandle(dbInfo);
	if(db == INVALID_HANDLE) {
		LogError("Free2BeKicked Stats could not establish a connection to a local SQLite database. The error given was: %s", error);
	}
	if(db != INVALID_HANDLE) {
		if(!SQL_FastQuery(db, "CREATE TABLE IF NOT EXISTS stats (name TEXT, value INTEGER)")) {
			SQL_GetError(db, error, sizeof(error));
			LogError("Free2BeKicked Stats could not attempt to create the table 'stats'. The error given was: %s", error);
		}
		query = SQL_Query(db, "SELECT * FROM stats WHERE name = 'f2p_kicked'");
		if(SQL_GetRowCount(query) == 0) {
			SQL_FastQuery(db, "INSERT INTO stats VALUES ('f2p_kicked', 0)");
		}
		query = SQL_Query(db, "SELECT * FROM stats WHERE name = 'f2p_allowed'");
		if(SQL_GetRowCount(query) == 0) {
			SQL_FastQuery(db, "INSERT INTO stats VALUES ('f2p_allowed', 0)");
		}
	}
}

public OnClientPostAdminCheck(client) {
	if(GetConVarBool(enabled) && !IsFakeClient(client)) {
		decl String:steamId[32];
		GetClientAuthString(client, steamId, sizeof(steamId));
		if(Steam_CheckClientSubscription(client, 0) && !Steam_CheckClientDLC(client, 459)) {
			if(CheckCommandAccess(client, "BypassPremiumCheck", ADMFLAG_ROOT, true)) {
				if(GetConVarBool(log)) {
					LogToFileEx(logFile, "Player %N<%s> is F2P, but has bypassed the premium check.", client, steamId);
				}
				if(db != INVALID_HANDLE) {
					SQL_FastQuery(db, "UPDATE stats SET value = value + 1 WHERE name = 'f2p_allowed'");
				}
				return;
			}
			if(GetConVarBool(log)) {
				LogToFileEx(logFile, "Player %N<%s> is F2P, and has been kicked.", client, steamId);
			}
			if(db != INVALID_HANDLE) {
				SQL_FastQuery(db, "UPDATE stats SET value = value + 1 WHERE name = 'f2p_kicked'");
			}
			new String:message[1024];
			GetConVarString(kickMessage, message, sizeof(message));
			KickClient(client, message);
		}
	}
	return;
}

public Action:Command_PrintStats(client, args) {
	if(db == INVALID_HANDLE) {
		ReplyToCommand(client, "[SM] Error: there is no connection to the SQLite database.");
		return;
	} else {
		query = SQL_Query(db, "SELECT * FROM stats WHERE name = 'f2p_kicked'");
		new kicks = SQL_FetchInt(query, 1);
		CloseHandle(query);
		query = SQL_Query(db, "SELECT * FROM stats WHERE name = 'f2p_allowed'");
		new allows = SQL_FetchInt(query, 1);
		CloseHandle(query);
		ReplyToCommand(client, "[SM] To date, %i F2P clients have been kicked and %i F2P clients have bypassed the check.", kicks, allows);
		return;
	}
}