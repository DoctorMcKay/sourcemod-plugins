<?php
require('./config.php');
if(isset($_GET['getlist'])) {
	header('Content-type: text/plain');
	$q = mysql_query("SELECT * FROM `smdj_songs`");
	$songs = array();
	$i = 0;
	while($a = mysql_fetch_array($q)) {
		$songs[$i] = $a;
		$i++;
	}
	shuffle($songs);
	foreach($songs as $value) {
		echo $value['url'] . '|' . $value['title'] . "\n";
	}
	exit(0);
}
require('./header.php');
?>
<h3>Shuffle All</h3>
<object type="application/x-shockwave-flash" data="player_mp3_multi.swf" width="300" height="200">
    <param name="movie" value="player_mp3_multi.swf" />
    <param name="FlashVars" value="playlist=<?php echo urlencode('shuffle.php?getlist'); ?>&amp;autoplay=1&amp;showvolume=1&amp;width=300&amp;height=200" />
</object>
<?php require('./footer.php'); ?>