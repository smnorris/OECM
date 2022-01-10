-- summarize and score designations

select
  designations,
  forest_restriction_max,
  mine_restriction_max,
  og_restriction_max,
  (forest_restriction_max + mine_restriction_max + og_restriction_max) as sum_restriction,
  area_ha
from
(
  select
    array_to_string(designations, '; ') as designations,
    forest_restriction_max,
        mine_restriction_max,
        og_restriction_max,
    round((sum(st_area(geom)) / 10000)::numeric, 2) as area_ha
  from
  (
    select
      array_agg(distinct designation) as designations,
      forest_restriction_max,
        mine_restriction_max,
        og_restriction_max,
      geom
    from
    (
      select
        unnest(designation) as designation,
        forest_restriction_max,
        mine_restriction_max,
        og_restriction_max,
        geom
      from designations_planarized
      --where  st_area(geom) > 1000
    ) as f
    group by geom, forest_restriction_max,
        mine_restriction_max,
        og_restriction_max
  ) as b
  group by designations, forest_restriction_max,
        mine_restriction_max,
        og_restriction_max
) as baz
where area_ha > 100;
