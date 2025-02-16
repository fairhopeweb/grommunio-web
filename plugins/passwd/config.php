<?php

// Whether to use AAPI or ZCORE for setpasswd functionality
define("PLUGIN_PASSWD_USE_ZCORE", false);

// Enable the passwd plugin for all clients
define('PLUGIN_PASSWD_USER_DEFAULT_ENABLE', false);

// Enable the passwd plugin for all clients
define('PLUGIN_PASSWD_STRICT_CHECK_ENABLE', true);

// The grommunio admin API passwd endpoint
define('PLUGIN_PASSWD_ADMIN_API_ENDPOINT', 'http://[::1]:8080/api/v1/passwd');

?>
