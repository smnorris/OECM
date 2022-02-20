-- load source polygons for given tile
WITH tile AS
(
  select
    map_tile,
    geom
  from tiles
  where map_tile = :'tile'
),

src_a AS
(
  SELECT
    src.adm_nr_region_id,
    t.map_tile,
    CASE 
      WHEN ST_CoveredBy(src.geom, t.geom) THEN st_multi(src.geom)
      ELSE ST_Multi(ST_Intersection(src.geom, t.geom))
    END as geom
  FROM adm_nr_regions_sp src
  INNER JOIN tile t
  ON st_intersects(src.geom, t.geom)
),

src_b AS
(
  SELECT
    src.cef_id,
    t.map_tile,
    CASE 
      WHEN ST_CoveredBy(src.geom, t.geom) THEN st_multi(src.geom)
      ELSE ST_Multi(ST_Intersection(src.geom, t.geom))
    END as geom
  FROM cef_human_disturbance src
  INNER JOIN tile t
  ON st_intersects(src.geom, t.geom)
),

src_c AS
(

  SELECT
    src.designations_planarized_id,
    src.map_tile,
    st_multi(src.geom) as geom
  FROM designations_planarized src
  inner join tile t
  on src.map_tile = t.map_tile
),

-- put them together
src_all AS 
(
  select map_tile, (st_dump(geom)).geom from src_a
  union all 
  select map_tile, (st_dump(geom)).geom from src_b
  union all
  select map_tile, (st_dump(geom)).geom from src_c
),

-- dump poly rings and convert to lines
rings as
(
  SELECT
    map_tile,
    ST_Exteriorring((ST_DumpRings(geom)).geom) AS geom
  FROM src_all
),

-- node the lines with st_union and dump to singlepart lines
lines as
(
  SELECT
    map_tile,
    (st_dump(st_union(geom, .1))).geom as geom
  FROM rings
  GROUP BY map_tile
),

-- polygonize the resulting noded lines
flattened AS
(
  SELECT
    map_tile,
    (ST_Dump(ST_Polygonize(geom))).geom AS geom
  FROM lines
  GROUP BY map_tile
)

-- get the attributes and insert into output
INSERT INTO oecm_nrr_cef (
  designations_planarized_id,
  adm_nr_region_id,
  cef_id,
  map_tile,
  geom
)
SELECT
  c.designations_planarized_id,
  a.adm_nr_region_id,
  b.cef_id,
  f.map_tile,
  f.geom
FROM flattened f
LEFT OUTER JOIN adm_nr_regions_sp a
ON ST_Contains(a.geom, ST_PointOnSurface(f.geom))
LEFT OUTER JOIN cef_human_disturbance b
ON ST_Contains(b.geom, ST_PointOnSurface(f.geom))
LEFT OUTER JOIN designations_planarized c
ON ST_Contains(c.geom, ST_PointOnSurface(f.geom));