MODPATH=${0%/*}
API=`getprop ro.build.version.sdk`
AML=/data/adb/modules/aml

# debug
exec 2>$MODPATH/debug.log
set -x

# function
dolby_prop() {
resetprop ro.vendor.dolby.dax.version DAX3_3.6.1.6_r1
resetprop vendor.audio.dolby.ds2.enabled false
resetprop vendor.audio.dolby.ds2.hardbypass false
resetprop ro.vendor.audio.dolby.dax.support true
#resetprop ro.vendor.audio.dolby.fade_switch true
#resetprop vendor.dolby.dap.param.tee false
#resetprop vendor.dolby.mi.metadata.log false
#resetprop vendor.audio.gef.enable.traces false
#resetprop vendor.audio.gef.debug.flags false
}

# property
#ddolby_prop
resetprop ro.audio.hifi false
resetprop ro.vendor.audio.hifi false
resetprop ro.vendor.audio.ring.filter true
resetprop ro.vendor.audio.scenario.support  true
#resetprop ro.vendor.audio.sfx.audiovisual false
resetprop ro.vendor.audio.sfx.earadj true
resetprop ro.vendor.audio.sfx.independentequalizer true
resetprop ro.vendor.audio.sfx.scenario true
resetprop ro.vendor.audio.sfx.spk.stereo true
resetprop ro.audio.soundfx.type mi
resetprop ro.vendor.audio.soundfx.type mi
resetprop ro.audio.soundfx.usb true
resetprop ro.vendor.audio.soundfx.usb true
#resetprop ro.audio.soundfx.dirac false
#resetprop ro.vendor.audio.sfx.harmankardon true
#resetprop ro.vendor.audio.sfx.speaker true
#resetprop ro.vendor.audio.sfx.spk.movie true
#resetprop ro.vendor.audio.surround.headphone.only false
#resetprop ro.vendor.audio.scenario.headphone.only false
#resetprop ro.vendor.audio.feature.spatial true
#resetprop ro.vendor.audio.misound.bluetooth.enable true

# restart
if [ "$API" -ge 24 ]; then
  SVC=audioserver
else
  SVC=mediaserver
fi
PID=`pidof $SVC`
if [ "$PID" ]; then
  killall $SVC
fi

# function
stop_service() {
for NAMES in $NAME; do
  if [ "`getprop init.svc.$NAMES`" == running ]\
  || [ "`getprop init.svc.$NAMES`" == restarting ]; then
    stop $NAMES
  fi
done
}
run_service() {
for FILES in $FILE; do
  killall $FILES
  $FILES &
  PID=`pidof $FILES`
done
}
dolby_service() {
# stop
NAME="dms-hal-1-0 dms-hal-2-0 dms-v36-hal-2-0"
stop_service
# mount
DIR=/odm/bin/hw
FILE=$DIR/vendor.dolby_v3_6.hardware.dms360@2.0-service
if [ "`realpath $DIR`" == $DIR ] && [ -f $FILE ]; then
  mount -o bind $MODPATH/system/vendor/$FILE $FILE
fi
# run
FILE=/vendor/bin/hw/vendor.dolby.hardware.dms@2.0-service
run_service
# restart
VIBRATOR=`realpath /*/bin/hw/vendor.qti.hardware.vibrator.service*`
[ "$VIBRATOR" ] && killall $VIBRATOR
POWER=`realpath /*/bin/hw/vendor.mediatek.hardware.mtkpower@*-service`
[ "$POWER" ] && killall $POWER
killall android.hardware.usb@1.0-service
killall android.hardware.usb@1.0-service.basic
killall android.hardware.sensors@1.0-service
killall android.hardware.sensors@2.0-service-mediatek
killall android.hardware.light-service.mt6768
killall android.hardware.lights-service.xiaomi_mithorium
killall vendor.samsung.hardware.light-service
CAMERA=`realpath /*/bin/hw/android.hardware.camera.provider@*-service_64`
[ "$CAMERA" ] && killall $CAMERA
}

# dolby
#ddolby_service

# wait
sleep 20

# aml fix
DIR=$AML/system/vendor/odm/etc
if [ -d $DIR ] && [ ! -f $AML/disable ]; then
  chcon -R u:object_r:vendor_configs_file:s0 $DIR
fi

# magisk
if [ -d /sbin/.magisk ]; then
  MAGISKTMP=/sbin/.magisk
else
  MAGISKTMP=`realpath /dev/*/.magisk`
fi

# path
MIRROR=$MAGISKTMP/mirror
SYSTEM=`realpath $MIRROR/system`
VENDOR=`realpath $MIRROR/vendor`
ODM=`realpath $MIRROR/odm`
MY_PRODUCT=`realpath $MIRROR/my_product`

# mount
NAME="*audio*effects*.conf -o -name *audio*effects*.xml -o -name *policy*.conf -o -name *policy*.xml"
if [ -d $AML ] && [ ! -f $AML/disable ]\
&& find $AML/system/vendor -type f -name $NAME; then
  NAME="*audio*effects*.conf -o -name *audio*effects*.xml"
#p  NAME="*audio*effects*.conf -o -name *audio*effects*.xml -o -name *policy*.conf -o -name *policy*.xml"
  DIR=$AML/system/vendor
else
  DIR=$MODPATH/system/vendor
fi
FILE=`find $DIR/etc -maxdepth 1 -type f -name $NAME`
if [ ! -d $ODM ] && [ "`realpath /odm/etc`" == /odm/etc ]\
&& [ "$FILE" ]; then
  for i in $FILE; do
    j="/odm$(echo $i | sed "s|$DIR||")"
    if [ -f $j ]; then
      umount $j
      mount -o bind $i $j
    fi
  done
fi
if [ ! -d $MY_PRODUCT ] && [ -d /my_product/etc ]\
&& [ "$FILE" ]; then
  for i in $FILE; do
    j="/my_product$(echo $i | sed "s|$DIR||")"
    if [ -f $j ]; then
      umount $j
      mount -o bind $i $j
    fi
  done
fi

# wait
until [ "`getprop sys.boot_completed`" == "1" ]; do
  sleep 10
done

# grant
PKG=com.miui.misound
pm grant $PKG android.permission.READ_PHONE_STATE
pm grant $PKG android.permission.RECORD_AUDIO
appops set $PKG SYSTEM_ALERT_WINDOW allow
if [ "$API" -ge 30 ]; then
  appops set $PKG AUTO_REVOKE_PERMISSIONS_IF_UNUSED ignore
fi

# grant
PKG=com.dolby.daxservice
if pm list packages | grep $PKG ; then
  if [ "$API" -ge 31 ]; then
    pm grant $PKG android.permission.BLUETOOTH_CONNECT
  fi
  if [ "$API" -ge 30 ]; then
    appops set $PKG AUTO_REVOKE_PERMISSIONS_IF_UNUSED ignore
  fi
fi

# function
stop_log() {
FILE=$MODPATH/debug.log
SIZE=`du $FILE | sed "s|$FILE||"`
if [ "$LOG" != stopped ] && [ "$SIZE" -gt 50 ]; then
  exec 2>/dev/null
  LOG=stopped
fi
}
check_audioserver() {
if [ "$NEXTPID" ]; then
  PID=$NEXTPID
else
  PID=`pidof $SVC`
fi
sleep 10
stop_log
NEXTPID=`pidof $SVC`
if [ "`getprop init.svc.$SVC`" != stopped ]; then
  until [ "$PID" != "$NEXTPID" ]; do
    check_audioserver
  done
  killall $PROC
  check_audioserver
else
  start $SVC
  check_audioserver
fi
}

# check
if [ "$API" -ge 24 ]; then
  SVC=audioserver
else
  SVC=mediaserver
fi
PROC=com.miui.misound
#dPROC="com.dolby.daxservice com.miui.misound"
killall $PROC
check_audioserver










