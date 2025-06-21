from airflow import DAG
from airflow.operators.python import PythonOperator
from datetime import datetime, timedelta
import requests, csv, os, boto3
from io import StringIO

BEARER_TOKEN = os.getenv("TWITTER_BEARER_TOKEN")
QUERY = "python"


def extract_tweets(**context):
    headers = {"Authorization": f"Bearer {BEARER_TOKEN}"}
    url = "https://api.x.com/2/tweets/search/recent"
    params = {"query": QUERY, "max_results": 10}
    response = requests.get(url, headers=headers, params=params)
    tweets = response.json().get("data", [])
    context['ti'].xcom_push(key='tweets', value=tweets)


def load_to_s3(**context):
    tweets = context['ti'].xcom_pull(key='tweets', task_ids='extract_tweets')
    csv_buffer = StringIO()
    writer = csv.writer(csv_buffer)
    writer.writerow(["id", "text"])

    for tweet in tweets:
        writer.writerow([tweet["id"], tweet["text"]])

    s3 = boto3.client('s3')
    key = f"twitter_data_{datetime.now().strftime('%Y%m%d%H%M')}.csv"
    s3.put_object(Bucket="pranai-twitter-output", Key=key, Body=csv_buffer.getvalue())


default_args = {
    "owner": "pranai",
    "retries": 1,
    "retry_delay": timedelta(minutes=5)
}
print("this is me running 1")
with DAG("twitter_etl_dag",
         default_args=default_args,
         start_date=datetime(2025, 6, 20),
         schedule_interval="@daily",
         catchup=False) as dag:

    t1 = PythonOperator(
        task_id='extract_tweets',
        python_callable=extract_tweets,
        provide_context=True
    )

    t2 = PythonOperator(
        task_id='load_to_s3',
        python_callable=load_to_s3,
        provide_context=True
    )

    t1 >> t2