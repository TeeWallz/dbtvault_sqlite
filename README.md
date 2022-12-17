<div align="center">
  <img src=".github/images/logo.png" alt="dbtvault">
</div>

# [dbtvault](https://github.com/Datavault-UK/dbtvault) for SQLite

## Please note that this plugin is currently very early in development

This plugin allows for some dbtvault features to be used on an SQLIte database.

It uses the SQLIte DBT adapter via the Python Module [dbt-sqlite](https://github.com/codeforkjeff/dbt-sqlite)

It currently supports he following dbtvault versions
* 0.9.0
* 0.9.1


# How to Use This

In order to to use **dbtvault for for SQLite**, install [dbt-sqlite](https://github.com/codeforkjeff/dbt-sqlite) in the same environment as your dbt project and be sure to create an entry in your `~/.dbt/profiles.yml`, with `type: sqlite` as per the documentation.

Include this package in your `packages.yml` file. Soon this will support teh `package` tag, but not for now!
```
 packages:
   - git: https://github.com/TeeWallz/dbtvault_sqlite.git
     version: 0.0.1
```




# Supported Features

| Macro/Template | Snowflake                                     |
|----------------|-----------------------------------------------|
| hash           | :heavy_check_mark:                            |
| stage          | :heavy_check_mark:                            |
| hub            | :heavy_check_mark:                            |
| link           | :heavy_check_mark:                            |
| sat            | :heavy_check_mark:                            |
| t_link         | :x:                                           |
| eff_sat        | :x:                                           |
| ma_sat         | :x:                                           |
| xts            | :x:                                           |
| pit            | :heavy_check_mark:                            |
| bridge         | :x:                                           |


# New Feature because I use it a lot

## pit_extraction
Allows for the joining and extraction of Satellites obtained from a PIT. Whilst a PIT can provides the PK and LDTS of the Satellite, there is no mechanism to obtain the daya from Satellites via a macro.

Please note that this Macro is under development and may not work in all cases yet. No doubt there is a better way of doing this.

Example:
```
{{ config(materialized='table') }}

{%- set yaml_metadata -%}
pit: pit__torrent__current
pk: TORRENT_SID
hub:
  hub__torrent
satellites: 
  sat__torrent__rss_feeds__attributes:
    suffix: _rss
    LDTS: LOAD_DATE_TIME
    fields:
      - media_bk
      - torrent_file_size
      - title
      - site_url
      - site
      - download_torrent_url
      - uploader_bk
      - published_date
      - LOAD_DATE_TIME
  sat__torrent__rss_feeds__measures:
    suffix: _rss
    LDTS: LOAD_DATE_TIME
    fields:
      - seeders
      - leechers
      - downloads_completed

{%- endset -%}

{% set metadata_dict = fromyaml(yaml_metadata) %}

{% set hub = metadata_dict['hub'] %}
{% set pit = metadata_dict['pit'] %}
{% set pk = metadata_dict['pk'] %}
{% set satellites = metadata_dict['satellites'] %}

{{ pit_extraction(hub=hub,
                pk=pk,
                pit=pit,
                satellites=satellites
) }}
```

Result:
```
WITH hub as (
    select * from main."hub__torrent"
),
pit as (
    select * from main."pit__torrent__current"
),
sat__torrent__rss_feeds__attributes as (
    select * from main."sat__torrent__rss_feeds__attributes"
),
sat__torrent__rss_feeds__measures as (
    select * from main."sat__torrent__rss_feeds__measures"
),
final as (
    select
        hub.TORRENT_SID,
        hub.TORRENT_BK,
        sat__torrent__rss_feeds__attributes.media_bk as media_bk_rss,
        sat__torrent__rss_feeds__attributes.torrent_file_size as torrent_file_size_rss,
        sat__torrent__rss_feeds__attributes.title as title_rss,
        sat__torrent__rss_feeds__attributes.site_url as site_url_rss,
        sat__torrent__rss_feeds__attributes.site as site_rss,
        sat__torrent__rss_feeds__attributes.download_torrent_url as download_torrent_url_rss,
        sat__torrent__rss_feeds__attributes.uploader_bk as uploader_bk_rss,
        sat__torrent__rss_feeds__attributes.published_date as published_date_rss,
        sat__torrent__rss_feeds__attributes.LOAD_DATE_TIME as LOAD_DATE_TIME_rss,
        sat__torrent__rss_feeds__measures.seeders as seeders_rss,
        sat__torrent__rss_feeds__measures.leechers as leechers_rss,
        sat__torrent__rss_feeds__measures.downloads_completed as downloads_completed_rss,
        1
    from
        hub
        join
            pit
            on
                hub.TORRENT_BK = pit.TORRENT_BK
                            
            left join
                sat__torrent__rss_feeds__attributes 
                    on 
                        pit.TORRENT_BK = sat__torrent__rss_feeds__attributes.TORRENT_BK and
                        pit.sat__torrent__rss_feeds__attributes_LDTS = sat__torrent__rss_feeds__attributes.LOAD_DATE_TIME
                            
            left join
                sat__torrent__rss_feeds__measures 
                    on 
                        pit.TORRENT_BK = sat__torrent__rss_feeds__measures.TORRENT_BK and
                        pit.sat__torrent__rss_feeds__measures_LDTS = sat__torrent__rss_feeds__measures.LOAD_DATE_TIME            
)
select
*
from
final
```