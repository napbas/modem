###############################################################################
#                                                                             #
#  This script parses data from the modem				      #
#                                                                             #
#                              Version 1.0                                    #
#                                April 2021                                   #
###############################################################################


####################### general data lines
#Jan  7 05:45:51 BAI-T201-AC1-TRX01 exp0: Technology: lte. RSRP: -78 dBm RX bytes:491296881 (468.54 MiB)  TX bytes:248919931 (237.39 MiB)
#Jan  7 05:45:53 BAI-T201-AC1-TRX01 exp1: Technology: lte. RSRP: -87 dBm RX bytes:458606888 (437.36 MiB)  TX bytes:201361968 (192.03 MiB)
#Jan  7 05:46:10 BAI-T201-AC1-TRX01 modem1: Technology: lte. RSRP: -48 dBm RX bytes:123217531 (117.51 MiB)  TX bytes:43630723 (41.61 MiB)
#Jan  7 05:46:23 BAI-T201-AC1-TRX01 modem2: Technology: lte. RSRP: -91 dBm RX bytes:217264067 (207.20 MiB)  TX bytes:35978369 (34.31 MiB)
#Jan  7 05:46:27 BAI-T201-AC1-TRX01 modem0: Technology: lte. RSRP: -96 dBm RX bytes:10212359 (9.74 MiB)  TX bytes:2145806 (2.05 MiB)

#######################other cases with tech stepdown
#Jan  6 00:22:21 BAI-T201-AC1-TRX01 modem1: Technology: OutOfCall. RSSI: -105 dBm RX bytes:2687783130 (2.50 GiB)  TX bytes:1604486856 (1.49 GiB)
#Jan  6 00:42:22 BAI-T201-AC1-TRX01 modem1: Technology: wcdma, hsupa, hsdpaplus, 64qam. RSSI: -58 dBm RX bytes:2794058002 (2.60 GiB)  TX bytes:1647211517 (1.53 GiB)
#Jan  6 00:43:33 BAI-T201-AC1-TRX01 modem1: Technology: wcdma, hsupa, hsdpaplus, 64qam. RSSI: -54 dBm RX bytes:2797978718 (2.61 GiB) TX bytes:1647788481 (1.53 GiB)
#Jan  6 00:44:44 BAI-T201-AC1-TRX01 modem1: Technology: wcdma, hsupa, hsdpaplus, 64qam. RSSI: -64 dBm RX bytes:2800559161 (2.61 GiB) TX bytes:1648056149 (1.53 GiB)
#Jan  6 00:45:55 BAI-T201-AC1-TRX01 modem1: Technology: wcdma, hsdpa, hsupa. RSSI: -49 dBm RX bytes:2803492426 (2.61 GiB)  TX bytes: 1648581416 (1.54 GiB)
#Jan  6 00:47:06 BAI-T201-AC1-TRX01 modem1: Technology: wcdma, hsdpa. RSSI: -62 dBm RX bytes:2810437494 (2.62 GiB)  TX bytes:1649222626 (1.54 GiB)

####################### Statistics
#cat BAI-T201-AC1-TRX01.log |grep Technology |awk '{print $7}'|sort -u			<< unique techs
#lte.
#OutOfCall.
#wcdma,

#cat BAI-T201-AC1-TRX01.log |grep Technology |grep lte|wc -l 
#4800
#cat BAI-T201-AC1-TRX01.log |grep Technology |grep wcdma|wc -l   
#714
#cat BAI-T201-AC1-TRX01.log |grep Technology |grep OutOfCall|wc -l             
#1

#################### GPS data
#Jan  5 23:06:23 BAI-T201-AC1-TRX01 GPS: 39.98976, -75.17213, Altitude: 37.4m

clear
echo "========== BEGIN $0 ==========="; date
LOGFILE=$1

KPIOUTPUTFILE=/tmp/modem-kpis-$(date "+%Y%m%d-%H%M%S")
GPSOUTPUTFILE=/tmp/modem-gps-$(date "+%Y%m%d-%H%M%S")
MISCOUTPUTFILE=/tmp/modem-misc-$(date "+%Y%m%d-%H%M%S")

KPIHEADER="date,device,subdevice,technology,RSRP/RSSI,RX bytes,TX bytes"
GPSHEADER="date,device,longitude,latitude,altitude"

echo $KPIHEADER > $KPIOUTPUTFILE
echo $GPSHEADER > $GPSOUTPUTFILE

######### Common Functions #####

# For a data field, it must have the word Technology in it
cat $1 | awk -v GPSOUTPUTFILE="$GPSOUTPUTFILE" -v MISCOUTPUTFILE="$MISCOUTPUTFILE" '

function printit() {
# print the values
	printf("%s,%s,%s,%s,%s,%s,%s\n",date,device,subdevice,technology,RSRP,RXbytes,TXbytes)
# reset values
	date=device=subdevice=technology=RSRP=RXbytes=TXbytes=""
}

#MAIN Awk
{
# Setting common variables for each log entry
date=$1" "$2" "$3
device=$4

#KPI vars
gsub (":","",$5);subdevice=$5
technology=$7;gsub ("[\.,]","",technology);

# for LTE data, 
if ( technology == "lte" ) {
	RSRP=$9
	gsub ("bytes:","",$12);RXbytes=$12
	gsub ("bytes:","",$16);TXbytes=$16
	printit()
}
# for wcdma data
else if (technology == "wcdma" ) {
	# hunt for the RSSI field as it could be in multiple places
	for (i=8; i<=NF; i++ ) {
		if ($i ~ "RSSI:" ) {
			# found the RSSI field, but will set it as the RSRP field to be consistent
			RSRP=$(i+1)
			# Redoing the technology stack as t could be many combinations
			for (t=8; t<i; t++ ) { technology = technology"-"$t }
			gsub ("[\.,]","",technology)
			gsub ("bytes:","",$(i+4));RXbytes=$(i+4)
			gsub ("bytes:","",$(i+8));TXbytes=$(i+8)
			printit()
		} #if end
	} #for end
} #else if end
else if ( subdevice == "GPS" ) {
	# enter the GPS coordinates #Jan  5 23:06:23 BAI-T201-AC1-TRX01 GPS: 39.98976, -75.17213, Altitude: 37.4m
	gsub (",","",$6);longitude=$6
	gsub (",","",$7);latitude=$7
	gsub ("m","",$9);altitude=$9
	# Rewrite in case of weak GPS signal
	#Jan  5 23:12:42 BAI-T201-AC1-TRX01 GPS: GPS coordinates not found: Weak Signal
	if ( longitude == "GPS") { longitude=latitude=altitude="weak signal" }
	printf("%s,%s,%s,%s,%s\n",date,device,longitude,latitude,altitude) >> GPSOUTPUTFILE
	date=device=longitude=latitude=altitude=""
} #end elseif
else {
# entries were not KPI and not GPS so just dumping them in misc
	print $0 >> MISCOUTPUTFILE
}


}' >> $KPIOUTPUTFILE

echo "KPI results are stored in: $KPIOUTPUTFILE"
head $KPIOUTPUTFILE

echo
echo "GSP results are stored in: $GPSOUTPUTFILE"
head $GPSOUTPUTFILE

echo
echo "MISC results are stored in: $MISCOUTPUTFILE, (non KPI/GPS entries)
head $MISCOUTPUTFILE
