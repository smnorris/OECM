with designations as
(select
        designations_planarized_id,
        unnest(designation) as designation,
        unnest(source_id) as source_id,
        forest_restriction_max,
        mine_restriction_max,
        og_restriction_max,
        geom
from designations_planarized
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
)

select 
  designations_planarized_id,
  array_to_string(array_agg(distinct act), ';') as acts
from all_acts 
group by designations_planarized_id