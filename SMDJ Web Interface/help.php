<?php
require('./config.php');
require('./header.php');
$song = mysql_fetch_array(mysql_query("SELECT * FROM `smdj_songs` ORDER BY title ASC"));
?>
<h1>Adobe Flash Player Help</h1>
Please visit this page in your desktop Web browser: <code>http://<?php echo $_SERVER['HTTP_HOST'] . $_SERVER['REQUEST_URI'] ?></code><br /><br />
<h2>How to install Adobe Flash Player for Other Browsers</h2>
First, go to this URL: <a href="http://get.adobe.com/flashplayer/otherversions/" target="_blank">http://get.adobe.com/flashplayer/otherversions/</a><br />
In Step 1, select your computer's operating system.<br />
In Step 2, select Flash Player (version) for Other Browsers.<br />
Be sure to uncheck any software you don't want, then click Download.<br />
After you install Flash (you may need to reboot), SMDJ should work correctly.<br /><br />
<b>If you can see and use the music player below and are currently viewing this page from in-game, then SMDJ will work for you:</b><br /><br />
<object type="application/x-shockwave-flash" data="player_mp3_maxi.swf" width="200" height="20">
     <param name="movie" value="player_mp3_maxi.swf" />
     <param name="FlashVars" value="mp3=<?php echo urlencode($song['url']); ?>&amp;autoplay=0&amp;volume=100&amp;showvolume=1&amp;loop=0" />
</object>
<?php require('./footer.php'); ?>