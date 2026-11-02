# Data Warehouse Naming Conventions

## 1. General Principles

* **Casing Standard**: Use `snake_case` (all lowercase with underscores) for all schemas, tables, views, columns, and foreign keys.
* **Clarity & Brevity**: Names must be self-explanatory and descriptive. Avoid ambiguous acronyms (e.g., use `player_name` instead of `ply_nm`).
* **Language**: All database identifiers must be in English.
* **Singular vs. Plural**:
  * **Dimension Tables**: Singular (`dim_team`, `dim_player`, `dim_venue`, `dim_date`) representing a single business entity.
  * **Fact Tables**: Plural or event-based (`fact_matches`, `fact_ball_deliveries`) representing repeated events or metrics.

---

## 2. Architecture & Schema Naming

| Layer | Schema Name | Purpose & Rule | Example |
| :--- | :--- | :--- | :--- |
| **Bronze** | `bronze` | Raw, ingested staging data. Text-heavy, immutable mirror of source files. | `bronze.crm_ipl_matches` |
| **Silver** | `silver` | Cleaned, typed, conformant, and deduplicated tables. | `silver.crm_ipl_matches` |
| **Gold** | `gold` | Production-ready dimensional model (Star Schema: facts and dimensions). | `gold.fact_matches`, `gold.dim_team` |

---

## 3. Table Naming Conventions

| Object Type | Prefix / Pattern | Rule | Examples |
| :--- | :--- | :--- | :--- |
| **Dimension** | `dim_<entity>` | Always singular noun describing entity. | `dim_player`, `dim_team`, `dim_date`, `dim_venue` |
| **Fact Table** | `fact_<event_or_process>` | Describes the business event or process. | `fact_matches`, `fact_ball_deliveries` |
| **Staging Table** | `<source>_<entity>` | Identifies the source system and raw data entity. | `crm_ipl_matches`, `crm_ipl_ball_by_ball` |
| **Bridge Table** | `bridge_<dim1>_<dim2>` | Used for many-to-many dimensional relationships. | `bridge_match_umpires` |
| **View** | `vw_<entity>` | Virtual abstraction for reporting or layer interfaces. | `vw_player_career_stats` |

---

## 4. Column Naming Conventions

### 4.1. Primary & Surrogate Keys
* **Surrogate Key (Dimensions)**: Always suffixed with `_key`. Data type: `INT IDENTITY(1,1)` or smart integer (`YYYYMMDD`).
  * `player_key`, `team_key`, `venue_key`, `date_key`
* **Natural / Business Key**: Always suffixed with `_id` from source system.
  * `match_id`, `delivery_id`

### 4.2. Foreign Keys
* Foreign keys in fact tables **must exactly match** the surrogate key of the referenced dimension table.
  * In `gold.fact_matches`: `venue_key` &rarr; references `gold.dim_venue(venue_key)`
  * In `gold.fact_matches`: `date_key` &rarr; references `gold.dim_date(date_key)`
  * **Role-Playing Foreign Keys**: If a dimension is referenced multiple times, prefix with the role:
    * `team1_key`, `team2_key`, `toss_winner_key`, `winner_key` (all referencing `dim_team`)
    * `batter_key`, `bowler_key`, `non_striker_key`, `player_dismissed_key` (all referencing `dim_player`)

### 4.3. Data Types & Column Prefixes/Suffixes

| Data Category | Prefix / Suffix Rule | Data Type | Examples |
| :--- | :--- | :--- | :--- |
| **Boolean Flags** | Prefix with `is_` or `has_` | `BIT` (`1` / `0`) | `is_boundary_4`, `is_boundary_6`, `is_wicket`, `is_dot_ball`, `is_powerplay`, `is_weekend`, `is_result` |
| **Counts / Quantities** | Suffix with `_count` or `_number` | `TINYINT` / `INT` | `wicket_count`, `ball_in_over`, `legal_ball_number` |
| **Metrics / Measures** | Suffix with `_runs` or metric name | `TINYINT` / `INT` | `batter_runs`, `extra_runs`, `total_runs`, `wides`, `noballs`, `byes`, `legbyes`, `penalty` |
| **Cumulative Metrics** | Suffix with `_so_far` or `_total` | `SMALLINT` / `INT` | `innings_runs_so_far`, `innings_wickets_so_far` |
| **Rates / Percentages** | Suffix with `_rate` or `_pct` | `DECIMAL(p, s)` | `current_run_rate`, `required_run_rate`, `economy_rate` |
| **Dates** | Suffix with `_date` | `DATE` | `match_date`, `full_date` |
| **Descriptions / Types** | Suffix with `_name`, `_kind`, `_type` | `VARCHAR` | `player_name`, `team_name`, `wicket_kind`, `match_type`, `season` |

---

## 5. Constraint & Index Naming Conventions

Use explicit, structured naming for all constraints to ensure readability in execution plans and error logs:

| Constraint Type | Pattern | Example |
| :--- | :--- | :--- |
| **Primary Key** | `PK_<schema>_<table_name>` | `PK_gold_fact_matches` |
| **Foreign Key** | `FK_<source_table>_<target_table>_<col>` | `FK_fact_matches_dim_venue_venue_key` |
| **Unique Constraint** | `UQ_<schema>_<table_name>_<col>` | `UQ_gold_dim_team_team_name` |
| **Default Constraint** | `DF_<table_name>_<col>` | `DF_fact_ball_deliveries_batter_runs` |
| **Non-Clustered Index** | `IX_<table_name>_<col>` | `IX_fact_ball_deliveries_batter_key` |

---

## 6. Stored Procedures & Functions

* **ETL Ingestion Procedures**: Use verb prefix `load_<layer_name>`.
  * `silver.load_silver`: Cleanses and transforms Bronze into Silver.
  * `gold.load_star_schema`: Transforms Silver into Gold Fact and Dimension tables.
* **Quality & Validation Procedures**: Use prefix `run_<task>`.
  * `silver.run_data_quality_checks`: Validates health and completeness assertions.
* **SQL Coding Standard**:
  * All SQL keywords written in **UPPERCASE** (`SELECT`, `INSERT`, `UPDATE`, `DELETE`, `JOIN`, `WHERE`, `GROUP BY`).
  * End every SQL statement with a semicolon `;`.
  * Avoid reserved words as column names; if necessary, wrap in brackets `[year]`.
