#pragma semicolon 1

#include <sourcemod>
#include <scp>

#define PLUGIN_VERSION		"1.7.0"

public Plugin:myinfo = {
	name        = "[TF2] Rainbowize",
	author      = "Dr. McKay",
	description = "Rainbows!",
	version     = PLUGIN_VERSION,
	url         = "http://www.doctormckay.com"
};

new bool:isRainbowized[MAXPLAYERS + 1] = {false, ...};
new Handle:colors;
new Handle:randomCvar;
new Handle:rainbowForward;

#define UPDATE_FILE		"rainbowize.txt"
#define CONVAR_PREFIX	"rainbowize"

#include "mckayupdater.sp"

public OnPluginStart() {
	RegAdminCmd("sm_rainbowize", Command_Rainbowize, ADMFLAG_CHAT, "Rainbowize!");
	
	randomCvar = CreateConVar("sm_rainbowize_random", "0", "Should the order of the colors in the message be random?");
	
	rainbowForward = CreateGlobalForward("OnRainbowizingChat", ET_Event, Param_Cell);
	LoadTranslations("common.phrases");
	colors = CreateArray(12);
	decl String:path[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, path, sizeof(path), "configs/rainbowize_colors.ini");
	if(!FileExists(path)) {
		PushArrayString(colors, "FF0000");
		PushArrayString(colors, "FF7F00");
		PushArrayString(colors, "FFD700");
		PushArrayString(colors, "00AA00");
		PushArrayString(colors, "0000FF");
		PushArrayString(colors, "6600FF");
		PushArrayString(colors, "8B00FF");
	} else {
		new Handle:file = OpenFile(path, "r");
		decl String:line[64];
		while(ReadFileLine(file, line, sizeof(line))) {
			line[6] = '\0'; // effectively substring 0, 6
			StringToUpper(line);
			if(strlen(line) != 6 || !IsValidHexadecimal(line)) {
				LogError("Invalid color detected in rainbowize_colors.ini. Problem on line: %s", line);
			} else {
				PushArrayString(colors, line);
			}
		}
		if(GetArraySize(colors) == 0) {
			LogError("No colors found in rainbowize_colors.ini file. Reverting to default.");
			PushArrayString(colors, "FF0000");
			PushArrayString(colors, "FF7F00");
			PushArrayString(colors, "FFD700");
			PushArrayString(colors, "00AA00");
			PushArrayString(colors, "0000FF");
			PushArrayString(colors, "6600FF");
			PushArrayString(colors, "8B00FF");
		}
		CloseHandle(file);
	}
}

bool:IsValidHexadecimal(const String:input[]) {
	for(new i = 0; ; i++) {
		if(input[i] == '\0') {
			break; // I'd rather return true here, but the compiler whines
		}
		if(!CharInString(input[i], "0123456789ABCDEF")) {
			return false;
		}
	}
	return true;
}

bool:CharInString(chr, const String:string[]) {
	for(new i = 0; ; i++) {
		if(string[i] == '\0') {
			break; // I'd rather return false here, but the compiler whines
		}
		if(string[i] == chr) {
			return true;
		}
	}
	return false;
}

StringToUpper(String:input[]) {
	for(new i = 0; ; i++) {
		if(input[i] == '\0') {
			return;
		}
		input[i] = CharToUpper(input[i]);
	}
}

public OnClientConnected(client) {
	isRainbowized[client] = false;
}

public Action:Command_Rainbowize(client, args) {
	if(args != 0 && args != 1 && args != 2) {
		ReplyToCommand(client, "[SM] Usage: sm_rainbowize <target> [1/0]");
		return Plugin_Handled;
	}
	if(args == 0) {
		if(isRainbowized[client]) {
			isRainbowized[client] = false;
		} else {
			isRainbowized[client] = true;
		}
		ShowActivity2(client, "[SM] ", "Toggled rainbow chat on self.");
		LogAction(client, client, "%L toggled rainbow chat on themself", client);
		return Plugin_Handled;
	}
	if(!CheckCommandAccess(client, "RainbowizeTargetOthers", ADMFLAG_CHAT)) {
		ReplyToCommand(client, "[SM] Usage: sm_rainbowize");
		return Plugin_Handled;
	}
	if(args == 1) {
		decl String:target_name[MAX_NAME_LENGTH];
		new target_list[MAXPLAYERS];
		new target_count;
		new bool:tn_is_ml;
		decl String:arg1[MAX_NAME_LENGTH];
		GetCmdArg(1, arg1, sizeof(arg1));
		if((target_count = ProcessTargetString(arg1, client, target_list, MAXPLAYERS, COMMAND_FILTER_NO_BOTS, target_name, sizeof(target_name), tn_is_ml)) <= 0) {
			ReplyToTargetError(client, target_count);
			return Plugin_Handled;
		}
		for(new i = 0; i < target_count; i++) {
			if(isRainbowized[target_list[i]]) {
				isRainbowized[target_list[i]] = false;
			} else {
				isRainbowized[target_list[i]] = true;
			}
			LogAction(client, target_list[i], "%L toggled rainbow chat on %L", client, target_list[i]);
		}
		ShowActivity2(client, "[SM] ", "Toggled rainbow chat on %s.", target_name);
		return Plugin_Handled;
	}
	if(args == 2) {
		decl String:target_name[MAX_NAME_LENGTH];
		new target_list[MAXPLAYERS];
		new target_count;
		new bool:tn_is_ml;
		decl String:arg1[MAX_NAME_LENGTH], String:arg2[4];
		GetCmdArg(1, arg1, sizeof(arg1));
		GetCmdArg(2, arg2, sizeof(arg2));
		new iState = StringToInt(arg2);
		if(iState != 0 && iState != 1) {
			ReplyToCommand(client, "[SM] Usage: sm_rainbowize <target> [1/0]");
			return Plugin_Handled;
		}
		new bool:bState = false;
		if(iState == 1) {
			bState = true;
		}
		decl String:sState[8];
		if(bState) {
			strcopy(sState, sizeof(sState), "on");
		} else {
			strcopy(sState, sizeof(sState), "off");
		}
		if((target_count = ProcessTargetString(arg1, client, target_list, MAXPLAYERS, COMMAND_FILTER_NO_BOTS, target_name, sizeof(target_name), tn_is_ml)) <= 0) {
			ReplyToTargetError(client, target_count);
			return Plugin_Handled;
		}
		for(new i = 0; i < target_count; i++) {
			isRainbowized[target_list[i]] = bState;
			LogAction(client, target_list[i], "%L set rainbow chat on %L %s", client, target_list[i], sState);
		}
		ShowActivity2(client, "[SM] ", "Set rainbow chat on %s %s", target_name, sState);
		return Plugin_Handled;
	}
	ReplyToCommand(client, "[SM] An unknown error occurred.");
	return Plugin_Handled;
}

public Action:OnChatMessage(&author, Handle:recipients, String:name[], String:message[]) {
	if(!isRainbowized[author] || !RainbowForward(author)) {
		return Plugin_Continue;
	}
	TrimString(message);
	decl String:buffers[64][64];
	new parts = ExplodeString(message, " ", buffers, sizeof(buffers), sizeof(buffers[]));
	new bool:first = true;
	new bool:random = GetConVarBool(randomCvar);
	new colorIndex = 0;
	decl String:color[12];
	if(random) {
		colorIndex = GetRandomInt(0, GetArraySize(colors) - 1);
	}
	new String:final[256];
	for(new i = 0; i < parts; i++) {
		if(first) {
			first = false;
		} else {
			StrCat(final, sizeof(final), " ");
		}
		GetArrayString(colors, colorIndex, color, sizeof(color));
		Format(final, sizeof(final), "%s\x07%s%s", final, color, buffers[i]);
		if(random) {
			colorIndex = GetRandomInt(0, GetArraySize(colors) - 1);
		} else {
			colorIndex++;
			if(colorIndex >= GetArraySize(colors)) {
				colorIndex = 0;
			}
		}
	}
	StripQuotes(final);
	strcopy(message, MAXLENGTH_MESSAGE, final);
	return Plugin_Changed;
}

public Action:CCC_OnChatColor(client) {
	if(isRainbowized[client]) {
		return Plugin_Handled;
	}
	return Plugin_Continue;
}

bool:RainbowForward(author) {
	new Action:result = Plugin_Continue;
	Call_StartForward(rainbowForward);
	Call_PushCell(author);
	Call_Finish(result);
	if(result == Plugin_Handled || result == Plugin_Stop) {
		return false;
	}
	return true;
}