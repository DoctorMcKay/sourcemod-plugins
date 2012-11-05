#pragma semicolon 1

#include <sourcemod>
#include <sdktools>

#undef REQUIRE_PLUGIN
#include <updater>

#define UPDATE_URL    "http://public-plugins.doctormckay.com/latest/mutecheck.txt"
#define PLUGIN_VERSION "1.9.1"

new String:tag[20];
new Handle:tagCvar = INVALID_HANDLE;
new Handle:updaterCvar = INVALID_HANDLE;

public Plugin:myinfo = {
	name        = "[ANY] MuteCheck",
	author      = "Dr. McKay",
	description = "Determine if anyone has muted a specific player and who",
	version     = PLUGIN_VERSION,
	url         = "http://www.doctormckay.com"
};

public APLRes:AskPluginLoad2(Handle:myself, bool:late, String:error[], err_max) {
	MarkNativeAsOptional("Updater_AddPlugin"); 
	return APLRes_Success;
}  

public OnPluginStart() {
	tagCvar = CreateConVar("sm_mutecheck_tag", "[SM]", "Tag to be prepended to Mutecheck replies");
	updaterCvar = CreateConVar("sm_mutecheck_auto_update", "1", "Enables automatic updating (has no effect if Updater is not installed)");
	RegAdminCmd("sm_mutecheck", MuteCheck, 0, "Determine if anyone has muted a specific player and who");
	LoadTranslations("common.phrases");
	GetConVarString(tagCvar, tag, sizeof(tag));
	HookConVarChange(tagCvar, TagChanged);
}

public TagChanged(Handle:cvar, const String:oldVal[], const String:newVal[]) {
	GetConVarString(tagCvar, tag, sizeof(tag));
}

public OnAllPluginsLoaded() {
	if(LibraryExists("updater")) {
		Updater_AddPlugin(UPDATE_URL);
		new String:newVersion[10];
		Format(newVersion, sizeof(newVersion), "%sA", PLUGIN_VERSION);
		CreateConVar("sm_mutecheck_version", newVersion, "MuteCheck Version", FCVAR_DONTRECORD|FCVAR_NOTIFY);
	} else {
		CreateConVar("sm_mutecheck_version", PLUGIN_VERSION, "MuteCheck Version", FCVAR_DONTRECORD|FCVAR_NOTIFY);	
	}
}

public Action:MuteCheck(client, args) {
	if(args != 0 && args != 1) {
		ReplyToCommand(client, "%s Usage: sm_mutecheck to check yourself or sm_mutecheck [target] to check a target", tag);
	}
	if(args == 0) {
		if(client == 0) {
			ReplyToCommand(client, "%s Use sm_mutecheck [target] from the console.", tag);
			return Plugin_Handled;
		}
		new bool:mutes = false;
		decl String:muteMessage[512];
		for(new i = 1; i <= MaxClients; i++) {
			if (!IsClientInGame(i) || IsFakeClient(i)) {
				continue;
			}			
			if(IsClientMuted(i, client)) {
				if(!mutes) {
					mutes = true;
					GetClientName(i, muteMessage, sizeof(muteMessage));
				} else {
					Format(muteMessage, sizeof(muteMessage), "%s, %N", muteMessage, i);
				}
			}
		}
		if(!mutes) {
			ReplyToCommand(client, "%s Muted by nobody.", tag);
		} else {
			ReplyToCommand(client, "%s Muted by %s.", tag, muteMessage);
		}
	} else if(args == 1) {
		if(!CheckCommandAccess(client, "sm_mutecheck_override", ADMFLAG_GENERIC)) {
			ReplyToCommand(client, "%s Usage: sm_mutecheck", tag);
			return Plugin_Handled;
		}
		decl String:arg1[MAX_NAME_LENGTH];
		GetCmdArg(1, arg1, sizeof(arg1));
		decl targets[MaxClients], String:target_name[MAX_NAME_LENGTH];
		new bool:tn_is_ml;
		new total = ProcessTargetString(arg1, client, targets, MaxClients, COMMAND_FILTER_NO_IMMUNITY|COMMAND_FILTER_NO_BOTS, target_name, MAX_NAME_LENGTH, tn_is_ml);
		if(total < 1) {
			ReplyToTargetError(client, total);
			return Plugin_Handled;
		}
		decl String:muteMessage[512];
		new bool:mutes;
		for(new i = 0; i < total; i++) {
			mutes = false;
			for(new j = 1; j <= MaxClients; j++) {
				if(!IsClientInGame(j) || IsFakeClient(j)) {
					continue;
				}
				if(IsClientMuted(j, targets[i])) {
					if(!mutes) {
						GetClientName(j, muteMessage, sizeof(muteMessage));
						mutes = true;
					} else {
						Format(muteMessage, sizeof(muteMessage), "%s, %N", muteMessage, j);
					}
				}
			}
			if(!mutes) {
				ReplyToCommand(client, "%s %N is muted by nobody.", tag, targets[i]);
			} else {
				ReplyToCommand(client, "%s %N is muted by %s.", tag, targets[i], muteMessage);
			}
		}
	}
	return Plugin_Handled;
}

public Action:Updater_OnPluginDownloading() {
	if(!GetConVarBool(updaterCvar)) {
		return Plugin_Handled;
	}
	return Plugin_Continue;
}

public Updater_OnPluginUpdated() {
	ReloadPlugin();
}