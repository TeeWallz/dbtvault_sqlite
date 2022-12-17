{% macro incremental_pit_truncate(tmp_relation, target_relation, statement_name="main") %}
    {%- set dest_columns = adapter.get_columns_in_relation(target_relation) -%}
    {%- set dest_cols_csv = dest_columns | map(attribute='quoted') | join(', ') -%}

    DELETE FROM {{ target_relation }};
{%- endmacro %}

{% macro incremental_pit_insert(tmp_relation, target_relation, statement_name="main") %}
    {%- set dest_columns = adapter.get_columns_in_relation(target_relation) -%}
    {%- set dest_cols_csv = dest_columns | map(attribute='quoted') | join(', ') -%}

    INSERT INTO {{ target_relation }} ({{ dest_cols_csv }})
       SELECT {{ dest_cols_csv }}
       FROM {{ tmp_relation }}
    ;
{%- endmacro %}