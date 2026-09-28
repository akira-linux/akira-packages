#!/bin/sh
export LD_LIBRARY_PATH=/opt/AmneziaVPN/client/lib:/opt/AmneziaVPN/service/bin
exec /opt/AmneziaVPN/service/bin/AmneziaVPN-service "$@"