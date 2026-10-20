"""One-shot schema bootstrap. Run with the migration task, never the API role."""
import os
import psycopg
from psycopg import sql

os.environ["AUTO_CREATE_SCHEMA"] = "false"
os.environ["AUTH_PROVIDER"] = "cognito"
from server import app, db

if __name__ == "__main__":
    with app.app_context():
        # Fresh AWS database only. Future schema changes require an explicit
        # versioned migration rather than relying on create_all to alter tables.
        db.create_all()
    with psycopg.connect(host=os.environ["DB_HOST"], dbname=os.environ["DB_NAME"],
                         user=os.environ["DB_USERNAME"], password=os.environ["DB_PASSWORD"],
                         sslmode="verify-full", sslrootcert=os.environ["DB_SSL_CA"]) as connection:
        with connection.cursor() as cursor:
            cursor.execute("SELECT 1 FROM pg_roles WHERE rolname = 'artea_app'")
            if not cursor.fetchone():
                cursor.execute(sql.SQL("CREATE ROLE artea_app LOGIN PASSWORD {}").format(sql.Literal(os.environ["APP_DB_PASSWORD"])))
            else:
                cursor.execute(sql.SQL("ALTER ROLE artea_app PASSWORD {}").format(sql.Literal(os.environ["APP_DB_PASSWORD"])))
            cursor.execute("REVOKE CREATE ON SCHEMA public FROM PUBLIC")
            cursor.execute("GRANT USAGE ON SCHEMA public TO artea_app")
            cursor.execute("GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO artea_app")
            cursor.execute("GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO artea_app")
            cursor.execute("ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO artea_app")
            cursor.execute("ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT USAGE, SELECT ON SEQUENCES TO artea_app")
    print("Schema and restricted runtime database role prepared")
