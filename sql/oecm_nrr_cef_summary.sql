with designations as
(
    select
        designations_planarized_id,
        unnest(designation) as designation,
        unnest(source_id) as source_id,
        unnest(source_name) as source_name,
        forest_restriction_max,
        mine_restriction_max,
        og_restriction_max,
        geom
    from designations_planarized_oecm_nrr_cef
),

-- extract disturbance into new columns
disturbance as
(
    select
        designations_planarized_id,
        source_name as cef_human_disturbance,
        cef_disturb_sub_group
    from designations d
    inner join src_40_cef_human_disturbance cef
    on d.source_id::integer = cef.ogc_fid
    where d.designation = 'cef_human_disturbance'
),

-- extract nr region into new column
region as
(
    select
        designations_planarized_id,
        source_name as nr_region
    from designations
    where designation = 'nr_region'
),

all_acts as
(
  select
      designations_planarized_id,
      unnest(string_to_array(trim(replace(replace(replace(replace(coalesce(ol.associated_act_name, '')       || ' ' ||
      coalesce(onl.associated_act_name, '')    || ' ' ||
      coalesce(uwrnh.legislation_act_name, '') || ' ' ||
      coalesce(whanh.legislation_act_name, '') || ' ' ||
      coalesce(uwrch.legislation_act_name, '') || ' ' ||
      coalesce(whach.legislation_act_name, ''), 'ForestRangePracticesAct', 'FRPA'), 'OilGasActivitiesAct', 'OGAA'), ':', ' '), ';', ' ')), ' ')) as act
  from designations d
  left outer join src_08_ogma_legal ol
  on d.source_id::integer = ol.legal_ogma_internal_id
  and d.designation = 'ogma_legal'
  left outer join src_09_ogma_non_legal onl
  on d.source_id::integer = onl.non_legal_ogma_internal_id
  and d.designation = 'ogma_non_legal'
  left outer join src_03_uwr_no_harvest uwrnh
  on d.source_id::integer = uwrnh.ungulate_winter_range_id
  and d.designation = 'uwr_no_harvest'
  left outer join src_04_wha_no_harvest whanh
  on d.source_id::integer = whanh.habitat_area_id
  and d.designation = 'wha_no_harvest'
  left outer join src_20_uwr_conditional_harvest uwrch
  on d.source_id::integer = uwrch.ungulate_winter_range_id
  and d.designation = 'uwr_conditional_harvest'
  left outer join src_21_wha_conditional_harvest whach
  on d.source_id::integer = whach.habitat_area_id
  and d.designation = 'wha_conditional_harvest'
  where designation in ('ogma_legal', 'ogma_non_legal','uwr_no_harvest','uwr_conditional_harvest','wha_no_harvest','wha_conditional_harvest')
),

distinct_acts as
(
  select
    designations_planarized_id,
    array_to_string(array_agg(distinct act), ';') as acts
  from all_acts
  group by designations_planarized_id
),

max_restrictions as
(
  select
    d.designations_planarized_id,
    array_remove(array_remove(array_agg(distinct d.designation),'nr_region'), 'cef_human_disturbance') as designations,
    r.nr_region,
    ds.cef_human_disturbance,
    ds.cef_disturb_sub_group,
    d.forest_restriction_max,
    d.mine_restriction_max,
    d.og_restriction_max,
    da.acts,
    d.geom
  from designations d
  left outer join distinct_acts da
  on d.designations_planarized_id = da.designations_planarized_id
  left outer join region r
  on d.designations_planarized_id = r.designations_planarized_id
  left outer join disturbance ds
  on d.designations_planarized_id = ds.designations_planarized_id
  group by
    d.designations_planarized_id,
    r.nr_region,
    ds.cef_human_disturbance,
    ds.cef_disturb_sub_group,
    d.forest_restriction_max,
    d.mine_restriction_max,
    d.og_restriction_max,
    da.acts,
    d.geom
),

areas as
(
  select
    array_to_string(designations, '; ') as designations,
    nr_region,
    cef_human_disturbance,
    cef_disturb_sub_group,
    forest_restriction_max,
    mine_restriction_max,
    og_restriction_max,
    acts,
    round((sum(st_area(geom)) / 10000)::numeric, 6) as area_ha
  from max_restrictions
  group by
    designations,
    nr_region,
    cef_human_disturbance,
    cef_disturb_sub_group,
    forest_restriction_max,
    mine_restriction_max,
    og_restriction_max,
    acts
),

total_per_designation as
(
  select
    designations,
    nr_region,
    sum(area_ha) as designation_area_ha
  from areas
  group by designations, nr_region
)

select
  a.designations,
  a.nr_region,
  a.cef_human_disturbance,
  a.cef_disturb_sub_group,
  a.forest_restriction_max,
  a.mine_restriction_max,
  a.og_restriction_max,
  a.acts,
  (a.forest_restriction_max + a.mine_restriction_max + a.og_restriction_max) as sum_restriction,
  t.designation_area_ha as designation_nrr_ha,
  round(((a.area_ha / t.designation_area_ha) * 100), 2) as designation_nrr_cef_pct,
  a.area_ha
from areas a
inner join total_per_designation t
on a.designations = t.designations and a.nr_region = t.nr_region
where a.area_ha > 0
order by designations;
