#!/bin/sh
yr=`date +%Y`
mo=`date +%m`
if [ -f downloaded_$yr$mo -a "$force" != true ]; then
  echo "Already downloaded Berkely data this month"
  exit
fi

base=http://berkeleyearth.lbl.gov/auto/Global/Gridded/
for var in TAVG TMIN TMAX
do
	decade=1880
	new=false
	while [ $decade -le 2010 ]; do
	    file=Complete_${var}_Daily_LatLong1_${decade}.nc
	    wget -N $base/$file
	    newfile=${var}_Daily_LatLong1_${decade}.nc
	    if [ ! -s $newfile -o $newfile -ot $file ]; then
	        new=true
    	    cdo -r -f nc4 -z zip settaxis,${decade}-01-01,0:0:0,1day Complete_${var}_Daily_LatLong1_${decade}.nc aap.nc
	        cdo -r -f nc4 -z zip selvar,temperature aap.nc $newfile
	        rm aap.nc
	    fi
	    decade=$((decade + 10))
	done
	if [ $new = true ]; then
    	cdo -r -f nc4 -z zip copy ${var}_Daily_LatLong1_[12]???.nc ${var}_Daily_LatLong1.nc
	    $HOME/NINO/copyfiles.sh ${var}_Daily_LatLong1.nc
	fi

    file=Complete_${var}_LatLong1.nc
	wget -N $base/$file
	case $var in
		TAVG) start="1750-01-01";;
		TMAX) start="1833-01-01";;
		TMIN) start="1833-04-01";;
		*) echo "$0: error: unknow var $var"; exit -1;;
	esac
	ncfile=${var}_LatLong1.nc
	if [ ! -s $newfile -o $newfile -ot $file ]; then
	    cdo -r -f nc4 -z zip settaxis,${start},0:0:0,1mon Complete_${var}_LatLong1.nc aap.nc
	    cdo -r -f nc4 -z zip selvar,temperature aap.nc $ncfile
	    rm aap.nc
    	$HOME/NINO/copyfiles.sh ${var}_LatLong1.nc
	fi
	
done
date > downloaded_$yr$mo

exit

cp analysis-data.zip analysis-data.zip.old
wget -N http://www.berkeleyearth.org/downloads/analysis-data.zip
cmp analysis-data.zip analysis-data.zip.old
if [ $? != 0 ]; then
	unzip -u analysis-data.zip
	fgrep Earth Full_Database_Average_complete.txt | tr '%' "#" | \
		sed -e 's@Berkeley Earth@<a href="http://www.berkeleyearth.org">Berkeley Earth</a>@' > t2m_land_best.dat
	echo 
	echo "# T2m_land_anom [K] land-surface average temperature anomalies relative to 1950-1980" >> t2m_land_best.dat
	fgrep -v '%' Full_Database_Average_complete.txt | fgrep -v ' 2010 ' | cut -b 1-22 >> t2m_land_best.dat
	$HOME/NINO/copyfilesall.sh t2m_land_best.dat
fi


exit

# these are the unadjusted station series
for var in TAVG TMIN TMAX
do
	cd $var
	wget -N http://download.berkeleyearth.org/downloads/$var/LATEST%20-%20Quality%20Controlled.zip
	if [ ! -s data.txt -o data.txt -ot "LATEST - Quality Controlled.zip" ]; then
		unzip "LATEST - Quality Controlled.zip"
	fi
	cd ..
done
