from airflow import DAG
from airflow.operators.bash import BashOperator
from datetime import datetime, timedelta

# Default arguments
default_args = {
    'owner': 'airflow',
    'depends_on_past': False,
    'start_date': datetime(2025, 6, 25),
    'email_on_failure': False,
    'email_on_retry': False,
    'retries': 1,
    'retry_delay': timedelta(minutes=5),
}

# Create DAG
dag = DAG(
    'simple_bash_test_dag',
    default_args=default_args,
    description='A simple bash test DAG for MWAA',
    schedule_interval=None,
    catchup=False,
    tags=['test', 'mwaa', 'bash'],
)

# Simple bash task
hello_task = BashOperator(
    task_id='say_hello_bash',
    bash_command='echo "Hello from MWAA with Bash!" && date',
    dag=dag,
)

# Python task without imports
from airflow.operators.python_operator import PythonOperator

def simple_hello():
    """Very simple function"""
    return "Hello from Python in MWAA!"

python_task = PythonOperator(
    task_id='say_hello_python',
    python_callable=simple_hello,
    dag=dag,
)

# Set task dependencies
hello_task >> python_task