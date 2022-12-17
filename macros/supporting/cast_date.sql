{%- macro sqlite__cast_date(column_str, as_string=false, datetime=false, alias=none) -%}

    {{ dbtvault.snowflake__cast_date(column_str=column_str, as_string=as_string, datetime=datetime, alias=alias)}}

{%- endmacro -%}