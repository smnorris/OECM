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
        WHEN ST_CoveredBy(src.geom, t.geom) THEN src.geom
        ELSE ST_Intersection(src.geom, t.geom)
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
        WHEN ST_CoveredBy(src.geom, t.geom) THEN src.geom
        ELSE ST_Intersection(src.geom, t.geom)
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
      src.geom
    FROM oecm src
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
  where st_dimension(geom) = 2
),

-- node the lines with st_union and dump to singlepart lines
lines as
(
  SELECT
    map_tile,
    (st_dump(st_union(geom, .01))).geom as geom
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
INSERT INTO oecm_nrr_cef_subgroups (
    designations_planarized_id,
    adm_nr_region_id,
    cef_id,
    designation,
    source_id,
    source_name,
    forest_restrictions,
    mine_restrictions,
    og_restrictions,
    forest_restriction_max,
    mine_restriction_max,
    og_restriction_max,
    sum_restriction,
    acts,
    nr_region,
    cef_disturb_group,
    cef_disturb_group_rank,
    cef_disturb_sub_group,
    cef_disturb_sub_group_rank,
    map_tile,
    geom
)
SELECT
  c.designations_planarized_id,
  a.adm_nr_region_id,
  b.cef_id,
  c.designation,
  c.source_id,
  c.source_name,
  c.forest_restrictions,
  c.mine_restrictions,
  c.og_restrictions,
  c.forest_restriction_max,
  c.mine_restriction_max,
  c.og_restriction_max,
  c.sum_restriction,
  c.acts,
  a.region_name as nr_region,
  b.cef_disturb_group,
  b.cef_disturb_group_rank,
  b.cef_disturb_sub_group,
  b.cef_disturb_sub_group_rank,
  f.map_tile,
  f.geom
FROM flattened f
LEFT OUTER JOIN adm_nr_regions_sp a
ON ST_Contains(a.geom, ST_PointOnSurface(f.geom))
LEFT OUTER JOIN cef_human_disturbance b
ON ST_Contains(b.geom, ST_PointOnSurface(f.geom))
LEFT OUTER JOIN oecm c
ON ST_Contains(c.geom, ST_PointOnSurface(f.geom));