#pragma semicolon 1

#include <sourcemod>
#include <ccc>

#undef REQUIRE_PLUGIN
#include <updater>

#define UPDATE_URL			"http://hg.doctormckay.com/public-plugins/raw/default/chatcolorsmysqlmodule.txt"
#define PLUGIN_VERSION		"1.1.3"

public Plugin:myinfo = {
	name        = "[Source 2009] Custom Chat Colors MySQL Module",
	author      = "Dr. McKay",
	description = "Allows for Custom Chat Colors to be configured via MySQL",
	version     = PLUGIN_VERSION,
	url         = "http://www.doctormckay.com"
};

new Handle:cvarUpdater;

new Handle:kv;

public OnPluginStart() {
	cvarUpdater = CreateConVar("ccc_mysql_auto_update", "1", "Enables automatic updating (has no effect if Updater is not installed)");
	RegAdminCmd("sm_ccc_mysql_dump", Command_DumpData, ADMFLAG_ROOT, "DEBUG: Dumps cached data");
	CCC_OnConfigReloaded();
}

public CCC_OnConfigReloaded() {
	if(SQL_CheckConfig("custom-chatcolors")) {
		SQL_TConnect(OnDatabaseConnected, "custom-chatcolors");
	} else if(SQL_CheckConfig("default")) {
		SQL_TConnect(OnDatabaseConnected, "default");
	} else {
		SetFailState("No database configuration \"custom-chatcolors\" or \"default\" found.");
	}
}

public OnDatabaseConnected(Handle:owner, Handle:hndl, const String:error[], any:data) {
	if(hndl == INVALID_HANDLE) {
		if(kv == INVALID_HANDLE) {
			SetFailState("Unable to connect to database. %s", error);
		} else {
			LogError("Unable to connect to database. Falling back to saved values. %s", error);
			return;
		}
	}
	if(kv == INVALID_HANDLE) {
		SQL_TQuery(hndl, OnTableCreated, "CREATE TABLE IF NOT EXISTS `custom_chatcolors` (`index` int(11) NOT NULL, `identity` varchar(32) NOT NULL, `flag` char(1) DEFAULT NULL, `tag` varchar(32) DEFAULT NULL, `tagcolor` varchar(8) DEFAULT NULL, `namecolor` varchar(8) DEFAULT NULL, `textcolor` varchar(8) DEFAULT NULL, PRIMARY KEY (`index`), UNIQUE KEY `identity` (`identity`)) ENGINE=MyISAM DEFAULT CHARSET=latin1", hndl);
	} else {
		SQL_TQuery(hndl, OnDataReceived, "SELECT * FROM `custom_chatcolors` ORDER BY `index` ASC", hndl);
	}
}

public OnTableCreated(Handle:owner, Handle:hndl, const String:error[], any:db) {
	if(hndl == INVALID_HANDLE) {
		CloseHandle(db);
		SetFailState("Error creating database table. %s", error);
	}
	SQL_TQuery(db, OnDataReceived, "SELECT * FROM `custom_chatcolors` ORDER BY `index` ASC", db);
}

public OnDataReceived(Handle:owner, Handle:hndl, const String:error[], any:db) {
	if(hndl == INVALID_HANDLE) {
		if(kv == INVALID_HANDLE) {
			CloseHandle(db);
			SetFailState("Unable to query database. %s", error);
		} else {
			CloseHandle(db);
			LogError("Unable to query database. Falling back to saved values. %s", error);
			return;
		}
	}
	if(kv != INVALID_HANDLE) {
		CloseHandle(kv);
	}
	kv = CreateKeyValues("admin_colors");
	decl String:identity[33], String:flag[2], String:tag[33], String:tagcolor[12], String:namecolor[12], String:textcolor[12];
	while(SQL_FetchRow(hndl)) {
		// index	identity	flag	tag		tagcolor	namecolor	textcolor
		// 0		1			2		3		4			5			6
		SQL_FetchString(hndl, 1, identity, sizeof(identity));
		SQL_FetchString(hndl, 2, flag, sizeof(flag));
		SQL_FetchString(hndl, 3, tag, sizeof(tag));
		SQL_FetchString(hndl, 4, tagcolor, sizeof(tagcolor));
		SQL_FetchString(hndl, 5, namecolor, sizeof(namecolor));
		SQL_FetchString(hndl, 6, textcolor, sizeof(textcolor));
		KvJumpToKey(kv, identity, true);
		if(StrContains(identity, "STEAM_") != 0 && strlen(flag) > 0) {
			KvSetString(kv, "flag", flag);
		}
		if(strlen(tag) > 0) {
			KvSetString(kv, "tag", tag);
		}
		if(strlen(tagcolor) == 6 || strlen(tagcolor) == 8 || StrEqual(tagcolor, "O", false) || StrEqual(tagcolor, "G", false) || StrEqual(tagcolor, "T", false)) {
			if(strlen(tagcolor) > 1) {
				Format(tagcolor, sizeof(tagcolor), "#%s", tagcolor);
			}
			KvSetString(kv, "tagcolor", tagcolor);
		}
		if(strlen(namecolor) == 6 || strlen(namecolor) == 8 || StrEqual(namecolor, "O", false) || StrEqual(namecolor, "G", false) || StrEqual(namecolor, "T", false)) {
			if(strlen(namecolor) > 1) {
				Format(namecolor, sizeof(namecolor), "#%s", namecolor);
			}
			KvSetString(kv, "namecolor", namecolor);
		}
		if(strlen(textcolor) == 6 || strlen(textcolor) == 8 || StrEqual(textcolor, "O", false) || StrEqual(textcolor, "G", false) || StrEqual(textcolor, "T", false)) {
			if(strlen(textcolor) > 1) {
				Format(textcolor, sizeof(textcolor), "#%s", textcolor);
			}
			KvSetString(kv, "textcolor", textcolor);
		}
		KvRewind(kv);
	}
	CloseHandle(db); // Close database connection
}

public Action:Command_DumpData(client, args) {
	if(kv == INVALID_HANDLE) {
		ReplyToCommand(client, "\x04[CCC] \x01No data is currently loaded.");
		return Plugin_Handled;
	}
	decl String:path[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, path, sizeof(path), "data/custom-chatcolors-mysql-dump.txt");
	KeyValuesToFile(kv, path);
	ReplyToCommand(client, "\x04[CCC] \x01Loaded data has been dumped to %s", path);
	return Plugin_Handled;
}

public CCC_OnUserConfigLoaded(client) {
	if(kv == INVALID_HANDLE) {
		// Database not ready yet, let's wait till it is
		CreateTimer(5.0, Timer_CheckDatabase, GetClientUserId(client), TIMER_REPEAT);
		return;
	}
	decl String:auth[32];
	GetClientAuthString(client, auth, sizeof(auth));
	KvRewind(kv);
	if(!KvJumpToKey(kv, auth)) {
		KvRewind(kv);
		KvGotoFirstSubKey(kv);
		new AdminId:admin = GetUserAdmin(client);
		new AdminFlag:flag;
		decl String:configFlag[2];
		decl String:section[32];
		new bool:found = false;
		do {
			KvGetSectionName(kv, section, sizeof(section));
			KvGetString(kv, "flag", configFlag, sizeof(configFlag));
			if(StrEqual(configFlag, "") && StrContains(section, "STEAM_", false) == -1) {
				found = true;
				break;
			}
			if(!FindFlagByChar(configFlag[0], flag)) {
				if(strlen(configFlag) > 0) {
					LogError("Invalid flag given for identity \"%s\"", section);
				}
				continue;
			}
			if(GetAdminFlag(admin, flag)) {
				found = true;
				break;
			}
		} while(KvGotoNextKey(kv));
		if(!found) {
			return;
		}
	}
	decl String:clientTag[32];
	decl String:clientTagColor[12];
	decl String:clientNameColor[12];
	decl String:clientChatColor[12];
	KvGetString(kv, "tag", clientTag, sizeof(clientTag));
	KvGetString(kv, "tagcolor", clientTagColor, sizeof(clientTagColor));
	KvGetString(kv, "namecolor", clientNameColor, sizeof(clientNameColor));
	KvGetString(kv, "textcolor", clientChatColor, sizeof(clientChatColor));
	ReplaceString(clientTagColor, sizeof(clientTagColor), "#", "");
	ReplaceString(clientNameColor, sizeof(clientNameColor), "#", "");
	ReplaceString(clientChatColor, sizeof(clientChatColor), "#", "");
	new tagLen = strlen(clientTagColor);
	new nameLen = strlen(clientNameColor);
	new chatLen = strlen(clientChatColor);
	new color;
	if(strlen(clientTag) > 0) {
		CCC_SetTag(client, clientTag);
	}
	if(tagLen == 6 || tagLen == 8 || StrEqual(clientTagColor, "T", false) || StrEqual(clientTagColor, "G", false) || StrEqual(clientTagColor, "O", false)) {
		if(StrEqual(clientTagColor, "T", false)) {
			color = COLOR_TEAM;
		} else if(StrEqual(clientTagColor, "G", false)) {
			color = COLOR_GREEN;
		} else if(StrEqual(clientTagColor, "O", false)) {
			color = COLOR_OLIVE;
		} else {
			color = StringToInt(clientTagColor, 16);
		}
		CCC_SetColor(client, CCC_TagColor, color, tagLen == 8); // tagLen == 8 evaluates to true if alpha is specified
	}
	if(nameLen == 6 || nameLen == 8 || StrEqual(clientNameColor, "G", false) || StrEqual(clientNameColor, "O", false)) {
		if(StrEqual(clientNameColor, "G", false)) {
			color = COLOR_GREEN;
		} else if(StrEqual(clientNameColor, "O", false)) {
			color = COLOR_OLIVE;
		} else {
			color = StringToInt(clientNameColor, 16);
		}
		CCC_SetColor(client, CCC_NameColor, color, nameLen == 8);
	}
	if(chatLen == 6 || chatLen == 8 || StrEqual(clientChatColor, "T", false) || StrEqual(clientChatColor, "G", false) || StrEqual(clientChatColor, "O", false)) {
		if(StrEqual(clientChatColor, "T", false)) {
			color = COLOR_TEAM;
		} else if(StrEqual(clientChatColor, "G", false)) {
			color = COLOR_GREEN;
		} else if(StrEqual(clientChatColor, "O", false)) {
			color = COLOR_OLIVE;
		} else {
			color = StringToInt(clientChatColor, 16);
		}
		CCC_SetColor(client, CCC_ChatColor, color, chatLen == 8);
	}
}

public Action:Timer_CheckDatabase(Handle:timer, any:userid) {
	new client = GetClientOfUserId(userid);
	if(client == 0) {
		return Plugin_Stop;
	}
	if(kv == INVALID_HANDLE) {
		return Plugin_Continue;
	}
	CCC_OnUserConfigLoaded(client);
	return Plugin_Stop;
}

/////////////////////////////////

public OnAllPluginsLoaded() {
	new Handle:convar;
	if(LibraryExists("updater")) {
		Updater_AddPlugin(UPDATE_URL);
		decl String:version[12];
		Format(version, sizeof(version), "%sA", PLUGIN_VERSION);
		convar = CreateConVar("custom_chat_colors_mysql_version", version, "Custom Chat Colors MySQL Module Version", FCVAR_DONTRECORD|FCVAR_NOTIFY|FCVAR_CHEAT);
	} else {
		convar = CreateConVar("custom_chat_colors_mysql_version", PLUGIN_VERSION, "Custom Chat Colors MySQL Module Version", FCVAR_DONTRECORD|FCVAR_NOTIFY|FCVAR_CHEAT);	
	}
	HookConVarChange(convar, Callback_VersionConVarChanged);
	Callback_VersionConVarChanged(convar, "", ""); // Check the cvar value
}

public OnLibraryAdded(const String:name[]) {
	if(StrEqual(name, "updater")) {
		Updater_AddPlugin(UPDATE_URL);
	}
}

public Callback_VersionConVarChanged(Handle:convar, const String:oldValue[], const String:newValue[]) {
	if(LibraryExists("updater")) {
		decl String:version[12];
		Format(version, sizeof(version), "%sA", PLUGIN_VERSION);
		SetConVarString(convar, version);
	} else {
		SetConVarString(convar, PLUGIN_VERSION);
	}
}

public Action:Updater_OnPluginDownloading() {
	if(!GetConVarBool(cvarUpdater)) {
		return Plugin_Handled;
	}
	return Plugin_Continue;
}

public Updater_OnPluginUpdated() {
	ReloadPlugin();
}