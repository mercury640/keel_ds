resource "null_resource" "db_init" {
  provisioner "local-exec" {
    command = <<EOF
      PGPASSWORD=${var.rds_master_pass} psql -h ${var.rds_endpoint} -U master -d ${var.rds_db_name} <<SQL
      CREATE SCHEMA IF NOT EXISTS ${var.rds_schema_name};
      CREATE TABLE IF NOT EXISTS ${var.rds_schema_name}.info (
        id SERIAL PRIMARY KEY,
        value INTEGER,
        ip TEXT
      );
      CREATE USER ${var.rds_serv_user} WITH PASSWORD ${var.rds_serv_pass};
      GRANT ALL PRIVILEGES ON DATABASE ${var.rds_db_name} TO ${var.rds_serv_user};
      GRANT USAGE, CREATE ON SCHEMA ${var.rds_schema_name} TO ${var.rds_serv_user};
      GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA ${var.rds_schema_name} TO ${var.rds_serv_user};
      SQL
    EOF
  }
}
