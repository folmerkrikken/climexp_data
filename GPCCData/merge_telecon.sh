#!/bin/sh
###set -x
dataset="$1"
if [ -z "$dataset" ]; then
    echo "usage: $0 gpcc|cmorph|erai"
    exit -1
fi
dir=$HOME/climexp
case $dataset in
    gpcc) file=$dir/GPCCData/gpcc_10_combined.nc;;
    cmorph) file=$dir/NCEPData/cmorph_monthly.nc;;
    erai) file=$dir/ERA-interim/erai_tp_daily_extended_mo.nc;;
    *) echo "$0: unknown dataset $dataset"; exit -1;;
esac
if [ ! -s $file ]; then
    echo "$0: error: cannot find file $file"
    exit -1
fi
month=0
files=""
while [ $month -lt 12 ]; do
    month=$((month+1))
    outfile=telecon_prcp_$month.dat
    patternfield $file corr_prcp_nino34.nc regr $month > $outfile
    files="$files $outfile"
done
outfile=telecon_nino34_$dataset.dat
./merge_telecon $files > $outfile
rm $files
mv $outfile aap.dat
cat > $outfile <<EOF
# Nino34 index based on GPCC station-based land prdcipitation projected on ENSO teleconnections
# using resgression patterns
# nino34_prcp [1] Nino index from land precipitation
EOF
normdiff aap.dat null monthly monthly | fgrep -v '#' >> $outfile
month=0
files=""
while [ $month -lt 12 ]; do
    month=$((month+1))
    outfile=telecon_corr_prcp_$month.dat
    patternfield $file corr_prcp_nino34.nc corr $month > $outfile
    files="$files $outfile"
done
outfile=telecon_corr_nino34_$dataset.dat
./merge_telecon $files > $outfile
rm $files
mv $outfile aap.dat
cat > $outfile <<EOF
# Nino34 index based on GPCC station-based land prdcipitation projected on ENSO teleconnections
# using correlation patterns
# nino34_prcp [1] Nino index from land precipitation
EOF
normdiff aap.dat null monthly monthly | fgrep -v '#' >> $outfile
$HOME/NINO/copyfilesall.sh telecon_nino34_$dataset.dat telecon_corr_nino34_$dataset.dat