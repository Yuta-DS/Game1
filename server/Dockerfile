FROM python:3.12-slim
ENV PYTHONDONTWRITEBYTECODE=1 PYTHONUNBUFFERED=1 AUTO_CREATE_SCHEMA=false AI_ALLOW_LOOPBACK_GUESTS=0
WORKDIR /app
COPY requirements*.txt ./
RUN pip install --no-cache-dir -r requirements-aws.txt \
    && python -c "import urllib.request; urllib.request.urlretrieve('https://truststore.pki.rds.amazonaws.com/global/global-bundle.pem', '/app/rds-ca.pem')" \
    && useradd --uid 10001 --create-home artea
COPY server.py aws_app.py manage_aws.py ./
RUN mkdir -p ai_cache uploads && chown -R artea:artea /app
USER 10001
ENV DB_SSL_CA=/app/rds-ca.pem
EXPOSE 8000
CMD ["gunicorn", "--bind", "0.0.0.0:8000", "--workers", "2", "--threads", "4", "--timeout", "100", "--access-logfile", "-", "--error-logfile", "-", "aws_app:app"]
