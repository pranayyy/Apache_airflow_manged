from datetime import datetime, timedelta
from airflow import DAG
from airflow.operators.python import PythonOperator

def hello_world():
    print("Hello from Airflow!")

default_args = {
    'owner': 'airflow',
    'retries': 1,
    'retry_delay': timedelta(minutes=1),
}

with DAG(
    dag_id='simple_test_dag',
    default_args=default_args,
    description='A simple DAG to test Airflow setup',
    start_date=datetime(2025, 6, 1),
    schedule_interval='@daily',
    catchup=False,
    tags=['test']
) as dag:

    task_hello = PythonOperator(
        task_id='say_hello',
        python_callable=hello_world
    )

    task_hello
