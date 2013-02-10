#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <steamtools>

#undef REQUIRE_PLUGIN
#include <updater>

#define UPDATE_URL			"http://hg.doctormckay.com/public-plugins/raw/default/backpack-tf.txt"
#define PLUGIN_VERSION		"1.7.0"
#define BACKPACK_TF_URL		"http://backpack.tf/api/IGetPrices/v2/"
#define STEAM_URL			"http://www.doctormckay.com/steamapi/itemnames.php" // please don't use this page for anything besides this plugin, I don't want my server to crash... code used to generate it is here: http://pastebin.com/GV5HUtMZ ... don't make me limit requests to this page by IP... I will do it if necessary
#define ITEM_EARBUDS		143
#define ITEM_KEY			5021
#define ITEM_CRATE			5022
#define ITEM_SALVAGED_CRATE	5068
#define ITEM_HAUNTED_SCRAP	267
#define ITEM_HEADTAKER		266
#define QUALITY_UNIQUE		"6"
#define QUALITY_UNUSUAL		"5"
#define NOTIFICATION_SOUND	"replay/downloadcomplete.wav"

public Plugin:myinfo = {
	name        = "[TF2] backpack.tf Price Check",
	author      = "Dr. McKay",
	description = "Provides a price check command for use with backpack.tf",
	version     = PLUGIN_VERSION,
	url         = "http://www.doctormckay.com"
};

new lastCacheTime;
new cacheTime;
new Handle:backpackTFPricelist;
new Handle:steamSchema;

new String:keyPrice[16];
new String:budsPrice[16];

new Handle:itemNameTrie;
new Handle:qualityNameTrie;
new Handle:unusualNameTrie;

new Handle:cvarBPCommand;
new Handle:cvarDisplayUpdateNotification;
new Handle:cvarDisplayChangedPrices;
new Handle:cvarHudXPos;
new Handle:cvarHudYPos;
new Handle:cvarMenuHoldTime;
new Handle:cvarDisplayOnWebsite;
new Handle:cvarUpdater;

new Handle:hudText;

new bool:noPrices = true;

new Handle:hostname;
new Handle:hostport;
new Handle:sv_password;

public OnPluginStart() {
	cvarBPCommand = CreateConVar("backpack_tf_bp_command", "1", "Enables the !bp command for use with backpack.tf");
	cvarDisplayUpdateNotification = CreateConVar("backpack_tf_display_update_notification", "1", "Display a notification to clients when the cached price list has been updated?");
	cvarDisplayChangedPrices = CreateConVar("backpack_tf_display_changed_prices", "1", "If backpack_tf_display_update_notification is set to 1, display all prices that changed since the last update?");
	cvarHudXPos = CreateConVar("backpack_tf_update_notification_x_pos", "0.01", "X position for HUD text", _, true, -1.0, true, 1.0);
	cvarHudYPos = CreateConVar("backpack_tf_update_notification_y_pos", "0.01", "Y position for HUD text", _, true, -1.0, true, 1.0);
	cvarMenuHoldTime = CreateConVar("backpack_tf_menu_open_time", "0", "Time to keep the price panel open for, 0 = forever");
	cvarDisplayOnWebsite = CreateConVar("backpack_tf_display_on_website", "1", "Enable to display your server on backpack.tf's server list");
	cvarUpdater = CreateConVar("backpack_tf_auto_update", "1", "Enables automatic updating (has no effect if Updater is not installed)");
	
	hostname = FindConVar("hostname");
	hostport = FindConVar("hostport");
	sv_password = FindConVar("sv_password");
	
	RegAdminCmd("sm_bp", Command_Backpack, 0, "Usage: sm_bp <player>");
	RegAdminCmd("sm_backpack", Command_Backpack, 0, "Usage: sm_backpack <player>");
	
	RegAdminCmd("sm_pc", Command_PriceCheck, 0, "Usage: sm_pc <item>");
	RegAdminCmd("sm_pricecheck", Command_PriceCheck, 0, "Usage: sm_pricecheck <item>");
	
	RegAdminCmd("sm_updateprices", Command_UpdatePrices, ADMFLAG_ROOT, "Updates backpack.tf prices");
	
	qualityNameTrie = CreateTrie();
	SetTrieString(qualityNameTrie, "0", "Normal");
	SetTrieString(qualityNameTrie, "1", "Genuine");
	SetTrieString(qualityNameTrie, "2", "rarity2");
	SetTrieString(qualityNameTrie, "3", "Vintage");
	SetTrieString(qualityNameTrie, "4", "rarity3");
	SetTrieString(qualityNameTrie, "5", "Unusual");
	SetTrieString(qualityNameTrie, "6", "Unique");
	SetTrieString(qualityNameTrie, "7", "Community");
	SetTrieString(qualityNameTrie, "8", "Valve");
	SetTrieString(qualityNameTrie, "9", "Self-Made");
	SetTrieString(qualityNameTrie, "10", "Customized");
	SetTrieString(qualityNameTrie, "11", "Strange");
	SetTrieString(qualityNameTrie, "12", "Completed");
	SetTrieString(qualityNameTrie, "13", "Haunted");
	SetTrieString(qualityNameTrie, "600", "Uncraftable"); // custom for backpack.tf
	
	unusualNameTrie = CreateTrie();
	SetTrieString(unusualNameTrie, "6", "Green Confetti");
	SetTrieString(unusualNameTrie, "7", "Purple Confetti");
	SetTrieString(unusualNameTrie, "8", "Haunted Ghosts");
	SetTrieString(unusualNameTrie, "9", "Green Energy");
	SetTrieString(unusualNameTrie, "10", "Purple Energy");
	SetTrieString(unusualNameTrie, "11", "Circling TF Logo");
	SetTrieString(unusualNameTrie, "12", "Massed Flies");
	SetTrieString(unusualNameTrie, "13", "Burning Flames");
	SetTrieString(unusualNameTrie, "14", "Scorching Flames");
	SetTrieString(unusualNameTrie, "15", "Searing Plasma");
	SetTrieString(unusualNameTrie, "16", "Vivid Plasma");
	SetTrieString(unusualNameTrie, "17", "Sunbeams");
	SetTrieString(unusualNameTrie, "18", "Circling Peace Sign");
	SetTrieString(unusualNameTrie, "19", "Circling Heart");
	SetTrieString(unusualNameTrie, "29", "Stormy Storm");
	SetTrieString(unusualNameTrie, "30", "Blizzardy Storm");
	SetTrieString(unusualNameTrie, "31", "Nuts n' Bolts");
	SetTrieString(unusualNameTrie, "32", "Orbiting Planets");
	SetTrieString(unusualNameTrie, "33", "Orbiting Fire");
	SetTrieString(unusualNameTrie, "34", "Bubbling");
	SetTrieString(unusualNameTrie, "35", "Smoking");
	SetTrieString(unusualNameTrie, "36", "Steaming");
	SetTrieString(unusualNameTrie, "37", "Flaming Lantern");
	SetTrieString(unusualNameTrie, "38", "Cloudy Moon");
	SetTrieString(unusualNameTrie, "39", "Cauldron Bubbles");
	SetTrieString(unusualNameTrie, "40", "Eerie Orbiting Fire");
	SetTrieString(unusualNameTrie, "43", "Knifestorm");
	SetTrieString(unusualNameTrie, "44", "Misty Skull");
	SetTrieString(unusualNameTrie, "45", "Harvest Moon");
	SetTrieString(unusualNameTrie, "46", "It's A Secret To Everybody");
	SetTrieString(unusualNameTrie, "47", "Stormy 13th Hour");
	
	hudText = CreateHudSynchronizer();
	
	CreateTimer(3600.0, Timer_Update, _, TIMER_REPEAT); // please please please do not change this value, once an hour is plenty
}

public Steam_FullyLoaded() {
	DownloadSteamApi();
}

DownloadSteamApi() {
	new HTTPRequestHandle:request = Steam_CreateHTTPRequest(HTTPMethod_GET, STEAM_URL);
	Steam_SendHTTPRequest(request, OnSteamApiComplete);
}

public OnMapStart() {
	PrecacheSound(NOTIFICATION_SOUND);
}

public OnSteamApiComplete(HTTPRequestHandle:HTTPRequest, bool:requestSuccessful, HTTPStatusCode:statusCode) {
	if(statusCode != HTTPStatusCode_OK || !requestSuccessful) {
		LogError("Steam Web API failed. Status code: %i", _:statusCode);
		CreateTimer(60.0, Timer_TrySteamAPI); // try again!
		return;
	}
	decl String:path[256];
	BuildPath(Path_SM, path, sizeof(path), "data/backpack-tf.txt");
	
	Steam_WriteHTTPResponseBody(HTTPRequest, path);
	Steam_ReleaseHTTPRequest(HTTPRequest);
	
	steamSchema = CreateKeyValues("result");
	FileToKeyValues(steamSchema, path);
	KvGotoFirstSubKey(steamSchema);
	itemNameTrie = CreateTrie();
	decl String:defindex[8], String:name[64];
	do {
		KvGetString(steamSchema, "defindex", defindex, sizeof(defindex));
		KvGetString(steamSchema, "name", name, sizeof(name));
		SetTrieString(itemNameTrie, defindex, name);
	} while(KvGotoNextKey(steamSchema));
	DownloadPrices();
}

public Action:Timer_TrySteamAPI(Handle:timer) {
	LogMessage("Attempting to download Steam API again...");
	DownloadSteamApi();
}

DownloadPrices() {
	noPrices = true;
	new HTTPRequestHandle:request = Steam_CreateHTTPRequest(HTTPMethod_GET, BACKPACK_TF_URL);
	Steam_SetHTTPRequestGetOrPostParameter(request, "vdf", "1");
	if(GetConVarBool(cvarDisplayOnWebsite)) {
		decl String:name[128], String:encName[128], String:map[128], String:encMap[128], String:ip[64], String:port[64], octets[4], String:password[64];
		GetConVarString(hostname, name, sizeof(name));
		GetCurrentMap(map, sizeof(map));
		Steam_GetPublicIP(octets);
		Format(ip, sizeof(ip), "%d.%d.%d.%d", octets[0], octets[1], octets[2], octets[3]);
		IntToString(GetConVarInt(hostport), port, sizeof(port));
		GetConVarString(sv_password, password, sizeof(password));
		
		UrlEncodeString(encName, sizeof(encName), name);
		UrlEncodeString(encMap, sizeof(encMap), map);
		
		Steam_SetHTTPRequestGetOrPostParameter(request, "hostname", encName);
		Steam_SetHTTPRequestGetOrPostParameter(request, "map", encMap);
		Steam_SetHTTPRequestGetOrPostParameter(request, "ip", ip);
		Steam_SetHTTPRequestGetOrPostParameter(request, "port", port);
		Steam_SetHTTPRequestGetOrPostParameter(request, "password", (strlen(password) == 0) ? "0" : "1");
	}
	Steam_SendHTTPRequest(request, OnBackpackTFComplete);
}

// Borrowed from Dynamic MOTD
UrlEncodeString(String:output[], size, const String:input[])
{
	new icnt = 0;
	new ocnt = 0;
	
	for(;;)
	{
		if (ocnt == size)
		{
			output[ocnt-1] = '\0';
			return;
		}
		
		new c = input[icnt];
		if (c == '\0')
		{
			output[ocnt] = '\0';
			return;
		}
		
		// Use '+' instead of '%20'.
		// Still follows spec and takes up less of our limited buffer.
		if (c == ' ')
		{
			output[ocnt++] = '+';
		}
		else if ((c < '0' && c != '-' && c != '.') ||
			(c < 'A' && c > '9') ||
			(c > 'Z' && c < 'a' && c != '_') ||
			(c > 'z' && c != '~')) 
		{
			output[ocnt++] = '%';
			Format(output[ocnt], size-strlen(output[ocnt]), "%x", c);
			ocnt += 2;
		}
		else
		{
			output[ocnt++] = c;
		}
		
		icnt++;
	}
}

public Action:Timer_Update(Handle:timer) {
	DownloadPrices();
}

public OnBackpackTFComplete(HTTPRequestHandle:HTTPRequest, bool:requestSuccessful, HTTPStatusCode:statusCode) {
	if(statusCode != HTTPStatusCode_OK || !requestSuccessful) {
		LogError("backpack.tf API failed. Status code: %i", _:statusCode);
		CreateTimer(60.0, Timer_Update); // try again!
		return;
	}
	decl String:path[256];
	BuildPath(Path_SM, path, sizeof(path), "data/backpack-tf.txt");
	
	Steam_WriteHTTPResponseBody(HTTPRequest, path);
	Steam_ReleaseHTTPRequest(HTTPRequest);
	PrintToServer("backpack.tf price list successfully downloaded!");
	
	if(backpackTFPricelist != INVALID_HANDLE) {
		CloseHandle(backpackTFPricelist);
	}
	backpackTFPricelist = CreateKeyValues("Response");
	FileToKeyValues(backpackTFPricelist, path);
	lastCacheTime = cacheTime;
	cacheTime = KvGetNum(backpackTFPricelist, "current_time");
	decl String:buffer[32];
	
	IntToString(ITEM_KEY, buffer, sizeof(buffer));
	PrepPriceKv();
	KvJumpToKey(backpackTFPricelist, buffer);
	KvJumpToKey(backpackTFPricelist, QUALITY_UNIQUE);
	KvJumpToKey(backpackTFPricelist, "0");
	KvGetString(backpackTFPricelist, "price", keyPrice, sizeof(keyPrice));
	
	IntToString(ITEM_EARBUDS, buffer, sizeof(buffer));
	PrepPriceKv();
	KvJumpToKey(backpackTFPricelist, buffer);
	KvJumpToKey(backpackTFPricelist, QUALITY_UNIQUE);
	KvJumpToKey(backpackTFPricelist, "0");
	KvGetString(backpackTFPricelist, "price", budsPrice, sizeof(budsPrice));
	
	CleanString(keyPrice, sizeof(keyPrice));
	CleanString(budsPrice, sizeof(budsPrice));
	
	noPrices = false;
	
	PrintToServer("Key: %s ref", keyPrice);
	PrintToServer("Buds: %.2f keys, %s ref", StringToFloat(budsPrice) / StringToFloat(keyPrice), budsPrice);
	
	if(!GetConVarBool(cvarDisplayUpdateNotification)) {
		return;
	}
	
	if(lastCacheTime == 0) { // first download
		new Handle:array = CreateArray(64);
		PushArrayString(array, "Type !pc for a price check.");
		SetHudTextParams(GetConVarFloat(cvarHudXPos), GetConVarFloat(cvarHudYPos), 4.0, 0, 255, 0, 255);
		for(new i = 1; i <= MaxClients; i++) {
			if(!IsClientInGame(i) || IsFakeClient(i)) {
				continue;
			}
			ShowSyncHudText(i, hudText, "Price list updated.");
			EmitSoundToClient(i, NOTIFICATION_SOUND);
		}
		CreateTimer(4.0, Timer_DisplayHudText, array, TIMER_REPEAT);
		return;
	}
	
	PrepPriceKv();
	KvGotoFirstSubKey(backpackTFPricelist);
	new bool:isNegative = false;
	decl String:defindex[8], String:section[32], String:quality[32], String:name[64], String:difference[32], String:message[128], String:lastUpdate[32];
	new Handle:array = CreateArray(128);
	PushArrayString(array, "Type !pc for a price check.");
	if(GetConVarBool(cvarDisplayChangedPrices)) {
		do {
			// loop through items
			KvGetSectionName(backpackTFPricelist, defindex, sizeof(defindex));
			KvGotoFirstSubKey(backpackTFPricelist);
			do {
				// loop through qualities
				KvGetSectionName(backpackTFPricelist, section, sizeof(section));
				KvGotoFirstSubKey(backpackTFPricelist);
				do {
					// loop through instances (series #s, effects)
					KvGetString(backpackTFPricelist, "last_update", lastUpdate, sizeof(lastUpdate));
					if(strlen(lastUpdate) == 0 || StringToInt(lastUpdate) == 0 || StringToInt(lastUpdate) < lastCacheTime) {
						continue; // hasn't updated
					}
					KvGetString(backpackTFPricelist, "last_change", difference, sizeof(difference));
					CleanString(difference, sizeof(difference));
					
					if(StrEqual(section, QUALITY_UNIQUE)) {
						Format(quality, sizeof(quality), ""); // if quality is unique, don't display a quality
					} else {
						if(!GetTrieString(qualityNameTrie, section, quality, sizeof(quality))) {
							LogError("Unknown quality index: %s. Please report this!", section);
							continue;
						}
					}
					
					GetTrieString(itemNameTrie, defindex, name, sizeof(name));
					ReplaceString(name, sizeof(name), "The ", "");
					
					isNegative = (difference[0] == '-');
					if(isNegative) {
						GetPriceString(difference[1], difference, sizeof(difference), StringToInt(defindex), section);
					} else {
						GetPriceString(difference, difference, sizeof(difference), StringToInt(defindex), section);
					}
					
					Format(message, sizeof(message), "%s%s%s: %s%s", quality, StrEqual(quality, "") ? "" : " ", name, isNegative ? "-" : "+", difference);
					PushArrayString(array, message);
					
				} while(KvGotoNextKey(backpackTFPricelist)); // end: instances
				KvGoBack(backpackTFPricelist);
				
			} while(KvGotoNextKey(backpackTFPricelist)); // end: qualities
			KvGoBack(backpackTFPricelist);
			
		} while(KvGotoNextKey(backpackTFPricelist)); // end: items
	}
	
	SetHudTextParams(GetConVarFloat(cvarHudXPos), GetConVarFloat(cvarHudYPos), 4.0, 0, 255, 0, 255);
	for(new i = 1; i <= MaxClients; i++) {
		if(!IsClientInGame(i) || IsFakeClient(i)) {
			continue;
		}
		ShowSyncHudText(i, hudText, "Price list updated.");
		EmitSoundToClient(i, NOTIFICATION_SOUND);
	}
	CreateTimer(4.0, Timer_DisplayHudText, array, TIMER_REPEAT);
}

public Action:Timer_DisplayHudText(Handle:timer, any:array) {
	if(GetArraySize(array) == 0) {
		CloseHandle(array);
		return Plugin_Stop;
	}
	decl String:text[64];
	GetArrayString(array, 0, text, sizeof(text));
	SetHudTextParams(GetConVarFloat(cvarHudXPos), GetConVarFloat(cvarHudYPos), 4.0, 0, 255, 0, 255);
	for(new i = 1; i <= MaxClients; i++) {
		if(!IsClientInGame(i) || IsFakeClient(i)) {
			continue;
		}
		ShowSyncHudText(i, hudText, text);
	}
	RemoveFromArray(array, 0);
	return Plugin_Continue;
}

PrepPriceKv() {
	KvRewind(backpackTFPricelist);
	KvJumpToKey(backpackTFPricelist, "prices");
}

CleanString(String:str[], maxlen) {
	new pastDecimal = -1;
	for(new i = 0; i < maxlen; i++) {
		if(str[i] == '\0') {
			break;
		}
		if(str[i] == '.') {
			pastDecimal = 0;
			continue;
		}
		if(pastDecimal == -1) {
			continue;
		}
		pastDecimal++;
		if(pastDecimal > 2 && str[i] == '0') {
			str[i] = '\0';
			break;
		}
		if(pastDecimal > 2 && str[i] == '9') {
			str[i] = '\0';
			str[i - 1] = IncrementChar(str[i - 1]);
			break;
		}
	}
}

IncrementChar(char) {
	switch(char) {
		case '0': return '1';
		case '1': return '2';
		case '2': return '3';
		case '3': return '4';
		case '4': return '5';
		case '5': return '6';
		case '6': return '7';
		case '7': return '8';
		case '8': return '9';
		case '9': return '9';
	}
	return '0';
}

public Action:Command_PriceCheck(client, args) {
	if(noPrices || steamSchema == INVALID_HANDLE) {
		ReplyToCommand(client, "\x04[SM] \x01The price list has not been loaded yet.");
		return Plugin_Handled;
	}
	if(args == 0) {
		new Handle:menu = CreateMenu(Handler_ItemSelection);
		SetMenuTitle(menu, "Price Check");
		KvRewind(steamSchema);
		KvGotoFirstSubKey(steamSchema);
		PrepPriceKv();
		decl String:name[128], String:defindex[8];
		do {
			KvGetString(steamSchema, "name", name, sizeof(name));
			KvGetString(steamSchema, "defindex", defindex, sizeof(defindex));
			if(!KvJumpToKey(backpackTFPricelist, defindex)) {
				continue;
			}
			KvGoBack(backpackTFPricelist);
			AddMenuItem(menu, name, name);
		} while(KvGotoNextKey(steamSchema));
		DisplayMenu(menu, client, 0);
		return Plugin_Handled;
	}
	decl String:name[128], String:itemName[128], String:resultName[128]; // resultName stores the current found item, in case we only have one result
	GetCmdArgString(name, sizeof(name));
	new bool:exact = StripQuotes(name);
	KvRewind(steamSchema);
	KvGotoFirstSubKey(steamSchema);
	new defindex = -1;
	PrepPriceKv();
	decl String:index[8];
	new Handle:matches;
	if(!exact) {
		matches = CreateArray(128);
	}
	do {
		KvGetString(steamSchema, "name", itemName, sizeof(itemName));
		if(exact) {
			if(StrEqual(itemName, name, false)) {
				KvGetString(steamSchema, "defindex", index, sizeof(index));
				if(!KvJumpToKey(backpackTFPricelist, index)) {
					continue;
				}
				strcopy(resultName, sizeof(resultName), itemName);
				defindex = KvGetNum(steamSchema, "defindex");
				break;
			}
		} else {
			if(StrContains(itemName, name, false) != -1) {
				KvGetString(steamSchema, "defindex", index, sizeof(index));
				PrepPriceKv();
				if(!KvJumpToKey(backpackTFPricelist, index) || FindStringInArray(matches, itemName) != -1) {
					continue;
				}
				defindex = KvGetNum(steamSchema, "defindex"); // in case there's only one result, store it here
				strcopy(resultName, sizeof(resultName), itemName);
				PushArrayString(matches, itemName);
			}
		}
	} while(KvGotoNextKey(steamSchema));
	if(!exact && GetArraySize(matches) > 1) {
		new Handle:menu = CreateMenu(Handler_ItemSelection);
		SetMenuTitle(menu, "Search Results");
		new size = GetArraySize(matches);
		for(new i = 0; i < size; i++) {
			GetArrayString(matches, i, itemName, sizeof(itemName));
			AddMenuItem(menu, itemName, itemName);
		}
		DisplayMenu(menu, client, 0);
		CloseHandle(matches);
		return Plugin_Handled;
	}
	if(!exact) {
		CloseHandle(matches);
	}
	if(defindex == -1) {
		ReplyToCommand(client, "\x04[SM] \x01No matching item was found.");
		return Plugin_Handled;
	}
	new bool:isCrate = (defindex == ITEM_CRATE || defindex == ITEM_SALVAGED_CRATE);
	new bool:onlyOneUnusual = (defindex == ITEM_HEADTAKER || defindex == ITEM_HAUNTED_SCRAP);
	PrepPriceKv();
	IntToString(defindex, index, sizeof(index));
	KvJumpToKey(backpackTFPricelist, index);
	new Handle:menu = CreateMenu(Handler_PriceListMenu);
	SetMenuTitle(menu, "Price Check: %s\nPrices are estimates only\nPrices courtesy of backpack.tf\n ", resultName);
	KvGotoFirstSubKey(backpackTFPricelist);
	new bool:unusualDisplayed = false;
	decl String:section[8], String:price[64], String:quality[16], String:series[8], String:buffer[64];
	do {
		KvGetSectionName(backpackTFPricelist, section, sizeof(section));
		KvGotoFirstSubKey(backpackTFPricelist);
		do {
			KvGetString(backpackTFPricelist, "price", price, sizeof(price));
			CleanString(price, sizeof(price));
			GetPriceString(price, price, sizeof(price), defindex, section);
			if(StrEqual(section, QUALITY_UNUSUAL) && !onlyOneUnusual) {
				if(!unusualDisplayed) {
					AddMenuItem(menu, index, "Unusual: View Effects");
					unusualDisplayed = true;
				}
			} else {
				if(!GetTrieString(qualityNameTrie, section, quality, sizeof(quality))) {
					LogError("Unknown quality index: %s. Please report this!", section);
					continue;
				}
				if(isCrate) {
					KvGetSectionName(backpackTFPricelist, series, sizeof(series));
					if(StrEqual(series, "0")) {
						continue;
					}
					if(StrEqual(section, QUALITY_UNIQUE)) {
						Format(buffer, sizeof(buffer), "Series %s: %s", series, price);
					} else {
						Format(buffer, sizeof(buffer), "%s: Series %s: %s", quality, series, price);
					}
				} else {
					Format(buffer, sizeof(buffer), "%s: %s", quality, price);
				}
				AddMenuItem(menu, "", buffer, ITEMDRAW_DISABLED);
			}
		} while(KvGotoNextKey(backpackTFPricelist));
		KvGoBack(backpackTFPricelist);
	} while(KvGotoNextKey(backpackTFPricelist));
	DisplayMenu(menu, client, GetConVarInt(cvarMenuHoldTime));
	return Plugin_Handled;
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

public Handler_PriceListMenu(Handle:menu, MenuAction:action, client, param) {
	if(action == MenuAction_End) {
		CloseHandle(menu);
	}
	if(action != MenuAction_Select) {
		return;
	}
	decl String:defindex[32];
	new Handle:menu2 = CreateMenu(Handler_PriceListMenu);
	GetMenuItem(menu, param, defindex, sizeof(defindex));
	decl String:name[64];
	GetTrieString(itemNameTrie, defindex, name, sizeof(name));
	ReplaceString(name, sizeof(name), "The ", "");
	SetMenuTitle(menu2, "Price Check: Unusual %s\nPrices are estimates only\nPrices courtesy of backpack.tf\n ", name);
	PrepPriceKv();
	KvJumpToKey(backpackTFPricelist, defindex);
	KvJumpToKey(backpackTFPricelist, QUALITY_UNUSUAL);
	KvGotoFirstSubKey(backpackTFPricelist);
	decl String:effect[8], String:effectName[64], String:message[128], String:price[64];
	do {
		KvGetSectionName(backpackTFPricelist, effect, sizeof(effect));
		if(!GetTrieString(unusualNameTrie, effect, effectName, sizeof(effectName))) {
			LogError("Unknown unusual effect: %s. Please report this!", effect);
			continue;
		}
		KvGetString(backpackTFPricelist, "price", price, sizeof(price));
		CleanString(price, sizeof(price));
		GetPriceString(price, price, sizeof(price), StringToInt(defindex), QUALITY_UNUSUAL);
		Format(message, sizeof(message), "%s: %s", effectName, price);
		AddMenuItem(menu2, "", message, ITEMDRAW_DISABLED);
	} while(KvGotoNextKey(backpackTFPricelist));
	DisplayMenu(menu2, client, GetConVarInt(cvarMenuHoldTime));
}

GetPriceString(const String:price[], String:priceString[], maxlen, defindex, const String:quality[]) {
	new Float:key = StringToFloat(keyPrice);
	new Float:buds = StringToFloat(budsPrice);
	new Float:prc = StringToFloat(price);
	if(prc >= buds && !(defindex == ITEM_EARBUDS && StrEqual(quality, QUALITY_UNIQUE))) {
		// Get the price in buds, and fix any rounding errors if necessary
		new Float:budsPrc = FloatDiv(prc, buds);
		new Float:budsPricePart = FloatFraction(budsPrc);
		if(FloatCompare(budsPricePart, 0.95) == 1 || FloatCompare(budsPricePart, 0.05) == -1) {
			budsPrc = float(RoundToNearest(budsPrc));
		}
		
		// Get the price in keys, and fix any rounding errors if necessary
		new Float:keyPrc = FloatDiv(prc, key);
		new Float:keyPricePart = FloatFraction(keyPrc);
		if(FloatCompare(keyPricePart, 0.95) == 1 || FloatCompare(keyPricePart, 0.05) == -1) {
			keyPrc = float(RoundToNearest(keyPrc));
		}
		
		Format(priceString, maxlen, "%.2f Bud%s (%.2f Keys)", budsPrc, (FloatCompare(budsPrc, 1.0) == 0) ? "" : "s", keyPrc);
	} else if(prc >= key && !(defindex == ITEM_KEY && StrEqual(quality, QUALITY_UNIQUE))) {
		// Get the price in keys, and fix any rounding errors if necessary
		new Float:keyPrc = FloatDiv(prc, key);
		new Float:keyPricePart = FloatFraction(keyPrc);
		if(FloatCompare(keyPricePart, 0.95) == 1 || FloatCompare(keyPricePart, 0.05) == -1) {
			keyPrc = float(RoundToNearest(keyPrc));
		}
		
		Format(priceString, maxlen, "%.2f Key%s (%s Refined)", keyPrc, (FloatCompare(keyPrc, 1.0) == 0) ? "" : "s", price);
	} else {
		Format(priceString, maxlen, "%s Refined", price);
	}
}

public Action:Command_Backpack(client, args) {
	if(!GetConVarBool(cvarBPCommand)) {
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
	Format(url, sizeof(url), "http://backpack.tf/id/%s", steamID);
	new Handle:Kv = CreateKeyValues("data");
	KvSetString(Kv, "title", "");
	KvSetString(Kv, "type", "2");
	KvSetString(Kv, "msg", url);
	KvSetNum(Kv, "customsvr", 1);
	ShowVGUIPanel(client, "info", Kv);
	CloseHandle(Kv);
	return Plugin_Handled;
}

DisplayClientMenu(client) {
	new Handle:menu = CreateMenu(Handler_ClientMenu);
	SetMenuTitle(menu, "Select Player");
	decl String:name[MAX_NAME_LENGTH], String:index[8];
	for(new i = 1; i <= MaxClients; i++) {
		if(!IsClientInGame(i) || IsFakeClient(i)) {
			continue;
		}
		GetClientName(i, name, sizeof(name));
		IntToString(GetClientUserId(i), index, sizeof(index));
		AddMenuItem(menu, index, name);
	}
	DisplayMenu(menu, client, 0);
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
	DownloadPrices();
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

/////////////////////////////////

public OnAllPluginsLoaded() {
	new Handle:convar;
	if(LibraryExists("updater")) {
		Updater_AddPlugin(UPDATE_URL);
		new String:newVersion[10];
		Format(newVersion, sizeof(newVersion), "%sA", PLUGIN_VERSION);
		convar = CreateConVar("backpack_tf_version", newVersion, "backpack.tf Price Check Version", FCVAR_DONTRECORD|FCVAR_NOTIFY|FCVAR_CHEAT);
	} else {
		convar = CreateConVar("backpack_tf_version", PLUGIN_VERSION, "backpack.tf Price Check Version", FCVAR_DONTRECORD|FCVAR_NOTIFY|FCVAR_CHEAT);	
	}
	HookConVarChange(convar, Callback_VersionConVarChanged);
}

public OnLibraryAdded(const String:name[]) {
	if(StrEqual(name, "updater")) {
		Updater_AddPlugin(UPDATE_URL);
	}
}

public Callback_VersionConVarChanged(Handle:convar, const String:oldValue[], const String:newValue[]) {
	ResetConVar(convar);
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