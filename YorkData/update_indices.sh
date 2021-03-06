#!/bin/sh
base=http://www-users.york.ac.uk/~kdc3/papers/coverage2013
for file in had4_krig_v2_0_0.txt
do
    wget -N -q $base/$file
    f=${file%.txt}_gl.dat
    cat > $f <<EOF
# <a href="http://www-users.york.ac.uk/~kdc3/papers/coverage2013/series.html">Cowtan and Way</a> global mean temperature, HadCRUT4 in-filled with kriging.
# Tglobal [K] HadCRUT4 global mean T2m/SST in-filled with kriging
# institution :: University of York, University of Ottawa.
# title ::  HadCRUT4 in-filled with kriging
# references :: Cowtan, K., & Way, R. G. (2014). Coverage bias in the HadCRUT4 temperature series and its impact on recent temperature trends. Quarterly Journal of the Royal Meteorological Society.
# history :: retrieved `date`
# source_url :: $base/$file
# source :: http://www-users.york.ac.uk/~kdc3/papers/coverage2013/series.html
# climexp_url :: https://climexp.knmi.nl/getindices.cgi?${f%.dat}
EOF
    cut -b 1-17 $file >> $f
done
$HOME/NINO/copyfilesall.sh had4*.dat
