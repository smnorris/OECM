with areas as
(
  select
    b.designation,
    b.source_id,
    b.source_name,
    b.forest_restrictions,
    b.mine_restrictions,
    b.og_restrictions,
    b.forest_restriction_max,
    b.mine_restriction_max,
    b.og_restriction_max,
    b.sum_restriction,
    b.acts,
    c.region_name as nr_region,
    d.cef_disturb_group_rank,
    d.cef_disturb_sub_group,
    round((sum(st_area(a.geom)) / 10000)::numeric, 2) as area_ha
  from oecm_nrr_cef a
  inner join oecm b on a.designations_planarized_id = b.designations_planarized_id
  left outer join adm_nr_regions_sp c on a.adm_nr_region_id = c.adm_nr_region_id
  left outer join cef_human_disturbance d on a.cef_id = d.cef_id
  --where a.map_tile = '092B053'
  group by
    b.designation,
    b.source_id,
    b.source_name,
    b.forest_restrictions,
    b.mine_restrictions,
    b.og_restrictions,
    b.forest_restriction_max,
    b.mine_restriction_max,
    b.og_restriction_max,
    b.sum_restriction,
    b.acts,
    c.region_name,
    d.cef_disturb_group_rank,
    d.cef_disturb_sub_group
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
  round(((a.area_ha / t.designation_area_ha) * 100), 2) as designation_nrr_cef_pct,
  a.area_ha
from areas a
inner join total_per_designation t
on a.designation = t.designation and a.nr_region = t.nr_region
where area_ha > 100;