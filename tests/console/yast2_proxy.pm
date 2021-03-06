# SUSE's openQA tests
#
# Copyright (c) 2016 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Test thast squid proxy can be started after setup with YaST
# Maintainer: Zaoliang Luo <zluo@suse.de>

use strict;
use base "console_yasttest";
use testapi;
use utils;


my %sub_menu_needles = (
    start_up      => 'yast2_proxy_start-up',
    http_ports    => 'yast2_proxy_http_ports_selected',
    patterns      => 'yast2_proxy_http_refresh_patterns_selected',
    cache_setting => 'yast2_proxy_http_cache_setting_selected',
    cache_dir     => 'yast2_proxy_http_cache_directory_selected',
    access_ctrl   => 'yast2_proxy_http_access_control_selected',
    log_timeouts  => 'yast2_proxy_logging_timeouts_selected',
    miscellanous  => 'yast2_proxy_miscellanous_selected'
);

sub select_sub_menu {
    my ($initial_screen, $wanted_screen) = @_;
    send_key_until_needlematch $sub_menu_needles{$initial_screen}, 'tab';
    wait_still_screen 1;
    send_key 'down';
    assert_screen $sub_menu_needles{$wanted_screen};
    wait_still_screen 1;
    wait_screen_change { send_key 'ret'; };
    wait_still_screen 1;
}

sub empty_field {
    my ($shortkey, $empty_field_needle, $symbols_to_remove) = @_;
    $symbols_to_remove //= 20;

    for my $i (0 .. $symbols_to_remove) {
        send_key $shortkey;
        send_key 'backspace';
        return if check_screen $empty_field_needle, 0;
    }
}

sub run {
    select_console 'root-console';

    if (is_sle && sle_version_at_least('15')) {
        my $ret = zypper_call('in squid', exitcode => [0, 104]);
        return record_soft_failure 'bsc#1056793' if $ret == 104;
    }

    # install yast2-squid, yast2-proxy, squid package at first
    zypper_call("in squid yast2-squid yast2-proxy", timeout => 180);

    # set up visible_hostname or squid spends 30s trying to determine public hostname
    script_run 'echo "visible_hostname $HOSTNAME" >> /etc/squid/squid.conf';

    # start yast2 squid configuration
    script_run("yast2 squid; echo yast2-squid-status-\$? > /dev/$serialdev", 0);

    # check that squid configuration page shows up
    assert_screen 'yast2_proxy_squid';

    # enable service start
    send_key_until_needlematch 'yast2_proxy_service_start', 'alt-b';    #Start service when booting

    # if firewall is enabled, then send_key alt-p, else move to page http ports
    if (check_screen 'yast2_proxy_firewall_enabled') { send_key 'alt-p'; }
    wait_still_screen 3;

    # check network interfaces with open port in firewall
    # repeat action as sometimes keys are not triggering action on leap if workers are slow
    send_key_until_needlematch 'yast2_proxy_network_interfaces', 'alt-d', 2, 5;

    wait_still_screen 1;
    send_key 'alt-n';
    wait_still_screen 1;
    send_key 'alt-a';
    wait_screen_change { send_key 'alt-o' };

    # move to http ports
    select_sub_menu 'start_up', 'http_ports';

    # edit details of http ports setting
    send_key 'alt-i';

    # check dialog "edit current http port"
    assert_screen 'yast2_proxy_http_ports_current';
    send_key 'alt-h';
    type_string 'localhost';
    # On leap it happens that field losses it's focus and backspace doesn't remove symbols
    empty_field 'alt-p', 'yast2_proxy_http_port_empty', 10;
    type_string '80';
    send_key 'alt-t';
    assert_screen 'yast2_proxy_http_port_transparent';
    send_key 'alt-o';
    assert_screen 'yast2_proxy_http_ports_edit';

    #	move to page refresh patterns
    select_sub_menu 'http_ports', 'patterns';

    # check refresh patterns page is opend
    assert_screen 'yast2_proxy_refresh_patterns';
    # change the order here
    send_key 'alt-w';
    assert_screen 'yast2_proxy_refresh_patterns_oder';

    # move to page cache setting
    select_sub_menu 'patterns', 'cache_setting';

    # change some value in cache settings
    send_key 'alt-a';
    type_string_slow "11\n";
    send_key 'alt-x';
    type_string_slow "4086\n";
    send_key 'alt-i';
    type_string_slow "3\n";
    send_key 'alt-l';
    type_string_slow "87\n";
    send_key 'alt-s';
    type_string_slow "92\n";
    wait_screen_change { send_key 'alt-e'; };
    send_key 'end';
    wait_screen_change { send_key 'ret'; };
    wait_screen_change { send_key 'alt-m'; };
    send_key 'end';
    wait_screen_change { send_key 'ret'; };

    # check new value in cache settings
    assert_screen 'yast2_proxy_cache_settings_new';

    # move to page cache directory
    select_sub_menu 'cache_setting', 'cache_dir';

    # check the page cache directory is opened for a new directory name and other changes
    assert_screen 'yast_proxy_cache_directory_name';
    empty_field 'alt-d', 'yast_proxy_cache_dir_empty', 25;
    type_string_slow "/var/cache/squid1";
    send_key 'alt-s';
    type_string_slow "120\n";
    send_key 'alt-e';
    type_string_slow "20\n";
    send_key 'alt-v';
    type_string_slow "246\n";

    # check the changes made correctly
    assert_screen 'yast_proxy_cache_directory_new';

    # move to page Access Control to edit ACL Groups
    select_sub_menu 'cache_dir', 'access_ctrl';
    assert_screen 'yast2_proxy_http_new_cache_dir';
    send_key 'alt-y';    # confirm to create new directory
    assert_screen 'yast2_proxy_http_access_control_selected';
    wait_still_screen 1;
    # change subnet for 192.168.0.0/16 to 192.168.0.0/18
    wait_screen_change { send_key 'tab'; };
    wait_screen_change { send_key 'down'; };
    wait_screen_change { send_key 'down'; };
    assert_screen 'yast2_proxy_acl_group_localnet';
    wait_still_screen 1;
    send_key 'alt-i';
    assert_screen 'yast2_proxy_acl_group_edit';
    send_key 'alt-e';
    send_key 'backspace';
    type_string '8';
    wait_screen_change { send_key 'alt-o'; };

    # move to Access Control and change something
    send_key_until_needlematch 'yast2_proxy_safe_ports_selected', 'tab';
    send_key 'alt-w';
    wait_still_screen 1;
    send_key 'alt-w';

    # check changes in ACL Groups and Access Control
    assert_screen 'yast2_proxy_access_control_new';

    # move to Logging and Timeouts
    select_sub_menu 'access_ctrl', 'log_timeouts';
    # check logging and timeouts setting is opened to edit
    assert_screen 'yast2_proxy_logging_timeouts_setting';
    send_key 'alt-a';
    wait_still_screen 1;
    send_key 'alt-w';

    # check acces log directory can be browsed and defined
    assert_screen 'yast2_proxy_access_log_directory';
    wait_still_screen 1;
    send_key 'alt-c';
    wait_still_screen 1;
    send_key 'alt-g';
    empty_field 'alt-e', 'yast2_proxy_cache_log_dir_empty', 35;
    type_string "/var/log/squid/proxy_cache.log";
    empty_field 'alt-s', 'yast2_proxy_store_log_dir_empty', 35;
    type_string "/var/log/squid/proxy_store.log";

    # move to timeouts now
    wait_screen_change { send_key 'alt-t'; };
    wait_screen_change { send_key 'up'; };
    wait_screen_change { send_key 'alt-l'; };
    wait_screen_change { send_key 'up'; };
    # check above changes for logging and timeouts
    assert_screen 'yast2_proxy_logging_timeouts_new';

    #	move to miscellanous now for change language into de-de and admin email
    select_sub_menu 'log_timeouts', 'miscellanous';
    wait_screen_change { send_key 'alt-l'; };
    for (1 .. 5) {
        wait_screen_change { send_key 'up'; };
    }
    wait_screen_change { send_key 'ret'; };
    send_key 'alt-a';
    empty_field 'alt-a', 'yast2_proxy_admin_email_empty', 35;
    type_string 'webmaster@localhost';

    # check language and email now
    assert_screen 'yast2_proxy_miscellanous';

    # move to Start-Up and start proxy server now
    #	for (1..35) {send_key 'tab'; save_screenshot;}
    send_key_until_needlematch 'yast2_proxy_miscellanous_selected', 'shift-tab';
    send_key_until_needlematch 'yast2_proxy_start-up',              'up';
    wait_still_screen 1;
    send_key 'ret';

    assert_screen 'yast2_proxy_squid';
    wait_still_screen 1;
    # now save settings and start squid server
    send_key 'alt-s';
    #	check again before to close configuration
    assert_screen 'yast2_proxy_before_close';
    wait_still_screen 1;
    # finish configuration with OK
    wait_screen_change { send_key 'alt-o'; };

    # yast might take a while on sle12 due to suseconfig
    wait_serial("yast2-squid-status-0", 360) || die "'yast2 squid' didn't finish";

    # check squid proxy server status
    assert_script_run "systemctl show -p ActiveState squid.service|grep ActiveState=active";
    assert_script_run "systemctl show -p SubState squid.service|grep SubState=running";

}
1;

# vim: set sw=4 et:
