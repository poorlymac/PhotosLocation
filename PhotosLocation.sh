#!/bin/bash
# Maximum KM's from a city to consider in that city
KMS=100
EARTH=6371
USER=$(whoami)
PHOTOS="/Users/$USER/Pictures/Photos Library.photoslibrary"
if [ -d "$PHOTOS" ]
then
	# If we have gcc and homebrew sqlite3 we can do city matching
	if [ -f /usr/local/opt/sqlite/bin/sqlite3 ]
	then
		SQLITE3=/usr/local/opt/sqlite
	elif [ -f /opt/homebrew/opt/sqlite3/bin/sqlite3 ]
	then
		SQLITE3=/opt/homebrew/opt/sqlite3
	fi
	if [ "$SQLITE3" != "" ] && [ -f /usr/bin/gcc ]
	then
		if [ ! -f cities500.zip ]
		then
			echo "Retrieving city data ..."
			curl -O http://download.geonames.org/export/dump/cities500.zip
			unzip cities500.zip
		fi
		if [ ! -f cities500.txt ]
		then
			echo "Unzipping city data ..."
			unzip cities500.zip
		fi

		echo "$(date) Compiling required sqlite extensions ..."
		gcc -fPIC -lm -shared -fno-common -dynamiclib extension-functions.c -L $SQLITE3/lib -lsqlite3 -o libsqlitefunctions.dylib
		echo "$(date) Exporting ZASSET & ZADDITIONALASSETATTRIBUTES from \"$PHOTOS/database/Photos.sqlite\" ..."
		$SQLITE3/bin/sqlite3 -readonly "$PHOTOS/database/Photos.sqlite" \
			".output ZASSET.sql" \
			".dump ZASSET" \
			".output ZADDITIONALASSETATTRIBUTES.sql" \
			".dump ZADDITIONALASSETATTRIBUTES" \
			".quit"
		if [ $? -ne 0 ]
		then
			echo "Unable to open Photos database, allow the application you're running this Full Disk Access in Privacy & Security System Preferences temporarily"
			exit 1
		fi

		# Note: doing radians conversions upfront to speed things up a little
		echo "$(date) Loading ZASSET and Exporting data (warning, this may take some time due to nearest city search) ..."
		rm -f PhotosLocation.sqlite
		$SQLITE3/bin/sqlite3 PhotosLocation.sqlite \
			".read ZASSET.sql" \
			".read ZADDITIONALASSETATTRIBUTES.sql" \
			"ALTER TABLE ZASSET ADD COLUMN zasset_latitude  REAL;" \
			"UPDATE ZASSET SET zasset_latitude = RADIANS(zlatitude);" \
			"ALTER TABLE ZASSET ADD COLUMN zasset_longitude REAL;" \
			"UPDATE ZASSET SET zasset_longitude = RADIANS(zlongitude);" \
			".mode tab" \
			"SELECT 'Photos', COUNT(*) FROM ZASSET;" \
			"SELECT 'Photos with a LatLong', COUNT(*) FROM ZASSET WHERE zlatitude != -180.000;" \
			"SELECT 'Percentage with a LatLong',ROUND((1.0*SUM(CASE WHEN zlatitude = -180.000 THEN 0 ELSE 1 END) )/(1.0*COUNT(*))*100, 2) FROM ZASSET;" \
			"
				CREATE TABLE cities500 (
					geonameid		INTEGER,
					name			TEXT,
					asciiname		TEXT,
					alternatenames		TEXT,
					latitude		REAL,
					longitude		REAL,
					feature_class		TEXT,
					feature_code 		TEXT,
					country_code		TEXT,
					cc2			TEXT,
					admin1_code		TEXT,
					admin2_code		TEXT,
					admin3_code		TEXT,
					admin4_code 		TEXT,
					population		INTEGER,
					elevation		INTEGER,
					dem			TEXT,
					timezone		TEXT,
					modification_date	TEXT	
				);
			" \
			".import ./cities500.txt cities500" \
			"ALTER TABLE cities500 ADD COLUMN c5_latitude  REAL;" \
			"UPDATE cities500 SET c5_latitude = RADIANS(latitude);" \
			"CREATE INDEX c5_latitude_idx ON cities500 (c5_latitude);" \
			"ALTER TABLE cities500 ADD COLUMN c5_longitude REAL;" \
			"UPDATE cities500 SET c5_longitude = RADIANS(longitude);" \
			"CREATE INDEX c5_longitude_idx ON cities500 (c5_longitude);" \
			"SELECT 'Cities 500 Points', COUNT(*) FROM cities500;" \
			".mode csv" \
			".output PhotosLocation.csv" \
			"
				SELECT  STRFTIME('%Y/%m/%d',zDateCreated + 978307200.0, 'unixepoch') date,
								STRFTIME('%H:%M:%S',zDateCreated + 978307200.0, 'unixepoch') time,
								zlatitude, zlongitude, '-' name,
								COALESCE('Near ' || closest_city, '') || '<br/>' || zOriginalfileName description
				FROM (
					SELECT zOriginalfileName, zDateCreated, za.zlatitude, za.zlongitude, (
						SELECT closest_city FROM (
							SELECT ($EARTH * ACOS(SIN(c5_latitude) * SIN(zasset_latitude) + COS(c5_latitude) * COS(zasset_latitude) * (COS(c5_longitude - zasset_longitude)))) d,
											asciiname || ' (' || country_code || ')' closest_city
							FROM cities500 c5
							WHERE c5_latitude  BETWEEN za.zasset_latitude  - $KMS / $EARTH.00000 AND za.zasset_latitude  + $KMS / $EARTH.00000
							AND   c5_longitude BETWEEN za.zasset_longitude - $KMS / $EARTH.00000 AND za.zasset_longitude + $KMS / $EARTH.00000
							ORDER BY 1
							LIMIT 1
						) WHERE d <= $KMS
					) closest_city
					FROM ZASSET za, ZADDITIONALASSETATTRIBUTES zaa
					WHERE za.zlatitude != -180.000
					AND   za.z_pk = zaa.zasset
				) closest
				ORDER BY zDateCreated
			" \
			".output stdout" \
			".quit"
	else
		echo "$(date) Exporting data ..."
		$SQLITE3/bin/sqlite3 -readonly Photos.sqlite \
			".mode csv" \
			".output PhotosLocation.csv" \
			"
				SELECT	STRFTIME('%Y/%m/%d',za.zDateCreated + 978307200.0, 'unixepoch') date,
    						STRFTIME('%H:%M:%S',za.zDateCreated + 978307200.0, 'unixepoch') time,
    						za.zlatitude, za.zlongitude, '-' name, zaa.zOriginalfileName description
				FROM ZASSET za, ZADDITIONALASSETATTRIBUTES zaa
				WHERE za.zlatitude != -180.000
				AND   za.z_pk = zaa.zasset
				ORDER BY za.zDateCreated
			" \
			".output stdout"
	fi

	GPSBABEL=$(which gpsbabel)
	if [ "$GPSBABEL" != "" ]
	then
		echo "$(date) Converting to GPX format ..."
		gpsbabel -i unicsv,fields=date+time+lat+lon+name+desc -f PhotosLocation.csv -o gpx -F PhotosLocation.gpx
		open PhotosLocation.gpx
	fi
	
	echo "$(date) Cleaning up ..."
	echo "Complete."
else
	echo "$(date) Unable to locate photos library in $PHOTOS."
fi
