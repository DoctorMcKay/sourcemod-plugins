#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <socket>

#define PLUGIN_VERSION		"1.0.0"

public Plugin:myinfo = {
	name		= "[ANY] HTTP Text MOTD",
	author		= "Dr. McKay",
	description	= "Downloads a text file over HTTP and displays it as the text MOTD",
	version		= PLUGIN_VERSION,
	url			= "http://www.doctormckay.com"
};

new Handle:g_cvarHost;
new Handle:g_cvarPort;
new Handle:g_cvarPath;
new Handle:g_cvarWriteFile;
new Handle:g_cvarMOTDFileText;
new String:g_Buffer[4096];

#define UPDATE_FILE		"motd_text_http.txt"
#define CONVAR_PREFIX	"motd_text"

#include "mckayupdater.sp"

public OnPluginStart() {
	g_cvarHost = CreateConVar("motd_text_host", "", "Host to download file from (domain or IP)\nExample: www.example.com");
	g_cvarPort = CreateConVar("motd_text_port", "80", "Port your HTTP server is running on (usually 80)");
	g_cvarPath = CreateConVar("motd_text_path", "/", "Path to request from your server\nExample: /motd_text.txt");
	g_cvarWriteFile = CreateConVar("motd_text_write_file", "1", "If 1, writes the content of the downloaded file to the motd_text.txt file (or whatever file is specified by motdfile_text", _, true, 0.0, true, 1.0);
	AutoExecConfig();
	g_cvarMOTDFileText = FindConVar("motdfile_text");
	
	RegAdminCmd("sm_motd_text_redownload", Command_Redownload, ADMFLAG_ROOT, "Redownloads the motd_text.txt file");
}

public Action:Command_Redownload(client, args) {
	DownloadFile();
	ReplyToCommand(client, "\x04[SM] \x01File downloading...");
	return Plugin_Handled;
}

public OnConfigsExecuted() {
	DownloadFile();
}

DownloadFile() {
	g_Buffer[0] = '\0';
	decl String:host[256];
	GetConVarString(g_cvarHost, host, sizeof(host));
	if(strlen(host) == 0) {
		LogMessage("Skipping file download, no host specified");
		return;
	}
	new Handle:socket = SocketCreate(SOCKET_TCP, OnSocketError);
	SocketConnect(socket, OnSocketConnected, OnSocketReceive, OnSocketDisconnect, host, GetConVarInt(g_cvarPort));
	SocketSetOption(socket, ConcatenateCallbacks, 12288);
}

public OnSocketConnected(Handle:socket, any:arg) {
	decl String:host[256], String:path[1024], String:request[2048];
	GetConVarString(g_cvarHost, host, sizeof(host));
	GetConVarString(g_cvarPath, path, sizeof(path));
	Format(request, sizeof(request), "GET %s HTTP/1.0\r\nHost: %s\r\nConnection: close\r\nPragma: no-cache\r\nCache-Control: no-cache\r\n\r\n", path, host);
	SocketSend(socket, request);
}

public OnSocketReceive(Handle:socket, const String:receiveData[], const dataSize, any:arg) {
	StrCat(g_Buffer, sizeof(g_Buffer), receiveData);
}

public OnSocketDisconnect(Handle:socket, any:arg) {
	new pos = StrContains(g_Buffer, "\r\n\r\n");
	new dataPos = pos + 4;
	
	decl String:headerstring[pos + 1];
	strcopy(headerstring, pos + 1, g_Buffer);
	decl String:headers[64][128];
	new total = ExplodeString(headerstring, "\r\n", headers, sizeof(headers), sizeof(headers[]));
	new statusCode = 0;
	for(new i = 0; i < total; i++) {
		if(StrContains(headers[i], "HTTP/") == 0) {
			pos = StrContains(headers[i], " ") + 1;
			new pos2 = pos + StrContains(headers[i][pos], " ");
			decl String:status[pos2 - pos + 1];
			strcopy(status, pos2 - pos + 1, headers[i][pos]);
			statusCode = StringToInt(status);
			i = total;
		}
	}
	
	if(statusCode >= 300) {
		LogError("HTTP request failed. Status code: %d", statusCode);
		CloseHandle(socket);
		return;
	}
	
	decl String:data[4096];
	strcopy(data, sizeof(data), g_Buffer[dataPos]);
	ReplaceString(data, sizeof(data), "\r", "\n");
	
	if(g_cvarMOTDFileText != INVALID_HANDLE && GetConVarBool(g_cvarWriteFile)) {
		decl String:path[PLATFORM_MAX_PATH];
		GetConVarString(g_cvarMOTDFileText, path, sizeof(path));
		new Handle:file = OpenFile(path, "w");
		WriteFileString(file, data, false);
		CloseHandle(file);
	}
	
	new bool:locked = LockStringTables(false);
	new table = FindStringTable("InfoPanel");
	new index = FindStringIndex(table, "motd_text");
	if(index < 0 || index > GetStringTableMaxStrings(table)) {
		AddToStringTable(table, "motd_text", data, sizeof(data));
	} else {
		SetStringTableData(table, index, data, sizeof(data));
	}
	LockStringTables(locked);
}

public OnSocketError(Handle:socket, const errorType, const errorNum, any:arg) {
	LogError("Socket error type %d, error num %d", errorType, errorNum);
	CloseHandle(socket);
}