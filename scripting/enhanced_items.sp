#pragma semicolon 1

#include <sourcemod>

#define PLUGIN_VERSION		"1.1.0"

#define QUALITY_DECORATED_WEAPON	15

public Plugin:myinfo = {
	name		= "[TF2] Enhanced Item Notifications",
	author		= "Dr. McKay",
	description	= "Combines multiple item notifications for the same item into one",
	version		= PLUGIN_VERSION,
	url			= "http://www.doctormckay.com"
};

new Handle:g_ItemsGame;
new Handle:g_Languages;
new Handle:g_Colors;
new Handle:g_ItemsFoundThisFrame[MAXPLAYERS + 1];

enum {
	Item_Quality,
	Item_Method,
	Item_Defindex,
	Item_Quantity,
	Item_Max
};

#define UPDATE_FILE		"enhanced_items.txt"
#define CONVAR_PREFIX	"enhanced_items"

#include "mckayupdater.sp"

public OnPluginStart() {
	// Parse items_game.txt to get names for items
	g_ItemsGame = CreateKeyValues("items_game");
	FileToKeyValues(g_ItemsGame, "scripts/items/items_game.txt");
	
	// Hook the item_found event
	HookEvent("item_found", Event_ItemFound, EventHookMode_Pre);
	
	// Create a trie for languages
	// We'll parse localization files as we need them and store them here
	g_Languages = CreateTrie();
	
	// Handle late-loads
	for(new i = 1; i <= MaxClients; i++) {
		if(IsClientConnected(i)) {
			OnClientConnected(i);
		}
	}
	
	// Load the game's colors, but lowercase them
	new Handle:kv = CreateKeyValues("Scheme");
	FileToKeyValues(kv, "resource/clientscheme.res"); // Reads inside VPKs
	KvJumpToKey(kv, "Colors");
	KvGotoFirstSubKey(kv, false);
	
	g_Colors = CreateTrie();
	
	new r, g, b, color;
	decl String:name[32];
	do {
		KvGetSectionName(kv, name, sizeof(name));
		KvGetColor(kv, NULL_STRING, r, g, b, color); // We don't want alpha so we'll just store it in color, which we'll change on the next line
		color = (r << 16) | (g << 8) | (b << 0);
		
		StrToLower(name);
		
		SetTrieValue(g_Colors, name, color);
	} while(KvGotoNextKey(kv, false));
	
	CloseHandle(kv);
}

public OnClientConnected(client) {
	// There will be 4 elements in each array contained in this array for each item found this frame
	// The first element of each contained array is the item's quality
	// The second is the method by which the item was found
	// The third is the item's defindex
	// The fourth is the number of matching items that were acquired
	g_ItemsFoundThisFrame[client] = CreateArray(Item_Max);
}

public OnClientDisconnect_Post(client) {
	CloseHandle(g_ItemsFoundThisFrame[client]);
}

public Event_ItemFound(Handle:event, const String:name[], bool:dontBroadcast) {
	new client = GetEventInt(event, "player");
	new quality = GetEventInt(event, "quality");
	new method = GetEventInt(event, "method");
	new defindex = GetEventInt(event, "itemdef");
	
	if(quality == QUALITY_DECORATED_WEAPON || method >= 4) {
		return; // Too much garbage to deal with here, we'll just let the default message print
	}
	
	SetEventBroadcast(event, true);
	
	new size = GetArraySize(g_ItemsFoundThisFrame[client]);
	new item[Item_Max];
	for(new i = 0; i < size; i++) {
		GetArrayArray(g_ItemsFoundThisFrame[client], i, item);
		if(item[Item_Quality] == quality && item[Item_Method] == method && item[Item_Defindex] == defindex) {
			item[Item_Quantity]++;
			SetArrayArray(g_ItemsFoundThisFrame[client], i, item);
			return;
		}
	}
	
	item[Item_Quality] = quality;
	item[Item_Method] = method;
	item[Item_Defindex] = defindex;
	item[Item_Quantity] = 1;
	PushArrayArray(g_ItemsFoundThisFrame[client], item);
}

public OnGameFrame() {
	new size, j, item[Item_Max];
	// Iterate through all connected players and send the actual messages
	for(new i = 1; i <= MaxClients; i++) {
		if(!IsClientConnected(i)) {
			continue;
		}
		
		size = GetArraySize(g_ItemsFoundThisFrame[i]);
		for(j = 0; j < size; j++) {
			GetArrayArray(g_ItemsFoundThisFrame[i], j, item);
			BroadcastItem(i, item[Item_Quality], item[Item_Method], item[Item_Defindex], item[Item_Quantity]);
		}
		
		ClearArray(g_ItemsFoundThisFrame[i]);
	}
}

BroadcastItem(client, quality, method, defindex, quantity) {
	if(!ShouldAcquisitionMethodBePrinted(method)) {
		return;
	}
	
	decl String:token[64], String:qualityName[32];
	
	GetAcquisitionMethodToken(method, token, sizeof(token));
	new bool:hasQuality = GetQualityName(quality, qualityName, sizeof(qualityName));
	new color;
	if(hasQuality) {
		StrToLower(qualityName);
		decl String:colorName[64];
		Format(colorName, sizeof(colorName), "qualitycolor%s", qualityName);
		hasQuality = GetTrieValue(g_Colors, colorName, color);
	}
	
	decl String:message[512], String:finder[MAX_NAME_LENGTH], String:itemName[256], String:quantityString[32], String:colorCode[9];
	GetClientName(client, finder, sizeof(finder));
	
	if(hasQuality) {
		Format(colorCode, sizeof(colorCode), ":\x07%06X", color); // Add the : since we're going to replace :: with it
	} else {
		strcopy(colorCode, sizeof(colorCode), ":\x01");
	}
	
	if(quantity == 1) {
		strcopy(quantityString, sizeof(quantityString), "\x01");
	} else {
		Format(quantityString, sizeof(quantityString), "\x01(x%d)", quantity);
	}
	
	for(new i = 1; i <= MaxClients; i++) {
		if(!IsClientInGame(i)) {
			continue;
		}
		
		if(!LocalizeToken(i, token, message, sizeof(message)) || !GetItemName(i, defindex, itemName, sizeof(itemName))) {
			// If we can't localize part of the message, don't show it
			continue;
		}
		
		ReplaceString(message, sizeof(message), "%s1", finder);
		ReplaceString(message, sizeof(message), "%s2", itemName);
		ReplaceString(message, sizeof(message), "%s3", quantityString);
		ReplaceString(message, sizeof(message), "::", colorCode);
		
		new Handle:bf = StartMessageOne("SayText2", i, USERMSG_RELIABLE|USERMSG_BLOCKHOOKS);
		BfWriteByte(bf, client);
		BfWriteByte(bf, false);
		BfWriteString(bf, message);
		EndMessage();
	}
}

GetAcquisitionMethodToken(method, String:token[], maxlen) {
	switch(method) {
		case 0: strcopy(token, maxlen, "Item_Found");
		case 1: strcopy(token, maxlen, "Item_Crafted");
		case 2: strcopy(token, maxlen, "Item_Traded");
		case 3: strcopy(token, maxlen, "Item_Purchased"); // This event isn't triggered anymore
		case 4: strcopy(token, maxlen, "Item_FoundInCrate");
		case 5: strcopy(token, maxlen, "Item_Gifted");
		// 6 and 7 appear to be unused - they print nothing (unprinted acquisition method?)
		case 8: strcopy(token, maxlen, "Item_Earned");
		case 9: strcopy(token, maxlen, "Item_Refunded");
		case 10: strcopy(token, maxlen, "Item_GiftWrapped");
		// 11 through 14 appear to be unused - they print (null) on the client
		case 15: strcopy(token, maxlen, "Item_PeriodicScoreReward");
		case 16: strcopy(token, maxlen, "Item_MvMBadgeCompletionReward");
		case 17: strcopy(token, maxlen, "Item_MvMSquadSurplusReward");
		case 18: strcopy(token, maxlen, "Item_HolidayGift");
		// 19 is "received from the community market", but there's no translation token for it
		// If we wanted we could maybe use Item_Purchased but this also covers items that the player listed and has just removed the listing for
		case 20: strcopy(token, maxlen, "Item_RecipeOutput");
		case 22: strcopy(token, maxlen, "Item_QuestOutput");
		default: strcopy(token, maxlen, "Item_Found"); // The game defaults to "found"
	}
}

bool:ShouldAcquisitionMethodBePrinted(method) {
	switch(method) {
		case 6, 7, 11, 12, 13, 14, 19:
			return false;
	}
	
	return true;
}

bool:GetQualityName(quality, String:name[], maxlen) {
	KvRewind(g_ItemsGame);
	KvJumpToKey(g_ItemsGame, "qualities");
	KvGotoFirstSubKey(g_ItemsGame);
	do {
		if(KvGetNum(g_ItemsGame, "value", (quality == 0 ? -1 : 0)) == quality) {
			KvGetSectionName(g_ItemsGame, name, maxlen);
			return true;
		}
	} while(KvGotoNextKey(g_ItemsGame));
	
	return false;
}

bool:GetItemName(client, defindex, String:name[], maxlen) {
	KvRewind(g_ItemsGame);
	KvJumpToKey(g_ItemsGame, "items");
	
	decl String:def[16];
	IntToString(defindex, def, sizeof(def));
	if(!KvJumpToKey(g_ItemsGame, def)) {
		return false;
	}
	
	decl String:token[64];
	KvGetString(g_ItemsGame, "item_name", token, sizeof(token));
	if(strlen(token) == 0) {
		decl String:prefab[32];
		KvGetString(g_ItemsGame, "prefab", prefab, sizeof(prefab));
		if(strlen(prefab) == 0) {
			return false;
		}
		
		KvRewind(g_ItemsGame);
		KvJumpToKey(g_ItemsGame, "prefabs");
		if(!KvJumpToKey(g_ItemsGame, prefab)) {
			return false;
		}
		
		KvGetString(g_ItemsGame, "item_name", token, sizeof(token));
		if(strlen(token) == 0) {
			return false;
		}
	}
	
	new Handle:lang = GetLanguage(client);
	if(lang == INVALID_HANDLE) {
		LogError("Unable to get item name for server language (attempting to print to \"%L\")!", client);
		return false;
	}
	
	if(!LocalizeToken(client, token[1], name, maxlen)) {
		return false;
	}
	
	decl String:languageName[32];
	GetTrieString(lang, "__name__", languageName, sizeof(languageName));
	if(StrEqual(languageName, "english") && KvGetNum(g_ItemsGame, "propername")) {
		// All non-English languages that I looked at included "The" in the item's name, if applicable
		Format(name, maxlen, "The %s", name);
	}
	
	return true;
}

bool:LocalizeToken(client, const String:token[], String:output[], maxlen) {
	new Handle:lang = GetLanguage(client);
	if(lang == INVALID_HANDLE) {
		LogError("Unable to localize token for server language!");
		return false;
	} else {
		return GetTrieString(lang, token, output, maxlen);
	}
}

Handle:GetLanguage(client) {
	new languageNum = (client == LANG_SERVER ? GetServerLanguage() : GetClientLanguage(client));
	decl String:language[64];
	GetLanguageInfo(languageNum, _, _, language, sizeof(language));
	
	new Handle:lang;
	if(!GetTrieValue(g_Languages, language, lang)) {
		lang = ParseLanguage(language);
		SetTrieValue(g_Languages, language, lang);
	}
	
	if(lang == INVALID_HANDLE && client != LANG_SERVER) {
		// If the client's language isn't valid, fall back to the server's language
		return GetLanguage(LANG_SERVER);
	} else if(lang == INVALID_HANDLE) {
		return INVALID_HANDLE;
	}
	
	return lang;
}

Handle:ParseLanguage(const String:language[]) {
	decl String:filename[64];
	Format(filename, sizeof(filename), "resource/tf_%s.txt", language);
	new Handle:file = OpenFile(filename, "r");
	if(file == INVALID_HANDLE) {
		return INVALID_HANDLE;
	}
	
	// The localization files are encoded in UCS-2, breaking all of our available parsing options
	// We have to go byte-by-byte then line-by-line :(
	
	// This parser isn't perfect since some values span multiple lines, but since we're only interested in single-line values, this is sufficient
	
	new Handle:lang = CreateTrie();
	SetTrieString(lang, "__name__", language);
	
	new data, i = 0, high_surrogate, low_surrogate;
	decl String:line[2048];
	while(ReadFileCell(file, data, 2) == 1) {
		if( high_surrogate ) {
			// for characters in range 0x10000 <= X <= 0x10FFFF
			low_surrogate = data;
			data = ((high_surrogate - 0xD800) << 10) + (low_surrogate - 0xDC00) + 0x10000;
			line[i++] = ((data >> 18) & 0x07) | 0xF0;
			line[i++] = ((data >> 12) & 0x3F) | 0x80;
			line[i++] = ((data >> 6) & 0x3F) | 0x80;
			line[i++] = (data & 0x3F) | 0x80;
			high_surrogate = 0;
		}
		else if(data < 0x80) {
			// It's a single-byte character
			line[i++] = data;
			
			if(data == '\n') {
				line[i] = '\0';
				HandleLangLine(line, lang);
				i = 0;
			}
		}
		else if(data < 0x800) {
			// It's a two-byte character
			line[i++] = ((data >> 6) & 0x1F) | 0xC0;
			line[i++] = (data & 0x3F) | 0x80;
		} else if(data <= 0xFFFF) {
			if(0xD800 <= data <= 0xDFFF) {
				high_surrogate = data;
				continue;
			}
			line[i++] = ((data >> 12) & 0x0F) | 0xE0;
			line[i++] = ((data >> 6) & 0x3F) | 0x80;
			line[i++] = (data & 0x3F) | 0x80;
		}
	}
	
	CloseHandle(file);
	return lang;
}

HandleLangLine(String:line[], Handle:lang) {
	TrimString(line);
	
	if(line[0] != '"') {
		// Not a line containing at least one quoted string
		return;
	}
	
	decl String:token[128], String:value[1024];
	new pos = BreakString(line, token, sizeof(token));
	if(pos == -1) {
		// This line doesn't have two quoted strings
		return;
	}
	
	BreakString(line[pos], value, sizeof(value));
	SetTrieString(lang, token, value);
}

StrToLower(String:str[]) {
	new length = strlen(str);
	for(new i = 0; i < length; i++) {
		str[i] = CharToLower(str[i]);
	}
}
