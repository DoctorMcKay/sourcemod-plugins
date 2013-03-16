#pragma semicolon 1

#define REQUIRE_EXTENSIONS
#include <sourcemod>
#include <colors>
#include <socket> // Compiled with this version of colors.inc: https://forums.alliedmods.net/showpost.php?p=1883578&postcount=311
#include <clientprefs>

#define PLUGIN_VERSION "2.5.1"

new Handle:advertCvar;
new Handle:joinAdvertCvar;
new Handle:djUrlCvar;
new Handle:djUrlPortCvar;
new Handle:helpAdvertCvar;
new Handle:authKeyCvar;
new Handle:defaultRepeatCvar;
new Handle:defaultShuffleCvar;
new Handle:debugCvar;

new Handle:songMenu;
new Handle:songTitles;
new Handle:songIds;
new Handle:playlistIds;
new Handle:playlistNames;
new Handle:playlistSteamIds;
new Handle:playlistSongs;

new Handle:repeatCookie;
new Handle:shuffleCookie;

new bool:warningShown[MAXPLAYERS + 1];
new bool:advertShown[MAXPLAYERS + 1];
new bool:capturingPlaylistName[MAXPLAYERS + 1];
new bool:configsExecuted;

new Handle:hudText;

new Handle:playlistArray[MAXPLAYERS + 1];
new String:newPlaylistName[MAXPLAYERS + 1][33];

new Handle:forwardOnStartListen;

new songToPlay[MAXPLAYERS + 1];

public Plugin:myinfo = {
	name        = "[ANY] SourceMod DJ",
	author      = "Dr. McKay",
	description = "Allows users to choose music to listen to",
	version     = PLUGIN_VERSION,
	url         = "http://www.doctormckay.com"
};

public APLRes:AskPluginLoad2(Handle:myself, bool:late, String:error[], err_max) {
	MarkNativeAsOptional("GetUserMessageType"); // For colors.inc
	return APLRes_Success;
}

public OnPluginStart() {
	RegConsoleCmd("sm_dj", Command_MusicMenu, "Listen to music");
	RegConsoleCmd("sm_jukebox", Command_MusicMenu, "Listen to music");
	RegConsoleCmd("sm_music", Command_MusicMenu, "Listen to music");
	RegConsoleCmd("sm_randomsong", Command_RandomSong, "Plays a random song");
	RegConsoleCmd("sm_songlist", Command_SongList, "Displays an advanced list of songs");
	RegConsoleCmd("sm_musicoff", Command_MusicOff, "Turn off music");
	RegConsoleCmd("sm_musicinfo", Command_MusicInfo, "Displays info and controls about your current music");
	RegConsoleCmd("sm_musichelp", Command_MusicHelp, "Display Adobe Flash help");
	RegAdminCmd("sm_reloadsongs", Command_ReloadSongs, ADMFLAG_RCON, "Reloads the songs list for SourceMod DJ");
	RegAdminCmd("smdj_debug_dumparrays", Command_Debug_DumpArrays, ADMFLAG_ROOT, "DEBUG: Dumps the arrays to a file");
	AddCommandListener(Command_Say, "say");
	AddCommandListener(Command_Say, "say_team");
	advertCvar = CreateConVar("smdj_advert", "1", "Sets whether a user's music choice will be broadcast to the server");
	joinAdvertCvar = CreateConVar("smdj_join_advert", "1", "Sets whether a user will be informed about SMDJ's usage upon joining");
	djUrlCvar = CreateConVar("smdj_url", "", "The URL to your SMDJ Web installation. The proper value of this variable is displayed in the admin panel of your Web installation.");
	djUrlPortCvar = CreateConVar("smdj_url_port", "80", "If your web installation is hosted on a different port, set it here");
	authKeyCvar = CreateConVar("smdj_auth_token", "", "The auth token displayed in the admin panel of your SMDJ Web installation", FCVAR_PROTECTED);
	helpAdvertCvar = CreateConVar("smdj_help_advert", "1", "Sets whether a user is notified how to install Flash when they pick their first song");
	defaultRepeatCvar = CreateConVar("smdj_repeat_default", "1", "Whether repeat should be enabled or disabled for new clients");
	defaultShuffleCvar = CreateConVar("smdj_shuffle_default", "0", "Whether shuffle should be enabled or disabled for new clients");
	debugCvar = CreateConVar("smdj_debug", "0", "Set to 1 for debugging", FCVAR_DONTRECORD);
	new Handle:version = CreateConVar("smdj_version", PLUGIN_VERSION, "SourceMod DJ Version", FCVAR_DONTRECORD|FCVAR_NOTIFY|FCVAR_CHEAT);
	HookConVarChange(version, Callback_VersionChanged);
	AutoExecConfig();
	HookEvent("player_spawn", Event_PlayerSpawn);
	songTitles = CreateArray(33);
	songIds = CreateArray();
	playlistIds = CreateArray();
	playlistNames = CreateArray(33);
	playlistSteamIds = CreateArray(33);
	playlistSongs = CreateArray(1024);
	repeatCookie = RegClientCookie("smdj_repeat", "", CookieAccess_Private);
	shuffleCookie = RegClientCookie("smdj_shuffle", "", CookieAccess_Private);
	TagsCheck("SMDJ");
	HookConVarChange(FindConVar("sv_tags"), Callback_TagsChanged);
	hudText = CreateHudSynchronizer();
	forwardOnStartListen = CreateGlobalForward("SMDJ_OnStartListen", ET_Ignore, Param_Cell, Param_String);
	LoadTranslations("common.phrases");
}

public Callback_TagsChanged(Handle:convar, const String:oldValue[], const String:newValue[]) {
	TagsCheck("SMDJ");
}

public Callback_VersionChanged(Handle:convar, const String:oldValue[], const String:newValue[]) {
	decl String:defaultValue[32];
	GetConVarDefault(convar, defaultValue, sizeof(defaultValue));
	if(!StrEqual(newValue, defaultValue)) {
		SetConVarString(convar, defaultValue);
	}
}

public OnConfigsExecuted() {
	configsExecuted = true;
	LoadSongs();
}

public OnMapStart() {
	if(configsExecuted) {
		LoadSongs();
	}
}

public OnClientPutInServer(client) {
	warningShown[client] = false;
	advertShown[client] = false;
	capturingPlaylistName[client] = false;
	if(playlistArray[client] != INVALID_HANDLE) {
		CloseHandle(playlistArray[client]);
		playlistArray[client] = INVALID_HANDLE;
	}
}

public OnClientCookiesCached(client) {
	decl String:value[8];
	GetClientCookie(client, repeatCookie, value, sizeof(value));
	if(!StrEqual(value, "0") && !StrEqual(value, "1")) {
		GetConVarString(defaultRepeatCvar, value, sizeof(value));
		SetClientCookie(client, repeatCookie, value);
	}
	GetClientCookie(client, shuffleCookie, value, sizeof(value));
	if(!StrEqual(value, "0") && !StrEqual(value, "1")) {
		GetConVarString(defaultShuffleCvar, value, sizeof(value));
		SetClientCookie(client, shuffleCookie, value);
	}
}

public Action:Command_SongList(client, args) {
	if(client == 0) {
		ReplyToCommand(client, "[SMDJ] This command can only be used from in-game.");
		return Plugin_Handled;
	}
	decl String:url[256], String:repeat[8];
	GetConVarString(djUrlCvar, url, sizeof(url));
	ReplaceString(url, sizeof(url), "http://", "", false);
	ReplaceString(url, sizeof(url), "https://", "", false);
	decl String:parts[16][64];
	new String:path[256];
	new total = ExplodeString(url, "/", parts, sizeof(parts), sizeof(parts[]));
	for(new i = 1; i < total; i++) {
		Format(path, sizeof(path), "/%s", parts[i]);
	}
	GetClientCookie(client, repeatCookie, repeat, sizeof(repeat));
	Format(url, sizeof(url), "http://%s:%i%s/index.php?repeat=%s", parts[0], GetConVarInt(djUrlPortCvar), path, repeat);
	ShowMOTDPanel(client, "SMDJ", url, MOTDPANEL_TYPE_URL);
	return Plugin_Handled;
}

public Event_PlayerSpawn(Handle:event, const String:name[], bool:dontBroadcast) {
	if(!GetConVarBool(joinAdvertCvar)) {
		return;
	}
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	if(advertShown[client] || !IsClientConnected(client) || !IsClientInGame(client) || IsFakeClient(client)) {
		return;
	}
	CPrintToChat(client, "{green}[SMDJ] {default}This server is running SourceMod DJ. Type {olive}!dj {default}or {olive}!music {default}in chat to choose a song.");
	advertShown[client] = true;
}

public Action:Command_RandomSong(client, args) {
	if(songMenu == INVALID_HANDLE) {
		CPrintToChat(client, "{green}[SMDJ] {default}There are no songs to play.");
		return Plugin_Handled;
	}
	PlaySong(client, GetArrayCell(songIds, GetRandomInt(0, GetArraySize(songIds) - 1)));
	return Plugin_Handled;
}

public Action:Command_MusicOff(client, args) {
	if(client == 0) {
		ReplyToCommand(client, "[SMDJ] This command can only be used from in-game.");
		return Plugin_Handled;
	}
	OpenURL(client, -1);
	return Plugin_Handled;
}

public Action:Command_MusicMenu(client, args) {
	if(client == 0) {
		ReplyToCommand(client, "[SMDJ] This command can only be used from in-game.");
		return Plugin_Handled;
	}
	if(!AreClientCookiesCached(client)) {
		ReplyToCommand(client, "\x04[SMDJ] \x01SMDJ is not ready yet.");
		return Plugin_Handled;
	}
	if(playlistArray[client] != INVALID_HANDLE) {
		NewPlaylistMenu(client);
		return Plugin_Handled;
	}
	if(args != 0) {
		decl String:title[33];
		GetCmdArgString(title, sizeof(title));
		new index = -1;
		new size = GetArraySize(songTitles);
		decl String:compare[33];
		for(new i = 0; i < size; i++) {
			GetArrayString(songTitles, i, compare, sizeof(compare)); // FindStringInArray is case sensitive :/
			if(StrEqual(title, compare, false)) {
				index = i;
				break;
			}
		}
		if(index == -1) {
			CPrintToChat(client, "{green}[SMDJ] {default}The requested song title was not found.");
			return Plugin_Handled;
		} else {
			PlaySong(client, index);
			return Plugin_Handled;
		}
	}
	if(songMenu == INVALID_HANDLE) {
		CPrintToChat(client, "{green}[SMDJ] {default}There are no songs to display.");
		return Plugin_Handled;
	}
	decl String:value[8], String:repeat[32];
	GetClientCookie(client, repeatCookie, value, sizeof(value));
	if(StrEqual(value, "1")) {
		Format(repeat, sizeof(repeat), "Repeat is ON");
	} else {
		Format(repeat, sizeof(repeat), "Repeat is OFF");
	}
	new Handle:menu = CreateMenu(Handler_TopMenu);
	SetMenuTitle(menu, "SourceMod DJ");
	AddMenuItem(menu, "songList", "Song List");
	AddMenuItem(menu, "shuffleAll", "Shuffle All");
	AddMenuItem(menu, "playlists", "Playlists");
	AddMenuItem(menu, "random", "Random Song");
	AddMenuItem(menu, "info", "Music Info");
	AddMenuItem(menu, "stopMusic", "Stop Music");
	AddMenuItem(menu, "repeat", repeat);
	if(CheckCommandAccess(client, "SMDJPlayToOthers", ADMFLAG_SLAY)) {
		AddMenuItem(menu, "playToOthers", "Play to Others");
	}
	SetMenuPagination(menu, MENU_NO_PAGINATION);
	SetMenuExitButton(menu, true);
	DisplayMenu(menu, client, 0);
	return Plugin_Handled;
}

public Handler_TopMenu(Handle:menu, MenuAction:action, client, param) {
	if(action == MenuAction_Select) {
		decl String:selection[16];
		GetMenuItem(menu, param, selection, sizeof(selection));
		if(StrEqual(selection, "repeat")) {
			decl String:value[8];
			GetClientCookie(client, repeatCookie, value, sizeof(value));
			if(StrEqual(value, "1")) {
				SetClientCookie(client, repeatCookie, "0");
			} else {
				SetClientCookie(client, repeatCookie, "1");
			}
			Command_MusicMenu(client, 0);
		} else if(StrEqual(selection, "songList")) {
			DisplayMenu(songMenu, client, 0);
		} else if(StrEqual(selection, "playlists")) {
			ShowPlaylistMenu(client);
		} else if(StrEqual(selection, "shuffleAll")) {
			PlaySong(client, -2);
		} else if(StrEqual(selection, "stopMusic")) {
			OpenURL(client, -1);
		} else if(StrEqual(selection, "random")) {
			PlaySong(client, GetArrayCell(songIds, GetRandomInt(0, GetArraySize(songIds) - 1)));
		} else if(StrEqual(selection, "info")) {
			ShowMOTDPanel(client, "", "", MOTDPANEL_TYPE_URL);
		} else if(StrEqual(selection, "playToOthers")) {
			new Handle:menu2 = CreateMenu(Handler_SongToOthers);
			SetMenuTitle(menu2, "Select Song");
			decl String:title[33], String:index[4];
			for(new i = 0; i < GetArraySize(songIds); i++) {
				GetArrayString(songTitles, i, title, sizeof(title));
				Format(index, sizeof(index), "%i", i);
				AddMenuItem(menu2, index, title);
			}
			SetMenuExitBackButton(menu2, true);
			DisplayMenu(menu2, client, 0);
			return;
		}
	}
	if(action == MenuAction_End) {
		CloseHandle(menu);
	}
}

public Handler_SongToOthers(Handle:menu, MenuAction:action, client, param) {
	if(action == MenuAction_End) {
		CloseHandle(menu);
	}
	if(action == MenuAction_Cancel) {
		if(param == MenuCancel_ExitBack) {
			Command_MusicMenu(client, 0);
			return;
		}
	}
	if(action != MenuAction_Select) {
		return;
	}
	decl String:selection[16]; // selection is array index
	GetMenuItem(menu, param, selection, sizeof(selection));
	songToPlay[client] = StringToInt(selection);
	new Handle:menu2 = CreateMenu(Handler_SelectTarget);
	SetMenuTitle(menu2, "Select Target");
	AddMenuItem(menu2, "@all", "Entire server");
	decl String:target[32], String:name[MAX_NAME_LENGTH];
	for(new i = 1; i <= MaxClients; i++) {
		if(!IsClientInGame(i) || IsFakeClient(i) || !CanAdminTarget(GetUserAdmin(client), GetUserAdmin(i))) {
			continue;
		}
		Format(target, sizeof(target), "#%i", GetClientUserId(i));
		Format(name, sizeof(name), "%N (%i)", i, GetClientUserId(i));
		AddMenuItem(menu2, target, name);
	}
	SetMenuExitBackButton(menu2, true);
	DisplayMenu(menu2, client, 0);
}

public Handler_SelectTarget(Handle:menu, MenuAction:action, client, param) {
	if(action == MenuAction_End) {
		CloseHandle(menu);
	}
	if(action == MenuAction_Cancel) {
		if(param == MenuCancel_ExitBack) {
			Command_MusicMenu(client, 0);
			return;
		}
	}
	if(action != MenuAction_Select) {
		return;
	}
	decl String:selection[32];
	GetMenuItem(menu, param, selection, sizeof(selection));
	decl target_list[MaxClients], String:target_name[MAX_NAME_LENGTH], bool:tn_is_ml;
	new total = ProcessTargetString(selection, client, target_list, MaxClients, COMMAND_FILTER_NO_BOTS, target_name, sizeof(target_name), tn_is_ml);
	if(total < 1) {
		ReplyToTargetError(client, total);
		return;
	}
	decl String:title[33];
	GetArrayString(songTitles, songToPlay[client], title, sizeof(title)); // songToPlay is array index
	for(new i = 0; i < total; i++) {
		PrintToChat(target_list[i], "\x04[SMDJ] \x01You are now listening to \x05%s", title);
		PlaySong(target_list[i], songToPlay[client], false, true);
		LogAction(client, target_list[i], "%L played song \"%s\" to %L", client, title, i);
	}
	ShowActivity2(client, "\x04[SMDJ] \x05", "\x01Played song \x05%s \x01to \x05%s", title, target_name);
}

ShowPlaylistMenu(client) {
	decl String:shuffle[32];
	GetClientCookie(client, shuffleCookie, shuffle, sizeof(shuffle));
	if(StrEqual(shuffle, "0")) {
		Format(shuffle, sizeof(shuffle), "( Shuffle is OFF )");
	} else {
		Format(shuffle, sizeof(shuffle), "( Shuffle is ON )");
	}
	decl String:auth[32], String:steamID[32], String:playlistID[8], String:playlistName[33];
	GetClientAuthString(client, auth, sizeof(auth));
	new Handle:menu = CreateMenu(Handler_Playlist);
	SetMenuTitle(menu, "Playlists");
	AddMenuItem(menu, "newplaylist", "( New Playlist )");
	AddMenuItem(menu, "deleteplaylist", "( Delete Playlist )", (FindStringInArray(playlistSteamIds, auth) != -1) ? ITEMDRAW_DEFAULT : ITEMDRAW_DISABLED);
	AddMenuItem(menu, "shuffle", shuffle);
	for(new i = 0; i < GetArraySize(playlistSteamIds); i++) {
		GetArrayString(playlistSteamIds, i, steamID, sizeof(steamID));
		if(!StrEqual(steamID, auth)) {
			continue;
		}
		Format(playlistID, sizeof(playlistID), "%i", GetArrayCell(playlistIds, i));
		GetArrayString(playlistNames, i, playlistName, sizeof(playlistName));
		AddMenuItem(menu, playlistID, playlistName);
	}
	SetMenuExitBackButton(menu, true);
	DisplayMenu(menu, client, 0);
}

public Handler_Playlist(Handle:menu, MenuAction:action, client, param) {
	if(action == MenuAction_End) {
		CloseHandle(menu);
	}
	if(action == MenuAction_Cancel) {
		if(param == MenuCancel_ExitBack) {
			Command_MusicMenu(client, 0);
			return;
		}
	}
	if(action != MenuAction_Select) {
		return;
	}
	decl String:selection[16];
	GetMenuItem(menu, param, selection, sizeof(selection));
	if(StrEqual(selection, "newplaylist")) {
		capturingPlaylistName[client] = true;
		SetHudTextParams(-1.0, 0.3, 999999999.0, 0, 255, 0, 255);
		ShowSyncHudText(client, hudText, "Please type the name for your playlist\nin chat and press Enter.");
		return;
	} else if(StrEqual(selection, "deleteplaylist")) {
		new Handle:menu2 = CreateMenu(Handler_DeletePlaylist);
		SetMenuTitle(menu2, "Select a playlist to delete");
		decl String:auth[32], String:steamID[32], String:playlistID[8], String:playlistName[33];
		GetClientAuthString(client, auth, sizeof(auth));
		for(new i = 0; i < GetArraySize(playlistSteamIds); i++) {
			GetArrayString(playlistSteamIds, i, steamID, sizeof(steamID));
			if(!StrEqual(steamID, auth)) {
				continue;
			}
			Format(playlistID, sizeof(playlistID), "%i", GetArrayCell(playlistIds, i));
			GetArrayString(playlistNames, i, playlistName, sizeof(playlistName));
			AddMenuItem(menu2, playlistID, playlistName);
		}
		SetMenuExitBackButton(menu2, true);
		DisplayMenu(menu2, client, 0);
		return;
	} else if(StrEqual(selection, "shuffle")) {
		decl String:shuffle[8];
		GetClientCookie(client, shuffleCookie, shuffle, sizeof(shuffle));
		if(StrEqual(shuffle, "1")) {
			SetClientCookie(client, shuffleCookie, "0");
		} else {
			SetClientCookie(client, shuffleCookie, "1");
		}
		ShowPlaylistMenu(client);
		return;
	}
	PlaySong(client, StringToInt(selection), true);
}

public Handler_DeletePlaylist(Handle:menu, MenuAction:action, client, param) {
	if(action == MenuAction_End) {
		CloseHandle(menu);
	}
	if(action == MenuAction_Cancel) {
		if(param == MenuCancel_ExitBack) {
			ShowPlaylistMenu(client);
			return;
		}
	}
	if(action != MenuAction_Select) {
		return;
	}
	decl String:selection[16], String:name[33];
	GetMenuItem(menu, param, selection, sizeof(selection));
	new id = FindValueInArray(playlistIds, StringToInt(selection));
	GetArrayString(playlistNames, id, name, sizeof(name));
	new Handle:menu2 = CreateMenu(Handler_ConfirmDelete);
	SetMenuTitle(menu2, "Are you sure you want to delete\n\"%s\"?", name);
	AddMenuItem(menu2, selection, "Yes");
	AddMenuItem(menu2, "no", "No");
	SetMenuExitButton(menu2, false);
	DisplayMenu(menu2, client, 0);
}

public Handler_ConfirmDelete(Handle:menu, MenuAction:action, client, param) {
	if(action == MenuAction_End) {
		CloseHandle(menu);
	}
	if(action != MenuAction_Select) {
		return;
	}
	decl String:selection[16];
	GetMenuItem(menu, param, selection, sizeof(selection));
	if(StrEqual(selection, "no")) {
		return;
	}
	new Handle:socket = SocketCreate(SOCKET_TCP, OnPostError);
	decl String:hostname[128], String:url[128], String:request[2048], String:authToken[64], String:postdata[2048];
	GetConVarString(djUrlCvar, url, sizeof(url));
	new Handle:pack = CreateDataPack();
	WritePackCell(pack, client);
	WritePackCell(pack, 2); // 1 = adding, 2 = deleting, 3 = modifying
	ReplaceString(url, sizeof(url), "http://", "", false);
	if(SplitString(url, "/", hostname, sizeof(hostname)) == -1) {
		LogError("Bad URL input");
		return;
	}
	ReplaceString(url, sizeof(url), hostname, "", false);
	GetConVarString(authKeyCvar, authToken, sizeof(authToken));
	Format(postdata, sizeof(postdata), "auth=%s&id=%s&method=2", authToken, selection);
	Format(request, sizeof(request), "POST %s/playlist.php HTTP/1.1\r\nHost: %s\r\nContent-Length: %i\r\nContent-Type: application/x-www-form-urlencoded\r\nConnection: close\r\n\r\n%s", url, hostname, strlen(postdata), postdata);
	WritePackString(pack, request);
	SocketSetArg(socket, pack);
	SocketConnect(socket, OnPostConnected, OnPostReceive, OnPostDisconnected, hostname, GetConVarInt(djUrlPortCvar));
}

public Action:Command_Say(client, const String:command[], argc) {
	if(!capturingPlaylistName[client] || IsChatTrigger()) {
		return Plugin_Continue;
	}
	decl String:name[33];
	GetCmdArgString(name, sizeof(name));
	TrimString(name);
	StripQuotes(name);
	new pos = FindStringInArray(playlistNames, name);
	if(pos != -1) {
		decl String:auth[32], String:steamID[32];
		GetClientAuthString(client, auth, sizeof(auth));
		GetArrayString(playlistSteamIds, pos, steamID, sizeof(steamID));
		if(StrEqual(auth, steamID)) {
			SetHudTextParams(-1.0, 0.3, 999999999.0, 0, 255, 0, 255);
			ShowSyncHudText(client, hudText, "Please type the name for your playlist\nin chat and press Enter.\n\nYou already have a playlist with that name.");
			return Plugin_Handled;
		}
	}
	capturingPlaylistName[client] = false;
	SetHudTextParams(0.0, 0.0, 0.1, 0, 0, 0, 0);
	ShowSyncHudText(client, hudText, "");
	playlistArray[client] = CreateArray();
	strcopy(newPlaylistName[client], sizeof(newPlaylistName[]), name);
	NewPlaylistMenu(client);
	return Plugin_Handled;
}

NewPlaylistMenu(client, position = 0) {
	new Handle:menu = CreateMenu(Handler_NewPlaylist);
	SetMenuTitle(menu, "New Playlist: %s (%i songs)", newPlaylistName[client], GetArraySize(playlistArray[client]));
	AddMenuItem(menu, "done", "( Create Playlist )", (GetArraySize(playlistArray[client]) > 0) ? ITEMDRAW_DEFAULT : ITEMDRAW_DISABLED);
	AddMenuItem(menu, "cancel", "( Cancel )");
	decl String:title[33], String:id[4];
	for(new i = 0; i < GetArraySize(songIds); i++) {
		Format(id, sizeof(id), "%i", GetArrayCell(songIds, i));
		GetArrayString(songTitles, i, title, sizeof(title));
		AddMenuItem(menu, id, title, (FindValueInArray(playlistArray[client], GetArrayCell(songIds, i)) == -1) ? ITEMDRAW_DEFAULT: ITEMDRAW_DISABLED);
	}
	DisplayMenuAtItem(menu, client, position, 0);
}

public Handler_NewPlaylist(Handle:menu, MenuAction:action, client, param) {
	if(action == MenuAction_End) {
		CloseHandle(menu);
	}
	if(action != MenuAction_Select) {
		return;
	}
	decl String:selection[8];
	GetMenuItem(menu, param, selection, sizeof(selection));
	if(StrEqual(selection, "done")) {
		decl String:songs[1024];
		new bool:first = true;
		for(new i = 0; i < GetArraySize(playlistArray[client]); i++) {
			if(first) {
				first = false;
				Format(songs, sizeof(songs), "%i", GetArrayCell(playlistArray[client], i));
			} else {
				Format(songs, sizeof(songs), "%s,%i", songs, GetArrayCell(playlistArray[client], i));
			}
		}
		new Handle:socket = SocketCreate(SOCKET_TCP, OnPostError);
		decl String:hostname[128], String:url[128], String:request[2048], String:authToken[64], String:postdata[2048], String:auth[32];
		GetConVarString(djUrlCvar, url, sizeof(url));
		new Handle:pack = CreateDataPack();
		WritePackCell(pack, client);
		WritePackCell(pack, 1); // 1 = adding, 2 = deleting, 3 = modifying
		ReplaceString(url, sizeof(url), "http://", "", false);
		if(SplitString(url, "/", hostname, sizeof(hostname)) == -1) {
			LogError("Bad URL input");
			return;
		}
		ReplaceString(url, sizeof(url), hostname, "", false);
		GetConVarString(authKeyCvar, authToken, sizeof(authToken));
		GetClientAuthString(client, auth, sizeof(auth));
		Format(postdata, sizeof(postdata), "auth=%s&name=%s&steamid=%s&method=1&songs=%s", authToken, newPlaylistName[client], auth, songs);
		Format(request, sizeof(request), "POST %s/playlist.php HTTP/1.1\r\nHost: %s\r\nContent-Length: %i\r\nContent-Type: application/x-www-form-urlencoded\r\nConnection: close\r\n\r\n%s", url, hostname, strlen(postdata), postdata);
		WritePackString(pack, request);
		SocketSetArg(socket, pack);
		SocketConnect(socket, OnPostConnected, OnPostReceive, OnPostDisconnected, hostname, GetConVarInt(djUrlPortCvar));
		CloseHandle(playlistArray[client]);
		playlistArray[client] = INVALID_HANDLE;
		return;
	} else if(StrEqual(selection, "cancel")) {
		CloseHandle(playlistArray[client]);
		playlistArray[client] = INVALID_HANDLE;
		PrintToChat(client, "\x04[SMDJ] \x01You have cancelled creating your playlist.");
		return;
	}
	PushArrayCell(playlistArray[client], StringToInt(selection));
	NewPlaylistMenu(client, GetMenuSelectionPosition());
}

public OnPostConnected(Handle:socket, any:pack) {
	ResetPack(pack);
	ReadPackCell(pack); // iterate
	ReadPackCell(pack); // iterate
	decl String:request[2048];
	ReadPackString(pack, request, sizeof(request));
	SocketSend(socket, request);
}

public OnPostReceive(Handle:socket, const String:receiveData[], dataSize, any:pack) {
	if(StrContains(receiveData, "Bad auth token", false) != -1 || StrContains(receiveData, "Invalid data", false) != -1) {
		ResetPack(pack);
		new client = ReadPackCell(pack);
		new method = ReadPackCell(pack);
		if(method == 1) {
			CPrintToChat(client, "{green}[SMDJ] {default}An error occurred when adding your playlist. Contact the server administrator.");
		} else if(method == 2) {
			CPrintToChat(client, "{green}[SMDJ] {default}An error occurred when deleting your playlist. Contact the server administrator.");
		} else {
			CPrintToChat(client, "{green}[SMDJ] {default}An error occurred when modifying your playlist. Contact the server administrator.");
		}
	}
	if(StrContains(receiveData, "Bad auth token", false) != -1) {
		LogError("Bad auth token");
	} else if(StrContains(receiveData, "Invalid data", false) != -1) {
		LogError("Invalid data");
	}
}

public OnPostDisconnected(Handle:socket, any:pack) {
	ResetPack(pack);
	new client = ReadPackCell(pack);
	new method = ReadPackCell(pack);
	if(method == 1) {
		CPrintToChat(client, "{green}[SMDJ] {default}Your playlist has been added.");
	} else if(method == 2) {
		CPrintToChat(client, "{green}[SMDJ] {default}Your playlist has been deleted.");
	} else {
		CPrintToChat(client, "{green}[SMDJ] {default}Your playlist has been modified.");
	}
	LoadSongs();
	CloseHandle(socket);
	CloseHandle(pack);
}

public OnPostError(Handle:socket, errorType, errorNum, any:pack) {
	ResetPack(pack);
	new client = ReadPackCell(pack);
	new method = ReadPackCell(pack);
	if(method == 1) {
		CPrintToChat(client, "{green}[SMDJ] {default}An error occurred when adding your playlist. Contact the server administrator.");
	} else if(method == 2) {
		CPrintToChat(client, "{green}[SMDJ] {default}An error occurred when deleting your playlist. Contact the server administrator.");
	} else {
		CPrintToChat(client, "{green}[SMDJ] {default}An error occurred when modifying your playlist. Contact the server administrator.");
	}
	CloseHandle(pack);
	CloseHandle(socket);
	LogError("Post socket error %i (error number %i)", errorType, errorNum);
}

public Action:Command_ReloadSongs(client, args) {
	LoadSongs();
	ReplyToCommand(client, "[SM] The song list has been refreshed.");
	return Plugin_Handled;
}

LoadSongs() {
	ClearArray(songTitles);
	ClearArray(songIds);
	ClearArray(playlistIds);
	ClearArray(playlistNames);
	ClearArray(playlistSteamIds);
	ClearArray(playlistSongs);
	if(songMenu != INVALID_HANDLE) {
		CloseHandle(songMenu);
	}
	songMenu = INVALID_HANDLE;
	new Handle:socket = SocketCreate(SOCKET_TCP, OnSocketError);
	decl String:path[128], String:hostname[128], String:url[128], String:request[256], String:authToken[64];
	GetConVarString(djUrlCvar, url, sizeof(url));
	BuildPath(Path_SM, path, sizeof(path), "data/smdj.txt");
	new Handle:pack = CreateDataPack();
	new Handle:file = OpenFile(path, "wb");
	WritePackCell(pack, _:file);
	ReplaceString(url, sizeof(url), "http://", "", false);
	if(SplitString(url, "/", hostname, sizeof(hostname)) == -1) {
		LogError("Bad URL input");
		return;
	}
	ReplaceString(url, sizeof(url), hostname, "", false);
	GetConVarString(authKeyCvar, authToken, sizeof(authToken));
	Format(request, sizeof(request), "GET %s/index.php?keyvalues=%s HTTP/1.0\r\nHost: %s\r\nConnection: close\r\nPragma: no-cache\r\nCache-Control: no-cache\r\n\r\n", url, authToken, hostname);
	WritePackString(pack, request);
	SocketSetArg(socket, pack);
	SocketConnect(socket, OnSocketConnected, OnSocketReceive, OnSocketDisconnected, hostname, GetConVarInt(djUrlPortCvar));
}

public OnSocketConnected(Handle:socket, any:pack) {
	ResetPack(pack);
	decl String:request[256];
	ReadPackCell(pack); // iterate the pack
	ReadPackString(pack, request, sizeof(request));
	SocketSend(socket, request);
}

public OnSocketReceive(Handle:socket, String:data[], const size, any:pack) {
	ResetPack(pack);
	new Handle:file = Handle:ReadPackCell(pack);
	
	// Skip the header data.
	new pos = StrContains(data, "\r\n\r\n");
	pos = (pos != -1) ? pos + 4 : 0;
	
	for (new i = pos; i < size; i++) {
		WriteFileCell(file, data[i], 1);
	}
}

public OnSocketDisconnected(Handle:socket, any:pack) {
	ResetPack(pack);
	CloseHandle(Handle:ReadPackCell(pack));
	CloseHandle(pack);
	CloseHandle(socket);
	decl String:path[128], String:line[50];
	BuildPath(Path_SM, path, sizeof(path), "data/smdj.txt");
	new Handle:file = OpenFile(path, "r");
	ReadFileLine(file, line, sizeof(line));
	if(StrEqual(line, "Bad auth token", false)) {
		SetFailState("Invalid auth token given");
		return;
	} else if(StrEqual(line, "No songs", false)) {
		LogMessage("There were no songs to load");
		return;
	}
	songMenu = CreateMenu(Handler_PlaySong);
	SetMenuTitle(songMenu, "Choose a song:");
	new Handle:kv = CreateKeyValues("SMDJ");
	if(!FileToKeyValues(kv, path)) {
		SetFailState("An unknown error occurred.");
		return;
	}
	KvJumpToKey(kv, "Songs");
	if(!KvGotoFirstSubKey(kv)) {
		LogError("There are no songs, even though the web interface said there were!");
		CloseHandle(kv);
		return;
	}
	decl String:songTitle[33], String:songId[5], String:index[5];
	KvGetString(kv, "title", songTitle, sizeof(songTitle));
	KvGetString(kv, "id", songId, sizeof(songId));
	PushArrayString(songTitles, songTitle);
	PushArrayCell(songIds, StringToInt(songId));
	IntToString(GetArraySize(songIds) - 1, index, sizeof(index));
	AddMenuItem(songMenu, index, songTitle);
	while(KvGotoNextKey(kv)) {
		KvGetString(kv, "title", songTitle, sizeof(songTitle));
		KvGetString(kv, "id", songId, sizeof(songId));
		PushArrayString(songTitles, songTitle);
		PushArrayCell(songIds, StringToInt(songId));
		IntToString(GetArraySize(songIds) - 1, index, sizeof(index));
		AddMenuItem(songMenu, index, songTitle);
	}
	SetMenuExitBackButton(songMenu, true);
	KvRewind(kv);
	KvJumpToKey(kv, "Playlists");
	if(!KvGotoFirstSubKey(kv)) {
		// no playlists
		CloseHandle(kv);
		return;
	}
	decl String:name[33], String:steamID[33], String:songs[1024];
	do {
		PushArrayCell(playlistIds, KvGetNum(kv, "id"));
		KvGetString(kv, "name", name, sizeof(name));
		KvGetString(kv, "steamid", steamID, sizeof(steamID));
		KvGetString(kv, "songs", songs, sizeof(songs));
		PushArrayString(playlistNames, name);
		PushArrayString(playlistSteamIds, steamID);
		PushArrayString(playlistSongs, songs);
	} while(KvGotoNextKey(kv));
	CloseHandle(kv);
}

public OnSocketError(Handle:socket, const errorType, const errorNum, any:pack) {
	ResetPack(pack);
	CloseHandle(Handle:ReadPackCell(pack));
	CloseHandle(pack);
	CloseHandle(socket);

	decl String:error[256];
	FormatEx(error, sizeof(error), "Socket error: %d (Error code %d)", errorType, errorNum);
}

public Handler_PlaySong(Handle:menu, MenuAction:action, client, param) {
	if(action == MenuAction_Select) {
		decl String:songIndex[5];
		GetMenuItem(menu, param, songIndex, sizeof(songIndex));
		PlaySong(client, StringToInt(songIndex));
	}
	if(action == MenuAction_Cancel) {
		if(param == MenuCancel_ExitBack) {
			Command_MusicMenu(client, 0);
			return;
		}
	}
}

PlaySong(client, index, bool:playlist = false, bool:silent = false) {
	if(!warningShown[client] && GetConVarBool(helpAdvertCvar)) {
		PrintHintText(client, "If you cannot hear the music, type !musichelp");
		//CPrintToChat(client, "{green}[SMDJ] {default}You must have Adobe Flash Player for Other Browsers installed to listen to music. Type {olive}!musichelp {default}for help.");
		warningShown[client] = true;
	}
	CPrintToChat(client, "{green}[SMDJ] {default}Type {olive}!musicoff {default}to stop the music or {olive}!musicinfo {default}for controls.");
	if(index == -2) {
		if(GetConVarBool(advertCvar) && !silent) {
			CPrintToChatAllEx(client, "{green}[SMDJ] {teamcolor}%N {default}is listening to {olive}all songs (shuffled)", client);
		}
		OpenURL(client, -2);
		return;
	}
	if(playlist) {
		if(GetConVarBool(advertCvar) && !silent) {
			CPrintToChatAllEx(client, "{green}[SMDJ] {teamcolor}%N {default}is listening to {olive}a personal playlist", client);
		}
		decl String:shuffle[8];
		GetClientCookie(client, shuffleCookie, shuffle, sizeof(shuffle));
		OpenURL(client, index, StringToInt(shuffle), true);
		return;
	}
	new id = GetArrayCell(songIds, index);
	decl String:title[33];
	GetArrayString(songTitles, index, title, sizeof(title));
	if(GetConVarBool(advertCvar) && !silent) {
		CPrintToChatAllEx(client, "{green}[SMDJ] {teamcolor}%N {default}is listening to {olive}%s", client, title);
	}
	decl String:repeat[8];
	GetClientCookie(client, repeatCookie, repeat, sizeof(repeat));
	OpenURL(client, id, StringToInt(repeat));
	Call_StartForward(forwardOnStartListen);
	Call_PushCell(client);
	Call_PushString(title);
	Call_Finish();
}

OpenURL(client, songId, repeat = 1, bool:playlist = false) {
	new Handle:panel = CreateKeyValues("data");
	
	KvSetString(panel, "title", "SMDJ");
	KvSetNum(panel, "type", MOTDPANEL_TYPE_URL);

	if(songId == -1) {
		KvSetString(panel, "msg", "about:blank");
	} else {
		decl String:url[256];
		GetConVarString(djUrlCvar, url, sizeof(url));
		ReplaceString(url, sizeof(url), "http://", "", false);
		ReplaceString(url, sizeof(url), "https://", "", false);
		decl String:parts[16][64];
		new String:path[256];
		new total = ExplodeString(url, "/", parts, sizeof(parts), sizeof(parts[]));
		for(new i = 1; i < total; i++) {
			Format(path, sizeof(path), "/%s", parts[i]);
		}
		if(songId == -2) {
			Format(url, sizeof(url), "http://%s:%i%s/shuffle.php", parts[0], GetConVarInt(djUrlPortCvar), path);
		} else if(!playlist) {
			Format(url, sizeof(url), "http://%s:%i%s/index.php?play=%i&repeat=%i", parts[0], GetConVarInt(djUrlPortCvar), path, songId, repeat);
		} else {
			// repeat is shuffle
			Format(url, sizeof(url), "http://%s:%i%s/playlist.php?id=%i&shuffle=%i", parts[0], GetConVarInt(djUrlPortCvar), path, songId, repeat);
		}
		KvSetString(panel, "msg", url);
	}
	
	ShowVGUIPanel(client, "info", panel, GetConVarBool(debugCvar));
	CloseHandle(panel);
	return;
}

public Action:Command_MusicInfo(client, args) {
	ShowMOTDPanel(client, "", "", MOTDPANEL_TYPE_URL);
	return Plugin_Handled;
}

public Action:Command_MusicHelp(client, args) {
	decl String:url[256];
	GetConVarString(djUrlCvar, url, sizeof(url));
	ReplaceString(url, sizeof(url), "http://", "", false);
	ReplaceString(url, sizeof(url), "https://", "", false);
	decl String:parts[16][64];
	new String:path[256];
	new total = ExplodeString(url, "/", parts, sizeof(parts), sizeof(parts[]));
	for(new i = 1; i < total; i++) {
		Format(path, sizeof(path), "/%s", parts[i]);
	}
	Format(url, sizeof(url), "http://%s:%i%s/help.php", parts[0], 80, path);
	ShowMOTDPanel(client, "SMDJ Help", url, MOTDPANEL_TYPE_URL);
	return Plugin_Handled;
}

public Action:Command_Debug_DumpArrays(client, args) {
	decl String:path[256];
	BuildPath(Path_SM, path, sizeof(path), "data/smdj_arrays_dump.txt");
	new Handle:file = OpenFile(path, "w");
	WriteFileLine(file, "----- SMDJ Arrays Dump -----");
	for(new i = 0; i < GetArraySize(songIds); i++) {
		WriteFileLine(file, "songIds[%i] = %i", i, GetArrayCell(songIds, i));
	}
	WriteFileLine(file, "----------------------------");
	decl String:value[1024];
	for(new i = 0; i < GetArraySize(songTitles); i++) {
		GetArrayString(songTitles, i, value, sizeof(value));
		WriteFileLine(file, "songTitles[%i] = %s", i, value);
	}
	WriteFileLine(file, "----------------------------");
	for(new i = 0; i < GetArraySize(playlistIds); i++) {
		WriteFileLine(file, "playlistIds[%i] = %i", i, GetArrayCell(playlistIds, i));
	}
	WriteFileLine(file, "----------------------------");
	for(new i = 0; i < GetArraySize(playlistNames); i++) {
		GetArrayString(playlistNames, i, value, sizeof(value));
		WriteFileLine(file, "playlistNames[%i] = %s", i, value);
	}
	WriteFileLine(file, "----------------------------");
	for(new i = 0; i < GetArraySize(playlistSteamIds); i++) {
		GetArrayString(playlistSteamIds, i, value, sizeof(value));
		WriteFileLine(file, "playlistSteamIds[%i] = %s", i, value);
	}
	WriteFileLine(file, "----------------------------");
	for(new i = 0; i < GetArraySize(playlistSongs); i++) {
		GetArrayString(playlistSongs, i, value, sizeof(value));
		WriteFileLine(file, "playlistSongs[%i] = %s", i, value);
	}
	CloseHandle(file);
	ReplyToCommand(client, "[SMDJ] The arrays have been dumped to data/smdj_arrays_dump.txt");
	return Plugin_Handled;
}

// Code pulled from TF2 Stats: https://forums.alliedmods.net/showthread.php?t=109006
TagsCheck(const String:tag[]) { 
	new Handle:hTags = FindConVar("sv_tags"); 
	decl String:tags[255]; 
	GetConVarString(hTags, tags, sizeof(tags)); 
	if (!(StrContains(tags, tag, false)>-1)) { 
		decl String:newTags[255]; 
		Format(newTags, sizeof(newTags), "%s,%s", tags, tag); 
		SetConVarString(hTags, newTags); 
		GetConVarString(hTags, tags, sizeof(tags)); 
	}
	CloseHandle(hTags); 
}