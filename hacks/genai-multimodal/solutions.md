# Multimodal GenAI with RAG

## Introduction

## Coach's Guides

- Challenge 1: Loading the data
- Challenge 2: Generating multimodal embeddings
- Challenge 3: Semantic search with BigQuery
- Challenge 4: Introduction to RAG
- Challenge 5: Structured outputs
- Challenge 6: Code interpreter

## Challenge 1: Loading the data

### Notes & Guidance

Create a GCS bucket and copy sample files to that bucket.

```shell
REGION=...
BUCKET="gs://$GOOGLE_CLOUD_PROJECT-videos"

gsutil mb -l $REGION $BUCKET
gsutil -m cp {...} $BUCKET/ # TODO ME: or wget from a website?
```

Create a new BQ dataset

```shell
BQ_DATASET=embeddings
bq mk --location=$REGION -d $BQ_DATASET
```

Create a connection and give permission to access buckets

```shell
CONN_ID=conn
bq mk --connection --location=$REGION --connection_type=CLOUD_RESOURCE $CONN_ID

SA_CONN=`bq show --connection --format=json $REGION.$CONN_ID | jq -r .cloudResource.serviceAccountId`

gcloud projects add-iam-policy-binding $GOOGLE_CLOUD_PROJECT --member="serviceAccount:$SA_CONN" \
    --role="roles/storage.objectUser" --condition=None
```

Now, create the object table (replace the variables with literals)

```sql
CREATE OR REPLACE EXTERNAL TABLE `$BQ_DATASET.videos`
WITH CONNECTION `$REGION.$CONN_ID`
OPTIONS(
  object_metadata = 'SIMPLE',
  uris = ['gs://$BUCKET/*.mp4']
)
```

## Challenge 2: Generating multimodal embeddings

### Notes & Guidance

First, give permissions to create/access the model

```shell
gcloud projects add-iam-policy-binding $GOOGLE_CLOUD_PROJECT --member="serviceAccount:$SA_CONN" \
    --role="roles/aiplatform.user" --condition=None
```

Now, create the model

```sql
CREATE OR REPLACE MODEL `$BQ_DATASET.multimodal_embedding_model`
REMOTE WITH CONNECTION `$REGION.$CONN_ID`
OPTIONS (
  ENDPOINT = 'multimodalembedding@001'
)
```

Generate the embeddings

```sql
CREATE OR REPLACE TABLE `$BQ_DATASET.video_embeddings`
AS
SELECT *
FROM
  ML.GENERATE_EMBEDDING(
    MODEL `$BQ_DATASET.multimodal_embedding_model`,
    TABLE `$BQ_DATASET.videos`
  )
```

> **Note**  
> In order to use Vector Indexes the table needs to have at least 5000 rows for the index, with only 60 rows in this table we cannot create a Vector Index but we can use Vector Search directly (without the index).

> **Note**  
> BigQuery might not be the best solution for doing single row lookups, typically a transactional database (AlloyDB, CloudSpanner) or  specific services such as _Vertex AI Vector Search_ would be used, but these require additional setup hence we'll stick to BigQuery for now.

## Challenge 3: Semantic search with BigQuery

### Notes & Guidance

In order to get the top result there are two methods, first one uses `top_k` parameter, and the second one uses `ORDER BY` with `LIMIT`.

#### Using `top_k`

```sql
SELECT
  base.uri,
  distance
FROM
  VECTOR_SEARCH( 
    TABLE embeddings.video_embeddings,
    'ml_generate_embedding_result',
    (
      SELECT ml_generate_embedding_result AS query
      FROM ML.GENERATE_EMBEDDING( 
        MODEL embeddings.multimodal_embedding_model,
        (SELECT "weather in South Africa next week" AS content) 
      )
    ),
    top_k => 1
  )
```

#### Using `ORDER BY` and `LIMIT`

```sql
SELECT
  base.uri,
  distance
FROM
  VECTOR_SEARCH( 
    TABLE embeddings.video_embeddings,
    'ml_generate_embedding_result',
    (
      SELECT ml_generate_embedding_result AS query
      FROM ML.GENERATE_EMBEDDING( 
        MODEL embeddings.multimodal_embedding_model,
        (SELECT "weather in South Africa next week" AS content) 
      )
    ),
  )
ORDER BY distance
LIMIT 1
```

