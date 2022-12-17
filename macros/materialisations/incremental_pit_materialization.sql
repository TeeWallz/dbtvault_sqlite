{%- materialization pit_incremental, adapter='sqlite' -%}

  {%- set full_refresh_mode = should_full_refresh() -%}

  {% if target.type == "sqlserver" %}
      {%- set target_relation = this.incorporate(type='table') -%}
  {%  else %}
      {%- set target_relation = this -%}
  {% endif %}
  {%- set existing_relation = load_relation(this) -%}
  {%- set tmp_relation = make_temp_relation(target_relation) -%}

  {{ run_hooks(pre_hooks, inside_transaction=False) }}

  -- `BEGIN` happens here:
  {{ run_hooks(pre_hooks, inside_transaction=True) }}

  {%- set to_drop = [] -%}
  {%- if existing_relation is none -%}
      {%- set build_sql = create_table_as(False, target_relation, sql) -%}
  {%- elif existing_relation.is_view or full_refresh_mode -%}
      {#-- Make sure the backup doesn't exist so we don't encounter issues with the rename below #}
      {%- set backup_identifier = existing_relation.identifier ~ "__dbt_backup" -%}
      {%- set backup_relation = existing_relation.incorporate(path={"identifier": backup_identifier}) -%}
      {%- do adapter.drop_relation(backup_relation) -%}

      {%- do adapter.rename_relation(target_relation, backup_relation) -%}
      {%- set build_sql = create_table_as(False, target_relation, sql) -%}
      {%- do to_drop.append(backup_relation) -%}
  {%- else -%}

      {%- set tmp_relation = make_temp_relation(target_relation) -%}
      {%- do run_query(create_table_as(True, tmp_relation, sql)) -%}
      {%- do adapter.expand_target_column_types(
             from_relation=tmp_relation,
             to_relation=target_relation) -%}
      
      {# SQLite is unable to perform multiple statements in a single execute. Split these if required. #}
      {# This split could be done for all adaptors, however this is just a small change for now as to not effect the others. #}
      {% if target.type == "sqlite" %}
          {%- set build_sql = incremental_pit_truncate(tmp_relation, target_relation) -%}
          {%- set build_sql_insert = incremental_pit_insert(tmp_relation, target_relation) -%}
      {%  else %}
          {%- set build_sql = dbtvault.incremental_pit_replace(tmp_relation, target_relation) -%}
      {% endif %}
      
{%- endif -%}

  {%- call statement("main") -%}
      {{ build_sql }}
  {%- endcall -%}

  {% if build_sql_insert is defined %}
      {%- call statement("main") -%}
          {{ build_sql_insert }}
      {%- endcall -%}
  {% endif %}
  

  {{ run_hooks(post_hooks, inside_transaction=True) }}

  -- `COMMIT` happens here
  {%- do adapter.commit() -%}

  {%- for rel in to_drop -%}
      {%- do adapter.drop_relation(rel) -%}
  {%- endfor -%}

  {{ run_hooks(post_hooks, inside_transaction=False) }}

  {{ return({'relations': [target_relation]}) }}

{%- endmaterialization -%}