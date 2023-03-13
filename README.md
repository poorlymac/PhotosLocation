# PhotosLocation
A very basic bash script to extract the location & date metadata from your iPhoto library and create a GPX file

## What it does
* Extracts the photo metadata from the iPhoto database into another SQLite3 Database
* Converts the iPhoto GPS data into a CSV
* Converts the CSV data into a GPX file
* Opens the GPX file in your default reader, I recommend [GPXSee](http://www.gpxsee.org)

## Requires
* [GPSBabel](https://www.gpsbabel.org) commandline

## Running
```bash
./PhotosLocation.sh
```

## Example Result
![Travails](My%20Travels.png)
