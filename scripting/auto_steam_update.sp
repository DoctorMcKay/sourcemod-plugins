#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <steamtools>

#undef REQUIRE_PLUGIN
#tryinclude <updater>

#define UPDATE_URL    "http://hg.doctormckay.com/public-plugins/raw/default/automatic_steam_update.txt"
#define PLUGIN_VERSION "1.9.1"

#define ALERT_SOUND "ui/system_message_alert.wav"

new Handle:delayCvar;
new Handle:timerCvar;
new Handle:messageTimeCvar;
new Handle:lockCvar;
new Handle:passwordCvar;
new Handle:kickMessageCvar;
new Handle:shutdownMessageCvar;
new Handle:hudXCvar;
new Handle:hudYCvar;
new Handle:hudRCvar;
new Handle:hudGCvar;
new Handle:hudBCvar;
new Handle:updaterCvar;
new Handle:restartTimer;
new bool:suspendPlugin = false;
new timeRemaining = 0;
new bool:disallowPlayers = false;
new String:originalPassword[255];

new bool:isTF = false;

new Handle:hudText;
new Handle:sv_password;

public Plugin:myinfo = {
	name        = "[ANY] Automatic Steam Update",
	author      = "Dr. McKay",
	description = "Automatically restarts the server to update via Steam",
	version     = PLUGIN_VERSION,
	url         = "http://www.doctormckay.com"
};

public APLRes:AskPluginLoad2(Handle:myself, bool:late, String:error[], err_max) {
	MarkNativeAsOptional("Updater_AddPlugin"); 
	return APLRes_Success;
} 

public OnPluginStart() {
	AutoExecConfig(true, "plugin.autosteamupdate");
	
	delayCvar = CreateConVar("auto_steam_update_delay", "5", "How long in minutes the server should wait before starting another countdown after being postponed.");
	timerCvar = CreateConVar("auto_steam_update_timer", "5", "How long in minutes the server should count down before restarting.");
	messageTimeCvar = CreateConVar("auto_steam_update_message_display_time", "5", "At how much time in minutes left on the timer should the timer be displayed?");
	lockCvar = CreateConVar("auto_steam_update_lock", "0", "0 - don't lock the server / 1 - set sv_password to auto_steam_update_password during timer / 2 - don't set a password, but kick everyone who tries to connect during the timer");
	passwordCvar = CreateConVar("auto_steam_update_password", "", "The password to set sv_password to if auto_steam_update_lock = 1", FCVAR_PROTECTED);
	kickMessageCvar = CreateConVar("auto_steam_update_kickmessage", "The server will shut down soon to acquire Steam updates, so no new connections are allowed", "The message to display to kicked clients if auto_steam_update_lock = 2");
	shutdownMessageCvar = CreateConVar("auto_steam_update_shutdown_message", "Server shutting down for Steam update", "The message displayed to clients when the server restarts");
	hudXCvar = CreateConVar("auto_steam_update_hud_text_x_pos", "0.01", "X-position for HUD timer (only on supported games) -1 = center", _, true, -1.0, true, 1.0);
	hudYCvar = CreateConVar("auto_steam_update_hud_text_y_pos", "0.01", "Y-position for HUD timer (only on supported games) -1 = center", _, true, -1.0, true, 1.0);
	hudRCvar = CreateConVar("auto_steam_update_hud_text_red", "0", "Amount of red for the HUD timer (only on supported games)", _, true, 0.0, true, 255.0);
	hudGCvar = CreateConVar("auto_steam_update_hud_text_green", "255", "Amount of red for the HUD timer (only on supported games)", _, true, 0.0, true, 255.0);
	hudBCvar = CreateConVar("auto_steam_update_hud_text_blue", "0", "Amount of red for the HUD timer (only on supported games)", _, true, 0.0, true, 255.0);
	updaterCvar = CreateConVar("auto_steam_update_auto_update", "1", "Enables automatic plugin updating (has no effect if Updater is not installed)");
	
	sv_password = FindConVar("sv_password");
	
	RegAdminCmd("sm_postponeupdate", Command_PostponeUpdate, ADMFLAG_RCON, "Postpone a pending server restart for a Steam update");
	RegAdminCmd("sm_updatetimer", Command_ForceRestart, ADMFLAG_RCON, "Force the server update timer to start immediately");
	
	hudText = CreateHudSynchronizer();
	if(hudText == INVALID_HANDLE) {
		LogMessage("HUD text is not supported on this mod. The persistant timer will not display.");
	} else {
		LogMessage("HUD text is supported on this mod. The persistant timer will display.");
	}
	
	decl String:folder[16];
	GetGameFolderName(folder, sizeof(folder));
	if(StrEqual(folder, "tf", false)) {
		isTF = true;
	}
}

public OnMapStart() {
	if(isTF) {
		PrecacheSound(ALERT_SOUND); // this sound is in TF2 only
	}
}

public OnClientPostAdminCheck(client) {
	if(CheckCommandAccess(client, "BypassAutoSteamUpdateDisallow", ADMFLAG_GENERIC, true)) {
		return;
	}
	if(disallowPlayers) {
		decl String:kickMessage[255];
		GetConVarString(kickMessageCvar, kickMessage, sizeof(kickMessage));
		KickClient(client, kickMessage);
	}
}

public Action:Steam_RestartRequested() {
	startTimer();
	return Plugin_Continue;
}

public Action:Command_ForceRestart(client, args) {
	suspendPlugin = false;
	LogAction(client, -1, "%L manually triggered an update timer", client);
	startTimer(true);
	return Plugin_Handled;
}

startTimer(bool:forced = false) {
	if(suspendPlugin) {
		return;
	}
	if(!IsServerPopulated()) { // If there's no clients in the server, go ahead and restart it
		LogMessage("Received a master server restart request, and there are no players in the server. Restarting to update.");
		ServerCommand("_restart");
		return;
	}
	new lock = GetConVarInt(lockCvar);
	if(lock == 1) {
		decl String:password[255];
		GetConVarString(passwordCvar, password, sizeof(password));
		GetConVarString(sv_password, originalPassword, sizeof(originalPassword));
		SetConVarString(sv_password, password);
	}
	if(lock == 2) {
		disallowPlayers = true;
	}
	if(!forced) {
		LogMessage("Received a master server restart request, beginning restart timer.");
	}
	timeRemaining = GetConVarInt(timerCvar) * 60;
	timeRemaining++;
	restartTimer = CreateTimer(1.0, DoTimer, INVALID_HANDLE, TIMER_REPEAT);
	suspendPlugin = true;
	return;
}

public Action:DoTimer(Handle:timer) {
	timeRemaining--;
	if(timeRemaining <= -1) {
		LogMessage("Restarting server for Steam update.");
		for(new i = 1; i <= MaxClients; i++) {
			if (!IsClientAuthorized(i) || !IsClientInGame(i) || IsFakeClient(i)) {
				continue;
			}
			new String:kickMessage[255];
			GetConVarString(shutdownMessageCvar, kickMessage, sizeof(kickMessage));
			KickClient(i, kickMessage);
		}
		ServerCommand("_restart");
		return Plugin_Stop;
	}
	if(timeRemaining / 60 <= GetConVarInt(messageTimeCvar)) {
		if(hudText != INVALID_HANDLE) {
			for(new i = 1; i <= MaxClients; i++) {
				if(!IsClientConnected(i) || !IsClientInGame(i) || IsFakeClient(i)) {
					continue;
				}
				SetHudTextParams(GetConVarFloat(hudXCvar), GetConVarFloat(hudYCvar), 1.0, GetConVarInt(hudRCvar), GetConVarInt(hudGCvar), GetConVarInt(hudBCvar), 255);
				ShowSyncHudText(i, hudText, "Update: %i:%02i", timeRemaining / 60, timeRemaining % 60);
			}
		}
		if(timeRemaining > 60 && timeRemaining % 60 == 0) {
			PrintHintTextToAll("A game update has been released.\nThis server will shut down to update in %i minutes.", timeRemaining / 60);
			PrintToServer("[SM] A game update has been released. This server will shut down to update in %i minutes.", timeRemaining / 60);
			if(isTF) {
				EmitSoundToAll(ALERT_SOUND);
			}
		}
		if(timeRemaining == 60) {
			PrintHintTextToAll("A game update has been released.\nThis server will shut down to update in 1 minute.");
			PrintToServer("[SM] A game update has been released. This server will shut down to update in 1 minute.");
			if(isTF) {
				EmitSoundToAll(ALERT_SOUND);
			}
		}
	}
	if(timeRemaining <= 60 && hudText == INVALID_HANDLE) {
		PrintCenterTextAll("Update: %i:%02i", timeRemaining / 60, timeRemaining % 60);
	}
	return Plugin_Continue;
}

public Action:Command_PostponeUpdate(client, args) {
	if(restartTimer == INVALID_HANDLE) {
		ReplyToCommand(client, "[SM] There is no update timer currently running.");
		return Plugin_Handled;
	}
	CloseHandle(restartTimer);
	restartTimer = INVALID_HANDLE;
	LogAction(client, -1, "%L aborted the update timer.", client);
	new Float:delay = GetConVarInt(delayCvar) * 60.0;
	CreateTimer(delay, ReenablePlugin);
	ReplyToCommand(client, "[SM] The update timer has been cancelled for %i minutes.", GetConVarInt(delayCvar));
	PrintHintTextToAll("The update timer has been cancelled for %i minutes.", GetConVarInt(delayCvar));
	disallowPlayers = false;
	if(GetConVarInt(lockCvar) == 1) {
		SetConVarString(sv_password, originalPassword);
	}
	return Plugin_Handled;
}

public Action:ReenablePlugin(Handle:timer) {
	suspendPlugin = false;
	return Plugin_Stop;
}

IsServerPopulated() {
	for(new i = 1; i <= MaxClients; i++) {
		if(IsClientConnected(i) && !IsFakeClient(i)) {
			return true;
		}
	}
	return false;
}

/////////////////////////////////

public OnAllPluginsLoaded() {
	new Handle:convar;
	if(LibraryExists("updater")) {
		Updater_AddPlugin(UPDATE_URL);
		new String:newVersion[10];
		Format(newVersion, sizeof(newVersion), "%sA", PLUGIN_VERSION);
		convar = CreateConVar("auto_steam_update_version", newVersion, "Automatic Steam Update Version", FCVAR_DONTRECORD|FCVAR_NOTIFY|FCVAR_CHEAT);
	} else {
		convar = CreateConVar("auto_steam_update_version", PLUGIN_VERSION, "Automatic Steam Update Version", FCVAR_DONTRECORD|FCVAR_NOTIFY|FCVAR_CHEAT);	
	}
	HookConVarChange(convar, Callback_VersionConVarChanged);
}

public Callback_VersionConVarChanged(Handle:convar, const String:oldValue[], const String:newValue[]) {
	ResetConVar(convar);
}

public Action:Updater_OnPluginDownloading() {
	if(!GetConVarBool(updaterCvar)) {
		return Plugin_Handled;
	}
	return Plugin_Continue;
}

public OnLibraryAdded(const String:name[]) {
	if(StrEqual(name, "updater")) {
		Updater_AddPlugin(UPDATE_URL);
	}
}

public Updater_OnPluginUpdated() {
	ReloadPlugin();
}