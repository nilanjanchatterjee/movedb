library(sf)
library(geojsonsf)
library(tidyverse)

data_df <- readRDS("Final_summary_data_1005.rds")
data_df1 <- readRDS("data_mammal_taxclean_2.rds")


data_df_exp <- data_df |> 
  mutate(Latitude_reported = as.character(Latitude_reported),
         Longitude_reported = as.character(Longitude_reported)) |> # --- Split semicolon-separated values into multiple rows ---
  separate_rows(Latitude_reported, Longitude_reported, sep = ";") |>       # Split & expand into multiple rows
  mutate(lat = as.numeric(Latitude_reported),
         long = as.numeric(Longitude_reported))        # Convert back to numeric after splitting

data_df_loc_filter <- data_df_exp |> filter(!is.na(lat) & !is.na(long)) |>
  select(c(Title, DOI, `Publication Year`, `Sample Size`, Location, lat, long, species_ncbi)) |>
  st_as_sf(coords = c("long", "lat"), crs =4326) 
names(data_df_loc_filter)[6] <- "species"
st_write(data_df_loc_filter, "study_df_new.geojson", driver="GeoJSON", append = TRUE)

###################################################################################
library(jsonlite)

# Read your geojson file
geojson_data <- readLines("./docs/study_df_new.geojson") |> paste(collapse = "\n")

# Inject it into the HTML template
html_content <- sprintf('
<!DOCTYPE html>
<html>
<html>
<head>
  <meta charset="utf-8">
  <title>Global Species Telemetry Research Database</title>

  <link rel="stylesheet" href="https://unpkg.com/leaflet/dist/leaflet.css"/>
  <link rel="stylesheet" href="https://unpkg.com/leaflet.markercluster/dist/MarkerCluster.css"/>

  <link href="https://cdn.jsdelivr.net/npm/bootstrap@5.3.0/dist/css/bootstrap.min.css" rel="stylesheet">

  <style>
    #map { height: 70vh; }
  </style>
</head>

<body>

<div class="container mt-4 text-center">
  <h1>Global GPS telemetry Studies database</h1>
  <p>
    An open-access spatial database of published species studies across the globe that have used Global Positioning System (GPS) telemetry.
  </p>
  <p> The database currently consists only the mammalian taxa but we are planning to include other taxa in future. 
  </p>
</div>

<div id="map"></div>

<div class="container text-center mt-4">

  <a href="introduction.html" class="btn btn-primary m-2">About</a>
  <a href="explorer.html" class="btn btn-primary m-2">Explore Data</a>
  <a href="resources.html" class="btn btn-primary m-2">Methods</a>
  <a href="add-a-map.html" class="btn btn-primary m-2">Add your data</a>
  <a href="https://github.com/nilanjanchatterjee" class="btn btn-outline-dark m-2">GitHub</a>

</div>

<script src="https://unpkg.com/leaflet/dist/leaflet.js"></script>
<!-- MarkerCluster Plugin -->
  <link rel="stylesheet" href="https://unpkg.com/leaflet.markercluster/dist/MarkerCluster.css"/>
  <link rel="stylesheet" href="https://unpkg.com/leaflet.markercluster/dist/MarkerCluster.Default.css"/>
  <script src="https://unpkg.com/leaflet.markercluster/dist/leaflet.markercluster.js"></script>

<script>

<head>
  <link rel="stylesheet" href="https://unpkg.com/leaflet/dist/leaflet.css"/>
  <script src="https://unpkg.com/leaflet/dist/leaflet.js"></script>
  <style> #map { height: 800px; width: 100%%; } </style>
</head>
<body>
  <div id="map"></div>
  <script>
    var geojsonData = %s;   // ← GeoJSON injected by R here
    
    // --- Base map ---
    var map = L.map("map").setView([0, 0], 8);
    L.tileLayer("https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png", {
      attribution: "© OpenStreetMap contributors"
    }).addTo(map);


    // --- Create cluster group ---
    var clusterGroup = L.markerClusterGroup({
      // How many pixels radius to cluster within
      maxClusterRadius: 50,

      // Cluster appearance by count
      iconCreateFunction: function(cluster) {
        var count = cluster.getChildCount();
        var size, color;

        if (count < 10) {
          size = 30; color = "#4CAF50";        // Small  → Green
        } else if (count < 50) {
          size = 40; color = "#FF9800";        // Medium → Orange
        } else if (count < 100) {
          size = 50; color = "#F44336";        // Large  → Red  
        } else {
          size = 60; color = "#6E1604";        // Very Large  → Brown
        }

        return L.divIcon({
          html: `<div style="
            background-color: ${color};
            width: ${size}px;
            height: ${size}px;
            border-radius: 50%%;
            border: 3px solid white;
            box-shadow: 0 2px 6px rgba(0,0,0,0.4);
            display: flex;
            align-items: center;
            justify-content: center;
            color: white;
            font-weight: bold;
            font-size: 13px;
            font-family: Arial, sans-serif;
          ">${count}</div>`,
          className: "",
          iconSize: [size, size]
        });
      },

      // Zoom into cluster on click
      zoomToBoundsOnClick: true,

      // Show coverage area on hover
      showCoverageOnHover: true,

      // Fully expand cluster at this zoom level
      disableClusteringAtZoom: 16
    });

    // --- Add GeoJSON points into the cluster group ---
    L.geoJSON(geojsonData, {
      pointToLayer: function(feature, latlng) {
        return L.circleMarker(latlng, {
          radius      : 8,
          fillColor   : "#2196F3",
          color       : "#fff",
          weight      : 2,
          opacity     : 1,
          fillOpacity : 0.9
        });
      },
      onEachFeature: function(feature, layer) {
        if (feature.properties) {
          // Build popup from all available properties
          var popupContent = Object.entries(feature.properties)
            .map(([k, v]) => `<b>${k}:</b> ${v}`)
            .join("<br>");
          layer.bindPopup(popupContent);
        }
      }
    }).addTo(clusterGroup);   // ← Add to clusterGroup, NOT directly to map

    // Add the cluster group to the map
    clusterGroup.addTo(map);

    // Auto-fit map to all points
    if (clusterGroup.getLayers().length > 0) {
      map.fitBounds(clusterGroup.getBounds(), { padding: [30, 30] });
    }
  </script>
</body>
</html>
', geojson_data)

# Save the final HTML
writeLines(html_content, "docs/index.html")

# Preview in browser
rstudioapi::viewer("map_output.html")   # Quick preview in RStudio
browseURL("map_output.html")            # Opens in your default browser
