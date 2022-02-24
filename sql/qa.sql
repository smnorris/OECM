# total area comparison
select sum(st_area(geom)) from oecm;                   
select sum(st_area(geom)) from oecm_nrr_cef_subgroups; 
select sum(st_area(geom)) from oecm_nrr_cef_groups;    

# where are the differences?
with cef as
(
select 
  designations_planarized_id,
  sum(st_area(geom)) as area
from oecm_nrr_cef_subgroups
group by designations_planarized_id
)
select
  a.designations_planarized_id,
  abs(st_area(a.geom) - b.area) as difference
from oecm a
inner join cef b
on a.designations_planarized_id = b.designations_planarized_id
order by abs(st_area(a.geom) - b.area) desc;