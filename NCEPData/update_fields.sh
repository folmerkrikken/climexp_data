#!/bin/sh
# OIv2 SST
make oiv22grads
./oiv22grads
describefield sstoi_v2.ctl
$HOME/NINO/copyfiles.sh sstoi_v2.??? iceoi_v2.???

make cmap2dat
./cmap2dat
describefield cmap.ctl
$HOME/NINO/copyfiles.sh cmap.???

cp camsopi.nc camsopi.nc.old
wget -q -N http://iridl.ldeo.columbia.edu/SOURCES/.NOAA/.NCEP/.CPC/.CAMS_OPI/.v0208/.mean/data.cdf
cp data.cdf camsopi.nc
$HOME/NINO/copyfiles.sh camsopi.nc