#!/bin/bash

if [ -z "$ALPINO_HOME" ]
then
    echo "$0: Error: Please set your ALPINO_HOME environment variable" 1>&2
    exit 1
fi

# Are you sure you have enough memory for this?
export PROLOGMAXSIZE=8000M

DEBUG=0

if [ $DEBUG = 0 ]
then
    NULL=/dev/null
fi

mkdir -p log

$ALPINO_HOME/bin/Alpino -notk -veryfast user_max=60000 \
    server_kind=parse \
    server_port=11211 \
    assume_input_is_tokenized=on \
    debug=$DEBUG \
    -init_dict_p \
    batch_command=alpino_server &> ${NULL:-log/alpino11.out} &

sleep 10
echo hallo 11211 | nc localhost 11211 | grep sentence

if [ "$1" = "-i" ]
then
    ./alpiner -v config.toml
    ./stop.bash
else
    ./alpiner config.toml &> log/alpiner.out &
    ps -p `pgrep -f -u $USER 'alpiner|server_port=11211'`
fi
