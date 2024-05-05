# terraform_bigquery_remote_functions
Contains examples on how to create and deploy remote functions with Terraform.

## Folder Structure

|Folder Name | File Name | Description |
|------------|-----------|-------------|
| application/cloud_function/bq_base64_decrypt| main.py | Python code for cloud function deployment| 
| application/cloud_function/bq_remote_add| main.py | Python code for cloud function deployment|
| root | decryption.tf | Terraform file to create required resources for decryption cloud function|
| root | provider.tf | Setup a terraform provider. Google provider in this example|
| root | variables.tf | Variables used for resource creation|
| root | variables.tfvars | Variable declaration. Not published on this page. Read Terraform docks [here](https://developer.hashicorp.com/terraform/language/values/variables#variable-definitions-tfvars-files)|

Executing terraform to deploy resources..
```
terraform apply -var-file="variables.tfvars"
```
> NOTE: Ensure that the variables.tfvars file is popultaed to add location and project_id parameters.
>

For detailed explanation visit [my blog](https://yashmehta.au/gcp/bigquery-remote-functions/)
