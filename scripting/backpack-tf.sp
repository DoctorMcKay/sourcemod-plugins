#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <steamtools>
#include <advanced_motd>

#define PLUGIN_VERSION		"3.0.0"
#define BACKPACK_TF_URL		"http://backpack.tf/api/IGetPrices/v4/"
#define NOTIFICATION_SOUND	"replay/downloadcomplete.wav"
#define QUALITY_UNUSUAL		"5"
#define QUALITY_UNIQUE		"6"

public Plugin:myinfo = {
	name        = "[TF2] backpack.tf Price Check",
	author      = "Dr. McKay",
	description = "Provides a price check command for use with backpack.tf",
	version     = PLUGIN_VERSION,
	url         = "http://www.doctormckay.com"
};

new g_LastCacheTime;
new g_CacheTime;
new Handle:g_PriceList;

new Handle:g_Qualities;
new Handle:g_Effects;
new Handle:g_NoEffectUnusuals;

new Handle:g_cvarBPCommand;
new Handle:g_cvarDisplayUpdateNotification;
new Handle:g_cvarDisplayChangedPrices;
new Handle:g_cvarHudXPos;
new Handle:g_cvarHudYPos;
new Handle:g_cvarHudRed;
new Handle:g_cvarHudGreen;
new Handle:g_cvarHudBlue;
new Handle:g_cvarHudHoldTime;
new Handle:g_cvarMenuHoldTime;
new Handle:g_cvarAPIKey;
new Handle:g_cvarTag;

new Handle:g_HudSync;
new Handle:sv_tags;

new Float:g_MetalUSD;
new Float:g_KeysRaw;
new Float:g_BudsRaw;

#define UPDATE_FILE		"backpack-tf.txt"
#define CONVAR_PREFIX	"backpack_tf"

#include "mckayupdater.sp"

public OnPluginStart() {
	g_cvarBPCommand = CreateConVar("backpack_tf_bp_command", "1", "Enables the !bp command for use with backpack.tf");
	g_cvarDisplayUpdateNotification = CreateConVar("backpack_tf_display_update_notification", "1", "Display a notification to clients when the cached price list has been updated?");
	g_cvarDisplayChangedPrices = CreateConVar("backpack_tf_display_changed_prices", "1", "If backpack_tf_display_update_notification is set to 1, display all prices that changed since the last update?");
	g_cvarHudXPos = CreateConVar("backpack_tf_update_notification_x_pos", "-1.0", "X position for HUD text from 0.0 to 1.0, -1.0 = center", _, true, -1.0, true, 1.0);
	g_cvarHudYPos = CreateConVar("backpack_tf_update_notification_y_pos", "0.1", "Y position for HUD text from 0.0 to 1.0, -1.0 = center", _, true, -1.0, true, 1.0);
	g_cvarHudRed = CreateConVar("backpack_tf_update_notification_red", "0", "Red value of HUD text", _, true, 0.0, true, 255.0);
	g_cvarHudGreen = CreateConVar("backpack_tf_update_notification_green", "255", "Green value of HUD text", _, true, 0.0, true, 255.0);
	g_cvarHudBlue = CreateConVar("backpack_tf_update_notification_blue", "0", "Blue value of HUD text", _, true, 0.0, true, 255.0);
	g_cvarHudHoldTime = CreateConVar("backpack_tf_update_notification_message_time", "5", "Seconds to keep each message in the update ticker on the screen", _, true, 0.0);
	g_cvarMenuHoldTime = CreateConVar("backpack_tf_menu_open_time", "0", "Time to keep the price panel open for, 0 = forever");
	g_cvarAPIKey = CreateConVar("backpack_tf_api_key", "", "API key obtained at http://backpack.tf/api/register/", FCVAR_PROTECTED);
	g_cvarTag = CreateConVar("backpack_tf_add_tag", "1", "If 1, adds the backpack.tf tag to your server's sv_tags, which is required to be listed on http://backpack.tf/servers", _, true, 0.0, true, 1.0);
	AutoExecConfig();
	
	LoadTranslations("backpack-tf.phrases");
	
	sv_tags = FindConVar("sv_tags");
	
	RegConsoleCmd("sm_bp", Command_Backpack, "Usage: sm_bp <player>");
	RegConsoleCmd("sm_backpack", Command_Backpack, "Usage: sm_backpack <player>");
	
	RegConsoleCmd("sm_pc", Command_PriceCheck, "Usage: sm_pc <item>");
	RegConsoleCmd("sm_pricecheck", Command_PriceCheck, "Usage: sm_pricecheck <item>");
	
	RegAdminCmd("sm_updateprices", Command_UpdatePrices, ADMFLAG_ROOT, "Updates backpack.tf prices");
	
	g_Qualities = CreateTrie();
	SetTrieString(g_Qualities, "0", "Normal");
	SetTrieString(g_Qualities, "1", "Genuine");
	SetTrieString(g_Qualities, "2", "rarity2");
	SetTrieString(g_Qualities, "3", "Vintage");
	SetTrieString(g_Qualities, "4", "rarity3");
	SetTrieString(g_Qualities, "5", "Unusual");
	SetTrieString(g_Qualities, "6", "Unique");
	SetTrieString(g_Qualities, "7", "Community");
	SetTrieString(g_Qualities, "8", "Valve");
	SetTrieString(g_Qualities, "9", "Self-Made");
	SetTrieString(g_Qualities, "10", "Customized");
	SetTrieString(g_Qualities, "11", "Strange");
	SetTrieString(g_Qualities, "12", "Completed");
	SetTrieString(g_Qualities, "13", "Haunted");
	SetTrieString(g_Qualities, "14", "Collector's");
	
	g_Effects = CreateTrie();
	// Original effects
	SetTrieString(g_Effects, "6", "Green Confetti");
	SetTrieString(g_Effects, "7", "Purple Confetti");
	SetTrieString(g_Effects, "8", "Haunted Ghosts");
	SetTrieString(g_Effects, "9", "Green Energy");
	SetTrieString(g_Effects, "10", "Purple Energy");
	SetTrieString(g_Effects, "11", "Circling TF Logo");
	SetTrieString(g_Effects, "12", "Massed Flies");
	SetTrieString(g_Effects, "13", "Burning Flames");
	SetTrieString(g_Effects, "14", "Scorching Flames");
	SetTrieString(g_Effects, "15", "Searing Plasma");
	SetTrieString(g_Effects, "16", "Vivid Plasma");
	SetTrieString(g_Effects, "17", "Sunbeams");
	SetTrieString(g_Effects, "18", "Circling Peace Sign");
	SetTrieString(g_Effects, "19", "Circling Heart");
	// Batch 2
	SetTrieString(g_Effects, "29", "Stormy Storm");
	SetTrieString(g_Effects, "30", "Blizzardy Storm");
	SetTrieString(g_Effects, "31", "Nuts n' Bolts");
	SetTrieString(g_Effects, "32", "Orbiting Planets");
	SetTrieString(g_Effects, "33", "Orbiting Fire");
	SetTrieString(g_Effects, "34", "Bubbling");
	SetTrieString(g_Effects, "35", "Smoking");
	SetTrieString(g_Effects, "36", "Steaming");
	// Halloween
	SetTrieString(g_Effects, "37", "Flaming Lantern");
	SetTrieString(g_Effects, "38", "Cloudy Moon");
	SetTrieString(g_Effects, "39", "Cauldron Bubbles");
	SetTrieString(g_Effects, "40", "Eerie Orbiting Fire");
	SetTrieString(g_Effects, "43", "Knifestorm");
	SetTrieString(g_Effects, "44", "Misty Skull");
	SetTrieString(g_Effects, "45", "Harvest Moon");
	SetTrieString(g_Effects, "46", "It's A Secret To Everybody");
	SetTrieString(g_Effects, "47", "Stormy 13th Hour");
	// Batch 3
	SetTrieString(g_Effects, "56", "Kill-a-Watt");
	SetTrieString(g_Effects, "57", "Terror-Watt");
	SetTrieString(g_Effects, "58", "Cloud 9");
	SetTrieString(g_Effects, "59", "Aces High");
	SetTrieString(g_Effects, "60", "Dead Presidents");
	SetTrieString(g_Effects, "61", "Miami Nights");
	SetTrieString(g_Effects, "62", "Disco Beat Down");
	// Robo-effects
	SetTrieString(g_Effects, "63", "Phosphorous");
	SetTrieString(g_Effects, "64", "Sulphurous");
	SetTrieString(g_Effects, "65", "Memory Leak");
	SetTrieString(g_Effects, "66", "Overclocked");
	SetTrieString(g_Effects, "67", "Electrostatic");
	SetTrieString(g_Effects, "68", "Power Surge");
	SetTrieString(g_Effects, "69", "Anti-Freeze");
	SetTrieString(g_Effects, "70", "Time Warp");
	SetTrieString(g_Effects, "71", "Green Black Hole");
	SetTrieString(g_Effects, "72", "Roboactive");
	// Halloween 2013
	SetTrieString(g_Effects, "73", "Arcana");
	SetTrieString(g_Effects, "74", "Spellbound");
	SetTrieString(g_Effects, "75", "Chiroptera Venenata");
	SetTrieString(g_Effects, "76", "Poisoned Shadows");
	SetTrieString(g_Effects, "77", "Something Burning This Way Comes");
	SetTrieString(g_Effects, "78", "Hellfire");
	SetTrieString(g_Effects, "79", "Darkblaze");
	SetTrieString(g_Effects, "80", "Demonflame");
	
	g_NoEffectUnusuals = CreateTrie();
	SetTrieValue(g_NoEffectUnusuals, "Haunted Metal Scrap", 0);
	SetTrieValue(g_NoEffectUnusuals, "Horseless Headless Horsemann's Headtaker", 0);
	
	g_HudSync = CreateHudSynchronizer();
}

public OnConfigsExecuted() {
	CreateTimer(2.0, Timer_AddTag); // Let everything load first
}

public Action:Timer_AddTag(Handle:timer) {
	if(!GetConVarBool(g_cvarTag)) {
		return;
	}
	
	decl String:value[512];
	GetConVarString(sv_tags, value, sizeof(value));
	TrimString(value);
	if(strlen(value) == 0) {
		SetConVarString(sv_tags, "backpack.tf");
		return;
	}
	
	decl String:tags[64][64];
	new total = ExplodeString(value, ",", tags, sizeof(tags), sizeof(tags[]));
	for(new i = 0; i < total; i++) {
		if(StrEqual(tags[i], "backpack.tf")) {
			return; // Tag found, nothing to do here
		}
	}
	
	StrCat(value, sizeof(value), ",backpack.tf");
	SetConVarString(sv_tags, value);
}

public OnMapStart() {
	PrecacheSound(NOTIFICATION_SOUND);
}

public Steam_FullyLoaded() {
	CreateTimer(1.0, Timer_Update); // In case of late-loads
}

GetCachedPricesAge() {
	decl String:path[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, path, sizeof(path), "data/backpack-tf.txt");
	if(!FileExists(path)) {
		return -1;
	}
	
	new Handle:kv = CreateKeyValues("Response");
	if(!FileToKeyValues(kv, path)) {
		CloseHandle(kv);
		return -1;
	}
	
	new offset = KvGetNum(kv, "time_offset", 1337); // The actual offset can be positive, negative, or zero, so we'll just use 1337 as a default since that's unlikely
	new time = KvGetNum(kv, "current_time");
	CloseHandle(kv);
	if(offset == 1337 || time == 0) {
		return -1;
	}
	
	return GetTime() - time;
}

public Action:Timer_Update(Handle:timer) {
	new age = GetCachedPricesAge();
	if(age != -1 && age < 900) { // 15 minutes
		LogMessage("Locally saved pricing data is %d minutes old, bypassing backpack.tf query", age / 60);
		if(g_PriceList != INVALID_HANDLE) {
			CloseHandle(g_PriceList);
		}
		
		decl String:path[PLATFORM_MAX_PATH];
		BuildPath(Path_SM, path, sizeof(path), "data/backpack-tf.txt");
		g_PriceList = CreateKeyValues("Response");
		FileToKeyValues(g_PriceList, path);
		
		CreateTimer(float(3600 - age), Timer_Update);
		return;
	}
	
	decl String:key[32];
	GetConVarString(g_cvarAPIKey, key, sizeof(key));
	if(strlen(key) == 0) {
		SetFailState("No API key set. Fill in your API key and reload the plugin.");
		return;
	}
	
	new HTTPRequestHandle:request = Steam_CreateHTTPRequest(HTTPMethod_GET, BACKPACK_TF_URL);
	Steam_SetHTTPRequestGetOrPostParameter(request, "key", key);
	Steam_SetHTTPRequestGetOrPostParameter(request, "format", "vdf");
	Steam_SetHTTPRequestGetOrPostParameter(request, "raw", "1");
	Steam_SendHTTPRequest(request, OnBackpackTFComplete);
}

public OnBackpackTFComplete(HTTPRequestHandle:request, bool:successful, HTTPStatusCode:status) {
	if(status != HTTPStatusCode_OK || !successful) {
		LogError("backpack.tf API failed. Connection %s, status code = %d", successful ? "successful" : "unsuccessful", _:status);
		Steam_ReleaseHTTPRequest(request);
		CreateTimer(60.0, Timer_Update); // try again!
		return;
	}
	
	decl String:path[256];
	BuildPath(Path_SM, path, sizeof(path), "data/backpack-tf.txt");
	
	Steam_WriteHTTPResponseBody(request, path);
	Steam_ReleaseHTTPRequest(request);
	
	new Handle:kv = CreateKeyValues("response");
	FileToKeyValues(kv, path);
	if(!KvGetNum(kv, "success")) {
		decl String:message[256];
		KvGetString(kv, "message", message, sizeof(message));
		LogError("backpack.tf API failed. Message: %s", message);
		if(StrEqual(message, "API key does not exist.")) {
			CreateTimer(600.0, Timer_Update); // Try again in 10 minutes since bad API key
		} else {
			CreateTimer(60.0, Timer_Update); // Try again in a minute
		}
		
		return;
	}
	
	CreateTimer(3600.0, Timer_Update);
	
	if(g_PriceList != INVALID_HANDLE) {
		CloseHandle(g_PriceList);
	}
	
	g_PriceList = kv;
	g_LastCacheTime = g_CacheTime;
	g_CacheTime = KvGetNum(kv, "current_time");
	
	new offset = GetTime() - g_CacheTime;
	KvSetNum(kv, "time_offset", offset);
	KeyValuesToFile(kv, path);
	
	// Get the raw prices of keys and buds so we can convert USD prices
	KvRewind(g_PriceList);
	g_MetalUSD = KvGetFloat(g_PriceList, "raw_usd_value");
	
	PrepPriceKv();
	KvJumpToKey(g_PriceList, "Mann Co. Supply Crate Key");
	KvJumpToKey(g_PriceList, "prices");
	KvJumpToKey(g_PriceList, QUALITY_UNIQUE);
	KvJumpToKey(g_PriceList, "Tradable");
	KvJumpToKey(g_PriceList, "Craftable");
	KvJumpToKey(g_PriceList, "0");
	g_KeysRaw = KvGetFloat(g_PriceList, "value_raw");
	
	PrepPriceKv();
	KvJumpToKey(g_PriceList, "Earbuds");
	KvJumpToKey(g_PriceList, "prices");
	KvJumpToKey(g_PriceList, QUALITY_UNIQUE);
	KvJumpToKey(g_PriceList, "Tradable");
	KvJumpToKey(g_PriceList, "Craftable");
	KvJumpToKey(g_PriceList, "0");
	g_BudsRaw = KvGetFloat(g_PriceList, "value_raw");
	
	LogMessage("backpack.tf price list successfully downloaded! USD/Metal: %.2f, Metal/Key: %.2f, Metal/Bud: %.2f", g_MetalUSD, g_KeysRaw, g_BudsRaw);
	
	if(!GetConVarBool(g_cvarDisplayUpdateNotification)) {
		return;
	}
	
	if(g_LastCacheTime == 0) { // first download
		new Handle:array = CreateArray(128);
		PushArrayString(array, "#Type_command");
		SetHudTextParams(GetConVarFloat(g_cvarHudXPos), GetConVarFloat(g_cvarHudYPos), GetConVarFloat(g_cvarHudHoldTime), GetConVarInt(g_cvarHudRed), GetConVarInt(g_cvarHudGreen), GetConVarInt(g_cvarHudBlue), 255);
		for(new i = 1; i <= MaxClients; i++) {
			if(!IsClientInGame(i)) {
				continue;
			}
			
			ShowSyncHudText(i, g_HudSync, "%t", "Price list updated");
			EmitSoundToClient(i, NOTIFICATION_SOUND);
		}
		
		CreateTimer(GetConVarFloat(g_cvarHudHoldTime), Timer_DisplayHudText, array, TIMER_REPEAT);
		return;
	}
	
	PrepPriceKv();
	KvGotoFirstSubKey(g_PriceList);
	
	// TODO: Ticker
	/*
	new bool:isNegative = false;
	new lastUpdate, Float:valueOld, Float:valueOldHigh, Float:value, Float:valueHigh, Float:difference;
	decl String:defindex[16], String:qualityIndex[32], String:quality[32], String:name[64], String:message[128], String:currency[32], String:currencyOld[32], String:oldPrice[64], String:newPrice[64];
	new Handle:array = CreateArray(128);
	PushArrayString(array, "#Type_command");
	if(GetConVarBool(g_cvarDisplayChangedPrices)) {
		do {
			// loop through items
			KvGetSectionName(g_PriceList, defindex, sizeof(defindex));
			if(StringToInt(defindex) == ITEM_REFINED) {
				continue; // Skip over refined price changes
			}
			KvGotoFirstSubKey(g_PriceList);
			do {
				// loop through qualities
				KvGetSectionName(g_PriceList, qualityIndex, sizeof(qualityIndex));
				if(StrEqual(qualityIndex, "item_info"))  {
					KvGetString(g_PriceList, "item_name", name, sizeof(name));
					continue;
				}
				KvGotoFirstSubKey(g_PriceList);
				do {
					// loop through instances (series #s, effects)
					lastUpdate = KvGetNum(g_PriceList, "last_change");
					if(lastUpdate == 0 || lastUpdate < g_Lastg_CacheTime) {
						continue; // hasn't updated
					}
					valueOld = KvGetFloat(g_PriceList, "value_old");
					valueOldHigh = KvGetFloat(g_PriceList, "value_high_old");
					value = KvGetFloat(g_PriceList, "value");
					valueHigh = KvGetFloat(g_PriceList, "value_high");
					
					KvGetString(g_PriceList, "currency", currency, sizeof(currency));
					KvGetString(g_PriceList, "currency_old", currencyOld, sizeof(currencyOld));
					
					if(strlen(currency) == 0 || strlen(currencyOld) == 0) {
						continue;
					}
					
					FormatPriceRange(valueOld, valueOldHigh, currency, oldPrice, sizeof(oldPrice), StrEqual(qualityIndex, QUALITY_UNUSUAL));
					FormatPriceRange(value, valueHigh, currency, newPrice, sizeof(newPrice), StrEqual(qualityIndex, QUALITY_UNUSUAL));
					
					// Get an average so we can determine if it went up or down
					if(valueOldHigh != 0.0) {
						valueOld = FloatDiv(FloatAdd(valueOld, valueOldHigh), 2.0);
					}
					
					if(valueHigh != 0.0) {
						value = FloatDiv(FloatAdd(value, valueHigh), 2.0);
					}
					
					// Get prices in terms of refined now so we can determine if it went up or down
					if(StrEqual(currencyOld, "earbuds")) {
						valueOld = FloatMul(FloatMul(valueOld, budsToKeys), keysToRef);
					} else if(StrEqual(currencyOld, "keys")) {
						valueOld = FloatMul(valueOld, keysToRef);
					}
					
					if(StrEqual(currency, "earbuds")) {
						value = FloatMul(FloatMul(value, budsToKeys), keysToRef);
					} else if(StrEqual(currency, "keys")) {
						value = FloatMul(value, keysToRef);
					}
					
					difference = FloatSub(value, valueOld);
					if(difference < 0.0) {
						isNegative = true;
						difference = FloatMul(difference, -1.0);
					} else {
						isNegative = false;
					}
					
					// Format a quality name
					if(StrEqual(qualityIndex, QUALITY_UNIQUE)) {
						Format(quality, sizeof(quality), ""); // if quality is unique, don't display a quality
					} else if(StrEqual(qualityIndex, QUALITY_UNUSUAL) && (StringToInt(defindex) != ITEM_HAUNTED_SCRAP && StringToInt(defindex) != ITEM_HEADTAKER)) {
						decl String:effect[16];
						KvGetSectionName(g_PriceList, effect, sizeof(effect));
						if(!GetTrieString(g_Effects, effect, quality, sizeof(quality))) {
							LogError("Unknown unusual effect: %s in OnBackpackTFComplete. Please report this!", effect);
							decl String:kvPath[PLATFORM_MAX_PATH];
							BuildPath(Path_SM, kvPath, sizeof(kvPath), "data/backpack-tf.%d.txt", GetTime());
							if(!FileExists(kvPath)) {
								KeyValuesToFile(g_PriceList, kvPath);
							}
							continue;
						}
					} else {
						if(!GetTrieString(g_Qualities, qualityIndex, quality, sizeof(quality))) {
							LogError("Unknown quality index: %s. Please report this!", qualityIndex);
							continue;
						}
					}
					
					Format(message, sizeof(message), "%s%s%s: %s #From %s #To %s", quality, StrEqual(quality, "") ? "" : " ", name, isNegative ? "#Down" : "#Up", oldPrice, newPrice);
					PushArrayString(array, message);
					
				} while(KvGotoNextKey(g_PriceList)); // end: instances
				KvGoBack(g_PriceList);
				
			} while(KvGotoNextKey(g_PriceList)); // end: qualities
			KvGoBack(g_PriceList);
			
		} while(KvGotoNextKey(g_PriceList)); // end: items
	}
	
	Setg_HudSyncParams(GetConVarFloat(g_cvarHudXPos), GetConVarFloat(g_cvarHudYPos), GetConVarFloat(g_cvarHudHoldTime), GetConVarInt(g_cvarHudRed), GetConVarInt(g_cvarHudGreen), GetConVarInt(g_cvarHudBlue), 255);
	for(new i = 1; i <= MaxClients; i++) {
		if(!IsClientInGame(i)) {
			continue;
		}
		ShowSyncg_HudSync(i, g_HudSync, "%t", "Price list updated");
		EmitSoundToClient(i, NOTIFICATION_SOUND);
	}
	CreateTimer(GetConVarFloat(g_cvarHudHoldTime), Timer_Displayg_HudSync, array, TIMER_REPEAT);*/
}

Float:GetRaw(const String:name[]) {
	decl String:buffer[32];
	PrepPriceKv();
	KvJumpToKey(g_PriceList, name);
	KvJumpToKey(g_PriceList, "prices");
	KvJumpToKey(g_PriceList, QUALITY_UNIQUE);
	KvJumpToKey(g_PriceList, "Tradable");
	KvJumpToKey(g_PriceList, "Craftable");
	KvJumpToKey(g_PriceList, "0");
	return KvGetFloat(g_PriceList, "value_raw");
}

public Action:Timer_DisplayHudText(Handle:timer, any:array) {
	if(GetArraySize(array) == 0) {
		CloseHandle(array);
		return Plugin_Stop;
	}
	
	decl String:text[128], String:display[128];
	GetArrayString(array, 0, text, sizeof(text));
	SetHudTextParams(GetConVarFloat(g_cvarHudXPos), GetConVarFloat(g_cvarHudYPos), GetConVarFloat(g_cvarHudHoldTime), GetConVarInt(g_cvarHudRed), GetConVarInt(g_cvarHudGreen), GetConVarInt(g_cvarHudBlue), 255);
	for(new i = 1; i <= MaxClients; i++) {
		if(!IsClientInGame(i)) {
			continue;
		}
		
		PerformTranslationTokenReplacement(i, text, display, sizeof(display));
		ShowSyncHudText(i, g_HudSync, display);
	}
	
	RemoveFromArray(array, 0);
	return Plugin_Continue;
}

PerformTranslationTokenReplacement(client, const String:message[], String:output[], maxlen) {
	SetGlobalTransTarget(client);
	strcopy(output, maxlen, message);
	decl String:buffer[64];
	
	Format(buffer, maxlen, "%t", "Type !pc for a price check");
	ReplaceString(output, maxlen, "#Type_command", buffer);
	
	Format(buffer, maxlen, "%t", "Up");
	ReplaceString(output, maxlen, "#Up", buffer);
	
	Format(buffer, maxlen, "%t", "Down");
	ReplaceString(output, maxlen, "#Down", buffer);
	
	Format(buffer, maxlen, "%t", "From");
	ReplaceString(output, maxlen, "#From", buffer);
	
	Format(buffer, maxlen, "%t", "To");
	ReplaceString(output, maxlen, "#To", buffer);
}

PrepPriceKv() {
	KvRewind(g_PriceList);
	KvJumpToKey(g_PriceList, "items");
}

public Action:Command_PriceCheck(client, args) {
	if(g_PriceList == INVALID_HANDLE) {
		ReplyToCommand(client, "\x04[SM] \x01%t.", "The price list has not loaded yet");
		return Plugin_Handled;
	}
	
	if(args == 0) {
		new Handle:menu = CreateMenu(Handler_ItemSelection);
		SetMenuTitle(menu, "%T", "Price check title", client);
		PrepPriceKv();
		KvGotoFirstSubKey(g_PriceList);
		decl String:name[128];
		do {
			KvGetSectionName(g_PriceList, name, sizeof(name));
			AddMenuItem(menu, name, name);
		} while(KvGotoNextKey(g_PriceList));
		
		DisplayMenu(menu, client, GetConVarInt(g_cvarMenuHoldTime));
		return Plugin_Handled;
	}
	
	PrepPriceKv();
	
	decl String:name[128];
	GetCmdArgString(name, sizeof(name));
	if(StripQuotes(name)) {
		// Exact match
		if(!KvJumpToKey(g_PriceList, name)) {
			ReplyToCommand(client, "\x04[SM] \x01%t.", "No matching item");
			return Plugin_Handled;
		}
		
		ShowPriceMenu(client);
		return Plugin_Handled;
	}
	
	KvGotoFirstSubKey(g_PriceList);
	new Handle:matches = CreateArray(128);
	
	decl String:itemName[128];
	do {
		KvGetSectionName(g_PriceList, itemName, sizeof(itemName));
		if(StrContains(itemName, name, false) != -1) {
			PushArrayString(matches, itemName);
		}
	} while(KvGotoNextKey(g_PriceList));
	
	new count = GetArraySize(matches);
	if(count == 0) {
		PrintToChat(client, "\x04[SM] \x01%t.", "No matching item");
	} else if(count == 1) {
		GetArrayString(matches, 0, name, sizeof(name));
		PrepPriceKv();
		KvJumpToKey(g_PriceList, name);
		ShowPriceMenu(client);
	} else {
		new Handle:menu = CreateMenu(Handler_ItemSelection);
		SetMenuTitle(menu, "%T", "Search Results", client);
		new size = GetArraySize(matches);
		for(new i = 0; i < size; i++) {
			GetArrayString(matches, i, itemName, sizeof(itemName));
			AddMenuItem(menu, itemName, itemName);
		}
		
		DisplayMenu(menu, client, GetConVarInt(g_cvarMenuHoldTime));
		CloseHandle(matches);
	}
	
	return Plugin_Handled;
}

ShowPriceMenu(client) {
	decl String:itemName[128];
	KvGetSectionName(g_PriceList, itemName, sizeof(itemName));
	KvJumpToKey(g_PriceList, "prices");
	KvGotoFirstSubKey(g_PriceList);
	
	new Handle:menu = CreateMenu(Handler_PriceMenu);
	SetGlobalTransTarget(client);
	SetMenuTitle(menu, "%t\n%t\n \n", "Price list title", itemName, "Prices are estimates");
	
	decl String:section[64], String:qualityName[32], String:tradability[32], String:craftability[32], String:currency[32], String:buffer[32], String:buffer2[32];
	// First iterate qualities
	do {
		qualityName[0] = '\0';
		
		KvGetSectionName(g_PriceList, section, sizeof(section));
		if(!GetTrieString(g_Qualities, section, qualityName, sizeof(qualityName))) {
			Format(qualityName, sizeof(qualityName), "Quality %d", section);
		}
		
		new temp;
		if(StrEqual(qualityName, "Unusual") && !GetTrieValue(g_NoEffectUnusuals, itemName, temp)) {
			Format(buffer, sizeof(buffer), "effects\n%s", itemName);
			Format(buffer2, sizeof(buffer2), "%t", "View effects");
			AddMenuItem(menu, buffer, buffer2);
			continue;
		}
		
		KvGotoFirstSubKey(g_PriceList);
		// Iterate tradability
		do {
			KvGetSectionName(g_PriceList, tradability, sizeof(tradability));
			
			KvGotoFirstSubKey(g_PriceList);
			// Iterate craftability
			do {
				KvGetSectionName(g_PriceList, craftability, sizeof(craftability));
				
				KvGotoFirstSubKey(g_PriceList);
				// Iterate instances (series, effect)
				do {
					KvGetSectionName(g_PriceList, section, sizeof(section));
					
					KvGetString(g_PriceList, "currency", currency, sizeof(currency));
					RenderPriceItem(menu, tradability, craftability, qualityName, StringToInt(section), itemName, KvGetFloat(g_PriceList, "value"), KvGetFloat(g_PriceList, "value_high"), currency, true);
				} while(KvGotoNextKey(g_PriceList)); // Instances
				
				KvGoBack(g_PriceList);
			} while(KvGotoNextKey(g_PriceList)); // Craftability
			
			KvGoBack(g_PriceList);
		} while(KvGotoNextKey(g_PriceList)); // Tradability
		
		KvGoBack(g_PriceList);
	} while(KvGotoNextKey(g_PriceList)); // Quality
	
	DisplayMenu(menu, client, GetConVarInt(g_cvarMenuHoldTime));
}

public Handler_ItemSelection(Handle:menu, MenuAction:action, client, param) {
	if(action == MenuAction_End) {
		CloseHandle(menu);
	}
	
	if(action != MenuAction_Select) {
		return;
	}
	
	decl String:selection[128];
	GetMenuItem(menu, param, selection, sizeof(selection));
	FakeClientCommand(client, "sm_pricecheck \"%s\"", selection);
}

public Handler_PriceMenu(Handle:menu, MenuAction:action, client, param) {
	if(action == MenuAction_End) {
		CloseHandle(menu);
	}
	
	if(action != MenuAction_Select) {
		return;
	}
	
	decl String:selection[256];
	GetMenuItem(menu, param, selection, sizeof(selection));
	
	if(StrContains(selection, "http://") == 0) {
		AdvMOTD_ShowMOTDPanel(client, "backpack.tf", selection, MOTDPANEL_TYPE_URL, true, true, true, OnItemInfoFailure);
		return;
	}
	
	decl String:parts[2][64];
	ExplodeString(selection, "\n", parts, sizeof(parts), sizeof(parts[]));
	
	if(StrEqual(parts[0], "effects")) {
		SetGlobalTransTarget(client);
		
		decl String:buffer[128], String:buffer2[128];
		Format(buffer, sizeof(buffer), "Unusual %s", parts[1]);
		
		new Handle:menu2 = CreateMenu(Handler_PriceMenu);
		SetMenuTitle(menu2, "%t\n%t\n \n", "Price list title", buffer, "Unusual prices are estimates");
		
		Format(buffer, sizeof(buffer), "http://backpack.tf/unusuals/%s", parts[1]);
		Format(buffer2, sizeof(buffer2), "%t", "View online");
		AddMenuItem(menu2, buffer, buffer2);
		
		PrepPriceKv();
		KvJumpToKey(g_PriceList, parts[1]);
		KvJumpToKey(g_PriceList, "prices");
		KvJumpToKey(g_PriceList, QUALITY_UNUSUAL);
		
		KvGotoFirstSubKey(g_PriceList);
		
		decl String:tradability[32], String:craftability[32], String:effect[32], String:currency[32], String:index[32];
		do {
			// Iterate tradability
			KvGetSectionName(g_PriceList, tradability, sizeof(tradability));
			KvGotoFirstSubKey(g_PriceList);
			
			do {
				// Iterate craftability
				KvGetSectionName(g_PriceList, craftability, sizeof(craftability));
				KvGotoFirstSubKey(g_PriceList);
				
				do {
					// Iterate effects
					KvGetSectionName(g_PriceList, index, sizeof(index));
					
					if(!GetTrieString(g_Effects, index, effect, sizeof(effect))) {
						LogError("Unknown effect: %s", index);
						continue;
					}
					
					KvGetString(g_PriceList, "currency", currency, sizeof(currency));
					RenderPriceItem(menu2, tradability, craftability, effect, 0, parts[1], KvGetFloat(g_PriceList, "value"), KvGetFloat(g_PriceList, "value_high"), currency, false);
				} while(KvGotoNextKey(g_PriceList));
				
				KvGoBack(g_PriceList);
			} while(KvGotoNextKey(g_PriceList));
			
			KvGoBack(g_PriceList);
		} while(KvGotoNextKey(g_PriceList));
		
		DisplayMenu(menu2, client, GetConVarInt(g_cvarMenuHoldTime));
	}
}

RenderPriceItem(Handle:menu, const String:tradability[], const String:craftability[], const String:qualityOrEffect[], series, const String:name[], Float:price, Float:priceHigh, const String:currency[], bool:isQuality) {
	decl String:output[128];
	
	if(float(RoundToFloor(price)) == price) {
		Format(output, sizeof(output), "%d", RoundToFloor(price));
	} else {
		Format(output, sizeof(output), "%.2f", price);
	}
	
	if(priceHigh != 0.0) {
		if(float(RoundToFloor(priceHigh)) == priceHigh) {
			Format(output, sizeof(output), "%s-%d", output, RoundToFloor(priceHigh));
		} else {
			Format(output, sizeof(output), "%s-%.2f", output, priceHigh);
		}
	}
	
	// TODO: Handle usd
	
	if(StrEqual(currency, "metal")) {
		Format(output, sizeof(output), "%s %t", output, "refined");
	} else if(StrEqual(currency, "keys") && StrEqual(output, "1")) {
		Format(output, sizeof(output), "%s %t", output, "key");
	} else if(StrEqual(currency, "keys")) {
		Format(output, sizeof(output), "%s %t", output, "keys");
	} else if(StrEqual(currency, "earbuds") && StrEqual(output, "1")) {
		Format(output, sizeof(output), "%s %t", output, "bud");
	} else if(StrEqual(currency, "earbuds")) {
		Format(output, sizeof(output), "%s %t", output, "buds");
	} else {
		LogError("Unknown currency \"%s\"", currency);
		return;
	}
	
	if(series != 0) {
		Format(output, sizeof(output), "%t", "Series", series, output);
	} else {
		decl String:item[64];
		item[0] = '\0';
		
		if(!StrEqual(tradability, "Tradable")) {
			strcopy(item, sizeof(item), tradability);
		}
		
		if(!StrEqual(craftability, "Craftable")) {
			Format(item, sizeof(item), "%s %s", item, craftability);
		}
		
		Format(item, sizeof(item), "%s %s", item, qualityOrEffect);
		TrimString(item);
		ReplaceString(item, sizeof(item), " Unique", "");
		TrimString(item);
		Format(output, sizeof(output), "%s: %s", item, output);
	}
	
	decl String:url[256];
	url[0] = '\0';
	
	if(isQuality) {
		Format(url, sizeof(url), "http://backpack.tf/stats/%s/%s/%s/%s/%d", qualityOrEffect, name, tradability, craftability, series);
	}
	
	AddMenuItem(menu, url, output, isQuality ? ITEMDRAW_DEFAULT : ITEMDRAW_DISABLED);
}

public OnItemInfoFailure(client, MOTDFailureReason:reason) {
	switch(reason) {
		case MOTDFailure_Disabled: PrintToChat(client, "\x04[SM] \x01You cannot view online item information with HTML MOTDs disabled.");
		case MOTDFailure_Matchmaking: PrintToChat(client, "\x04[SM] \x01You cannot view online item information after joining via Quickplay.");
		case MOTDFailure_QueryFailed: PrintToChat(client, "\x04[SM] \x01Unable to view online item information.");
	}
}

public Action:Command_Backpack(client, args) {
	if(!GetConVarBool(g_cvarBPCommand)) {
		return Plugin_Continue;
	}
	
	new target;
	if(args == 0) {
		target = GetClientAimTarget(client);
		if(target <= 0) {
			DisplayClientMenu(client);
			return Plugin_Handled;
		}
	} else {
		decl String:arg1[MAX_NAME_LENGTH];
		GetCmdArg(1, arg1, sizeof(arg1));
		target = FindTargetEx(client, arg1, true, false, false);
		if(target == -1) {
			DisplayClientMenu(client);
			return Plugin_Handled;
		}
	}
	
	decl String:steamID[64];
	Steam_GetCSteamIDForClient(target, steamID, sizeof(steamID)); // we could use the regular Steam ID, but we already have SteamTools, so we can just bypass backpack.tf's redirect directly
	decl String:url[256];
	Format(url, sizeof(url), "http://backpack.tf/profiles/%s", steamID);
	AdvMOTD_ShowMOTDPanel(client, "backpack.tf", url, MOTDPANEL_TYPE_URL, true, true, true, OnBackpackMOTDFailure);
	return Plugin_Handled;
}

public OnBackpackMOTDFailure(client, MOTDFailureReason:reason) {
	switch(reason) {
		case MOTDFailure_Disabled: PrintToChat(client, "\x04[SM] \x01You cannot view backpacks with HTML MOTDs disabled.");
		case MOTDFailure_Matchmaking: PrintToChat(client, "\x04[SM] \x01You cannot view backpacks after joining via Quickplay.");
		case MOTDFailure_QueryFailed: PrintToChat(client, "\x04[SM] \x01Unable to open backpack.");
	}
}

DisplayClientMenu(client) {
	new Handle:menu = CreateMenu(Handler_ClientMenu);
	SetMenuTitle(menu, "%T", "Select Player", client);
	decl String:name[MAX_NAME_LENGTH], String:index[8];
	for(new i = 1; i <= MaxClients; i++) {
		if(!IsClientInGame(i) || IsFakeClient(i)) {
			continue;
		}
		GetClientName(i, name, sizeof(name));
		IntToString(GetClientUserId(i), index, sizeof(index));
		AddMenuItem(menu, index, name);
	}
	
	DisplayMenu(menu, client, GetConVarInt(g_cvarMenuHoldTime));
}

public Handler_ClientMenu(Handle:menu, MenuAction:action, client, param) {
	if(action == MenuAction_End) {
		CloseHandle(menu);
	}
	
	if(action != MenuAction_Select) {
		return;
	}
	
	decl String:selection[32];
	GetMenuItem(menu, param, selection, sizeof(selection));
	FakeClientCommand(client, "sm_backpack #%s", selection);
}

public Action:Command_UpdatePrices(client, args) {
	new age = GetCachedPricesAge();
	if(age != -1 && age < 900) { // 15 minutes
		ReplyToCommand(client, "\x04[SM] \x01The price list cannot be updated more frequently than every 15 minutes. It is currently %d minutes old.", age / 60);
		return Plugin_Handled;
	}
	
	ReplyToCommand(client, "\x04[SM] \x01Updating backpack.tf prices...");
	Timer_Update(INVALID_HANDLE);
	return Plugin_Handled;
}

FindTargetEx(client, const String:target[], bool:nobots = false, bool:immunity = true, bool:replyToError = true) {
	decl String:target_name[MAX_TARGET_LENGTH];
	decl target_list[1], target_count, bool:tn_is_ml;
	
	new flags = COMMAND_FILTER_NO_MULTI;
	if(nobots) {
		flags |= COMMAND_FILTER_NO_BOTS;
	}
	if(!immunity) {
		flags |= COMMAND_FILTER_NO_IMMUNITY;
	}
	
	if((target_count = ProcessTargetString(
			target,
			client, 
			target_list, 
			1, 
			flags,
			target_name,
			sizeof(target_name),
			tn_is_ml)) > 0)
	{
		return target_list[0];
	} else {
		if(replyToError) {
			ReplyToTargetError(client, target_count);
		}
		return -1;
	}
}