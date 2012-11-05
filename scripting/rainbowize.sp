#pragma semicolon 1

#include <sourcemod>

#include <scp>
#undef REQUIRE_PLUGIN
#include <updater>

#define UPDATE_URL			"http://hg.doctormckay.com/public-plugins/raw/default/rainbowize.txt"
#define PLUGIN_VERSION		"1.5.1"

public Plugin:myinfo = {
	name        = "[TF2] Rainbowize",
	author      = "Dr. McKay",
	description = "Rainbows!",
	version     = PLUGIN_VERSION,
	url         = "http://www.doctormckay.com"
};

new bool:isRainbowized[MAXPLAYERS + 1] = {false, ...};
new String:colors[][] = {"FF0000", "FF7F00", "FFD700", "00AA00", "0000FF", "6600FF", "8B00FF"};
new Handle:randomCvar = INVALID_HANDLE;
new Handle:rainbowForward = INVALID_HANDLE;
new Handle:updaterCvar = INVALID_HANDLE;

public APLRes:AskPluginLoad2(Handle:myself, bool:late, String:error[], err_max) {
	MarkNativeAsOptional("Updater_AddPlugin"); 
	return APLRes_Success;
} 

public OnPluginStart() {
	RegAdminCmd("sm_rainbowize", Command_Rainbowize, ADMFLAG_CHAT, "Rainbowize!");
	randomCvar = CreateConVar("sm_rainbowize_random", "0", "Should the order of the colors in the message be random?");
	updaterCvar = CreateConVar("sm_rainbowize_auto_update", "1", "Enables automatic updating (has no effect if Updater is not installed");
	rainbowForward = CreateGlobalForward("OnRainbowizingChat", ET_Event, Param_Cell);
	LoadTranslations("common.phrases");
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
	decl String:buffers[128][128];
	new parts = ExplodeString(message, " ", buffers, sizeof(buffers), sizeof(buffers[]));
	new bool:first = true;
	new bool:random = GetConVarBool(randomCvar);
	new String:final[256];
	new color = 0;
	if(random) {
		color = GetRandomInt(0, sizeof(colors) - 1);
	}
	for(new i = 0; i < parts; i++) {
		if(first) {
			first = false;
		} else {
			StrCat(final, sizeof(final), " ");
		}
		Format(final, sizeof(final), "%s\x07%s%s", final, colors[color], buffers[i]);
		if(random) {
			color = GetRandomInt(0, sizeof(colors) - 1);
		} else {
			color++;
			if(color >= sizeof(colors)) {
				color = 0;
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

/////////////////////////////////

public OnAllPluginsLoaded() {
	RequireFeature(FeatureType_Native, "GetMessageFlags", "Simple Chat Processor is not installed. Please visit https://forums.alliedmods.net/showthread.php?t=167812 and install it.");
	new Handle:convar;
	if(LibraryExists("updater")) {
		Updater_AddPlugin(UPDATE_URL);
		new String:newVersion[10];
		Format(newVersion, sizeof(newVersion), "%sA", PLUGIN_VERSION);
		convar = CreateConVar("rainbowize_version", newVersion, "Rainbowize Version", FCVAR_DONTRECORD|FCVAR_NOTIFY|FCVAR_CHEAT);
	} else {
		convar = CreateConVar("rainbowize_version", PLUGIN_VERSION, "Rainbowize Version", FCVAR_DONTRECORD|FCVAR_NOTIFY|FCVAR_CHEAT);
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