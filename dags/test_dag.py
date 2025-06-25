from datetime import datetime, timedelta
from airflow import DAG
from airflow.operators.python import PythonOperator

def hello_world():
    print("Hello from Airflow!")
    return "Hello from Airflow!"  # Always return a value

default_args = {
    'owner': 'airflow',
    'depends_on_past': False,
    'start_date': datetime(2025, 6, 1),
    'email_on_failure': False,
    'email_on_retry': False,
    'retries': 1,
    'retry_delay': timedelta(minutes=5),  # Increased retry delay for MWAA
    'execution_timeout': timedelta(minutes=10),  # Add execution timeout
}

with DAG(
    dag_id='simple_test_dag',
    default_args=default_args,
    description='A simple DAG to test Airflow setup',
    start_date=datetime(2025, 6, 1),
    schedule_interval=None,  # Changed to manual trigger to avoid scheduling conflicts
    catchup=False,
    tags=['test'],
    # MWAA-specific configurations
    max_active_runs=1,  # Limit concurrent DAG runs
    max_active_tasks=5,  # Limit concurrent tasks
    dagrun_timeout=timedelta(minutes=30),  # Overall DAG timeout
) as dag:

    task_hello = PythonOperator(
        task_id='say_hello',
        python_callable=hello_world,
        # Task-specific configurations for MWAA
        pool='default_pool',
        queue='default',
        executor_config={
            'KubernetesExecutor': {
                'request_memory': '1Gi',
                'request_cpu': '100m',
            }
        } if dag.get_dag().executor_class == 'KubernetesExecutor' else {}
    )

    task_hello