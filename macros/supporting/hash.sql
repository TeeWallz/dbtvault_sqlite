{%- macro sqlite__hash(columns, alias, is_hashdiff) -%}

{%- set hash = var('hash', 'MD5') -%}
{%- set concat_string = var('concat_string', '||') -%}
{%- set null_placeholder_string = var('null_placeholder_string', '^^') -%}

{#- Select hashing algorithm -#}
{#- * Store as TEXT affinity, as opposed to BLOB because: -#}
{#- * SQLite stores data as-is regardless of datatype, only the fields string display is changed -#}
{#- * Whilst TEXT can take slightly more disk space, the benefits of troubleshooting via TEXT vs random characters outwigh costs -#}
{%- if hash == 'MD5' -%}
    {%- set hash_alg = 'MD5' -%}
{%- elif hash == 'SHA' -%}
    {%- set hash_alg = 'SHA256' -%}
{%- else -%}
    {%- set hash_alg = 'MD5' -%}
{%- endif -%}

{#- Select hashing expression (left and right sides) -#}
{%- if hash_alg == 'MD5' -%}
    {%- set hash_expr_left = 'MD5(' -%}
    {%- set hash_expr_right = ')' -%}
{%- elif hash_alg == 'SHA256' -%}
    {%- set hash_expr_left = 'ENCODE(SHA256(CAST(' -%}
    {%- set hash_expr_right = " AS TEXT)), 'hex')" -%}
{%- endif -%}

{%- set standardise = "NULLIF(UPPER(TRIM(CAST([EXPRESSION] AS TEXT))), '')" -%}

{#- Alpha sort columns before hashing if a hashdiff -#}
{%- if is_hashdiff and dbtvault.is_list(columns) -%}
    {%- set columns = columns|sort -%}
{%- endif -%}

{#- If single column to hash -#}
{%- if columns is string -%}
    {%- set column_str = dbtvault.as_constant(columns) -%}
    {%- if dbtvault.is_expression(column_str) -%}
        {%- set escaped_column_str = column_str -%}
    {%- else -%}
        {%- set escaped_column_str = dbtvault.escape_column_names(column_str) -%}
    {%- endif -%}

    {{- "CAST(HEX(UPPER({}{}{}) AS TEXT) AS {}".format(hash_expr_left, standardise | replace('[EXPRESSION]', escaped_column_str), hash_expr_right, dbtvault.escape_column_names(alias)) | indent(4) -}}

{#- Else a list of columns to hash -#}
{%- else -%}
    {%- set all_null = [] -%}

    {%- if is_hashdiff -%}
        {{- "CAST(HEX(UPPER({}'{}'||".format(hash_expr_left, concat_string) | indent(4) -}}
    {%- else -%}
        {{- "CAST(HEX(UPPER({}NULLIF('{}'||".format(hash_expr_left, concat_string) | indent(4) -}}
    {%- endif -%}

    {%- for column in columns -%}

        {%- do all_null.append(null_placeholder_string) -%}

        {%- set column_str = dbtvault.as_constant(column) -%}
        {%- if dbtvault.is_expression(column_str) -%}
            {%- set escaped_column_str = column_str -%}
        {%- else -%}
            {%- set escaped_column_str = dbtvault.escape_column_names(column_str) -%}
        {%- endif -%}

        {{- "\nCOALESCE({}, '{}')".format(standardise | replace('[EXPRESSION]', escaped_column_str), null_placeholder_string) | indent(4) -}}
        {{- "||" if not loop.last -}}

        {%- if loop.last -%}

            {% if is_hashdiff %}
                {{- "\n){}) AS TEXT) AS {}".format(hash_expr_right, dbtvault.escape_column_names(alias)) -}}
            {%- else -%}
                {{- "\n), '{}'{}) AS TEXT) AS {}".format(all_null | join(""), hash_expr_right, dbtvault.escape_column_names(alias)) -}}
            {%- endif -%}
        {%- else -%}

            {%- do all_null.append(concat_string) -%}

        {%- endif -%}
    {%- endfor -%}

{%- endif -%}

{%- endmacro -%}