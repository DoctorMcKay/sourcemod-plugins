#pragma semicolon 1

#include <sourcemod>
#include <geoipcity>

#undef REQUIRE_EXTENSIONS
#include <steamtools>

#define PLUGIN_VERSION			"1.0.0"

#define IsClientF2P(%1)			(Steam_CheckClientSubscription(%1, 0) && !Steam_CheckClientDLC(%1, 459))

public Plugin:myinfo = {
	name        = "[ANY] City Bans",
	author      = "Dr. McKay",
	description = "Allows for players to be banned based on their city",
	version     = PLUGIN_VERSION,
	url         = "http://www.doctormckay.com"
};

#define UPDATE_FILE		"citybans.txt"
#define CONVAR_PREFIX	"city_bans"

#include "mckayupdater.sp"

new Handle:cvarBanF2P;
new Handle:cvarBanMessage;

new Handle:db;
new bool:isTF;
new bool:steamToolsLoaded;

public APLRes:AskPluginLoad2(Handle:myself, bool:late, String:error[], err_max) {
	if(SQL_CheckConfig("citybans")) {
		db = SQL_Connect("citybans", true, error, err_max);
	} else if(SQL_CheckConfig("default")) {
		db = SQL_Connect("default", true, error, err_max);
	} else {
		strcopy(error, err_max, "No database configuration named 'citybans' or 'default' was found");
		return APLRes_Failure;
	}
	
	if(db == INVALID_HANDLE) {
		return APLRes_Failure; // SQL_Connect already filled out the error buffer
	}
	
	decl String:driver[64];
	SQL_ReadDriver(db, driver, sizeof(driver));
	if(StrEqual(driver, "MySQL", false)) {
		SQL_TQuery(db, OnTableCreated, "CREATE TABLE IF NOT EXISTS `citybans` (id INT(11) NOT NULL AUTO_INCREMENT, city VARCHAR(45) NOT NULL, country VARCHAR(45), PRIMARY KEY (id))");
	} else {
		SQL_TQuery(db, OnTableCreated, "CREATE TABLE IF NOT EXISTS `citybans` (id INTEGER PRIMARY KEY AUTOINCREMENT, city VARCHAR(45), country VARCHAR(45))");
	}
	return APLRes_Success;
}

public OnPluginStart() {
	decl String:gamefolder[64];
	GetGameFolderName(gamefolder, sizeof(gamefolder));
	isTF = StrEqual(gamefolder, "tf");
	
	cvarBanF2P = CreateConVar("city_bans_f2p", "1", "Only ban Free2Play accounts from banned cities (TF2 only, requires SteamTools)");
	cvarBanMessage = CreateConVar("city_bans_message", "You have been banned", "Message to display to city-banned players. A period will be automatically appended by the game.");
	
	RegAdminCmd("sm_bancity", Command_BanCity, ADMFLAG_BAN, "Bans a player by their city");
	RegAdminCmd("sm_listbannedcities", Command_ListBannedCities, ADMFLAG_UNBAN, "Lists all currently banned cities");
	RegAdminCmd("sm_unbancity", Command_UnbanCity, ADMFLAG_UNBAN, "Unbans a city");
	
	LoadTranslations("common.phrases");
}

public OnTableCreated(Handle:owner, Handle:hndl, const String:error[], any:data) {
	if(hndl == INVALID_HANDLE) {
		SetFailState("Unable to create table. %s", error);
	}
}

public Steam_FullyLoaded() {
	steamToolsLoaded = true;
}

public Steam_Shutdown() {
	steamToolsLoaded = false;
}

public OnClientPostAdminCheck(client) {
	if(IsFakeClient(client) || (isTF && steamToolsLoaded && GetConVarBool(cvarBanF2P) && !IsClientF2P(client)) || CheckCommandAccess(client, "BypassCityBan", ADMFLAG_ROOT)) {
		return;
	}
	decl String:ip[32], String:city[45], String:region[45], String:country_name[45], String:country_code[3], String:country_code3[4];
	GetClientIP(client, ip, sizeof(ip));
	if(!GeoipGetRecord(ip, city, region, country_name, country_code, country_code3)) {
		LogError("Unable to get GeoIP record for %L (IP %s)", client, ip);
		return;
	}
	
	decl String:query[256], String:cityESC[91], String:countryESC[91];
	SQL_EscapeString(db, city, cityESC, sizeof(cityESC));
	SQL_EscapeString(db, country_name, countryESC, sizeof(countryESC));
	Format(query, sizeof(query), "SELECT NULL FROM `citybans` WHERE city = '%s' AND country = '%s'", cityESC, countryESC);
	SQL_TQuery(db, OnUserChecked, query, GetClientUserId(client));
}

public OnUserChecked(Handle:owner, Handle:hndl, const String:error[], any:userid) {
	new client = GetClientOfUserId(userid);
	if(client == 0) {
		return;
	}
	
	if(hndl == INVALID_HANDLE) {
		LogError("Unable to check %L. %s", client, error);
		return;
	}
	
	if(SQL_GetRowCount(hndl) > 0) {
		decl String:message[256];
		GetConVarString(cvarBanMessage, message, sizeof(message));
		KickClient(client, "%s", message);
	}
}

public Action:Command_BanCity(client, args) {
	if(args != 1) {
		ReplyToCommand(client, "\x04[SM] \x01Usage: sm_bancity <target>");
		return Plugin_Handled;
	}
	
	decl String:arg1[MAX_NAME_LENGTH];
	GetCmdArg(1, arg1, sizeof(arg1));
	new target = FindTarget(client, arg1, true);
	if(target == -1) {
		return Plugin_Handled;
	}
	
	decl String:ip[64], String:city[45], String:region[45], String:country_name[45], String:country_code[3], String:country_code3[4];
	GetClientIP(target, ip, sizeof(ip));
	if(!GeoipGetRecord(ip, city, region, country_name, country_code, country_code3)) {
		ReplyToCommand(client, "\x04[SM] \x01Unable to get city information for %N.", target);
		return Plugin_Handled;
	}
	
	decl String:cityESC[91], String:countryESC[91], String:query[256];
	SQL_EscapeString(db, city, cityESC, sizeof(cityESC));
	SQL_EscapeString(db, country_name, countryESC, sizeof(countryESC));
	Format(query, sizeof(query), "SELECT NULL FROM `citybans` WHERE city = '%s' AND country = '%s'", cityESC, countryESC);
	
	new Handle:pack = CreateDataPack();
	if(client == 0) {
		WritePackCell(pack, 0);
	} else {
		WritePackCell(pack, GetClientUserId(client));
	}
	WritePackCell(pack, _:GetCmdReplySource());
	WritePackCell(pack, GetClientUserId(target));
	WritePackString(pack, city);
	WritePackString(pack, country_name);
	SQL_TQuery(db, OnBanChecked, query, pack);
	return Plugin_Handled;
}

public OnBanChecked(Handle:owner, Handle:hndl, const String:error[], any:pack) {
	ResetPack(pack);
	new userid = ReadPackCell(pack);
	new ReplySource:reply = ReplySource:ReadPackCell(pack);
	new target = GetClientOfUserId(ReadPackCell(pack));
	decl String:city[45], String:country[45];
	ReadPackString(pack, city, sizeof(city));
	ReadPackString(pack, country, sizeof(country));
	CloseHandle(pack);
	
	if(hndl == INVALID_HANDLE) {
		LogError("Unable to check ban for '%s, %s'. %s", city, country, error);
		new client = GetClientOfUserId(userid);
		if(userid != 0 && client == 0) {
			SetCmdReplySource(reply);
			ReplyToCommand(client, "\x04[SM] \x01Unable to ban %N.", target);
		}
		return;
	}
	
	if(target == 0) {
		return;
	}
	
	new client = GetClientOfUserId(userid);
	if(userid != 0 && client == 0) {
		return;
	}
	
	if(SQL_GetRowCount(hndl) > 0) {
		SetCmdReplySource(reply);
		ReplyToCommand(client, "\x04[SM] \x03%N\x01's city is already banned.", target);
		return;
	}
	
	decl String:message[256], String:query[256];
	GetConVarString(cvarBanMessage, message, sizeof(message));
	KickClient(target, "%s", message);
	
	pack = CreateDataPack();
	WritePackString(pack, city);
	WritePackString(pack, country);
	decl String:cityESC[91], String:countryESC[91];
	SQL_EscapeString(db, city, cityESC, sizeof(cityESC));
	SQL_EscapeString(db, country, countryESC, sizeof(countryESC));
	Format(query, sizeof(query), "INSERT INTO `citybans` (city, country) VALUES ('%s', '%s')", cityESC, countryESC);
	SQL_TQuery(db, OnBanInserted, query, pack);
	
	LogAction(client, target, "%L has city-banned %L. City: %s, %s", client, target, city, country);
	ShowActivity2(client, "\x04[SM] \x03", "\x01Banned %N by city: \x03%s, %s", target, city, country);
}

public OnBanInserted(Handle:owner, Handle:hndl, const String:error[], any:pack) {
	if(hndl == INVALID_HANDLE) {
		ResetPack(pack);
		decl String:city[45], String:country[45];
		ReadPackString(pack, city, sizeof(city));
		ReadPackString(pack, country, sizeof(country));
		LogError("Unable to insert city ban for %s, %s. %s", city, country, error);
	}
	CloseHandle(pack);
}

public Action:Command_ListBannedCities(client, args) {
	new Handle:pack = CreateDataPack();
	if(client == 0) {
		WritePackCell(pack, 0);
	} else {
		WritePackCell(pack, GetClientUserId(client));
	}
	WritePackCell(pack, _:GetCmdReplySource());
	SQL_TQuery(db, OnBansReceived, "SELECT id, city, country FROM `citybans` ORDER BY id ASC", pack);
	return Plugin_Handled;
}

public OnBansReceived(Handle:owner, Handle:hndl, const String:error[], any:pack) {
	ResetPack(pack);
	new userid = ReadPackCell(pack);
	new ReplySource:reply = ReplySource:ReadPackCell(pack);
	new bool:replyToChat = (reply == SM_REPLY_TO_CHAT);
	CloseHandle(pack);
	
	if(hndl == INVALID_HANDLE) {
		LogError("Unable to retreive ban list. %s", error);
		new client = GetClientOfUserId(userid);
		if(userid != 0 && client == 0) {
			return;
		}
		SetCmdReplySource(reply);
		ReplyToCommand(client, "\x04[SM] \x01An error occurred. Unable to retreive ban list.");
		return;
	}
	
	new client = GetClientOfUserId(userid);
	if(userid != 0 && client == 0) {
		return;
	}
	
	if(SQL_GetRowCount(hndl) == 0) {
		ReplyToCommand(client, "\x04[SM] \x01No cities are banned.");
		return;
	}
	
	if(client != 0 && replyToChat) {
		PrintToChat(client, "\x04[SM] \x01See console for output.");
	}
	
	decl String:city[45], String:country[45];
	while(SQL_FetchRow(hndl)) {
		SQL_FetchString(hndl, 1, city, sizeof(city));
		SQL_FetchString(hndl, 2, country, sizeof(country));
		if(client == 0) {
			PrintToServer("[%d] %s, %s", SQL_FetchInt(hndl, 0), city, country);
		} else {
			PrintToConsole(client, "[%d] %s, %s", SQL_FetchInt(hndl, 0), city, country);
		}
	}
}

public Action:Command_UnbanCity(client, args) {
	if(args != 1) {
		ReplyToCommand(client, "\x04[SM] \x01Usage: sm_unbancity <id>");
		return Plugin_Handled;
	}
	
	decl String:arg1[32];
	GetCmdArg(1, arg1, sizeof(arg1));
	
	new Handle:pack = CreateDataPack();
	if(client == 0) {
		WritePackCell(pack, 0);
	} else {
		WritePackCell(pack, GetClientUserId(client));
	}
	WritePackCell(pack, StringToInt(arg1));
	WritePackCell(pack, _:GetCmdReplySource());
	decl String:query[256];
	Format(query, sizeof(query), "SELECT city, country FROM `citybans` WHERE id = '%d'", StringToInt(arg1));
	SQL_TQuery(db, OnBanDeleteChecked, query, pack);
	return Plugin_Handled;
}

public OnBanDeleteChecked(Handle:owner, Handle:hndl, const String:error[], any:pack) {
	ResetPack(pack);
	new userid = ReadPackCell(pack);
	new id = ReadPackCell(pack);
	new ReplySource:reply = ReplySource:ReadPackCell(pack);
	CloseHandle(pack);
	
	if(hndl == INVALID_HANDLE) {
		LogError("Unable to query ban to delete. %s", error);
		new client = GetClientOfUserId(userid);
		if(userid != 0 && client == 0) {
			return;
		}
		SetCmdReplySource(reply);
		ReplyToCommand(client, "\x04[SM] \x01An error occurred while deleting the ban.");
		return;
	}
	
	new client = GetClientOfUserId(userid);
	
	if(userid != 0 && client == 0) {
		return;
	}
	
	SetCmdReplySource(reply);
	
	if(!SQL_FetchRow(hndl)) {
		ReplyToCommand(client, "\x04[SM] \x01No ban with that ID was found.");
		return;
	}
	
	decl String:query[256];
	Format(query, sizeof(query), "DELETE FROM `citybans` WHERE id = '%d'", id);
	SQL_TQuery(db, OnBanDeleted, query);
	
	decl String:city[45], String:country[45];
	SQL_FetchString(hndl, 0, city, sizeof(city));
	SQL_FetchString(hndl, 1, country, sizeof(country));
	
	LogAction(client, -1, "%L deleted ban #%d for %s, %s", client, id, city, country);
	ShowActivity2(client, "\x04[SM] \x03", "\x01Deleted ban for %s, %s", city, country);
}

public OnBanDeleted(Handle:owner, Handle:hndl, const String:error[], any:data) {
	if(hndl == INVALID_HANDLE) {
		LogError("Unable to delete ban. %s", error);
	}
}