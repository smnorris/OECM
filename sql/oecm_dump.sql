-- add acts to oecm designations

drop table if exists oecm;

create table oecm as

with designations as
(
  select
    designations_planarized_id,
    unnest(designation) as designation,
    unnest(source_id) as source_id,
    forest_restriction_max,
    mine_restriction_max,
    og_restriction_max,
    geom
  from designations_planarized
  order by designations_planarized_id
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
)

select
  a.designations_planarized_id,
  array_to_string(designation, ';') as designation,
  array_to_string(source_id, ';') as source_id,
  array_to_string(source_name, ';') as source_name,
  array_to_string(forest_restrictions, ';') as forest_restrictions,
  array_to_string(mine_restrictions, ';') as mine_restrictions,
  array_to_string(og_restrictions, ';') as og_restrictions,
  a.forest_restriction_max,
  a.mine_restriction_max,
  a.og_restriction_max,
  (a.forest_restriction_max + a.mine_restriction_max + a.og_restriction_max) as sum_restriction,
  c.acts,
  map_tile,
  geom
from designations_planarized a
left outer join positions b
on a.designations_planarized_id = b.designations_planarized_id
left outer join distinct_acts c
on a.designations_planarized_id = c.designations_planarized_id;

create index on oecm (designations_planarized_id);
create index on oecm using gist (geom);




-- -----------------------------------
-- oecm validation plus NRR and CEF
-- -----------------------------------

drop table if exists oecm_nrr_cef;

create table oecm_nrr_cef as

with positions as
(
  select
    designations_planarized_id,
    array_position(designation, 'nr_region') as nr_position,
    array_position(designation, 'cef_human_disturbance') as cef_position
  from designations_planarized_oecm_nrr_cef
  order by designations_planarized_id
),

designations as
(
  select
    designations_planarized_id,
    unnest(designation) as designation,
    unnest(source_id) as source_id,
    forest_restriction_max,
    mine_restriction_max,
    og_restriction_max,
    geom
  from designations_planarized_oecm_nrr_cef
  order by designations_planarized_id
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
)

select
  a.designations_planarized_id,
  array_to_string(array_remove(array_remove(designation, 'cef_human_disturbance'), 'nr_region'), ';') as designations,
  array_to_string(array_remove(array_remove(source_id, source_id[b.cef_position]), source_id[b.nr_position]), ';') as source_id,
  array_to_string(array_remove(array_remove(source_name, source_name[b.cef_position]), source_name[b.nr_position]), ';') as source_name,
  array_to_string(array_remove(array_remove(forest_restrictions, forest_restrictions[b.cef_position]), forest_restrictions[b.nr_position]), ';') as forest_restrictions,
  array_to_string(array_remove(array_remove(mine_restrictions, mine_restrictions[b.cef_position]), mine_restrictions[b.nr_position]), ';') as mine_restrictions,
  array_to_string(array_remove(array_remove(og_restrictions, og_restrictions[b.cef_position]), og_restrictions[b.nr_position]), ';') as og_restrictions,
  a.forest_restriction_max,
  a.mine_restriction_max,
  a.og_restriction_max,
  (a.forest_restriction_max + a.mine_restriction_max + a.og_restriction_max) as sum_restriction,
  c.acts,
  case when designation && ARRAY['nr_region'] then source_name[b.nr_position] end as nr_region,
  case when designation && ARRAY['cef_human_disturbance'] then source_name[b.cef_position] end as cef_human_disturbance,
  case when designation && ARRAY['cef_human_disturbance'] then cef.cef_disturb_sub_group,
  map_tile,
  geom
from designations_planarized_oecm_nrr_cef a
left outer join positions b
on a.designations_planarized_id = b.designations_planarized_id
left outer join distinct_acts c
on a.designations_planarized_id = c.designations_planarized_id
left outer join src_40_cef_human_disturbance cef
on a.source_id[b.cef_position]::integer = cef.ogc_fid;

create index on oecm_nrr_cef (designations_planarized_id);
create index on oecm_nrr_cef using gist (geom);