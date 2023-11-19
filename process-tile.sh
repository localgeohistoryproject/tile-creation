#!/bin/bash
# Keep track of started time
now=$(date +"%T")
echo "Process Script Started: $now"
# Import variables
source /home/ubuntu/.env
# Run update to ensure software installs correctly
apt update
apt upgrade -y
# Mount extra drive
DATA_DRIVE=$(lsblk | grep "[1][.][7-9][T]" | cut -d " " -f 1)
mkfs -t xfs /dev/${DATA_DRIVE}
mkdir /data
mount /dev/${DATA_DRIVE} /data
chown -R ubuntu:ubuntu /data
cd /data
# Install software needed for filtering
apt install -y awscli osmctools osmium-tool
# Keep track of intermediate time
now=$(date +"%T")
echo "Time: $now"
# Download inputs
aws s3 cp --no-sign-request --only-show-errors s3://daylight-map-distribution/release/v$DAYLIGHT_VERSION/ml-buildings-v$DAYLIGHT_VERSION.osm.pbf /data
mv /data/ml-buildings-v$DAYLIGHT_VERSION.osm.pbf /data/building-whole.osm.pbf
# Keep track of intermediate time
now=$(date +"%T")
echo "Time: $now"
# Crop building footprints
osmconvert /data/building-whole.osm.pbf -B=/home/ubuntu/Simplified25.poly -o=/data/building-input.osm.pbf
# Keep track of intermediate time
now=$(date +"%T")
echo "Time: $now"
# Remove trim from building footprints
osmium extract -p /home/ubuntu/Simplified10.poly -s smart -o /data/building-renumber.osm.pbf /data/building-input.osm.pbf
# Keep track of intermediate time
now=$(date +"%T")
echo "Time: $now"
# Download admin boundaries
aws s3 cp --no-sign-request --only-show-errors s3://daylight-map-distribution/release/v$DAYLIGHT_VERSION/admin-v$DAYLIGHT_VERSION.osc.gz /data
mv /data/admin-v$DAYLIGHT_VERSION.osc.gz /data/admin-input.osc.gz
# Keep track of intermediate time
now=$(date +"%T")
echo "Time: $now"
# Narrow required admin boundaries to .osm.pbf
gunzip /data/admin-input.osc.gz
osmconvert /data/admin-input.osc -o=/data/admin-input.osm.pbf
osmium tags-filter -o /data/admin-renumber.osm.pbf /data/admin-input.osm.pbf admin_level=2,4
# Keep track of intermediate time
now=$(date +"%T")
echo "Time: $now"
# Download Daylight Planet
aws s3 cp --no-sign-request --only-show-errors s3://daylight-map-distribution/release/v$DAYLIGHT_VERSION/planet-v$DAYLIGHT_VERSION.osm.pbf /data
mv /data/planet-v$DAYLIGHT_VERSION.osm.pbf /data/planet-input.osm.pbf
# Keep track of intermediate time
now=$(date +"%T")
echo "Time: $now"
# Determine highest ID in Daylight Planet
MAX_NODE_ID=$(osmium fileinfo -e -g data.maxid.nodes --no-progress /data/planet-input.osm.pbf)
MAX_WAY_ID=$(osmium fileinfo -e -g data.maxid.ways --no-progress /data/planet-input.osm.pbf)
if (( ${MAX_NODE_ID} < ${MAX_WAY_ID} )); then
  MAX_NODE_ID=${MAX_WAY_ID};
fi;
unset MAX_WAY_ID
MAX_RELATION_ID=$(osmium fileinfo -e -g data.maxid.relations --no-progress /data/planet-input.osm.pbf)
if (( ${MAX_NODE_ID} < ${MAX_RELATION_ID} )); then
  MAX_NODE_ID=${MAX_RELATION_ID};
fi;
unset MAX_RELATION_ID
MAX_CHANGESET_ID=$(osmium fileinfo -e -g data.maxid.changesets --no-progress /data/planet-input.osm.pbf)
if (( ${MAX_NODE_ID} < ${MAX_CHANGESET_ID} )); then
  MAX_NODE_ID=${MAX_CHANGESET_ID};
fi;
unset MAX_CHANGESET_ID
# Keep track of intermediate time
now=$(date +"%T")
echo "Time: $now"
# Renumber building footprints
echo "$((++MAX_NODE_ID))"
osmium renumber -o /data/building.osm.pbf -s $MAX_NODE_ID /data/building-renumber.osm.pbf
# Keep track of intermediate time
now=$(date +"%T")
echo "Time: $now"
# Determine highest ID in renumbered building footprints
MAX_NODE_ID=$(osmium fileinfo -e -g data.maxid.nodes --no-progress /data/building.osm.pbf)
MAX_WAY_ID=$(osmium fileinfo -e -g data.maxid.ways --no-progress /data/building.osm.pbf)
if (( ${MAX_NODE_ID} < ${MAX_WAY_ID} )); then
  MAX_NODE_ID=${MAX_WAY_ID};
fi;
unset MAX_WAY_ID
MAX_RELATION_ID=$(osmium fileinfo -e -g data.maxid.relations --no-progress /data/building.osm.pbf)
if (( ${MAX_NODE_ID} < ${MAX_RELATION_ID} )); then
  MAX_NODE_ID=${MAX_RELATION_ID};
fi;
unset MAX_RELATION_ID
MAX_CHANGESET_ID=$(osmium fileinfo -e -g data.maxid.changesets --no-progress /data/building.osm.pbf)
if (( ${MAX_NODE_ID} < ${MAX_CHANGESET_ID} )); then
  MAX_NODE_ID=${MAX_CHANGESET_ID};
fi;
unset MAX_CHANGESET_ID
# Keep track of intermediate time
now=$(date +"%T")
echo "Time: $now"
# Renumber admin boundaries
echo "$((++MAX_NODE_ID))"
osmium renumber -o /data/admin.osm.pbf -s $MAX_NODE_ID /data/admin-renumber.osm.pbf
# Keep track of intermediate time
now=$(date +"%T")
echo "Time: $now"
# Combine Daylight Planet, admin boundaries, and building footprints
osmium merge /data/admin.osm.pbf /data/building.osm.pbf /data/planet-input.osm.pbf -o /data/planet.osm.pbf
# Keep track of intermediate time
now=$(date +"%T")
echo "Time: $now"
# Install software needed for conversion
sudo apt-get install -y ca-certificates curl gnupg openjdk-$JAVA_VERSION-jre-headless screen
wget -nv https://github.com/onthegomap/planetiler/releases/download/v$PLANETILER_VERSION/planetiler.jar
sudo mkdir -p /etc/apt/keyrings
curl -fsSL https://deb.nodesource.com/gpgkey/nodesource-repo.gpg.key | sudo gpg --dearmor -o /etc/apt/keyrings/nodesource.gpg
echo "deb [signed-by=/etc/apt/keyrings/nodesource.gpg] https://deb.nodesource.com/node_$NODE_MAJOR.x nodistro main" | sudo tee /etc/apt/sources.list.d/nodesource.list
sudo apt-get update
sudo apt-get install -y nodejs
sudo npm install -g @mapbox/tilelive @mapbox/mbtiles
wget -nv https://github.com/protomaps/go-pmtiles/releases/download/v$PMTILES_VERSION/go-pmtiles_"$PMTILES_VERSION"_Linux_arm64.tar.gz
tar -xf go-pmtiles_"$PMTILES_VERSION"_Linux_arm64.tar.gz
# Keep track of intermediate time
now=$(date +"%T")
echo "Time: $now"
# Convert Daylight Planet to MBTiles (zoom levels 0-10)
java -Xmx30g \
  -jar planetiler.jar \
  `# Use downloaded Daylight Planet, set bounds, and download other files` \
  --osm-path=/data/planet.osm.pbf --bounds=planet --download \
  `# Accelerate the download by fetching the 10 1GB chunks at a time in parallel` \
  --download-threads=10 --download-chunk-size-mb=1000 \
  `# Also download name translations from wikidata` \
  --fetch-wikidata \
  `# Set Zoom level` \
  --minzoom=0 \
  --maxzoom=10 \
  --output=planet.mbtiles \
  `# Store temporary node locations at fixed positions in a memory-mapped file` \
  --nodemap-type=array --storage=mmap
# Keep track of intermediate time
now=$(date +"%T")
echo "Time: $now"
# Convert Daylight Planet to MBTiles (zoom levels 11-14)
java -Xmx30g \
  -jar planetiler.jar \
  `# Use downloaded Daylight Planet, set bounds` \
  --osm-path=/data/planet.osm.pbf --polygon=/home/ubuntu/Simplified10.poly \
  `# Set Zoom level` \
  --minzoom=11 \
  --maxzoom=14 \
  --output=zoom.mbtiles \
  `# Store temporary node locations at fixed positions in a memory-mapped file` \
  --nodemap-type=array --storage=mmap
# Keep track of intermediate time
now=$(date +"%T")
echo "Time: $now"
# Consolidate MBTiles
tilelive-copy --minzoom=11 --maxzoom=14 zoom.mbtiles tile.mbtiles
tilelive-copy --minzoom=0 --maxzoom=10 --bounds=$PLANET_BOUNDS planet.mbtiles tile.mbtiles
# Keep track of intermediate time
now=$(date +"%T")
echo "Time: $now"
# Convert to PMTiles
./pmtiles convert tile.mbtiles tile.pmtiles
# Keep track of intermediate time
now=$(date +"%T")
echo "Time: $now"
# Save to output bucket
export AWS_ACCESS_KEY_ID=$BUCKET_ACCESS_KEY_ID
export AWS_DEFAULT_REGION=$BUCKET_DEFAULT_REGION
export AWS_SECRET_ACCESS_KEY=$BUCKET_SECRET_ACCESS_KEY
if [ "" == "$BUCKET_ENDPOINT" ]; then
  BUCKET_ENDPOINT="https://s3.${BUCKET_DEFAULT_REGION}.amazonaws.com"
fi;
BUCKET_NAME_TILE=tile-$(date +%Y%m%d%H%M%S)
aws s3api create-bucket --bucket $BUCKET_NAME_TILE --endpoint-url $BUCKET_ENDPOINT
aws s3 cp --only-show-errors /data/tile.pmtiles --endpoint-url $BUCKET_ENDPOINT s3://$BUCKET_NAME_TILE/
# Keep track of completion time
now=$(date +"%T")
echo "Process Script Completed: $now"
