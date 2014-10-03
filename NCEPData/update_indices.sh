#!/bin/csh -f
cp sstoi.indices sstoi.indices.old
wget -q -N http://www.cpc.ncep.noaa.gov/data/indices/sstoi.indices
diff sstoi.indices sstoi.indices.old
if ( $status ) then
  echo "new file differs from old one"
  rm sstoi.indices.old
  sstoi2dat
else
  echo "new file is the same as old one, keeping old one"
endif
$HOME/NINO/copyfilesall.sh nino?.dat sstoi.indices

cp wksst8110.for wksst8110.for.old
wget -q -N http://www.cpc.ncep.noaa.gov/data/indices/wksst8110.for
diff wksst8110.for wksst8110.for.old
if ( $status ) then
  echo "new file differs from old one"
  rm wksst8110.for.old
  ./normalize_wksst wksst8110.for >! wksst.myfor
  echo 'y' | gnuplot plotninoweek.gnu
  gs -q -r300 -dTextAlphaBits=4 -dGraphicsAlphaBits=4 -dNOPAUSE -sDEVICE=ppmraw -sOutputFile=plotninoweek.ppm plotninoweek.eps -c quit
###  gsppm plotninoweek.ppm plotninoweek.eps
  pnmcrop plotninoweek.ppm | pnmscale 0.319 | pnmcut -left=1 | pnmtopng > ! plotninoweek.png
  rm -f plotninoweek.ppm
  epstopdf plotninoweek.eps
  cp -f plotninoweek.png /usr/people/oldenbor/www2/research/global_climate/enso
  ./ninoweek2daily
  foreach index ( nino2 nino3 nino4 nino5 )
    daily2longer ${index}_daily.dat 73 mean >! ${index}_5daily.dat
  end
else
  echo "new file is the same as old one, keeping old one"
endif
$HOME/NINO/copyfilesall.sh plotninoweek.??? 
$HOME/NINO/copyfiles.sh nino?_daily.dat
$HOME/NINO/copyfiles.sh nino?_5daily.dat

cp soi soi.old
wget -q -N http://www.cpc.ncep.noaa.gov/data/indices/soi
diff soi soi.old
if ( $status ) then
  echo "new file differs from old one"
  rm soi.old
  ./makesoi >! cpc_soi.dat
else
  echo "new file is the same as old one, keeping old one"
endif
$HOME/NINO/copyfilesall.sh cpc_soi.dat

cp tele_index.nh tele_index.nh.old
wget -q -N ftp://ftp.cpc.ncep.noaa.gov/wd52dg/data/indices/tele_index.nh
diff tele_index.nh tele_index.nh.old
if ( $status ) then
  echo "new file differs from old one"
  rm tele_index.nh.old
  ./tele2dat
else
  echo "new file is the same as old one, keeping old one"
endif
$HOME/NINO/copyfilesall.sh cpc_nao.dat cpc_ea.dat cpc_wp.dat cpc_epnp.dat cpc_pna.dat cpc_ea_wr.dat cpc_sca.dat cpc_tnh.dat cpc_pol.dat cpc_pt.dat

cp proj_norm_order.ascii proj_norm_order.ascii.old
wget -q -N http://www.cpc.ncep.noaa.gov/products/precip/CWlink/daily_mjo_index/proj_norm_order.ascii
diff proj_norm_order.ascii proj_norm_order.ascii.old
if ( $status ) then
  echo "new file differs from old one"
  rm proj_norm_order.ascii.old
    ./mjo2dat
  foreach file ( cpc_mjo*_daily.dat )
    daily2longer $file 12 mean >! `basename $file _daily.dat`_mean12.dat
  end
else
  echo "new file is the same as old one, keeping old one"
endif
$HOME/NINO/copyfiles.sh cpc_mjo*.dat

./update_annular.sh
./update_daily.sh
