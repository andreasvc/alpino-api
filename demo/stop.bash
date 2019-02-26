#!/bin/bash

E='alpiner|server_port=11211'

pkill -f -u $USER $E

sleep 2

pkill -KILL -f -u $USER $E
