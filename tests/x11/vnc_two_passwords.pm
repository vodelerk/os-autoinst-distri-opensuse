# SUSE's openQA tests
#
# Copyright © 2016-2017 SUSE LLC
#
# Copying and distribution of this file, with or without modification,
# are permitted in any medium without royalty provided the copyright
# notice and this notice are preserved.  This file is offered as-is,
# without any warranty.

# Summary: Check VNC Secondary viewonly password
# Maintainer: mkravec <mkravec@suse.com>
# Tags: poo#11794

use base "x11test";
use strict;
use testapi;
use utils 'ensure_unlocked_desktop';

my @options = ({pw => "full_access_pw", change => 1}, {pw => "view_only_pw", change => 0});
my $theme = "/usr/share/gnome-shell/theme/gnome-classic.css";
# arbitrary display assumed to be free for a VNC server
my $display = ':37';

sub type_and_wait {
    type_string shift;
    wait_screen_change {
        type_string "\n";
    };
}

sub start_vnc_server {
    # Disable remote administration from previous tests
    script_run "systemctl stop vncmanager";

    # Create password file
    type_string "tput civis\n";
    type_and_wait "vncpasswd /tmp/file.passwd";
    type_and_wait $options[0]->{pw};
    type_and_wait $options[0]->{pw};
    type_and_wait "y";
    type_and_wait $options[1]->{pw};
    type_and_wait $options[1]->{pw};
    type_string "tput cnorm\n";

    # Start server
    type_string "Xvnc $display -SecurityTypes=VncAuth -PasswordFile=/tmp/file.passwd\n";
    save_screenshot;
}

sub run {
    select_console "root-console";
    # Hide panel buttons so wait_screen_change ignores clock change
    assert_script_run "echo \"#panel .panel-button { color: transparent; }\" >> $theme";
    start_vnc_server;

    select_console 'x11';
    # Reload theme to hide panel text
    x11_start_program('rt', target_match => 'generic-desktop');

    # Start xev event watcher
    x11_start_program('xterm');
    send_key "super-right";
    type_string "DISPLAY=$display xev\n";

    # Start vncviewer (rw & ro mode) and check if changes are processed by xev
    foreach my $opt (@options) {
        x11_start_program("vncviewer $display -SecurityTypes=VncAuth", target_match => 'vnc_password_dialog', match_timeout => 60);
        type_string "$opt->{pw}\n";
        assert_screen 'vncviewer-xev';
        send_key "super-left";
        mouse_set(80, 120);

        wait_still_screen;
        my $c1 = wait_screen_change { type_string "string"; };
        my $c2 = wait_screen_change { mouse_click; };
        if ($c1 != $c2 || $c1 != $opt->{change}) {
            die "Expected: $opt->{change}, received: $c1, $c2 for $opt->{pw}";
        }
        send_key "alt-f4";
    }

    # Cleanup
    send_key "alt-f4";
    select_console 'root-console', await_console => 0;
    send_key "ctrl-c";
    assert_script_run "sed -i '\$d' $theme";
    select_console "x11";
    x11_start_program('rt', target_match => 'generic-desktop');
}

1;
# vim: set sw=4 et:
