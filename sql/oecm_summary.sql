with areas as
(
  select
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
    round((sum(st_area(geom)) / 10000)::numeric, 2) as area_ha
  from oecm
  group by
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
    acts
)

select
  designation,
  forest_restriction_max,
  mine_restriction_max,
  og_restriction_max,
  acts,
  sum_restriction,
  area_ha
from areas
where area_ha > 100;