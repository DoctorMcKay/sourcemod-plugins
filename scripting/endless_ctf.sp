#include <sourcemod>
#include <sdktools>
#include <tf2>
#include <tf2_stocks>

#define PLUGIN_VERSION   "1.0.1"
#define PROP_FLAG_CAPS   "m_nFlagCaptures"
#define PROP_SCORE       "m_iTotalScore"

#define UPDATE_FILE      "endless_ctf.txt"
#define CONVAR_PREFIX    "endless_ctf"

#include "mckayupdater.sp"

#pragma newdecls required

public Plugin myinfo = {
	name = "[TF2] Endless CTF",
	author = "Dr. McKay",
	description = "Run Capture the Flag maps without actually ending the round",
	version = PLUGIN_VERSION,
	url = "https://www.doctormckay.com"
};

ConVar g_cvarFlagCapsPerRound;
ConVar g_cvarWinPanelTime;
ConVar g_cvarWinCritsTime;
ConVar g_cvarWinSounds;
ConVar tf_flag_caps_per_round;

int g_TeamResourceEntities[4] = {-1, ...};

// Per-round data
ArrayList g_RoundCappers;
int g_RoundPlayerStartScores[MAXPLAYERS + 1];
int g_RoundPlayerKillstreaks[MAXPLAYERS + 1];

public void OnPluginStart() {
	g_cvarFlagCapsPerRound = CreateConVar("sm_flag_caps_per_round", "3", "How many flag captures should be considered a round", 0, true, 0.0, true, 127.0);
	g_cvarWinPanelTime = CreateConVar("endless_ctf_win_panel_time", "10", "How long (in seconds) to show the win panel when a team wins", 0, true, 3.0);
	g_cvarWinCritsTime = CreateConVar("endless_ctf_win_crits_time", "10", "How long (in seconds) to give all players on the winning team crits (0 to disable)", 0, true, 0.0);
	g_cvarWinSounds = CreateConVar("endless_ctf_win_sounds", "1", "Enable or disable \"victory\" or \"you failed\" sounds on round win", 0, true, 0.0, true, 1.0);
	tf_flag_caps_per_round = FindConVar("tf_flag_caps_per_round");
	
	tf_flag_caps_per_round.IntValue = 0;
	
	g_cvarFlagCapsPerRound.AddChangeHook(Hook_FlagCapsChanged);
	tf_flag_caps_per_round.AddChangeHook(Hook_FlagCapsChanged);
	
	g_RoundCappers = CreateArray();
	
	HookEvent("teamplay_flag_event", Event_FlagEvent);
	HookEvent("teamplay_round_start", Event_RoundStart);
	HookEvent("player_death", Event_PlayerDeath);
	
	AddNormalSoundHook(NormalSoundHook);
}

public void Hook_FlagCapsChanged(ConVar cvar, const char[] oldValue, const char[] newValue) {
	tf_flag_caps_per_round.IntValue = 0;
	SendFlagCapsToAllPlayers();
	CheckWinCondition();
}

public void OnMapStart() {
	char mapName[128];
	GetCurrentMap(mapName, sizeof(mapName));
	
	if (StrContains(mapName, "workshop/", false) == 0) {
		// It's a workshop map
		GetMapDisplayName(mapName, mapName, sizeof(mapName));
	}
	
	if (StrContains(mapName, "ctf_") != 0) {
		char pluginName[128];
		GetPluginFilename(INVALID_HANDLE, pluginName, sizeof(pluginName));
		PrintToServer("[%s] Current map is not ctf_*. Unloading self.", pluginName);
		ServerCommand("sm plugins unload \"%s\"", pluginName);
		return;
	}
	
	SendFlagCapsToAllPlayers();
	
	// Find team resource entities
	int ent = -1;
	while ((ent = FindEntityByClassname(ent, "tf_team")) != -1) {
		g_TeamResourceEntities[GetEntProp(ent, Prop_Send, "m_iTeamNum")] = ent;
	}
	
	if (g_TeamResourceEntities[2] == -1 || g_TeamResourceEntities[3] == -1) {
		SetFailState("Could not find tf_team entities for teams 2 and 3");
	}
	
	// If we were late loaded, go ahead and initialize scores and killstreaks
	int resourceEnt = GetPlayerResourceEntity();
	for (int i = 1; i <= MaxClients; i++) {
		if (!IsClientInGame(i)) {
			continue;
		}
		
		g_RoundPlayerKillstreaks[i] = 0;
		g_RoundPlayerStartScores[i] = GetEntProp(resourceEnt, Prop_Send, PROP_SCORE, 4, i);
	}
}

void SendFlagCapsToAllPlayers() {
	char capsPerRound[4];
	g_cvarFlagCapsPerRound.GetString(capsPerRound, sizeof(capsPerRound));
	for (int i = 1; i <= MaxClients; i++) {
		if (IsClientInGame(i) && !IsFakeClient(i)) {
			// Force the client's UI to show how many caps we're playing to
			tf_flag_caps_per_round.ReplicateToClient(i, capsPerRound);
		}
	}
}

public void OnClientPutInServer(int client) {
	if (!IsFakeClient(client)) {
		char capsPerRound[4];
		g_cvarFlagCapsPerRound.GetString(capsPerRound, sizeof(capsPerRound));
		tf_flag_caps_per_round.ReplicateToClient(client, capsPerRound);
	}
	
	g_RoundPlayerKillstreaks[client] = 0;
	g_RoundPlayerStartScores[client] = 0;
}

public Action Event_FlagEvent(Event event, const char[] name, bool dontBroadcast) {
	int client = event.GetInt("player");
	int eventType = event.GetInt("eventtype");
	
	if (eventType != view_as<int>(TF_FLAGEVENT_CAPTURED)) {
		return;
	}
	
	// When running in tf_flag_caps_per_round=0, the server does not actually increment the team resource entity's flag captures prop.
	// Instead, when a flag is captured, it increments the team score. The client shows team scores in the HUD when tf_flag_caps_per_round=0.
	// Since the server is running with 0 caps per round but clients believe there are more, we need to manually update the resource entity,
	// and correct the team scores.
	
	int cappingTeam = GetClientTeam(client);
	int teamEnt = g_TeamResourceEntities[cappingTeam];
	int captureCount = GetEntProp(teamEnt, Prop_Send, PROP_FLAG_CAPS);
	SetEntProp(teamEnt, Prop_Send, PROP_FLAG_CAPS, captureCount + 1, 1);
	SetTeamScore(cappingTeam, GetTeamScore(cappingTeam) - 1); // fix the team score
	
	if (g_RoundCappers.FindValue(GetClientUserId(client)) == -1) {
		g_RoundCappers.Push(GetClientUserId(client));
	}
	
	CheckWinCondition();
}

void CheckWinCondition() {
	// See if either team has won yet
	int capsRequired = g_cvarFlagCapsPerRound.IntValue;
	if (capsRequired == 0) {
		return; // no win condition
	}
	
	for (int team = 2; team <= 3; team++) {
		int captureCount = GetEntProp(g_TeamResourceEntities[team], Prop_Send, PROP_FLAG_CAPS);
		if (captureCount >= capsRequired) {
			// This team has won
			
			// Calculate scores
			ArrayList roundScores = CreateArray(2);
			int resourceEnt = GetPlayerResourceEntity();
			for (int i = 1; i <= MaxClients; i++) {
				if (IsClientInGame(i) && GetClientTeam(i) == team) {
					int score = GetEntProp(resourceEnt, Prop_Send, PROP_SCORE, 4, i);
					int scoreArray[2];
					scoreArray[0] = i;
					scoreArray[1] = score - g_RoundPlayerStartScores[i];
					roundScores.PushArray(scoreArray);
				}
			}
			
			SortADTArrayCustom(roundScores, SortRoundScores);
			
			// Calculate cappers
			char cappers[128];
			cappers[0] = '\0';
			for (int i = 0; i < g_RoundCappers.Length; i++) {
				int client = GetClientOfUserId(g_RoundCappers.Get(i));
				if (client == 0 || GetClientTeam(client) != team) {
					continue;
				}
				
				int cappersLen = strlen(cappers);
				cappers[cappersLen] = client;
				cappers[cappersLen + 1] = '\0';
			}
			
			// Reset flag caps
			SetEntProp(g_TeamResourceEntities[TFTeam_Blue], Prop_Send, PROP_FLAG_CAPS, 0, 1);
			SetEntProp(g_TeamResourceEntities[TFTeam_Red], Prop_Send, PROP_FLAG_CAPS, 0, 1);
			int previousBlueScore = GetTeamScore(view_as<int>(TFTeam_Blue));
			int previousRedScore = GetTeamScore(view_as<int>(TFTeam_Red));
			
			SetTeamScore(team, GetTeamScore(team) + 1);
			
			Event winEvent = CreateEvent("teamplay_win_panel");
			winEvent.SetInt("panel_style", 1);
			winEvent.SetInt("winning_team", team);
			winEvent.SetInt("winreason", 3);
			winEvent.SetString("cappers", cappers);
			winEvent.SetInt("flagcaplimit", capsRequired);
			winEvent.SetInt("blue_score", GetTeamScore(view_as<int>(TFTeam_Blue)));
			winEvent.SetInt("red_score", GetTeamScore(view_as<int>(TFTeam_Red)));
			winEvent.SetInt("blue_score_prev", previousBlueScore);
			winEvent.SetInt("red_score_prev", previousRedScore);
			winEvent.SetInt("round_complete", 1);
			
			// Player scores
			for (int i = 0; i < 3 && i < roundScores.Length; i++) {
				int scoreArray[2];
				roundScores.GetArray(i, scoreArray, sizeof(scoreArray));
				if (scoreArray[1] == 0) {
					// 0 points
					break;
				}
				
				char key[64];
				Format(key, sizeof(key), "player_%d", i + 1);
				winEvent.SetInt(key, scoreArray[0]);
				Format(key, sizeof(key), "player_%d_points", i + 1);
				winEvent.SetInt(key, scoreArray[1]);
			}
			
			// Highest killstreak
			int highestKillstreakPlayer = 0;
			for (int i = 1; i <= MaxClients; i++) {
				if (!IsClientInGame(i)) {
					continue;
				}
				
				if (g_RoundPlayerKillstreaks[i] > 0 && (highestKillstreakPlayer == 0 || g_RoundPlayerKillstreaks[i] > g_RoundPlayerKillstreaks[highestKillstreakPlayer])) {
					highestKillstreakPlayer = i;
				}
			}
			
			if (highestKillstreakPlayer != 0) {
				winEvent.SetInt("killstreak_player_1", highestKillstreakPlayer);
				winEvent.SetInt("killstreak_player_1_count", g_RoundPlayerKillstreaks[highestKillstreakPlayer]);
			}
			
			winEvent.SetInt("game_over", 0);
			winEvent.Fire();
			
			CreateTimer(g_cvarWinPanelTime.FloatValue, Timer_StartRound);
			
			float winCritsTime = g_cvarWinCritsTime.FloatValue;
			if (winCritsTime > 0.0) {
				for (int i = 1; i <= MaxClients; i++) {
					if (IsClientInGame(i) && IsPlayerAlive(i) && GetClientTeam(i) == team) {
						TF2_AddCondition(i, TFCond_CritOnWin, winCritsTime);
					}
				}
			}
			
			if (g_cvarWinSounds.BoolValue) {
				Event soundEvent = CreateEvent("teamplay_broadcast_audio");
				soundEvent.SetInt("team", team);
				soundEvent.SetString("sound", "Game.YourTeamWon");
				soundEvent.Fire();
				
				soundEvent = CreateEvent("teamplay_broadcast_audio");
				soundEvent.SetInt("team", 5 - team);
				soundEvent.SetString("sound", "Game.YourTeamLost");
				soundEvent.Fire();
			}
		}
	}
}

public int SortRoundScores(int idx1, int idx2, Handle array, Handle hndl) {
	int val1[2], val2[2];
	GetArrayArray(array, idx1, val1, sizeof(val1));
	GetArrayArray(array, idx2, val2, sizeof(val2));
	
	return val1[1] > val2[1] ? -1 : 1;
}

public Action Timer_StartRound(Handle timer, any data) {
	Event startEvent = CreateEvent("teamplay_round_start");
	startEvent.SetInt("full_reset", 0);
	startEvent.Fire();
}

public Action Event_RoundStart(Event event, const char[] name, bool dontBroadcast) {
	g_RoundCappers.Clear();
	
	// Reset everyone's scores and killstreaks
	int resourceEnt = GetPlayerResourceEntity();
	for (int i = 1; i <= MaxClients; i++) {
		g_RoundPlayerKillstreaks[i] = 0;
		g_RoundPlayerStartScores[i] = 0;
		
		if (IsClientInGame(i)) {
			g_RoundPlayerStartScores[i] = GetEntProp(resourceEnt, Prop_Send, PROP_SCORE, 4, i);
		}
	}
}

public Action Event_PlayerDeath(Event event, const char[] name, bool dontBroadcast) {
	int client = GetClientOfUserId(event.GetInt("attacker"));
	if (client == 0) {
		return;
	}
	
	int killstreak = event.GetInt("kill_streak_total");
	if (killstreak > g_RoundPlayerKillstreaks[client]) {
		g_RoundPlayerKillstreaks[client] = killstreak;
	}
}

public Action NormalSoundHook(int clients[64], int& numClients, char sample[PLATFORM_MAX_PATH], int &entity, int &channel, float &volume, int &level, int &pitch, int &flags) {
	// We don't care about sounds at all if we're not using win sounds
	if (!g_cvarWinSounds.BoolValue) {
		return Plugin_Continue;
	}
	
	int capturingTeam = -1;
	if (StrContains(sample, "vo/intel_teamcaptured") == 0) {
		capturingTeam = GetClientTeam(clients[0]);
	} else if (StrContains(sample, "vo/intel_enemycaptured") == 0) {
		capturingTeam = 5 - GetClientTeam(clients[0]);
	}
	
	if (capturingTeam == -1) {
		// This isn't a relevant sound
		return Plugin_Continue;
	}
	
	// Does the next capture for this team win it?
	int captureCount = GetEntProp(g_TeamResourceEntities[capturingTeam], Prop_Send, PROP_FLAG_CAPS);
	if (captureCount + 1 >= g_cvarFlagCapsPerRound.IntValue) {
		// This is going to be the winning capture. Suppress the default announcer sounds since we're about to have win/lose sounds.
		return Plugin_Stop;
	}
	
	return Plugin_Continue;
}
