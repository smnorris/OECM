with areas as
(
  select
    designation,
    forest_restriction_max,
    mine_restriction_max,
    og_restriction_max,
    sum_restriction,
    acts,
    nr_region,
    cef_disturb_group_rank,
    cef_disturb_sub_group,
    round((sum(st_area(a.geom)) / 10000)::numeric, 2) as area_ha
  from oecm_nrr_cef a
  where designations_planarized_id is not null
  group by
    designation,
    forest_restriction_max,
    mine_restriction_max,
    og_restriction_max,
    sum_restriction,
    acts,
    nr_region,
    cef_disturb_group_rank,
    cef_disturb_sub_group
),

total_per_designation as
(
  select
    designation,
    nr_region,
    sum(area_ha) as designation_area_ha
  from areas
  group by designation, nr_region
)

select
  a.designation,
  a.forest_restriction_max,
  a.mine_restriction_max,
  a.og_restriction_max,
  a.acts,
  a.sum_restriction,
  a.nr_region,
  a.cef_disturb_group_rank,
  a.cef_disturb_sub_group,
  t.designation_area_ha as designation_nrr_ha,
  case 
    when t.designation_area_ha > 0 then round(((a.area_ha / t.designation_area_ha) * 100), 2) 
    else 0 
  end as designation_nrr_cef_pct,
  a.area_ha
from areas a
left outer join total_per_designation t
on a.designation = t.designation and a.nr_region = t.nr_region
where a.area_ha > 0;