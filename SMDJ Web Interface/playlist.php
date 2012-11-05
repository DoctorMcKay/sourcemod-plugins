<?php
require('./config.php');
if($_POST['method'] >= 1 && $_POST['method'] <= 3) {
	header('Content-type: text/plain');
	if($_POST['auth'] != md5(sha1($config['pass']))) {
		die('Bad auth token');
	}
	if($_POST['method'] == 1) { // adding
		if(!$_POST['name'] || !$_POST['steamid'] || !$_POST['songs']) {
			die('Invalid data');
		}
		$q = mysql_fetch_array(mysql_query("SELECT * FROM `smdj_playlists` ORDER BY id DESC"));
		$id = $q['id'] + 1;
		$name = mysql_real_escape_string($_POST['name']);
		$steamid = mysql_real_escape_string($_POST['steamid']);
		$songs = mysql_real_escape_string($_POST['songs']);
		if(mysql_num_rows(mysql_query("SELECT * FROM `smdj_playlists` WHERE steamid = '$steamid' AND name = '$name'"))) {
			die('Already exists');
		}
		mysql_query("INSERT INTO `smdj_playlists` (id, name, steamid, songs) VALUES ('$id', '$name', '$steamid', '$songs')");
		exit;
	} elseif($_POST['method'] == 2) { // deleting
		if(!$_POST['id']) {
			die('Invalid data');
		}
		mysql_query("DELETE FROM `smdj_playlists` WHERE id = '" . mysql_real_escape_string($_POST['id']) . "'");
	}
}
if(!$_GET['id']) {
	header('location: index.php');
	exit;
}
$q = mysql_fetch_array(mysql_query("SELECT * FROM `smdj_playlists` WHERE id = '" . mysql_real_escape_string($_GET['id']) . "'"));
if(!$q['id']) {
	header('location: index.php');
	exit;
}
if(isset($_GET['getlist'])) {
	header('Content-type: text/plain');
	$songs = explode(',', $q['songs']);
	if($_GET['shuffle']) {
		shuffle($songs);
	}
	foreach($songs as $value) {
		$info = mysql_fetch_array(mysql_query("SELECT * FROM `smdj_songs` WHERE id = '$value'"));
		if(!$info['title']) {
			continue;
		}
		echo $info['url'] . '|' . $info['title'] . "\n";
	}
	exit;
}
require('./header.php');
?>
<h3><?php echo $q['name']; ?></h3>
<object type="application/x-shockwave-flash" data="player_mp3_multi.swf" width="300" height="200">
    <param name="movie" value="player_mp3_multi.swf" />
    <param name="FlashVars" value="playlist=<?php echo urlencode('playlist.php?id=' . $q['id'] . '&getlist&shuffle=' . $_GET['shuffle']); ?>&amp;autoplay=1&amp;showvolume=1&amp;width=300&amp;height=200" />
</object><br /><br />
<a href="index.php">Song Selection</a>
<?php require('./footer.php'); ?>