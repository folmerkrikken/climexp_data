#!/bin/sh
if [ "$1" = force ]; then
	force=true
else
	force=false
fi

yr=`date +%Y`
mo=`date +%m`
if [ $force != true -a -f downloaded_$yr$mo ]; then
  echo "Already downloaded ERA-interim this month"
  exit
fi
if [ 1 = 1 ]; then
./get_erainterim.py > get_erainterim.log 2>&1
./get_erainterim_daily.py > get_erainterim_daily.log 2>&1
./make_wspd.sh
./update_tglobal.sh
./update_twetbulb.sh
# probably runs on zuidzee
###$HOME/NINO/copyfiles.sh erai_*.nc erai_*.dat
rsync -avt erai_*.nc erai_*.dat bhlclim:climexp/ERA-interim/
rsync -avt erai_*.nc erai_*.dat  climexp-64400.climexp-knmi.surf-hosted.nl:climexp/ERA5/

fi


for var in tgx txx tnn tnx rx1day rx3day rx5day
do
    case $var in
        tgx) basevar=t2m;oper=max;;
        txx) basevar=tmax;oper=max;;
        tnn) basevar=tmin;oper=min;;
        tnx) basevar=tmin;oper=max;;
        rx1day) basevar=tp;oper=max;;
        rx3day) basevar=tp;oper="max sum 3";;
        rx5day) basevar=tp;oper="max sum 5";;
        *) echo "$0: unknown var $var"; exit -1;;
    esac
    echo "Computing $var"
    ###rsync erai_${basevar}_daily.nc zuidzee:NINO/ERA-interim/
    daily2longerfield erai_${basevar}_daily.nc 1 $oper minfac 75 erai_$var.nc
    rsync -at erai_$var.nc bhlclim:climexp/ERA-interim/
    rsync -at erai_$var.nc erai_*.dat  climexp-64400.climexp-knmi.surf-hosted.nl:climexp/ERA5/
    ###$HOME/NINO/copyfiles.sh erai_$var.nc
done

date > downloaded_$yr$mo
