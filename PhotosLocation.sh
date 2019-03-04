#!/bin/bash
# Maximum KM's from a city to consider in that city
KMS=100
EARTH=6371
USER=$(whoami)
PHOTOS="/Users/$USER/Pictures/Photos Library.photoslibrary"
if [ -d "$PHOTOS" ]
then
	# Copy the Photos Database over so we can read it
	echo "Copying Photos database ..."
	cp "$PHOTOS/database/photos.db" .
	# If we have gcc and homebrew sqlite3 we can do city matching
	if [ -f /usr/local/opt/sqlite/bin/sqlite3 ] && [ -f /usr/bin/gcc ]
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

		echo "Compiling required sqlite extensions ..."
		gcc -fno-common -dynamiclib extension-functions.c -o libsqlitefunctions.dylib

		# Note: doing radians conversions upfront to speed things up a little
		echo "Exporting data (warning, this may take some time due to nearest city search) ..."
		/usr/local/opt/sqlite/bin/sqlite3 photos.db \
			".load libsqlitefunctions.dylib" \
			"ALTER TABLE RKVersion ADD COLUMN rkv_latitude  REAL;" \
			"UPDATE RKVersion SET rkv_latitude = RADIANS(latitude);" \
			"ALTER TABLE RKVersion ADD COLUMN rkv_longitude REAL;" \
			"UPDATE RKVersion SET rkv_longitude = RADIANS(longitude);" \
			".mode tab" \
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
			"ALTER TABLE cities500 ADD COLUMN c5_longitude REAL;" \
			"UPDATE cities500 SET c5_longitude = RADIANS(longitude);" \
			".mode csv" \
			"SELECT COUNT(*) FROM RKVersion WHERE latitude IS NOT NULL" \
			".output PhotosLocation.csv" \
			"
				SELECT  STRFTIME('%Y/%m/%d',imageDate + 978307200.0, 'unixepoch') date,
					STRFTIME('%H:%M:%S',imageDate + 978307200.0, 'unixepoch') time,
					latitude, longitude, fileName, 'Near ' || COALESCE(closest_city, '') description
				FROM (
					SELECT fileName, imageDate, rkv.latitude, rkv.longitude, (
						SELECT closest_city FROM (
							SELECT ($EARTH * ACOS(SIN(c5_latitude) * SIN(rkv_latitude) + COS(c5_latitude) * COS(rkv_latitude) * (COS(c5_longitude - rkv_longitude)))) d, asciiname || ' (' || country_code || ')' closest_city
							FROM cities500 c5
							WHERE ABS(c5_latitude  - rkv_latitude ) <= $KMS / $EARTH.00000
							AND   ABS(c5_longitude - rkv_longitude) <= $KMS / $EARTH.00000
							ORDER BY 1
							LIMIT 1
						) WHERE d <= $KMS
					) closest_city
					FROM RKVersion rkv
					WHERE rkv.latitude IS NOT NULL
				) closest
			" \
			".output stdout"
	else
		echo "Exporting data ..."
		sqlite3 photos.db \
			".mode csv" \
			".output PhotosLocation.csv" \
			"
				SELECT	STRFTIME('%Y/%m/%d',imageDate + 978307200.0, 'unixepoch') date,
    					STRFTIME('%H:%M:%S',imageDate + 978307200.0, 'unixepoch') time,
    					latitude, longitude, fileName, '' description
				FROM RKVersion
				WHERE latitude IS NOT NULL
				ORDER BY imageDate
			" \
			".output stdout"
	fi

	GPSBABEL=$(which gpsbabel)
	if [ "$GPSBABEL" != "" ]
	then
		echo "Converting to GPX format ..."
		gpsbabel -i unicsv,fields=date+time+lat+lon+name+desc -f PhotosLocation.csv -o gpx -F PhotosLocation.gpx
		open PhotosLocation.gpx
	fi
	
	echo "Cleaning up ..."
	rm photos.db*
	echo "Complete."
else
	echo "Unable to locate photos library in $PHOTOS."
fi
