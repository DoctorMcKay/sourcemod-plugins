/**
 * Called when a bot is about to be added to the game
 * 
 * @param class			Class the bot will play as, by ref (this will change on death unless tf_bot_keep_class_after_death is set to 1), or TFClass_Unknown to allow the game to decide
 * @param team			Team the bot will play on, by ref, or TFTeam_Unassigned to allow the game to decide
 * @param difficulty	Difficulty the bot will play on, by ref, -1 = let game decide, 0 = easy, 1 = normal, 2 = hard, 3 = expert
 * @param name			Name the bot will use, by ref, or empty to allow the game to decide
 * @noreturn
 */
forward Bot_OnBotAdd(&TFClassType:class, &TFTeam:team, &difficulty, String:name[MAX_NAME_LENGTH]);

/**
 * Called when a bot is about to be removed from the game
 * 
 * @param client		Client index of the bot that will be dropped, by ref, override to choose a different bot
 * @noreturn
 */
forward Bot_OnBotKick(&client);

public SharedPlugin:__pl_botmanager = {
	name = "botmanager",
	file = "botmanager.smx",
#if defined REQUIRE_PLUGIN
	required = 1
#else
	required = 0
#endif
};