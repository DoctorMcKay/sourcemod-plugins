#pragma semicolon 1

#include <sourcemod>
#include <morecolors>

#define PLUGIN_VERSION		"1.2.0"

public Plugin:myinfo = {
    name		= "[TF2] Better Vote Scramble",
    author		= "Dr. McKay",
    description	= "A vote scramble system that uses TF2's built-in scrambler when the next round begins",
    version		= PLUGIN_VERSION,
    url			= "http://www.doctormckay.com"
}

new Handle:cvarPercentage;
new Handle:cvarVotesRequired;

new bool:votedToScramble[MAXPLAYERS + 1];
new bool:scrambleTeams = false;

new Handle:mp_bonusroundtime;

#define UPDATE_FILE		"votescramble.txt"
#define CONVAR_PREFIX	"better_votescramble"

#include "mckayupdater.sp"

public OnPluginStart() {
	cvarPercentage = CreateConVar("better_votescramble_percentage", "0.6", "Percentage required to initiate a team scramble");
	cvarVotesRequired = CreateConVar("better_votescramble_votes_required", "3", "Votes required to initiate a vote");
	
	AddCommandListener(Command_Say, "say");
	AddCommandListener(Command_Say, "say_team");
	
	HookEvent("teamplay_round_win", Event_RoundEnd);
	HookEvent("teamplay_round_stalemate", Event_RoundEnd);
	HookEvent("teamplay_win_panel", Event_RoundEnd);
	
	mp_bonusroundtime = FindConVar("mp_bonusroundtime");
	
	LoadTranslations("core.phrases");
}

public OnClientConnected(client) {
	votedToScramble[client] = false;
}

public Action:Command_Say(client, const String:command[], argc) {
	decl String:message[256];
	GetCmdArgString(message, sizeof(message));
	StripQuotes(message);
	TrimString(message);
	if(!StrEqual(message, "votescramble", false) && !StrEqual(message, "!votescramble", false)) {
		return Plugin_Continue;
	}
	if(!CheckCommandAccess(client, "votescramble", 0)) {
		ReplyToCommand(client, "[SM] %t.", "No Access");
		return Plugin_Continue;
	}
	if(votedToScramble[client]) {
		PrintToChatDelay(client, "\x04[SM] \x01You have already voted to scramble the teams.");
		return Plugin_Continue;
	}
	if(IsVoteInProgress()) {
		PrintToChatDelay(client, "\x04[SM] \x01Please wait for the current vote to end.");
		return Plugin_Continue;
	}
	if(scrambleTeams) {
		PrintToChatDelay(client, "\x04[SM] \x01A previous scramble vote has succeeded. Teams will be scrambled when the round ends.");
		return Plugin_Continue;
	}
	votedToScramble[client] = true;
	PrintToChatAllDelay(client, "{green}[SM] {teamcolor}%N {default}has voted to scramble the teams. [{lightgreen}%i{default}/{lightgreen}%i {default}votes required]", client, GetTotalVotes(), GetConVarInt(cvarVotesRequired));
	if(GetTotalVotes() >= GetConVarInt(cvarVotesRequired)) {
		InitiateVote();
	}
	return Plugin_Continue;
}

PrintToChatDelay(client, const String:format[], any:...) {
	decl String:buffer[512];
	VFormat(buffer, sizeof(buffer), format, 3);
	new Handle:pack = CreateDataPack();
	WritePackCell(pack, GetClientUserId(client));
	WritePackString(pack, buffer);
	CreateTimer(0.0, Timer_PrintToChat, pack);
}

PrintToChatAllDelay(client, const String:format[], any:...) {
	decl String:buffer[512];
	VFormat(buffer, sizeof(buffer), format, 3);
	new Handle:pack = CreateDataPack();
	WritePackCell(pack, GetClientUserId(client));
	WritePackString(pack, buffer);
	CreateTimer(0.0, Timer_PrintToChatAll, pack);
}

public Action:Timer_PrintToChat(Handle:timer, any:pack) {
	ResetPack(pack);
	new client = GetClientOfUserId(ReadPackCell(pack));
	if(client == 0) {
		CloseHandle(pack);
		return;
	}
	decl String:message[512];
	ReadPackString(pack, message, sizeof(message));
	CloseHandle(pack);
	PrintToChat(client, message);
}

public Action:Timer_PrintToChatAll(Handle:timer, any:pack) {
	ResetPack(pack);
	new client = GetClientOfUserId(ReadPackCell(pack));
	if(client == 0) {
		CloseHandle(pack);
		return;
	}
	decl String:message[512];
	ReadPackString(pack, message, sizeof(message));
	CloseHandle(pack);
	CPrintToChatAllEx(client, message);
}

GetTotalVotes() {
	new total = 0;
	for(new i = 1; i <= MaxClients; i++) {
		if(IsClientInGame(i) && !IsFakeClient(i) && votedToScramble[i]) {
			total++;
		}
	}
	return total;
}

InitiateVote() {
	for(new i = 1; i <= MaxClients; i++) {
		votedToScramble[i] = false;
	}
	new Handle:menu = CreateMenu(Handler_CastVote);
	SetMenuTitle(menu, "Scramble teams at the end of the round?");
	AddMenuItem(menu, "yes", "Yes");
	AddMenuItem(menu, "no", "No");
	SetMenuExitButton(menu, false);
	VoteMenuToAll(menu, 20);
}

public Handler_CastVote(Handle:menu, MenuAction:action, param1, param2) {
	if(action == MenuAction_End) {
		CloseHandle(menu);
	} else if(action == MenuAction_VoteCancel && param1 == VoteCancel_NoVotes) {
		PrintToChatAll("\x04[SM] \x01Team scramble vote failed: no votes were cast.");
	} else if(action == MenuAction_VoteEnd) {
		decl String:item[64];
		new Float:percent, Float:limit, votes, totalVotes;

		GetMenuVoteInfo(param2, votes, totalVotes);
		GetMenuItem(menu, param1, item, sizeof(item));
		
		percent = FloatDiv(float(votes),float(totalVotes));
		limit = GetConVarFloat(cvarPercentage);
		
		if(FloatCompare(percent, limit) >= 0 && StrEqual(item, "yes")) {
			PrintToChatAll("\x04[SM] \x01The vote was successful. Teams will be scrambled at the start of the next round.");
			scrambleTeams = true;
		} else {
			PrintToChatAll("\x04[SM] \x01The vote failed.");
		}
	}
}

public Event_RoundEnd(Handle:event, const String:name[], bool:dontBroadcast) {
	if(scrambleTeams) {
		new Float:delay = GetConVarFloat(mp_bonusroundtime) - 7.0;
		if(delay < 0.0) {
			delay = 0.0;
		}
		
		scrambleTeams = false;
		CreateTimer(delay, Timer_Scramble);
	}
}

public Action:Timer_Scramble(Handle:timer) {
	ServerCommand("mp_scrambleteams 2");
	PrintToChatAll("\x04[SM] \x01Scrambling the teams due to vote.");
}