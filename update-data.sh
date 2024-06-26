#!/usr/bin/env bash

DATASET=$1
PERIOD=$2

export PYTHONPATH=${PYTHONPATH}::/srv/map-portal/usr/local/lib/python2.7/dist-packages/
export PATH=${PATH}:/srv/map-portal/usr/local/bin:/usr/bin
export LD_LIBRARY_PATH=${LD_LIBRARY_PATH}:/srv/map-portal/usr/local/lib

# configuration

case $DATASET in

    ww3)
        SERVER=http://opendap.bom.gov.au:8080/
        SERVER_PATH=thredds/fileServer/nmoc/ww3_global_fc/
        DATA_SUBDIR=forecast
        ;;
    oceanmaps)
        SERVER=http://opendap.bom.gov.au:8080/
        SERVER_PATH=thredds/fileServer/nmoc/oceanmaps_ofam_fc/ops/latest/
        DATA_SUBDIR=data
	;;
    chloro)
        SERVER=https://oceandata.sci.gsfc.nasa.gov/
        SERVER_PATH=ob/getfile/
        DATA_SUBDIR=
        ;;
    currents)
        SERVER=http://opendap.bom.gov.au:8080/
        SERVER_PATH=/thredds/dodsC/nmoc/oceanmaps_ofam_fc/version-3.1/latest/
        DATA_SUBDIR=daily
        ;;
    coral)
        SERVER=ftp://ftp.star.nesdis.noaa.gov
        SERVER_PATH=/pub/sod/mecb/crw/data/5km/v3.1/nc/v1.0/daily/baa-max-7d/
        DATA_SUBDIR=daily
        MIRROR_FLAGS='-I ct5km_baa-max*.nc'
         ;;
    coral_ol)
        SERVER=ftp://ftp.star.nesdis.noaa.gov
        SERVER_PATH=/pub/sod/mecb/crw/data/outlook/v5/nc/v1/outlook/
        DATA_SUBDIR=outlook
        MIRROR_FLAGS='-I *060perc*.nc'
        ;;
    msla)
        SERVER=ftp://nrt.cmems-du.eu
        SERVER_PATH=/Core/SEALEVEL_GLO_PHY_L4_NRT_OBSERVATIONS_008_046/dataset-duacs-nrt-global-merged-allsat-phy-l4/
        DATA_SUBDIR=grids/daily
        ;;
    poamasla)
        SERVER=http://opendap.bom.gov.au:8080
        SERVER_PATH=/thredds/fileServer/paccsap/sea_level_seasonal/grid/
        DATA_SUBDIR=sla
        ;;
    #poamassta)
        #SERVER=http://opendap.bom.gov.au:8080
        #SERVER_PATH=/thredds/fileServer/paccsap/sea_surface_temperature_seasonal/grid/
        #DATA_SUBDIR=ssta
        #;;
    ersst)
        SERVER=ftp://ftp.ncdc.noaa.gov
        SERVER_PATH=/pub/data/cmb/ersst/v5/netcdf
        DATA_SUBDIR=monthly
        ;;
    reynolds)
        SERVER=https://www.ncei.noaa.gov
        SERVER_PATH=/data/sea-surface-temperature-optimum-interpolation/v2.1/access/avhrr/
        DATA_SUBDIR=daily-new-uncompressed
        ;;
    decile)
        SERVER=d
        SERVER_PATH=e
        DATA_SUBDIR=c
        ;;
    sealevel)
        BASE_URL=http://reg.bom.gov.au/ntc
        DATA_SUBDIR=gauges-new
        ;;
    mur)
	SERVER=https://opendap.jpl.nasa.gov:443
#	SERVER=http://podaac-opendap.jpl.nasa.gov
#	SERVER_PATH=/opendap/allData/ghrsst/data/L4/GLOB/JPL/MUR/
	SERVER_PATH=/opendap/allData/ghrsst/data/GDS2/L4/GLOB/JPL/MUR/v4.1/
	DATA_SUBDIR=data
	;;
    *)
        echo "Unknown dataset $DATASET" >&2
        exit 1
        ;;
esac

# load variables from ocean.config

if [ "$DATASET" != "decile" ]; then

DATA_DIR=`python << EOF
from ocean.config import get_server_config

config = get_server_config()
print config['dataDir']["$DATASET"]
EOF`

if [ "x$DATA_DIR" = "x" ]; then
    echo "DATA_DIR empty, very bad! Is PYTHONPATH set?" >&2
    exit 1
fi

# download data
cd $DATA_DIR$DATA_SUBDIR || exit 1
fi

case $DATASET in
    coral|coral_ol)
        lftp $SERVER << EOF
cd $SERVER_PATH || exit 1
mirror --only-missing -n $MIRROR_FLAGS
#chmod -R 666
EOF
   ;;
   reynolds)

	current_year=$(date +"%Y")
	current_month=$(date +"%m")
	current_month=$((10#$current_month))
	current_day=$(date +"%d")
	#current_day=$((10#$day))

	#setting the end limit of the month loop so that it does not iterate in the future
	#for (( m=1; m<=$current_month; m++ ))
	#do
        m=$current_month
           #retrieving number of days of the iterating month
           month=$((m-1)) #As unix month number starts from 0
	   end=`date +"%d" -d "-$(date +%d) days +$month month"`

	   #setting the end limit of the day loop so that it does not iterate in the future
           if (( $m==$current_month ))
           then
             end=$current_day;
	   fi

	   for (( d=1; d<=$end; d++ ))
	   do
	      mm=`seq -f "%02g" $m $m`; #Ensure month two digit long
             dd=`seq -f "%02g" $d $d`; #Ensure date two digit long
	     wget -nc --no-check-certificate $SERVER/$SERVER_PATH/${current_year}${mm}/oisst-avhrr-v02r01.${current_year}${mm}${dd}.nc
             wget -nc --no-check-certificate $SERVER/$SERVER_PATH/${current_year}${mm}/oisst-avhrr-v02r01.${current_year}${mm}${dd}_preliminary.nc
             mv oisst-avhrr-v02r01.${current_year}${mm}${dd}.nc avhrr-only-v2.${current_year}${mm}${dd}.nc
             mv oisst-avhrr-v02r01.${current_year}${mm}${dd}_preliminary.nc avhrr-only-v2.${current_year}${mm}${dd}_preliminary.nc


	   done
   #     done
    ;;
    ersst)
    yr=2020
    while [ $yr -le 2024 ]; do
    nm=1
    while [ $nm -le 12 ]; do
    if [ $nm -lt 10 ]; then
    nm=0$nm
    fi
    wget -c -N https://www.ncei.noaa.gov/pub/data/cmb/ersst/v5/netcdf/ersst.v5.$yr$nm.nc --no-check-certificate
    nm=`expr $nm + 1`
    done
    yr=`expr $yr + 1`
    done
    ;;
    poamasla)
            FILE='sla_grid_latest.nc'
            URL=$SERVER/$SERVER_PATH/$FILE
            #wget -q "$URL" -O "$FILE"|| echo -n "error ($?)"
            python /srv/map-portal/usr/local/bin/ssh.py
            response=`python << EOF
import os
from subprocess import check_call, CalledProcessError
try:
    check_call(['ncatted', '-a', '_FillValue,HEIGHT,c,f,NaN', '$FILE'])
except CalledProcessError as cpe:
    print cpe.read()
    print '\n'
"""
pre-generate configuration file and images.
"""
from ocean.datasets.poamasla import poamasla as Dataset
from datetime import *
from ocean.config import regionConfig

#Read regionconfig files and do a loop to generate images for all regions
date = date(2016, 4, 30)

ds = Dataset.poamasla()
values = {"dataset": "poamasla",
          "variable": "height",
          "plot": "map",
          "period": "seasonal",
          'date':date,
          "mode": "preprocess"
           }

for key, value in regionConfig.regions.iteritems():
    if value[0] == 'pac' or value[0] == None:
        values["area"] = key
        ds.process(values)

EOF`
            echo -n $response
    ;;
    poamassta)
            FILE='PACCSAP_oa_latest.nc'
            URL=$SERVER/$SERVER_PATH/$FILE
            wget -q "$URL" -O "$FILE" || echo -n "error ($?)"
            response=`python << EOF
import os
from subprocess import check_call, CalledProcessError
try:
    check_call(['ncatted', '-a', '_FillValue,SSTA,c,f,-999', '$FILE'])
except CalledProcessError as cpe:
    print cpe.read()
    print '\n'
"""
pre-generate configuration file and images.
"""
from ocean.datasets.poamassta import poamassta as Dataset
from ocean.config import regionConfig

#Read regionconfig files and do a loop to generate images for all regions
ds = Dataset.poamassta()
values = {"dataset": "poamassta", 
          "plot": "map", 
          "period": "seasonal", 
          "date": "20120701", 
          "mode": "preprocess"}

for key, value in regionConfig.regions.iteritems():
    if value[0] == 'pac' or value[0] == None:
        values["area"] = key
        for var in ["ssta", "sst"]:
            values["variable"] = var
            ds.process(values)

EOF`
            echo -n $response
    ;;
    ww3)
        find . -type f -name 'ww3_[0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]_[0-9][0-9].nc' -delete
        dates=("$(date +"%Y%m%d")" "$(date --date="yesterday" +"%Y%m%d")")
        hours=("12" "00")
        for date in "${dates[@]}"
        do
            for hour in "${hours[@]}"
            do
                FILE="$(printf "ww3_%s_%s.G.nc" "$date" "$hour")"
                FILETEST="$(printf "ww3_%s_%s.nc" "$date" "$hour")"
                URL=$SERVER/$SERVER_PATH/$FILE
                if [[ -e $FILE ]];
                then
                    break 2;
                else
                    wget -nc -nv "$URL" -O "$FILETEST";
                    if [[ $? -eq 0 ]];
                    then
                        break 2;
                    else
                        continue; 
                    fi
                fi
            done
        done
        response=`python << EOF
from ocean.datasets.ww3forecast import ww3forecast as Dataset
from datetime import *

date = date(2016, 4, 30)

values = {"dataset": "ww3forecast",
          "variable": "sig_wav_ht",
          "plot": "map",
          "period": "7days",
          'date':date,
          "area": "pac",
          "mode": "preprocess"
           }

ds = Dataset.ww3forecast()
ds.process(values)

EOF`
        echo -n $response
    ;;
    chloro)
        response=`python << EOF
import os
import urllib
import urllib2
import datetime
from datetime import timedelta, date
from dateutil.relativedelta import relativedelta
from subprocess import check_call, CalledProcessError, call
from ocean.datasets.chlorophyll import chlorophyll as Dataset
from ocean.config import regionConfig
import calendar
from calendar import monthrange
#username and password for ftp site
#user='zbegg'
#password='Oceanportal2017*'
#download ch
#echo 'Running bash'
cmd = 'bash download_chlor.sh'
os.system(cmd)
#done download
appkey='?appkey=fb95de75edd756ef103e91b2ec74c2dda74a3f93'
url = '$SERVER/$SERVER_PATH'
today = date.today()
format = "%Y%m%d"
ds = Dataset.chlorophyll()
values = {'dataset':'chlorophyll', 
          'plot':'map'
         }
#Month START

date_stamp = today.replace(day=1)
for delta in range(6):
    date_stamp = date_stamp + timedelta(-1)
    first_day_month = date_stamp.replace(day=1)
    last_day_month = date_stamp.replace(day=calendar.monthrange(date_stamp.year, date_stamp.month)[1])
    date_stamp = first_day_month

    first_date = first_day_month.timetuple()
    last_date = last_day_month.timetuple() 
    file_name = '/data/chloro/monthly/A%4d%03d%4d%03d.L3m_MO_CHL_chlor_a_4km.nc' % (first_date.tm_year, first_date.tm_yday, last_date.tm_year, last_date.tm_yday)
    
    first_part = str(first_date.tm_year)+""+str('%02d' % first_day_month.month)+"01"
    endmonth = monthrange(last_day_month.year, last_day_month.month)
    last_part = str(last_date.tm_year)+""+str('%02d' % last_day_month.month)+str(endmonth[1])
    file_to_download = "AQUA_MODIS."+first_part+"_"+last_part+".L3m.MO.CHL.chlor_a.4km.nc"
    print(file_to_download)
    outputfile = "/home/anuj/Desktop/choloro/"+file_to_download
    os.system('wget -nc https://oceandata.sci.gsfc.nasa.gov/ob/getfile/'+file_to_download+'?appkey=fb95de75edd756ef103e91b2ec74c2dda74a3f93 -O'+file_name+' --no-check-certificate')

myPath = "/data/chloro/monthly"
mySize = '10'

for file in os.listdir(myPath):
    if file.endswith(".nc"):
        f=os.path.join(myPath, file)
        fileSize = os.path.getsize(str(f))
    
        # Print the files that meet the condition
        if int(fileSize) <= int(mySize):
            os.remove(f)
myPath = "/data/chloro/daily"
mySize = '10'

for file in os.listdir(myPath):
    if file.endswith(".nc"):
        f=os.path.join(myPath, file)
        fileSize = os.path.getsize(str(f))
    
        # Print the files that meet the condition
        if int(fileSize) <= int(mySize):
            os.remove(f)

#print 'getting daily'
for delta in range(20):
    date_stamp = today + timedelta(-delta)
    date_stamp = date_stamp.timetuple()
    file_name_old = 'A%4d%03d.L3m_DAY_CHL_chlor_a_4km' % (date_stamp.tm_year, date_stamp.tm_yday)
    nc_file_name_old = file_name_old + '.nc'
    #nc_file_path = 'daily/' + nc_file_name
    #full_url = url + nc_file_name + appkey
    #print full_url
    file_name = 'AQUA_MODIS.%4d%02d%02d.L3m.DAY.CHL.chlor_a.4km.NRT' % (date_stamp.tm_year, date_stamp.tm_mon, date_stamp.tm_mday)
    nc_file_name = file_name + '.nc'
    nc_file_path = 'daily/' + nc_file_name
    full_url = url + nc_file_name + appkey
    if os.path.exists(nc_file_path):
        continue
    else:
        try:
            print('Downloading')
            #os.system('wget -nc https://oceandata.sci.gsfc.nasa.gov/ob/getfile/'+nc_file_name+'?appkey=fb95de75edd756ef103e91b2ec74c2dda74a3f93 --no-check-certificate -O /data/chloro/daily/'+nc_file_name_old)
            #check_call(['wget','-V', '--debug', '--auth-no-challenge=on', '--keep-session-cookies', '--content-disposition', full_url, '-P', '--random-wait','daily','--no-check-certificate', '-O',nc_file_name_old])
            #check_call([curl -O -b -L -n, full_url, 'daily']) 
        except CalledProcessError as cpe:
            print cpe.message; 
            print '\n'
            continue
        except OSError as oe:
            print oe.strerror;
            print '\n'
            print full_url;
            print '\n'
            continue

#Month END
#daily
if '$PERIOD' == 'daily':
    for delta in range(4):
        date_stamp = today + timedelta(-delta)
        date_stamp = date_stamp.timetuple()
        file_name_old = 'A%4d%03d.L3m_DAY_CHL_chlor_a_4km' % (date_stamp.tm_year, date_stamp.tm_yday)
        nc_file_name_old = file_name_old + '.nc'
        #nc_file_path = 'daily/' + nc_file_name
        #full_url = url + nc_file_name + appkey
        #print full_url
        file_name = 'AQUA_MODIS.%4d%02d%02d.L3m.DAY.CHL.chlor_a.4km.NRT' % (date_stamp.tm_year, date_stamp.tm_mon, date_stamp.tm_mday)
        nc_file_name = file_name + '.nc'
        nc_file_path = 'daily/' + nc_file_name
        full_url = url + nc_file_name + appkey
	if os.path.exists(nc_file_path):
            continue
        else:
            try:
                check_call(['wget','-V', '--debug', '--auth-no-challenge=on', '--keep-session-cookies', '--content-disposition', full_url, '-P', '--random-wait','daily','--no-check-certificate', '-O',nc_file_name_old])
		#check_call([curl -O -b -L -n, full_url, 'daily']) 
            except CalledProcessError as cpe:
                print cpe.message; 
                print '\n'
                continue
            except OSError as oe:
                print oe.strerror;
                print '\n'
                print full_url;
                print '\n'
                continue



    #----------preprocess --------
    date_stamp = today + timedelta(-2)
    date = datetime.date.strftime(format)
    print date_stamp

    values["variable"] = "chldaily"
    values["period"] = "daily"
    for key, value in regionConfig.regions.iteritems():
        if value[0] == 'pac' or value[0] == None:
            values["date"] = date_stamp
            values["area"] = key
            ds.process(values)

#monthly
elif '$PERIOD' == 'monthly':
    date_stamp = today.replace(day=1)
    for delta in range(4):
        date_stamp = date_stamp + timedelta(-1)
        first_day_month = date_stamp.replace(day=1)
        last_day_month = date_stamp.replace(day=calendar.monthrange(date_stamp.year, date_stamp.month)[1])
        date_stamp = first_day_month

        first_date = first_day_month.timetuple()
        last_date = last_day_month.timetuple() 
        file_name = 'A%4d%03d%4d%03d.L3m_MO_CHL_chlor_a_4km.nc' % (first_date.tm_year, first_date.tm_yday, last_date.tm_year, last_date.tm_yday)
        #os.system('wget -nc https://oceandata.sci.gsfc.nasa.gov/ob/getfile/'+file_name+'?appkey=fb95de75edd756ef103e91b2ec74c2dda74a3f93 --no-check-certificate -O /data/chloro/monthly/'+file_name)

    #----------preprocess --------
    """
    pre-generate images.
    """
    print
    print 'pre-generate images.'
    last_month = today - relativedelta(months=1)
    last_month_unformatted = date(last_month.year, last_month.month, 1)
#    date = last_month_unformatted.strftime(format)

    print 'preprocess image for ', date_stamp
    
    values["variable"] = "chlmonthly"
    values["period"] = "monthly"
    for key, value in regionConfig.regions.iteritems():
        if value[0] == 'pac' or value[0] == None:
            values["date"] = date_stamp
            values["area"] = key
            ds.process(values)

EOF`
        echo -n $response
    ;;
    sealevel)
        python << EOF | while read PRODUCT GAUGE
from ocean.config.tidalGaugeConfig import tidalGauge

for gauge in tidalGauge:
    product = gauge.split('_')[0]
    print product, gauge

EOF
        do
            echo -n "$GAUGE: "
            FILE=${GAUGE}SLD.txt
            URL=$BASE_URL/$PRODUCT/$FILE
            echo -n "$URL "
            wget -qO $FILE $URL || echo -n "error ($?)"
            echo
        done
    ;;

esac

# processing

case $DATASET in
    reynolds)
        python << EOF
# recompress daily data
#from ocean.processing.uncompress_synched_data import uncompress_synched_data

#uncompress_synched_data().process("$DATASET")
print "Calculate Monthly Averages..."

# calculate monthly averages
from ocean.processing.Calculate_Monthly_Averages import Calculate_Monthly_Averages

Calculate_Monthly_Averages().process("$DATASET")

from ocean.processing.Calculate_Weekly_Averages import Calculate_Weekly_Averages
Calculate_Weekly_Averages().process("$DATASET")

EOF

    ;& # continue

    ersst)
        python << EOF
# apply a patch to ERSST files
from ocean.processing.convert_ERSST_files import convert
convert()

# calculate multi month averages
from ocean.processing.Calculate_MultiMonth_Averages import Calculate_MultiMonth_Averages

Calculate_MultiMonth_Averages().process("$DATASET")

# FIXME: calculate deciles
EOF
     ;;
     msla)
	#username and password for the data ftp site     
	USER_NAME=zbegg
	PASSWORD=Oceanportal2017*

        #Gets the data
        #cd $DATA_DIR$DATA_SUBDIR || exit 1
	#ORIGINAL_FILE_NAME='nrt_global_allsat_phy_l4_%(year)04d%(month)02d%(day)02d_%(year)04d%(month)02d%(day)02d.nc'
	#NEW_FILE_NAME='nrt_global_allsat_phy_l4_%(year)04d%(month)02d%(day)02d'
        #lftp -u $USER_NAME:$PASSWORD $SERVER$SERVER_PATH python<<EOF
	#mirror --only-missing -n $MIRROR_FLAGS
        #chmod -R 666
	
EOF
python<<EOF
print "Calculate Monthly Averages..."
#PROD ANUJ
from datetime import datetime
import os
import netCDF4

pathbasemsla = "/data/sea_level/grids/daily"

currentMonth = '{:02d}'.format(datetime.now().month)
currentYear = datetime.now().year

#final_path = pathbasemsla+"/"+str(currentYear)+"/"+str(currentMonth)
final_path = pathbasemsla+"/"+str(currentYear)+"/04"

for file in os.listdir(final_path):
    if file.endswith(".nc"):
        nu = final_path+"/"+str(file)
        try:
          with netCDF4.Dataset(nu, "r+") as dataset:
              dataset.renameVariable("err_sla", "err") # RunTimeError
          print('changing variable name ...')
        except:
          print('continue')
#PROD ANUJ

# calculate monthly averages
from ocean.processing.Calculate_Monthly_Averages import Calculate_Monthly_Averages

Calculate_Monthly_Averages().process("$DATASET")
EOF
    ;;
    currents)
        python << EOF
print "Download and Convert Bluelink Currents..."

from ocean.processing.Download_Compile_Bluelink_Currents import Download_Compile_Bluelink_Currents
import sys, traceback

retry = 0
retry_max = 3
flag = True
while flag:
    try:
        Download_Compile_Bluelink_Currents("$DATA_DIR","$DATA_SUBDIR","$SERVER","$SERVER_PATH")
        print 'The currents file has been downloaded successfully.'
        flag = False
    except Exception,e:
        exc_type, exc_value, exc_traceback = sys.exc_info()
        if 'NetCDF' in str(exc_value):
            if (retry < retry_max):
                retry = retry + 1
                continue
            else:
                print 'Gave up after retrying ' + str(retry) + ' times for "' + str(exc_value) + '"'
                break

from ocean.config import regionConfig
from ocean.datasets.currentforecast import currentforecast as Dataset
from datetime import *
 
date = date(2016, 4, 30)
 
values = {"dataset": "currentforecast",
          "variable": "currents",
          "plot": "map",
          "period": "3days",
          'date':date,
          "area": "pac",
          "mode": "preprocess"
           }
 
ds = Dataset.currentforecast()
ds.process(values)

EOF
    ;;

    mur)
	python << EOF
print "Download MUR and process fronts..."
import os
from subprocess import check_call, CalledProcessError
from datetime import timedelta, date, datetime
from ocean.processing.Download_MUR import Download_MUR
from ocean.config import regionConfig
import glob
import sys, traceback

today=date.today()
retry_max = 3

for delta in range(2, 4):
    baseStartDate = today + timedelta(-delta)
    year=baseStartDate.year
    month=baseStartDate.month
    day=baseStartDate.day
    date = str(year) + str(month).zfill(2) + str(day).zfill(2)

    day_of_year=(datetime(year=year, month=month, day=day)-datetime(year,1,1)).days +1
    filename=str(year)+str(month).zfill(2)+str(day).zfill(2)+'090000-JPL-L4_GHRSST-SSTfnd-MUR-GLOB-v02.0-fv04.1.nc'
    total_name="$SERVER"+"$SERVER_PATH"+'/'+str(year)+'/'+str(day_of_year).zfill(3)+'/'+filename

    mur_path = "$DATA_DIR"+"$DATA_SUBDIR"
    local_file=os.path.join(mur_path, filename)
    if not os.path.exists(local_file):
        try:
            check_call(['wget', '--no-check-certificate', total_name, '-P', mur_path])
        except CalledProcessError as cpe:
            print cpe.message;
            print '\n'
            continue
        except OSError as oe:
            print oe.strerror;
            print '\n'
            print total_name;
            print '\n'
            continue


    #check file availability for each region and process if file does not exist
    for key, value in regionConfig.regions.iteritems():
        filepath = "$DATA_DIR" + "$DATA_SUBDIR" + "/" + key
        totalFiles = len(glob.glob(filepath + "/" + "*" + date + "*"))
        if ((regionConfig.regions[key][0]=='pac' and totalFiles != 4 and key != 'nauru') or (regionConfig.regions[key][0]=='pac' and totalFiles != 1 and key == 'nauru')):
            flag = True
            print 'processing files for ' + key + ' date: ' + date
            retry = 0
            while flag:
                try:
                    Download_MUR(local_file, "$DATA_DIR", "$DATA_SUBDIR", day, month, year, key)
                    flag = False
                except Exception,e:
                    print e
                    exc_type, exc_value, exc_traceback = sys.exc_info()
                    if 'NetCDF' in str(exc_value):
                        if (retry < retry_max):
                            retry = retry + 1
                            continue
                        else:
                            print 'Gave up after retrying ' + str(retry) + ' times for "' + str(exc_value) + '"'
                            break
        else:
            if (regionConfig.regions[key][0]=='pac'):
                print 'file exists. skipping processing for ' + key + ' date: ' + date
EOF
    ;;

    decile)
        python << EOF
print "Calculate Decile ..."

# calculate decile: reynolds and ersst
from ocean.processing.Calculate_Deciles import Calculate_Deciles

Calculate_Deciles().process("reynolds")
Calculate_Deciles().process("ersst")

EOF
    ;;

esac
