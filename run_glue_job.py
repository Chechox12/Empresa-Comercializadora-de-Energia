import boto3
import os

def lambda_handler(event, context):
    glue_client = boto3.client('glue')
    jobs = event.get('jobs', [])
    
    if not jobs:
        return {
            "statusCode": 400,
            "body": "Error: 'jobs' not provided in event payload"
        }
    
    responses = []
    for job_name in jobs:
        try:
            response = glue_client.start_job_run(JobName=job_name)
            responses.append({
                "job_name": job_name,
                "status": "Started",
                "run_id": response['JobRunId']
            })
        except Exception as e:
            responses.append({
                "job_name": job_name,
                "status": "Failed",
                "error": str(e)
            })
    
    return {
        "statusCode": 200,
        "body": responses
    }