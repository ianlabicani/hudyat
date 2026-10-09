[out:json][timeout:240];
area["ISO3166-2"="PH-00"]->.ncr;
rel(area.ncr)["boundary"="administrative"]["admin_level"="6"];
map_to_area->.cities;
foreach.cities->.c(
  .c out tags;
  (
    nwr["amenity"~"^(hospital|clinic|doctors|pharmacy|police|fire_station)$"](area.c);
    nwr["emergency"="assembly_point"](area.c);
    nwr["social_facility"="shelter"](area.c);
  );
  out center tags;
);
