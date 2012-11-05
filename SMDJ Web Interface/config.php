<?php
/******************************************
 * SourceMod DJ created by Dr. McKay
 * http://www.doctormckay.com
 * Manual: https://forums.alliedmods.net/showthread.php?t=172258
 ******************************************/

$config['host'] = 'localhost';				// Your database host, with port if applicable
$config['user'] = '';						// Your database username
$config['pass'] = '';						// Your database password
$config['name'] = '';						// Name of your database

$auth = '';									// Password to manage songs, either in plaintext or MD5 hash
$theme = 'default';							// Theme to use, currently 'default', 'tf2', 'counter-strike', and 'black' are available ('tf2' uses much more bandwidth)

$uploadmethod = 'local';					// Upload method - 'local' or 'ftp'. 'local' will upload files to /music relative to SMDJ root. 'ftp' will use the following FTP settings
$ftp['host'] = '';							// FTP upload host - IP or domain. No protocol or port
$ftp['user'] = '';							// FTP upload username
$ftp['pass'] = '';							// FTP upload password
$ftp['path'] = '';							// FTP upload path to upload to
$ftp['http'] = '';							// Where to access the FTP upload path via HTTP

error_reporting(0);							// Comment this line out for debugging

// D O  N O T  E D I T  B E L O W  T H I S  L I N E ! //
if($uploadmethod != 'local' && $uploadmethod != 'ftp') die('Error in configuration: invalid value for $uploadmethod');
$con = mysql_connect($config['host'], $config['user'], $config['pass']) or die('Couldn\'t connect to MySQL server');
mysql_select_db($config['name'], $con) or die('Couldn\'t select the database');
mysql_query("CREATE TABLE IF NOT EXISTS `smdj_songs` (id INTEGER NOT NULL, title VARCHAR(33) NOT NULL, url VARCHAR(255) NOT NULL)");
mysql_query("CREATE TABLE IF NOT EXISTS `smdj_playlists` (id INTEGER NOT NULL, name VARCHAR(33) NOT NULL, steamid VARCHAR(33) NOT NULL, songs TEXT NOT NULL)");
?>