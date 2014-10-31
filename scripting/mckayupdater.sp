/****************************************
 * mckayupdater.sp
 * 
 * This file is used in Dr. McKay's plugins for Updater integration
 * For more info on Dr. McKay's plugins, see http://www.doctormckay.com
 * For more info on Updater, see https://forums.alliedmods.net/showthread.php?t=169095
 * You may copy and use this file, but please be sure to change the URL to your own!
 * 
 * This file does the following tasks:
 * 		- Adds the plugin to Updater's updating pool (using UPDATER_BASE_URL/UPDATE_FILE (UPDATE_FILE should be defined prior to including this file))
 * 		- Creates a cvar CONVAR_PREFIX_auto_update to control whether Updater is enabled (CONVAR_PREFIX should be defined prior to including this file)
 * 		- Creates a version cvar CONVAR_PREFIX_version (CONVAR_PREFIX should be defined prior to including this file)
 * 		- Dynamically adds "A" to the version cvar based on whether Updater is installed and working
 * 
 * If you need to put code into OnAllPluginsLoaded, define ALL_PLUGINS_LOADED_FUNC with a function (doesn't need to be public) to be called inside of OnAllPluginsLoaded
 * 		For example, #define ALL_PLUGINS_LOADED_FUNC AllPluginsLoaded
 * 		AllPluginsLoaded() { ... }
 * 
 * If you need to put code into OnLibraryAdded, define LIBRARY_ADDED_FUNC with a function (doesn't need to be public) to be called inside of OnLibraryAdded
 * 		For example, #define LIBRARY_ADDED_FUNC LibraryAdded
 * 		LibraryAdded(const String:name[]) { ... }
 * 
 * If you need to put code into OnLibraryRemoved, define LIBRARY_REMOVED_FUNC with a function (doesn't need to be public) to be called inside of OnLibraryRemoved
 * 		For example, #define LIBRARY_REMOVED_FUNC LibraryRemoved
 * 		LibraryRemoved(const String:name[]) { ... }
 * 
 * Define RELOAD_ON_UPDATE and the plugin will reload itself upon being updated
 * 
 */

#if defined _mckay_updater_included
 #endinput
#endif
#define _mckay_updater_included

#if defined REQUIRE_PLUGIN
 #undef REQUIRE_PLUGIN
#endif
#include <updater>
#define REQUIRE_PLUGIN

#define UPDATER_BASE_URL "http://hg.doctormckay.com/public-plugins/raw/default"

new Handle:cvarEnableUpdater;
new Handle:cvarVersion;

public OnAllPluginsLoaded() {
	decl String:cvarName[64];
	Format(cvarName, sizeof(cvarName), "%s_auto_update", CONVAR_PREFIX);
	cvarEnableUpdater = CreateConVar(cvarName, "1", "Enables automatic updating (has no effect if Updater is not installed)");
	
	Format(cvarName, sizeof(cvarName), "%s_version", CONVAR_PREFIX);
	cvarVersion = CreateConVar(cvarName, PLUGIN_VERSION, "Plugin Version", FCVAR_DONTRECORD|FCVAR_CHEAT|FCVAR_NOTIFY);
	
	HookConVarChange(cvarEnableUpdater, CheckUpdaterStatus);
	HookConVarChange(cvarVersion, CheckUpdaterStatus);
	CheckUpdaterStatus(INVALID_HANDLE, "", "");
	
#if defined ALL_PLUGINS_LOADED_FUNC
	ALL_PLUGINS_LOADED_FUNC();
#endif
}

public OnLibraryAdded(const String:name[]) {
	CheckUpdaterStatus(INVALID_HANDLE, "", "");
	
#if defined LIBRARY_ADDED_FUNC
	LIBRARY_ADDED_FUNC(name);
#endif
}

public OnLibraryRemoved(const String:name[]) {
	CheckUpdaterStatus(INVALID_HANDLE, "", "");
	
#if defined LIBRARY_REMOVED_FUNC
	LIBRARY_REMOVED_FUNC(name);
#endif
}

public CheckUpdaterStatus(Handle:convar, const String:name[], const String:value[]) {
	if(cvarVersion == INVALID_HANDLE) {
		return; // Version cvar not created yet
	}
	
	if(LibraryExists("updater") && GetConVarBool(cvarEnableUpdater)) {
		decl String:url[512], String:version[12];
		Format(url, sizeof(url), "%s/%s", UPDATER_BASE_URL, UPDATE_FILE);
		Updater_AddPlugin(url); // Has no effect if we're already in Updater's pool
		
		Format(version, sizeof(version), "%sA", PLUGIN_VERSION);
		SetConVarString(cvarVersion, version);
	} else {
		SetConVarString(cvarVersion, PLUGIN_VERSION);
	}
}

public Action:Updater_OnPluginChecking() {
	if(!GetConVarBool(cvarEnableUpdater)) {
		return Plugin_Handled;
	}
	return Plugin_Continue;
}

#if defined RELOAD_ON_UPDATE
public Updater_OnPluginUpdated() {
	ReloadPlugin();
}
#endif