# Multimodal GenAI with RAG

## Introduction

## Coach's Guides

- Challenge 1: Loading the data
- Challenge 2: Generating multimodal embeddings
- Challenge 3: Semantic search with BigQuery
- Challenge 4: Introduction to RAG
- Challenge 5: Function calling with LLMs


## Challenge 1: Loading the data

### Notes & Guidance

Create a GCS bucket and copy sample files to that bucket. Although, we're using CLI here, students will probably use the Console. Make sure that if students choose a region that they stick to that for other challenges too. Keep in mind that some services might not be available in all regions.

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

In principle the same connection can be used to access Vertex AI models as long as it has the correct permissions, so we're now adding the additional permissions.

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

In order to get the top result there are two methods, first one uses `top_k` parameter, and the second one uses `ORDER BY` with `LIMIT`. Students could choose **either** one. This query should be put in the Cloud Function where originally an empty SQL string is set. Note the `?` placeholder, BigQuery supports query parameters to help prevent SQL injection when queries are constructed using user input, hence the use of the placeholder. See the [docs](https://cloud.google.com/bigquery/docs/parameterized-queries) for more info.

#### Option 1 - Using `top_k`

```sql
SELECT
  base.uri AS uri,
  distance
FROM
  VECTOR_SEARCH( 
    TABLE embeddings.video_embeddings,
    'ml_generate_embedding_result',
    (
      SELECT ml_generate_embedding_result AS query
      FROM ML.GENERATE_EMBEDDING( 
        MODEL embeddings.multimodal_embedding_model,
        (SELECT ? AS content) 
      )
    ),
    top_k => 1
  )
```

#### Option 2 - Using `ORDER BY` and `LIMIT`

```sql
SELECT
  base.uri AS uri,
  distance
FROM
  VECTOR_SEARCH( 
    TABLE embeddings.video_embeddings,
    'ml_generate_embedding_result',
    (
      SELECT ml_generate_embedding_result AS query
      FROM ML.GENERATE_EMBEDDING( 
        MODEL embeddings.multimodal_embedding_model,
        (SELECT ? AS content) 
      )
    )
  )
ORDER BY distance
LIMIT 1
```

## Challenge 4: Introduction to RAG

### Notes & Guidance

This challenge is mainly about prompt engineering and making sure that the multimodal prompt contains textual data as well as the video content as the context.

```python
system_instruction = """
You are a reliable weather forecast reporter, don't respond to anything else than weather information 
and if you don't have the requested information respond back with NO DATA.
"""
model = GenerativeModel(MODEL_NAME, system_instruction=system_instruction)
parts = ["Given the following video:", Part.from_uri(relevant_video_uri, mime_type="video/mp4"), question]
```

## Challenge 5: Function calling with LLMs

### Notes & Guidance

In this challenge the students are supposed to come up with the descriptions for the function and parameters so that the LLM can extract that information in the right format.

```python
function_decl = FunctionDeclaration(
    name=function_name,
    description="Returns the weather information for a city and a date in YYYY-MM-DD format",
    parameters={
        "type": "object",
        "properties": {  
            "city": {
                "type": "string",
                "description": "The name of the city to get weather information for"
            },
            "date": {
                "type": "string",
                "description": "The date for which the weather information is requested, in YYYY-MM-DD format"
            }
        }
    }
)
```