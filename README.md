---------- Compañía Comercializadora de Energía - Pipeline de Datos.

Este proyecto implementa un pipeline de datos en AWS utilizando Terraform para la infraestructura como código (IaC). El pipeline incluye la carga, transformación y catalogación de datos en un Data Lake en S3, y la ejecución de consultas en Athena.

---------- Estructura del Proyecto:

main.tf: Configuración principal de infraestructura en Terraform.

data/: Contiene los archivos CSV (clientes.csv, proveedores.csv, transacciones.csv) que se cargarán automáticamente en el bucket S3 (raw).

raw_to_processed.py: Script de transformación para Glue Jobs (de raw a processed).

run_glue_job.zip: Código empaquetado para la Lambda que ejecuta los Glue Jobs.

execute_athena_querys.zip: Código empaquetado para la Lambda que ejecuta consultas en Athena.

---------- Prerrequisitos

AWS CLI:

Instala y configura las credenciales de AWS.

Asegúrate de tener permisos para crear los siguientes recursos:

- S3 buckets
- Glue Crawler, Jobs, Databases
- Lambdas
- EventBridge Scheduler

Terraform:

Instala Terraform siguiendo las instrucciones oficiales.

Python 3.9 o superior:

Asegúrate de tener Python 3.9 o superior instalado por si necesitas modificar y volver a empaquetar los scripts .zip.

Pasos de Configuración:

- Clonar el repo
- inicializar terraform:
   - terraform init

- Luego se debe revisar y aplicar el plan de terraform por medio de estos comandos:
   - terraform plan
   - terraform apply
 
De aquí en adelante, el documento de word detalla toda la documentación referente al pipeline de datos!
