# Modernizing Classic Data Warehousing with BigQuery

## Introduction

## Coach's Guides

- Challenge 1: Loading the source data
- Challenge 2: Staging tables
- Challenge 3: DBT for automation
- Challenge 4: Dimensional modeling
- Challenge 5: Business Intelligence
- Challenge 6: Access control
- Challenge 7: Notebooks for data scientists
- Challenge 8: Cloud Composer for orchestration
- Challenge 9: Monitoring the workflow

## Challenge 1: Loading the source data

### Notes & Guidance

Although most of this will be done through the UI by the participants, the following commands make it possible to run this challenge from the command line.

```shell
REGION=us-central1  
BQ_DATASET=raw
bq mk --location=$REGION -d $BQ_DATASET
```
  
Creating the BigLake connection:

```shell
CONN_ID=conn
bq mk --connection --location=$REGION --connection_type=CLOUD_RESOURCE $CONN_ID

SA_CONN=`bq show --connection --format=json $REGION.$CONN_ID | jq -r .cloudResource.serviceAccountId`

gcloud projects add-iam-policy-binding $GOOGLE_CLOUD_PROJECT --member="serviceAccount:$SA_CONN" \
    --role="roles/storage.objectViewer" --condition=None
```

Once the connection is created and has the proper permissions, you can then run the following SQL for the tables `person`, `sales_order_header` and `sales_order_detail` after updating the relevant bits.

```sql
CREATE OR REPLACE EXTERNAL TABLE raw.person
  WITH CONNECTION `$REGION.$CONN_ID`
  OPTIONS (
    format = "CSV",
    uris = ['gs://${PROJECT_ID}-landing/person/*.csv']
  );
```

Let participants explore the data from BigQuery so that they understand that they're applying table semantics to blobs (CSV files).

## Challenge 2: Staging tables

### Notes & Guidance

```shell
BQ_DATASET=curated
bq mk --location=$REGION -d $BQ_DATASET
```

See below for example solutions, note that there are multiple ways of achieving the same objective and participants are free to explore those.

```sql
CREATE TABLE curated.stg_person AS
  SELECT DISTINCT * EXCEPT(hobby, comments, birth_date, date_first_purchase),
  SAFE.PARSE_DATE("%FZ", birth_date) AS birth_date,
  SAFE.PARSE_DATE("%FZ", date_first_purchase) AS date_first_purchase
  FROM raw.person
```

```sql
CREATE TABLE curated.stg_sales_order_header AS
  SELECT DISTINCT * EXCEPT(comment, order_date, ship_date, due_date), 
    DATE(order_date) AS order_date, 
    DATE(ship_date) AS ship_date,
    DATE(due_date) AS due_date 
  FROM raw.sales_order_header
```

```sql
CREATE TABLE curated.stg_sales_order_detail AS
  SELECT DISTINCT * 
  FROM raw.sales_order_detail
```

The table `person` has one duplicate record for `business_entity_id` with the value `11751`. You can verify that there are no duplicate records for this table by either checking the total number of rows (must be **19972**) or by running the following query (result should be empty):

```sql
SELECT
  business_entity_id,
  COUNT(*) cnt
FROM
  `curated.stg_person`
GROUP BY
  business_entity_id
HAVING
  cnt > 1
```

Regarding the `null` columns; since many columns have sparse data, *sampling* through Data Profile or Data Preparation will mark *too* many columns as all `null`. Data Profile allows you to set the sampling percentage to 100%, so that's on option, however Data Preparation doesn't allow you to change the sampling percentage at the time of this writing. Alternatively a SQL query could be used to determine if a column has only `null` values; the `COUNT` function doesn't include `null` values, so any column with a count of `0` will contain only `null` values. See below for an attempt to do this holistically, although doing this only for the suspicious columns is probably more practical (unless someone would like to automate the generation of this, or an alternative query, for all columns using the *INFORMATION_SCHEMA*).

```sql
WITH COL_COUNTS AS (
  SELECT "business_entity_id" as col, COUNT(business_entity_id) cnt FROM raw.person
  UNION ALL
  SELECT "person_type" as col, COUNT(person_type) cnt FROM raw.person
  UNION ALL
  SELECT "name_style" as col, COUNT(name_style) cnt FROM raw.person
  UNION ALL
  SELECT "hobby" as col, COUNT(hobby) cnt FROM raw.person
  -- add all columns
) 
SELECT col from COL_COUNTS WHERE cnt = 0
```

See below for a dynamic version of an alternative query that achieves the same. Note that this is only for reference (you'll have to replace `$PROJECT_ID`, `$REGION`, `$DATASET` and `$TABLE` placeholders with proper values to be able to run it).

```sql
DECLARE column_names ARRAY<STRING>;
DECLARE count_sql STRING;
SET column_names = (
  SELECT
      ARRAY_AGG(column_name)
    FROM
      `$PROJECT_ID.region-$REGION.INFORMATION_SCHEMA.COLUMNS`
    WHERE 
    table_catalog = '$PROJECT_ID'
    AND table_schema = '$DATASET'
    AND table_name = '$TABLE'
);
SET count_sql = (
  SELECT "SELECT "|| STRING_AGG(DISTINCT "COUNT(" || column_name || ") AS " || column_name) || " FROM $DATASET.$TABLE" 
  FROM UNNEST(column_names) as column_name
);
EXECUTE IMMEDIATE FORMAT("""
  SELECT 
    column_name, cnt FROM (%s) 
  UNPIVOT (
    cnt FOR column_name IN (%s)
  )
  WHERE cnt = 0
  """, 
  count_sql, ARRAY_TO_STRING(column_names, ", ")
);
```

## Challenge 3: DBT for automation

### Notes & Guidance

Configuring the Git connection should be trivial through the UI, you should click on the link `CONNECT WITH GIT` in the `SETTINGS` tab. In that settings tab you can also set the *Google Cloud Project ID* by editing `Workspace compilation overrides`.

After creating the workspace you can then click on `START EXECUTION` and pick Tag *staging*. Don't forget to include the dependencies.

> [!NOTE]  
> Although this is probably not required anymore, in case you get package not found errors, you'll need to navigate to the `workflow_settings.yaml` and click on `INSTALL PACKAGES` button to install the required packages so that the compilation works.

## Challenge 4: Dimensional modeling

### Notes & Guidance

```shell
BQ_DATASET=dwh
bq mk --location=$REGION -d $BQ_DATASET
```

See below for an example, but just like the previous examples, there are multiple options (left joins are fine, and probably better, too). This might be good moment to explain partitioning and clustering if participants are not familiar with the concepts. We're using `order_date` which is a date column as the partition column in this table. We could've used the `order_date_key` too, but then we'd have to use integer range partitioning and bucket things, which (for dates, and certainly for hash values) is not very efficient as there's a maximum of 10K partitions per table. For clustering, it's important to note that typically columns that are often used for joins for lookups are selected and the order matters! You should use the most often used column as the first cluster column. For this challenge we're just using `product_key` as the example.

Also note that BigQuery doesn't enforce primary & foreign key constraints, but they're used as hints for optimizing joins.

> [!NOTE]  
> At the time of this writing creating foreign key constraints through Dataform raises the following error: `Exceeded rate limits: too many table update operations for this table.`. So, for now we're not including foreign keys in the challenge.

Another thing to be aware of is that the gross profit can be negative.

```sql
config {
    type: "table",
    schema: "dwh",
    tags: ["fact"],
    bigquery: {
      partitionBy: "order_date",
      clusterBy: ["product_key"]
    }
}

SELECT
  ${keys.surrogate("sod.sales_order_id", "sod.sales_order_detail_id")} AS sales_key,
  ${keys.surrogate("sod.product_id")} AS product_key,
  ${keys.surrogate("customer_id")} AS customer_key,
  ${keys.surrogate("credit_card_id")} AS credit_card_key,
  ${keys.surrogate("ship_to_address_id")} AS ship_address_key,
  ${keys.surrogate("status")} AS order_status_key,
  ${keys.surrogate("order_date")} AS order_date_key,
  soh.order_date, 
  sod.unit_price,
  sod.unit_price_discount,
  p.standard_cost AS cost_of_goods_sold,
  sod.order_qty AS order_quantity,
  sod.order_qty * sod.unit_price AS gross_revenue,
  sod.order_qty * (sod.unit_price * (1 - sod.unit_price_discount) - p.standard_cost) AS gross_profit
FROM
  ${ref("stg_sales_order_detail")} sod,
  ${ref("stg_sales_order_header")} soh,
  ${ref("stg_product")} p
WHERE
  sod.sales_order_id = soh.sales_order_id
  AND sod.product_id = p.product_id

-- This is causing an error: *Exceeded rate limits: too many table update operations*, disabling it for now
--post_operations {
--  ${keys.primary(ctx, "sales_key")}
--  ${keys.foreign(ctx, ref("dim_product"), "product_key")}
--  ${keys.foreign(ctx, ref("dim_customer"), "customer_key")}
--  ${keys.foreign(ctx, ref("dim_credit_card"), "credit_card_key")}
--  ${keys.foreign(ctx, ref("dim_address"), "address_key", "ship_address_key")}
--  ${keys.foreign(ctx, ref("dim_order_status"), "order_status_key")}
--  ${keys.foreign(ctx, ref("dim_date"), "date_key", "order_date_key")}
--}
```

Total number of rows for this table should be: **121317**

## Challenge 5: Cloud Composer for orchestration

### Notes & Guidance

You need to set the environment variable `DATAFORM_REPOSITORY_ID` to the repository name (not the development workspace) configured in Challenge 4.

Note that the provided Git reference points to a tag in the remote repo, which includes the working code for the fact & obt tables. So Dataform will be using our code instead of the code built by the participants in the previous challenges.

> [!WARNING]  
> Keep in mind that the DAG runs the Dataform pipeline which will recreate the tables. At the time of this writing, recreating tables unfortunately removes the row level security filters and data policies, although there is a bug filed to address this issue. The current alternative is to apply these measures as part of the Dataform ([post_operations](https://cloud.google.com/dataform/docs/dataform-core#define-SQL) for RLS and [policy tags](https://cloud.google.com/dataform/docs/policy-tags) for masking) or Cloud Composer pipelines.

## Challenge 6: Monitoring the workflow

### Notes & Guidance

This should be trivial as well, from the *Monitoring* tab of the Cloud Composer environment you can find the *Failed DAG runs* chart and create an alert from it by filling in the provided details. Alternative is to go to the Cloud Monitoring screen and create a new chart based on the metric `Cloud Composer Workflow->Workflow->Workflow Runs` with a filter for `state = failed` and then save it in a dashboard. Once the chart is available in the dashboard, you can create the alert the same way as for the pre-defined *Failed DAG runs* from the *Monitoring* tab of the environment.
