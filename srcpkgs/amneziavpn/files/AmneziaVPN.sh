#!/bin/sh
export LD_LIBRARY_PATH=/opt/AmneziaVPN/client/lib
export QT_PLUGIN_PATH=/opt/AmneziaVPN/client/plugins
export QML2_IMPORT_PATH=/opt/AmneziaVPN/client/qml
export QT_QPA_PLATFORM_PLUGIN_PATH=/opt/AmneziaVPN/client/plugins/platforms
exec /opt/AmneziaVPN/client/bin/AmneziaVPN "$@"