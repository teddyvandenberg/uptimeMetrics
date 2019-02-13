#!/bin/sh

# Please provide the path and filename for the sqlite file you would like to use for this
db='/Users/teddyvandenberg/uptime/io-results.db'

# check for some necessary items
if [ ! -f $db ]; then
	echo "The io-results.db file is not present. Please 'touch io-results.db' and re-run this script.\nIf you are running this for the first time, please set a location for the DB in this file."
	exit 1
fi

if [ ! -f /usr/local/bin/speedtest-cli ]; then
	echo "Please install speedtest-cli: 'brew install speedtest-cli'"
	exit 1
fi

if [ ! -f /usr/local/bin/istats ]; then
	echo "Please install iStats: 'sudo gem install iStats'"
	exit 1
fi

# Get metrics
	# current time in epoch
curTime=`date +%s`
	# last time the system started in epoch
kernBootTime=`/usr/sbin/sysctl kern.boottime | awk '{ print $5 }' | sed s/,//`
	# get load averages
vmLoadAvg=`/usr/sbin/sysctl vm.loadavg | awk '{ print $3,$4,$5 }'`
vmLoadAvg="'"$vmLoadAvg"'"
	# get calculation of number of hours booted
uptimeHrs=$(expr $curTime - $kernBootTime)
uptimeHrs=$(expr $uptimeHrs / 60)
uptimeHrs=$(expr $uptimeHrs / 60)
	# Get download rate in mbits per second
mbpsDl=`/usr/local/bin/speedtest-cli --no-upload | grep Download | awk '{ print $2 }'`
	# get current CPU temp in Celcius
cpuTemp=`/usr/local/bin/istats cpu --value-only`
	# get the top 5 processes sorted by CPU percentage
cpuTop5=`/bin/ps auxcr | head -n 6 | tail -5`
	# get the top 5 processes sorted by MEM percentage
memTop5=`/bin/ps auxcm | head -n 6 | tail -5`

# intialize some variables
# processDB output example (please note the leading comma): ,'loginwindow','WindowServer','launchservicesd','TuneCrier','iStatMenusDaemon','firefox','plugin-container','Slack','plugin-container','plugin-container'
processDB="" 
c=0
while read -r line; do
	let "c++"
	# grab the % of cpu used by a process
	cpuPercent=`echo $line | awk '{ print $3 }'`
	# grab teh corresponding process name
	cpuProcess=`echo $line | awk '{ print $11 }'`
	processDB+=",'"$cpuPercent"/"$cpuProcess"'"
done <<< "$cpuTop5"

m=0
while read -r line; do
        let "m++"
	# grab the % of memory used by a process
        memPercent=`echo $line | awk '{ print $4 }'`
	# grab the corresponding process name
        memProcess=`echo $line | awk '{ print $11 }'`
	processDB+=",'"$memPercent"/"$memProcess"'"
done <<< "$memTop5"

# Create DB schema if missing
# Insert values to DB (please note the comma after vmLoadAvg is not missing, it is handled via the following string)
/usr/bin/sqlite3 $db -batch <<EOF
CREATE TABLE IF NOT EXISTS bw (id INTEGER PRIMARY KEY,
				temp INTEGER,
				boottime INTEGER,
				curtime INTEGER,
				uptimehrs INTEGER,
				mbpsdl INTEGER,
				load STRING,
				cpu1 STRING,
				cpu2 STRING,
				cpu3 STRING,
				cpu4 STRING,
				cpu5 STRING,
				mem1 STRING,
				mem2 STRING,
				mem3 STRING,
				mem4 STRING,
				mem5 STRING);
INSERT INTO bw (temp, 
		boottime,
		curtime,
		uptimehrs,
		mbpsdl,
		load,
		cpu1,
		cpu2,
		cpu3,
		cpu4,
		cpu5,
		mem1,
		mem2,
		mem3,
		mem4,
		mem5)
	values($cpuTemp,
		$kernBootTime,
		$curTime,
		$uptimeHrs,
		$mbpsDl,
		$vmLoadAvg
		$processDB);
EOF
