# Local Geohistory Project: Tile Creation

[![DOI](https://zenodo.org/badge/720603942.svg)](https://zenodo.org/doi/10.5281/zenodo.10155836)

## Summary

The Local Geohistory Project aims to educate users and disseminate information concerning the geographic history and structure of political subdivisions and local government. This repository contains a process to create a [PMTiles archive](https://github.com/protomaps/PMTiles) based on the [Daylight map distribution](https://daylightmap.org/) for use as a base map layer, which takes about two hours to run.

To start the process, the **create-instance.sh** shell script creates a compute-optimized instance in AWS capable of processing the large OpenStreetMap and related datasets. Inside this instance, the **process-tile.sh** shell script handles the steps from processing to uploading of the final archive.

The datasets are prepared for tiling using [Osmconvert](https://wiki.openstreetmap.org/wiki/Osmconvert) and the [Osmium Tool](https://osmcode.org/osmium-tool/), including clipping Microsoft Building Footprints to the area delimited by **Simplified10.poly**, filtering Administrative boundaries to only national and the highest subnational boundaries, renumbering IDs to avoid conflicts, reformatting, and merging the disparate datasets into one planet file for tiling.

[Planetiler](https://github.com/onthegomap/planetiler) is then used to create two intermediate MBTiles archives: one with the entire planet through zoom level 10, and another clipped to the previously delimited geographic area for higher zoom levels. These MBTiles archives are then combined into another intermediate MBTiles archive using [tilelive-copy](https://github.com/mapbox/tilelive/blob/master/bin/tilelive-copy). The [go-pmtiles](https://github.com/protomaps/go-pmtiles) utility then converts the tileset to the final PMTiles archive, which is then uploaded to a bucket compatible with AWS S3 (including Cloudflare R2).

When processing is complete, the instance is terminated in order to limit processing costs. However, it is recommended to verify that termination was successful via AWS's web console to avoid unanticipated charges.

## Deployment

These instructions were created using Ubuntu; however, URLs to software instructions are provided to facilitate installations on other operating systems.

### Prerequisites

In order to create an instance, an AWS account is required. Certain resources may need to be created in EC2 and S3 prior to running the process. More information about AWS is available at:

<https://aws.amazon.com/>

Several components must be installed to build the application. On Ubuntu, run the following code via Terminal:

```bash
sudo apt-get install awscli git
```

More detailed installation instructions for AWS Command Line Interface (AWS CLI) are available at:

<https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html>

More detailed installation instructions for Git are available at:

<https://git-scm.com/downloads>

### Clone repository

Navigate to the folder where the process code will be downloaded, then run the following command using a program such as Git BASH or Terminal:

```bash
git clone https://github.com/localgeohistoryproject/tile-creation.git tile-creation
```

This will create a subfolder named **tile-creation**, which contains the process code.

### Configure and run

Within the newly-created **tile-creation** folder, the root folder contains a Sample.env file that can be used to create the necessary .env file for the process, which is where information like credentials is stored.

First, copy the Sample.env, and name the copy **.env** (with nothing before the period). Then, populate the values labeled ***, following the directions in the file.

Once configurations are finalized, the **create-instance.sh** shell script can be executed in Terminal, as the below example illustrates:

```bash
./create-instance.sh
```

## Next steps

### Clipping

The **Simplified10.poly** and **Simplified25.poly** files are used to clip certain datasets to roughly within 0.1 or 0.25 degrees, respectively, of the Local Geohistory Project coverage area. This allows the tile archive to omit higher zoom levels and associated data for geographic areas outside of the required scope.

For more information on how to format these files for projects with other geographic scopes, see Osmosis's documentation on the [Polygon Filter File Format](https://wiki.openstreetmap.org/wiki/Osmosis/Polygon_Filter_File_Format).

### Serving tiles

This repository does not include the code required to serve the tiles. See the [Protomaps](https://docs.protomaps.com/) documentation for more information.

For an example of how served tiles can be incorporated into a web application, see the [Application repository](https://github.com/localgeohistoryproject/application).
