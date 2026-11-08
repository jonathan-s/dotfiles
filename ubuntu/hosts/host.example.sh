#!/bin/sh
# Per-machine values. Copy to ubuntu/hosts/host.sh (gitignored) and fill in.
#
# The placeholders below are documentation values on purpose: 192.0.2.0/24,
# 198.51.100.0/24 and 203.0.113.0/24 are reserved by RFC 5737, and example.*
# cannot be mistaken for a real name. ./install --check fails while any of them
# is still in place, which is what makes a forgotten value obvious.

HOST_NAME="example-host"
LOGIN_USER="example-user"
TIMEZONE="Europe/Example"

# The LAN this box lives on.
LAN_SUBNET="192.0.2.0/24"
LAN_ROUTER_IP="192.0.2.1"
LAN_SERVER_IP="192.0.2.10"

# Wildcard DNS served on the LAN, and the domain dokku fronts with Let's
# Encrypt.
LAN_DOMAIN="home.example.lan"
PUBLIC_DOMAIN="home.example.com"
ACME_EMAIL="you@example.com"
