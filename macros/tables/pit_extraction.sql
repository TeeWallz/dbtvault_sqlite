{%- macro pit_extraction(hub, pk, pit, satellites) -%}

{{- dbtvault.check_required_parameters(hub=hub,
                                        pk=pk,
                                        pit=pit,
                                        satellites=satellites) -}}

{{ "-- depends_on: " ~ ref(hub) -}}
{{ "-- depends_on: " ~ ref(pit) -}}

{%- for sat_name in satellites %}
{{ "-- depends_on: " ~ ref(sat_name) -}}
{%- endfor -%}

{{"\n"}}

WITH hub as (
    select * from {{ ref(hub) }}
),
pit as (
    select * from {{ ref(pit) }}
),
{% for sat_name in satellites -%}
{{ sat_name }} as (
    select * from {{ ref(sat_name) }}
){{- ',\n' -}}
{% endfor -%}


final as (
    select
        hub.{{pk}},
        {% for sat_name in satellites -%}
        {%- set suffix = satellites[sat_name]['suffix'] -%}
        {% for field in satellites[sat_name]['fields'] -%}
        {%- set field_name = field if field is string else (field.keys() | list)[0] -%}
        {%- set alias = field ~ suffix if field is string else (field.values() | list)[0] -%}
        {{sat_name ~ '.' ~ field_name ~ ' as ' ~ alias}}{{- ',' }}
        {% endfor -%}
        {% endfor -%}
        1
    from
        hub
        join
            pit
            on
                hub.{{ pk }} = pit.{{ pk }}
            {% for sat_name in satellites -%}
            {{'                ' if not loop.last}}
            left join
                {{ sat_name }} 
                    on 
                        pit.{{ pk }} = {{ sat_name }}.{{ pk }} and
                        pit.{{ sat_name }}_LDTS = {{ sat_name }}.{{ satellites[sat_name]['LDTS'] }}
            {% endfor -%}
{{- '\n' -}}
)
select
*
from
final

{%- endmacro -%}


