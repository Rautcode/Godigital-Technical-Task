import os
import boto3
import pandas as pd
import sqlalchemy
import logging
from botocore.exceptions import ClientError


logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)


S3_BUCKET = os.environ.get('S3_BUCKET')
S3_KEY = os.environ.get('S3_KEY')
RDS_HOST = os.environ.get('RDS_HOST')
RDS_PORT = os.environ.get('RDS_PORT')
RDS_DB = os.environ.get('RDS_DB')
RDS_USER = os.environ.get('RDS_USER')
RDS_PASSWORD = os.environ.get('RDS_PASSWORD')
GLUE_DB = os.environ.get('GLUE_DB')
GLUE_TABLE = os.environ.get('GLUE_TABLE')

def read_from_s3(bucket, key):
    """Read data from S3 bucket"""
    try:
        logger.info(f"Reading data from s3://{bucket}/{key}")
        s3_client = boto3.client('s3')
        response = s3_client.get_object(Bucket=bucket, Key=key)
        if key.endswith('.csv'):
            df = pd.read_csv(response['Body'])
        elif key.endswith('.json'):
            df = pd.read_json(response['Body'])
        elif key.endswith('.parquet'):
            df = pd.read_parquet(response['Body'])
        else:
            raise ValueError(f"Unsupported file format: {key}")
            
        logger.info(f"Successfully read {len(df)} rows from S3")
        return df
    except Exception as e:
        logger.error(f"Error reading from S3: {str(e)}")
        raise

def write_to_rds(df, table_name):
    """Write dataframe to RDS database"""
    try:
        logger.info(f"Attempting to write {len(df)} rows to RDS table {table_name}")
        connection_string = f"postgresql://{RDS_USER}:{RDS_PASSWORD}@{RDS_HOST}:{RDS_PORT}/{RDS_DB}"
        engine = sqlalchemy.create_engine(connection_string)
        
        
        df.to_sql(table_name, engine, if_exists='append', index=False)
        logger.info(f"Successfully wrote data to RDS table {table_name}")
        return True
    except Exception as e:
        logger.error(f"Error writing to RDS: {str(e)}")
        return False

def write_to_glue(df, database, table):
    """Write dataframe to AWS Glue Data Catalog / S3"""
    try:
        logger.info(f"Attempting to write {len(df)} rows to Glue table {database}.{table}")
        # Create a temporary parquet file
        temp_file = '/tmp/data.parquet'
        df.to_parquet(temp_file)
        s3_client = boto3.client('s3')
        target_path = f"s3://{S3_BUCKET}/glue-data/{database}/{table}/data.parquet"
        bucket, key = target_path.replace("s3://", "").split("/", 1)
        s3_client.upload_file(temp_file, bucket, key)
        glue_client = boto3.client('glue')
        
        try:
            glue_client.get_table(DatabaseName=database, Name=table)
        except ClientError:
            columns = []
            for column, dtype in df.dtypes.items():
                col_type = 'string'
                if pd.api.types.is_integer_dtype(dtype):
                    col_type = 'int'
                elif pd.api.types.is_float_dtype(dtype):
                    col_type = 'double'
                elif pd.api.types.is_bool_dtype(dtype):
                    col_type = 'boolean'
                
                columns.append({'Name': column, 'Type': col_type})
            
            glue_client.create_table(
                DatabaseName=database,
                TableInput={
                    'Name': table,
                    'StorageDescriptor': {
                        'Columns': columns,
                        'Location': f"s3://{S3_BUCKET}/glue-data/{database}/{table}",
                        'InputFormat': 'org.apache.hadoop.hive.ql.io.parquet.MapredParquetInputFormat',
                        'OutputFormat': 'org.apache.hadoop.hive.ql.io.parquet.MapredParquetOutputFormat',
                        'SerdeInfo': {
                            'SerializationLibrary': 'org.apache.hadoop.hive.ql.io.parquet.serde.ParquetHiveSerDe'
                        }
                    },
                    'TableType': 'EXTERNAL_TABLE'
                }
            )
        
        logger.info(f"Successfully wrote data to Glue table {database}.{table}")
        return True
    except Exception as e:
        logger.error(f"Error writing to Glue: {str(e)}")
        return False

def lambda_handler(event, context):
    """AWS Lambda entry point"""
    try:
        bucket = event.get('s3_bucket', S3_BUCKET)
        key = event.get('s3_key', S3_KEY)
        df = read_from_s3(bucket, key)
        table_name = os.path.splitext(os.path.basename(key))[0]
        rds_success = write_to_rds(df, table_name)
        if not rds_success:
            logger.info("RDS write failed, falling back to Glue")
            glue_success = write_to_glue(df, GLUE_DB, table_name)
            if not glue_success:
                logger.error("Both RDS and Glue writes failed")
                return {
                    'statusCode': 500,
                    'body': 'Failed to write data to either RDS or Glue'
                }
            else:
                return {
                    'statusCode': 200,
                    'body': f'Successfully processed {len(df)} rows and wrote to Glue'
                }
        else:
            return {
                'statusCode': 200,
                'body': f'Successfully processed {len(df)} rows and wrote to RDS'
            }
    except Exception as e:
        logger.error(f"Lambda execution failed: {str(e)}")
        return {
            'statusCode': 500,
            'body': f'Error: {str(e)}'
        }

if __name__ == "__main__":
    # Simulate Lambda event
    test_event = {
        's3_bucket': S3_BUCKET,
        's3_key': S3_KEY
    }
    result = lambda_handler(test_event, None)
    print(result)
