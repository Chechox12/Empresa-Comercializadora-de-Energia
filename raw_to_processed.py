import sys
import re
import boto3
import logging
import pandas as pd
import awswrangler as wr
from awsglue.utils import getResolvedOptions

#%%
#Funciones para limpiar columnas
def clean_characters(input_string):
    if isinstance(input_string, str):
        input_string = re.sub(r'ñ', 'ni', input_string)
        input_string = re.sub(r'[àáâãäå]', 'a', input_string)
        input_string = re.sub(r'[èéêë]', 'e', input_string)
        input_string = re.sub(r'[ìíîï]', 'i', input_string)
        input_string = re.sub(r'[òóôõö]', 'o', input_string)
        input_string = re.sub(r'[ùúûü]', 'u', input_string)
        input_string = ' '.join(re.findall(r"\w+", input_string))
    return input_string

def clean_col_name(df):
    df.columns = [re.sub(r'[- .²º/();]', '_', clean_characters(col.lower())) for col in df.columns]
    df.columns = [re.compile(r"\_+").sub("_", col).strip() for col in df.columns]
    df.columns = [col[:-1] if col[-1] == '_' else col for col in df.columns]
    df.columns = [col[1:] if col[0] == '_' else col for col in df.columns]
    return df

def get_latest_partition(bucket, data_folder):
    s3 = boto3.client('s3')
    paginator = s3.get_paginator('list_objects_v2')
    latest_partition = None
    partitions = []

    for page in paginator.paginate(Bucket=bucket, Prefix=data_folder):
        for obj in page.get('Contents', []):
            key = obj['Key']
            if key.endswith('.csv'):
                partition = '/'.join(key.split('/')[:-1])
                partitions.append(partition)

    if partitions:
        latest_partition = sorted(partitions)[-1]
    else:
        raise ValueError(f"No se encontraron particiones en el prefijo {data_folder}")
    
    return latest_partition
    
def get_csv_file(bucket, path):
    s3 = boto3.client('s3')
    response = s3.list_objects_v2(Bucket=bucket, Prefix=path)
    for obj in response.get('Contents', []):
        if obj['Key'].endswith('.csv'):
            return f"s3://{bucket}/{obj['Key']}"
    raise ValueError(f"No se encontró un archivo CSV en {path}")

#%%
#Configuración del logger
logger = logging.getLogger(name="ETL1 Proveedores")
logger.setLevel(logging.DEBUG)
handler = logging.StreamHandler(sys.stdout)
handler.setLevel(logging.DEBUG)
formatter = logging.Formatter('%(name)s - %(levelname)s - %(message)s')
handler.setFormatter(formatter)
logger.addHandler(handler)

#%%
#leer parámetros del job
logger.info("Leer parametros del job")

args = getResolvedOptions(
    sys.argv, 
    [
        'INPUT_BUCKET'
        ,'OUTPUT_BUCKET'
        ,"PATH_KEY"
    ]
)

input_bucket = args['INPUT_BUCKET']
data_folder = args['PATH_KEY']
output_bucket = args['OUTPUT_BUCKET']

#%%
#Encontrar la ultima partición
logger.info(f"buscando la particion mas reciente en: {input_bucket}/{data_folder}/")
try:
    latest_partition = get_latest_partition(input_bucket, data_folder)
    
    input_path = f's3://{input_bucket}/{latest_partition}/'
    
    logger.info(f"ultima partición encontrada: {latest_partition}")
except Exception as e:
    logger.error(f"Error buscando la partición mas reciente: {e}")
    sys.exit(1)


#%%
#Encontrar el archivo CSV en la partición
logger.info(f"Buscando archivo CSV en: {input_bucket}/{latest_partition}")
try:
    csv_path = get_csv_file(input_bucket, latest_partition)
    logger.info(f"Archivo CSV encontrado: {csv_path}")
except Exception as e:
    logger.error(f"Error buscando archivo CSV: {e}")
    sys.exit(1)

#%%
#Leer datos desde s3
logger.info(f'Leyendo datos desde: {csv_path}')

try:
    df = pd.read_csv(csv_path, delimiter=",", encoding = "ISO-8859-1")
    logger.info(f"Datos leidos correctamente: {len(df)} filas encontradas")
except Exception as e:
    logger.error(f"Error leyendo datos desde S3: {e}")
    sys.exit(1)

#%%
#Transformaciones
logger.info("Limpiando nombres de columnas")
try:
    df = clean_col_name(df)
    logger.info(f"Nombres de columnas despues de limpiar: {list(df.columns)}")
except Exception as e:
    logger.error(f"Error limpiando nombres de columnas: {e}")
    sys.exit(1)

#%%
#Guardar datos en formato Parquet
output_path = f's3://{output_bucket}/{latest_partition}/'

logger.info(f"Guardando datos procesados en {output_path}")
try:
    wr.s3.to_parquet(
        df=df,
        path=output_path,
        dataset=True,
        mode="overwrite",
    )
    logger.info("Datos guardados exitosamente")
except Exception as e:
    logger.error(f"Error al guardar datos en S3: {e}")
    sys.exit(1)

logger.info("Proceso completado exitosamente")