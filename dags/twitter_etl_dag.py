from airflow import DAG
from airflow.operators.python import PythonOperator
from datetime import datetime, timedelta
import requests
import csv
import os
import boto3
from io import StringIO

# Configuration
BEARER_TOKEN = os.getenv("TWITTER_BEARER_TOKEN")
QUERY = "python"
OUTPUT_BUCKET = "twitter-etl-output-bucket-unique-12345"


def extract_tweets(**context):
    """Extract tweets from Twitter API"""
    print("Extracting tweets...")
    BEARER_TOKEN = "AAAAAAAAAAAAAAAAAAAAAB562gEAAAAAIpezF4%2B%2FC%2F5hFmb9fYPEbYp7Alw%3DWCCNog6vecLlSV4CAlMZuD08DPGFu14fF4Qt4Z3HCIe33pZWqI"
    headers = {"Authorization": f"Bearer {BEARER_TOKEN}"}
    url = "https://api.twitter.com/2/tweets/search/recent"
    params = {
        "query": QUERY,
        "max_results": 10,
        "tweet.fields": "created_at,author_id,public_metrics"
    }

    try:
        response = requests.get(url, headers=headers, params=params)
        response.raise_for_status()
        tweets = response.json().get("data", [])

        print(f"Extracted {len(tweets)} tweets")
        context['ti'].xcom_push(key='tweets', value=tweets)

    except requests.exceptions.RequestException as e:
        print(f"Error extracting tweets: {e}")
        raise


def transform_tweets(**context):
    """Transform tweets data"""
    tweets = context['ti'].xcom_pull(key='tweets', task_ids='extract_tweets')

    transformed_tweets = []
    for tweet in tweets:
        transformed_tweet = {
            'id': tweet.get('id'),
            'text': tweet.get('text', '').replace('\n', ' ').replace('\r', ' '),
            'created_at': tweet.get('created_at'),
            'author_id': tweet.get('author_id'),
            'retweet_count': tweet.get('public_metrics', {}).get('retweet_count', 0),
            'like_count': tweet.get('public_metrics', {}).get('like_count', 0),
        }
        transformed_tweets.append(transformed_tweet)

    print(f"Transformed {len(transformed_tweets)} tweets")
    context['ti'].xcom_push(key='transformed_tweets', value=transformed_tweets)


def load_to_s3(**context):
    """Load tweets to S3"""
    tweets = context['ti'].xcom_pull(key='transformed_tweets', task_ids='transform_tweets')

    # Create CSV content
    csv_buffer = StringIO()
    writer = csv.writer(csv_buffer)

    # Write header
    writer.writerow(["id", "text", "created_at", "author_id", "retweet_count", "like_count"])

    # Write data
    for tweet in tweets:
        writer.writerow([
            tweet["id"],
            tweet["text"],
            tweet["created_at"],
            tweet["author_id"],
            tweet["retweet_count"],
            tweet["like_count"]
        ])

    # Upload to S3
    s3 = boto3.client('s3')
    timestamp = datetime.now().strftime('%Y%m%d_%H%M%S')
    key = f"twitter_data/year={datetime.now().year}/month={datetime.now().month:02d}/day={datetime.now().day:02d}/twitter_data_{timestamp}.csv"

    try:
        s3.put_object(
            Bucket=OUTPUT_BUCKET,
            Key=key,
            Body=csv_buffer.getvalue(),
            ContentType='text/csv'
        )
        print(f"Successfully uploaded {len(tweets)} tweets to s3://{OUTPUT_BUCKET}/{key}")

    except Exception as e:
        print(f"Error uploading to S3: {e}")
        raise


# Default arguments
default_args = {
    "owner": "pranai",
    "depends_on_past": False,
    "start_date": datetime(2025, 6, 20),
    "email_on_failure": False,
    "email_on_retry": False,
    "retries": 2,
    "execution_timeout": timedelta(minutes=60),
    "retry_delay": timedelta(minutes=5)
}

# Create DAG
with DAG(
        "twitter_etl_dag",
        default_args=default_args,
        description="ETL pipeline for Twitter data",
        schedule_interval="@daily",
        catchup=False,
        tags=["twitter", "etl", "social-media"]
) as dag:
    # Task 1: Extract tweets
    extract_task = PythonOperator(
        task_id='extract_tweets',
        python_callable=extract_tweets
    )

    # Task 2: Transform tweets
    transform_task = PythonOperator(
        task_id='transform_tweets',
        python_callable=transform_tweets
    )

    # Task 3: Load to S3
    load_task = PythonOperator(
        task_id='load_to_s3',
        python_callable=load_to_s3
    )

    # Define task dependencies
    extract_task >> transform_task >> load_task