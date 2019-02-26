#!/bin/bash

RESTART=0

case `echo hallo 11211 | nc localhost 11211 | grep sentence` in
*sentence*)
	;;
*)
	RESTART=1
	break
	;;
esac

if [ $RESTART = 0 ]
then
    if [ "`curl http://127.0.0.1:11200/up 2> /dev/null`" != "alpiner" ]
    then
	RESTART=1
    fi
fi

if [ $RESTART = 0 ]
then
    exit
fi

cd `dirname $0`

ln -s lock.$$ lock
if [ "`readlink lock`" != lock.$$ ]
then
    echo Getting lock failed
    exit
fi

echo Restarting alpiner
echo
cat log/alpiner.out
echo

./stop.bash

# wacht een tijd tot de poorten weer vrij zijn
sleep 60

./start.bash

rm -f lock
