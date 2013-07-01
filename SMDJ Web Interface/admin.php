<?php
session_start();
if($_POST['password']) {
	$_SESSION['admin_auth'] = $_POST['password'];
}

require('./config.php');
if($_SESSION['admin_auth'] != $auth && md5($_SESSION['admin_auth']) != $auth) {
	require('./header.php');
	if(isset($_POST['password'])) { echo '<div class="error">Incorrect password specified.</div><br />'; }
	echo 'Please provide your password below.<br /><br />';
	echo '<form method="post" action="admin.php">';
	echo '<input type="password" name="password" /><br />';
	echo '<input type="submit" value="Authenticate" />';
	echo '</form>';
	require('./footer.php');
	exit;
}
if(isset($_GET['upload'])) {
	require('./header.php');
	if($_GET['error'] == 1) { echo '<div class="error">The song title is required.</div>'; }
	if($_GET['error'] == 2) { echo '<div class="error">Filetype must be MP3 (given ' . $_GET['type'] . ')</div>'; }
	if($_GET['error'] == 3) { echo '<div class="error">Unable to connect to the FTP server.</div>'; }
	if($_GET['error'] == 4) { echo '<div class="error">Unable to upload the file to the FTP server.</div>'; }
	if($_GET['errorcode']) { echo '<div class="error">There was an error while uploading the file. Error code: ' . $_GET['errorcode'] . '</div>'; }
	echo '<h2>Upload A Song</h2>';
	echo '<form action="admin.php" method="post" enctype="multipart/form-data">';
	echo '<input type="hidden" name="do" value="upload" />';
	echo '<table>';
	echo '<tr><td>Title:</td><td><input type="text" name="title" style="width:300px" maxlength="33" /></td></tr>';
	echo '<tr><td>File:</td><td><input type="file" name="file" /></td></tr>';
	echo '</table><br /><br />';
	echo '<input type="submit" name="submit" value="Upload" />';
	echo '</form><br /><br />';
	echo '<a href="admin.php">Back To Management</a>';
	require('./footer.php');
	exit;
}
if(isset($_GET['deleteall'])) {
	require('./header.php');
	echo '<h2>Delete All Songs</h2>';
	echo 'WARNING! You are about to nuke your database! All your songs will be permanently cleared.<br /><br />';
	echo 'If you understand what you are doing and want to continue, click the "NUKE!" button below. Otherwise, click the Return link.<br /><br />';
	echo '<form method="post" action="admin.php">';
	echo '<input type="submit" name="nuke" value="NUKE!" />';
	echo '</form><br />';
	echo '<a href="admin.php">Return</a>';
	require('./footer.php');
	exit;
}
if($_POST['nuke']) {
	mysql_query('TRUNCATE TABLE `smdj_songs`');
	header('location: admin.php');
	exit;
}
if($_POST['submit']) {
	if($_POST['do'] == 'upload') {
		if(empty($_POST['title'])) {
			header('location: admin.php?upload&error=1');
			exit;
		}
		if($_FILES['file']['error'] > 0) {
			header('location: admin.php?upload&errorcode=' . $_FILES['file']['error']);
			exit;
		}
		if($_FILES['file']['type'] != 'audio/mp3' && $_FILES['file']['type'] != 'audio/mpeg') {
			header('location: admin.php?upload&error=2&type=' . urlencode($_FILES['file']['type']));
			exit;
		}
		if($uploadmethod == 'local') {
			move_uploaded_file($_FILES['file']['tmp_name'], './music/' . $_FILES['file']['name']);
			$url = 'http://' . $_SERVER['HTTP_HOST'] . $_SERVER['REQUEST_URI'];
			$url = substr($url, 0, strlen($url) - 10);
			$url = $url . '/music/' . $_FILES['file']['name'];
		}
		if($uploadmethod == 'ftp') {
			$ftpcon = ftp_connect($ftp['host']);
			$login = ftp_login($ftpcon, $ftp['user'], $ftp['pass']);
			if(!$ftpcon || !$login) {
				header('location: admin.php?upload&error=3');
				exit;
			}
			$upload = ftp_put($ftpcon, $ftp['path'] . '/' . $_FILES['file']['name'], $_FILES['file']['tmp_name'], FTP_BINARY);
			if(!$upload) {
				header('location: admin.php?upload&error=1');
				exit;
			}
			ftp_close($ftpcon);
			$url = 'http://' . $ftp['http'] . '/' . $_FILES['file']['name'];
		}
		$q = mysql_fetch_array(mysql_query("SELECT * FROM `smdj_songs` ORDER BY id DESC"));
		$id = ++$q['id'];
		mysql_query("INSERT INTO `smdj_songs` (id, title, url) VALUES ('$id', '" . mysql_real_escape_string($_POST['title']) . "', '$url')");
		header('location: admin.php?done=1');
		exit;
	} elseif($_POST['do'] == 'add') {
		if(empty($_POST['title']) || empty($_POST['url'])) {
			header('location: admin.php?error=1');
			exit;
		}
		$q = mysql_fetch_array(mysql_query("SELECT * FROM `smdj_songs` ORDER BY id DESC"));
		$id = ++$q['id'];
		mysql_query("INSERT INTO `smdj_songs` (id, title, url) VALUES ('$id', '" . mysql_real_escape_string($_POST['title']) . "', '" . mysql_real_escape_string($_POST['url']) . "')");
		header('location: admin.php?done=1');
		exit;
	} elseif($_POST['do'] == 'modify') {
		if(empty($_POST['title']) || empty($_POST['url'])) {
			header('location: admin.php?error=1&id=' . $_POST['id']);
			exit;
		}
		mysql_query("UPDATE `smdj_songs` SET title = '" . mysql_real_escape_string($_POST['title']) . "', url = '" . mysql_real_escape_string($_POST['url']) . "' WHERE id = '" . mysql_real_escape_string($_POST['id']) . "'");
		header('location: admin.php?done=2');
		exit;
	} elseif($_POST['delete']) {
		mysql_query("DELETE FROM `smdj_songs` WHERE id = '" . mysql_real_escape_string($_POST['delete']) . "'");
		header('location: admin.php?done=3');
		exit;
	}
}
require('./header.php');
if($_GET['error'] == 1) { echo '<div class="error">The song title and MP3 URL are required.</div>'; }
if($_GET['done'] == 1) { echo '<div class="success">The song has been added.</div>'; }
if($_GET['done'] == 2) { echo '<div class="success">The song has been updated.</div>'; }
if($_GET['done'] == 3) { echo '<div class="success">The song has been deleted.</div>'; }
$version_check = file_get_contents('https://bitbucket.org/Doctor_McKay/public-plugins/raw/default/smdj_version.txt');
if($version_check !== false && $version_check != SMDJ_VERSION) echo '<div class="error">The SMDJ Web Interface is out-of-date. You are running v' . SMDJ_VERSION . ', and the most recent version is v' . $version_check . '</div><br />';
if($_GET['id']) {
	if(!mysql_num_rows($query = mysql_query("SELECT * FROM `smdj_songs` WHERE id = '" . mysql_real_escape_string($_GET['id']) . "'"))) {
		echo 'Invalid song ID!';
	} else {
		$query = mysql_fetch_array($query);
		echo '<h3>' . $query['title'] . '</h3>';
		echo '<form method="post" action="admin.php">';
		echo '<input type="hidden" name="do" value="modify" />';
		echo '<input type="hidden" name="id" value="' . $_GET['id'] . '" />';
		echo '<table>';
		echo '<tr><td>Song Title:</td><td><input type="text" name="title" value="' . $query['title'] . '" style="width:300px" maxlength="33" /></td></tr>';
		echo '<tr><td>MP3 URL:</td><td><input type="text" name="url" value="' . $query['url'] . '" style="width:300px" maxlength="255" /></td></tr>';
		echo '</table>';
		echo '<input type="submit" name="submit" value="Submit" /><br /><br />';
		echo '</form>';
		echo 'Be sure to include the protocol (i.e. <code>http://</code>) in the URL!<br /><br />';
		echo '<form method="post" action="admin.php">';
		echo '<input type="hidden" name="delete" value="' . $_GET['id'] . '" />';
		echo '<input type="submit" name="submit" value="Delete Song" />';
		echo '</form><br /><br />';
		echo '<a href="admin.php">Return To Song List</a>';
	}
} else {
	echo '<table cellpadding="5"><th colspan="2">Plugin Config Variables:</th></tr>';
	echo '<tr><td class="right"><code>smdj_auth_token</code></td><td><code>"' . md5(sha1($config['pass'])) . '"</code></td></tr>';
	echo '<tr><td class="right"><code>smdj_url</code></td><td><code>"http://' . $_SERVER['HTTP_HOST'] . str_replace('/admin.php', '', $_SERVER['SCRIPT_NAME']) . '"</code></td></tr>';
	echo '</table>';
	echo '<h2>Edit A Song</h2>';
	$query = mysql_query("SELECT * FROM `smdj_songs` ORDER BY title ASC");
	while($arr = mysql_fetch_array($query)) {
		echo '<a href="admin.php?id=' . $arr['id'] . '">' . $arr['title'] . '</a><br />';
	}
	echo '<h2>Add A Song</h2>';
	echo '<a href="admin.php?upload">Upload A Song</a><br />';
	echo '<form method="post" action="admin.php">';
	echo '<input type="hidden" name="do" value="add" />';
	echo '<table>';
	echo '<tr><td>Song Title:</td><td><input type="text" name="title" style="width:300px" maxlength="33" /></td></tr>';
	echo '<tr><td>MP3 URL:</td><td><input type="text" name="url" style="width:300px" maxlength="255" /></td></tr>';
	echo '</table>';
	echo '<input type="submit" name="submit" value="Submit" /><br /><br />';
	echo '</form>';
	echo 'Be sure to include the protocol (i.e. <code>http://</code>) in the URL!<br /><br />';
	echo '<a href="index.php">Return To Front-End</a><br /><br />';
	echo '<a href="admin.php?deleteall">Delete All Songs</a><br /><br />';
}
require('./footer.php');
?>