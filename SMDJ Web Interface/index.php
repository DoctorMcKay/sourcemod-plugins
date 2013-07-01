<?php
require('./config.php');
if($_GET['keyvalues']) {
	header('Content-type: text/plain');
	if($_GET['keyvalues'] != md5(sha1($config['pass']))) {
		die('Bad auth token');
	}
	$q = mysql_query("SELECT * FROM `smdj_songs` ORDER BY title ASC");
	if(!mysql_num_rows($q)) {
		die('No songs');
	}
	echo '"SMDJ"' . "\n";
	echo '{' . "\n";
	echo '	"Songs"' . "\n";
	echo '	{' . "\n";
	$i = 1;
	while($a = mysql_fetch_array($q)) {
		echo '		"' . $i . '"' . "\n";
		echo '		{' . "\n";
		echo '			"id"			"' . $a['id'] . '"' . "\n";
		echo '			"title"			"' . $a['title'] . '"' . "\n";
		echo '		}' . "\n";
		$i++;
	}
	echo '	}' . "\n";
	echo '	"Playlists"' . "\n";
	echo '	{' . "\n";
	$q = mysql_query("SELECT * FROM `smdj_playlists` ORDER BY steamid ASC, name ASC");
	$i = 1;
	while($a = mysql_fetch_array($q)) {
		echo '		"' . $i . '"' . "\n";
		echo '		{' . "\n";
		echo '			"id"			"' . $a['id'] . '"' . "\n";
		echo '			"name"			"' . $a['name'] . '"' . "\n";
		echo '			"steamid"		"' . $a['steamid'] . '"' . "\n";
		echo '			"songs"			"' . $a['songs'] . '"' . "\n";
		echo '		}' . "\n";
	}
	echo '	}' . "\n";
	echo '}';
	exit(0);
}
require('./header.php');
if(mysql_num_rows($query = mysql_query("SELECT * FROM `smdj_songs` WHERE id = '" . mysql_real_escape_string($_GET['play']) . "'"))) {
	$query = mysql_fetch_array($query);
	if(isset($_GET['repeat']) && !$_GET['repeat']) {
		$loop = 0; // Sanitize input
	} else {
		$loop = 1;
	}
	if(isset($_GET['volume']) && $_GET['volume'] >= 10 && $_GET['volume'] <= 200) {
		$volume = $_GET['volume'];
	} else {
		$volume = 100;
	}
	echo '<h3>' . $query['title'] . '</h3>';
	echo '<object type="application/x-shockwave-flash" data="player_mp3_maxi.swf" width="200" height="20">
     <param name="movie" value="player_mp3_maxi.swf" />
     <param name="FlashVars" value="mp3=' . urlencode($query['url']) . '&amp;autoplay=1&amp;volume=' . $volume . '&amp;showvolume=1&amp;loop=' . $loop . '" />
	</object>';
	echo '<br /><br />';
	echo '<a href="index.php">Song Selection</a>';
} else {
	echo '<a href="shuffle.php">Shuffle All</a><br /><br />';
	if(isset($_GET['repeat'])) {
		if($_GET['repeat']) {
			$loop = '&repeat=1';
		} else {
			$loop = '&repeat=0';
		}
	} else {
		$loop = '';
	}
	$query = mysql_query("SELECT * FROM `smdj_songs` ORDER BY title ASC");
	while($arr = mysql_fetch_array($query)) {
		echo '<a href="index.php?play=' . $arr['id'] . $loop . '">' . $arr['title'] . '</a><br />';
	}
	echo '<br /><br />';
	echo '<a href="admin.php">Administration</a>';
}
require('./footer.php');
?>