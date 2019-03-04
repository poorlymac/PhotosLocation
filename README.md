# PhotosLocation
A very basic bash script to extract the location & date metadata from your iPhoto library and create a GPX file

## What it does
* Copies your Photos sqllite database locally to extract
* Extracts the photo metadata from the database into a CSV
* converts the CSV into a GPX file
* Opens the GPX file in your default reader, I recommend [GPXSee](http://www.gpxsee.org)

## Requires
* [GPSBabel](https://www.gpsbabel.org) commandline

## Running
```bash
./PhotosLocation.sh
```

## Example Result
![Travails](My%20Travels.png)
