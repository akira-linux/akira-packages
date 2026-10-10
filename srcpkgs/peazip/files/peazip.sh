#!/bin/sh
export LD_LIBRARY_PATH=/opt/peazip:$LD_LIBRARY_PATH
exec /opt/peazip/peazip "$@"