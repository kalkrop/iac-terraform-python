# Use a base image with Python 3.12.6 slim and Debian Bookworm
FROM python:3.12.6-slim-bookworm

# Set the working directory
WORKDIR /api

# Install Poetry
RUN pip install poetry
RUN poetry config virtualenvs.create false

# Copy pyproject.toml and install dependencies
COPY pyproject.toml poetry.lock ./
RUN poetry install --only main

# Copy the source code
COPY src/ ./src/

# Define the command to run on container start
CMD [ \
    "uvicorn", \
    "--app-dir", \
    "src/", \
    "--host", \
    "0.0.0.0", \
    "--port", \
    "8000", \
    "--reload", \
    "main:api" \
]