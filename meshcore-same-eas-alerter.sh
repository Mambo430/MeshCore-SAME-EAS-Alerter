#!/bin/bash
/usr/local/bin/rtl_fm -d 00000001 -f 162550000 -s 48000 -r 48000 | /usr/bin/MeshCore-SAME-EAS-Alerter --port /dev/ttyUSB0 --alert-channel 0 --test-channel 0
