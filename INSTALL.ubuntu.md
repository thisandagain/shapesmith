Install dependencies on Ubuntu
==============================

Install libraries
----------------

 * sudo apt-get install build-essential libncurses5-dev libssl-dev git-core cmake libx11-dev libfreetype6-dev libftgl-dev libxmu-dev libboost-dev
 * wget https://launchpad.net/ubuntu/+archive/primary/+files/json-spirit_4.04.orig.tar.gz
 * tar xzf json-spirit_4.04.orig.tar.gz
 * cd json_spirit_v4.04/
 * mkdir build
 * cd build
 * cmake ..
 * make
 * sudo make install


