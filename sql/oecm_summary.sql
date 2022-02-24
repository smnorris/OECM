select
  designation,
  forest_restriction_max,
  mine_restriction_max,
  og_restriction_max,
  sum_restriction,
  acts,
  round((sum(st_area(geom)) / 10000)::numeric, 2) as area_ha
from oecm
group by
  designation,
  forest_restriction_max,
  mine_restriction_max,
  og_restriction_max,
  sum_restriction,
  acts
order by designation
