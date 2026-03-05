# Cloud Architecture Security Analyzer
FROM python:3.11-slim

WORKDIR /app

# Dependências do sistema para Pillow e psycopg2
RUN apt-get update && apt-get install -y --no-install-recommends \
    libpq-dev \
    gcc \
    libjpeg-dev \
    zlib1g-dev \
    && rm -rf /var/lib/apt/lists/*

# Copiar projeto (necessário para pip install -e .)
COPY pyproject.toml ./
COPY config/ ./config/
COPY src/ ./src/
COPY .streamlit/ ./.streamlit/

# Instalar dependências (sem dev)
# Usar PyTorch CPU-only para reduzir imagem (~500MB vs ~4GB com CUDA)
RUN pip install --no-cache-dir -e . \
    --index-url https://download.pytorch.org/whl/cpu \
    --extra-index-url https://pypi.org/simple

# Copiar modelo YOLO e SQL (após install para melhor cache)
COPY sql/ ./sql/
COPY models/ ./models/

# Variáveis de ambiente padrão (sobrescritas pelo docker-compose)
ENV DB_HOST=postgres
ENV DB_PORT=5432
ENV DB_NAME=security_analyzer
ENV DB_USER=postgres
ENV DB_PASSWORD=postgres

EXPOSE 8501

# Streamlit precisa bind em 0.0.0.0 para acesso externo
CMD ["streamlit", "run", "src/app.py", "--server.address=0.0.0.0", "--server.port=8501"]
