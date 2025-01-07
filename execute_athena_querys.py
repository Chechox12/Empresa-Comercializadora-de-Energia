import boto3
import time
import json

def lambda_handler(event, context):
    # Configuración de Athena
    database = "cce_datalake_processed_db"
    query = "SELECT * FROM processed_proveedores LIMIT 10;"
    output_bucket = "s3://cce-datalake-analytics/athena-results/"
    
    client = boto3.client("athena", region_name="us-east-1")
    
    try:
        # Ejecutar consulta
        response = client.start_query_execution(
            QueryString=query,
            QueryExecutionContext={"Database": database},
            ResultConfiguration={"OutputLocation": output_bucket},
        )
        query_execution_id = response["QueryExecutionId"]
        print(f"Query execution ID: {query_execution_id}")

        # Verificar el estado de la consulta
        while True:
            status = client.get_query_execution(QueryExecutionId=query_execution_id)
            state = status["QueryExecution"]["Status"]["State"]
            state_reason = status["QueryExecution"]["Status"].get("StateChangeReason", "No reason provided")
            if state in ["SUCCEEDED", "FAILED", "CANCELLED"]:
                print(f"Estado: {state}")
                print(f"Motivo del error: {state_reason}")
                break
            print("Esperando que la consulta finalice...")
            time.sleep(2)

        if state == "SUCCEEDED":
            print("Consulta completada exitosamente.")
            #imprimir resultados
            results = client.get_query_results(QueryExecutionId=query_execution_id)
            rows = results["ResultSet"]["Rows"]
            print("Resultados de la consulta:")
            for row in rows:
                print(row["Data"])
            return {"statusCode": 200, "body": json.dumps("Consulta ejecutada exitosamente")}
        else:
            print(f"Error: La consulta finalizó con estado {state}")
            return {"statusCode": 500, "body": json.dumps(f"Error: Estado {state}")}

    except Exception as e:
        print(f"Error ejecutando consulta: {e}")
        return {"statusCode": 500, "body": json.dumps(f"Error: {str(e)}")}
