#! /usr/bin/env bash

#    Alexandrite OS
#    Copyright (C) 2021 naiad technology
#
#
#    config.sh
#
#
#
#    This program is free software: you can redistribute it and/or modify
#    it under the terms of the GNU General Public License as published by
#    the Free Software Foundation, either version 3 of the License, or
#    (at your option) any later version.
#
#    This program is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU General Public License for more details.

#    You should have received a copy of the GNU General Public License
#    along with this program.  If not, see <https://www.gnu.org/licenses/>.



# Functions...
test -f /.kconfig && . /.kconfig
test -f /.profile && . /.profile

# Greeting...
echo "Configure image: [$kiwi_iname]..."

# Setup baseproduct link
suseSetupProduct

# Activate services
suseInsertService sshd

# Setup default target, multi-user
baseSetRunlevel 3

# Remove yast if not in use
#suseRemoveYaST

# set plymouht theme
plymouth-set-default-theme naiad

# enable gdm
ln -fs /usr/lib/systemd/system/graphical.target /etc/systemd/system/default.target
