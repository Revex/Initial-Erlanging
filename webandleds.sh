#!  /bin/sh
#  /etc/init.d/webandleds

case "$1" in
  start)
    echo "Gonna startup our webserver and our leds! "
    cd ../../home/pi/erlang-ale/
    sudo erl -run webs -run leds
    ;;
  stop)
    echo "Stopping the LEDS and the WebServer! "
    ;;
  *)
  echo "Usage: /etc/init.d/webandleds [start or stop]"
  exit 1
 ;;
esac


echo "finished"
exit 0

