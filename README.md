# Infraestrutura como código com Terraform e Python

## Introdução

Para iniciar e acelerar o nível técnico no desenvolvimento de API seguindo as melhores práticas, padrões de projetos
e convenções em Python com FastAPI. Além de integrar este conhecimento com a área de infraestrutura, 
explorando do desenvolvimento manual de serviços na nuvem para automatizar provisionamento baseado em conceitos
de Infraestrura como Código (IaC), usando Terraform.

## Parte 1
## Criando um aplicação com Python, FastAPI and Postgres. No qual, é criado um simples TODO list
 
https://github.com/Syndelis/fast-api-terraform

## Iniciando com os seguintes passos:

- Criar um diretório com o nome do projeto. No caso optei por: 
```
mkdir iac-terraform-python
```

- Poetry version 1.8.3, para gerenciamento de dependencias e ambiente.
```
poetry init -n
```

- Criar arquivo main.py dentro do diretório src. Dentro do arquivo, vamos começar construir nossa api utilizando FastAPI:
```python
from fastapi import FastAPI


api = FastAPI()

@api.get("/")
def index():
    return "Hello World"
```

- Ative o ambiente virtual:
```
poetry shell
```

- Instalar fastapi
```python
poetry add fastapi
```

- Instalar uvicorn
```python
poetry add uvicorn
```

- No terminal. Execute o servidor uvicorn
```
uvicorn --app-dir src/ --host 0.0.0.0 --port 8000 --reload main:api
```

- Para verificar se está tudo certo. Tem a opção de abrir o navegador no endereço localhost:8000
Ou abrir um outro terminal e digitar:
```
http GET localhost:8000/
```

## Dockerizando...

- Tenha instalado:
Docker version 27.3.0, build e85edf8(ou mais atualizado)

- Crie o arquivo Dockerfile iac-terraform-python/Dockerfile

- Dentro do Dockerfile. Insira a versão do python que iremos utilizar:
```
# Use a base image with Python 3.12.6 slim and Debian Bookworm
FROM python:3.12.6-slim-bookworm 

# Install Poetry
RUN pip install poetry
RUN poetry config virtualenvs.create false

# Copy pyproject.toml and install dependencies
COPY pyproject.toml poetry.lock ./
RUN poetry install --only main
```

- Execute o comando para construir a imagem:
```
docker buildx build -t iactp .
```

- Execute o modo interativo e verifique se o fastapi foi devidamente instalado
```
docker run -it --entrypoint bash iactp
```

- Para verificar que está tudo instalado na imagem criada. Digite no bash:
```
poetry show
```

Se exibiu todos as bibliotecas instaldas. Pode comemorar!

- Agora vamos dar uma incrementada no Dockerfile, inserindo o diretório /api na imagem. Copiar o nosso src/ para dentro da imagem. Por fim, definindo o CMD. Ficando como abaixo:

```
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
```

- Execute o comando para construir a imagem:
```
docker buildx build -t iactp .
```

- Testando a aplicação executada pelo container.
```
docker run -p 8000:8000 iactp
```

- Criando o arquivo compose.yml. Dentre deste digite:
```
services:
  api:
    build:
      context: .
    ports:
      - 8000:8000
    volumes:
      - ./src/:/api/src/

- Execute o comando para disponibilizar os serviços na imagem criada pelo compose.yml
```
docker compose up 
```

- Se executar o comando e em seguida alterar o retorno no arquivo main, confirmará que o reload está funcionando.

- Vamos adicionar o serviço de banco de dados db de uma imagem do postgres:
```
services:
  api:
    build:
      context: .
    ports:
      - 8000:8000
    volumes:
      - ./src/:/api/src/
  db:
    image: postgres: 16.3
    environment:
      - POSTGRES_USER=postgres
      - POSTGRES_PASSWORD=postgres
      - POSTGRES_DB=postgres
```

- Testando se o banco postgres está acessível:
```
docker compose up
```

- Abra outro terminal e execute:
```
docker compose exec db psql -U postgres
```

- Digite para listar os db disponíveis. (Para voltar ao modo interativo do postgres: CTRL + :q):
```
\l
```

- Realizando um select:
```
select gen_random_uuid();
```

Para sair do modo psql do postgres:
```
\q
```

- Pare o docker compose em execução Ctrl + c

- Instale o psycopg2-binary
```
poetry add psycopg2-binary
```

- Altere o arquivo src/main.py
```python
from fastapi import FastAPI
import psycopg2 as pg


api = FastAPI()
conn = pg.connect(
    host="db",
    port="5432",
    user="postgres",
    password="postgres",
    database="postgres",
)

@api.get("/")
def index():
    cur = conn.cursor()
    cur.execute("SELECT gen_random_uuid();")
    uuid, *_ = cur.fetchone()
    return f"UUID from Postgres: {uuid}"
```

- Execute novamente
```
docker compose up
```

- Em outro terminal execute:
```
http GET localhost:8000/
```

- Ou acesse o seu navegador:
```
localhost:8000/
```

- Vamos agora instalar o sqlmodel:
```
poetry add sqlmodel
```

- Altere o src/main.py
```python
from fastapi import FastAPI
from sqlmodel import Field, Session, SQLModel, create_engine, select
from typing import Optional


class Task(SQLModel, table=True):
    id: Optional[int] = Field(default=None, primary_key=True)
    msg: str
    done: Optional[bool] = Field(default=False)


api = FastAPI()

engine = create_engine(
    "postgresql://postgres:postgres@db:5432/postgres"
)

@api.on_event("startup")
def run_migrations():
    SQLModel.metadata.create_all(engine)

@api.get("/")
def list():
    with Session(engine) as session:
      return  session.exec(
          select(Task)
      ).all()
```

- Como instalamos o sqlmodl, precisamos fazer build:
```
docker compose up --build
```

- Vamos "tipar" o que nossa função list retorna e criar o nosso endpoint post com a função create:
```python
from fastapi import FastAPI
from sqlmodel import Field, Session, SQLModel, create_engine, select
from typing import Optional


class Task(SQLModel, table=True):
    id: Optional[int] = Field(default=None, primary_key=True)
    msg: str
    done: Optional[bool] = Field(default=False)


api = FastAPI()

engine = create_engine(
    "postgresql://postgres:postgres@db:5432/postgres"
)

@api.on_event("startup")
def run_migrations():
    SQLModel.metadata.create_all(engine)

@api.get("/")
def list() -> list[Task]:
    with Session(engine) as session:
      return session.exec(
          select(Task)
      ).all()


@api.post("/")
def create(task: Task) -> Task:
    with Session(engine) as session:
        session.add(task)
        session.commit()
        session.refresh(task)
        return task
```

- Execute no terminal:
```
http POST localhost:8000/ msg="Infraestrutura como código com Python"
```

- Ou no navegador:
```
localhost:8000/ msg="Infraestrutura como código com Python"
```

- Vamos instalar o pydantic
```
poetry add pydantic
```

- Vamos alterar o main, adicionando o endpoint patch
```python
from fastapi import FastAPI
from pydantic import BaseModel
from sqlmodel import Field, Session, SQLModel, create_engine, select
from typing import Optional


class Task(SQLModel, table=True):
    id: Optional[int] = Field(default=None, primary_key=True)
    msg: str
    done: Optional[bool] = Field(default=False)


api = FastAPI()

engine = create_engine(
    "postgresql://postgres:postgres@db:5432/postgres"
)

@api.on_event("startup")
def run_migrations():
    SQLModel.metadata.create_all(engine)

@api.get("/")
def list() -> list[Task]:
    with Session(engine) as session:
      return session.exec(
          select(Task)
      ).all()


@api.post("/")
def create(task: Task) -> Task:
    with Session(engine) as session:
        session.add(task)
        session.commit()
        session.refresh(task)
        return task


class TaskUpdatePayload(BaseModel):
    done: bool


@api.patch("/{task_id}")
def update(task_id: int, body: TaskUpdatePayload) -> Task:
    with Session(engine) as session:
        task = session.exec(select(Task).where(Task.id == task_id)).one()
        task.done = body.done
        session.add(task)
        session.commit()
        session.refresh(task)
        return task
```

- Execute no terminal:
```
http PATCH localhost:8000/1 done:=true
```

--

## Parte 2

## Nesta parte realizei a criação de instancias na AWS e upload do código criado na sessção anterior.

Foi trabalhado a criação diretamente através do AWS web console. Onde foi criado uma instancia EC2, 
configurado o acesso SSH para updload do código. Foi necessário criar um banco de dados relacional através
do RDS e acessá-lo através da instancia EC2.
No processo utilizei os recursos Free Tier e após a utilização desativei todos os serviços para não ter surpresa no
cartão de crédito.

--

## Parte 3

## Finalmente definindo a Infraestrura como Código utilizando o Terraform.

Será necessário instalar o Terraform e utilizar o AWS console usando o HCL language.
Crie o arquivo main.tf com o código abaixo:
```
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.16"
    }
  }

  required_version = ">= 1.2.0"
}

provider "aws" {
  region  = "us-east-1"
  profile = "kakrop"
}

# NETWORK #################################################

resource "aws_vpc" "app_vpc" {
  cidr_block           = "10.1.0.0/16"
  enable_dns_hostnames = true
}

resource "aws_subnet" "private" {
  vpc_id                  = aws_vpc.app_vpc.id
  cidr_block              = "10.1.1.0/24"
  map_public_ip_on_launch = false
  availability_zone       = "us-east-1a"
}

resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.app_vpc.id
  cidr_block              = "10.1.2.0/24"
  map_public_ip_on_launch = true
  availability_zone       = "us-east-1a"
}

resource "aws_internet_gateway" "app_igw" {
  vpc_id = aws_vpc.app_vpc.id
}

resource "aws_eip" "app_eip" {
  vpc = true
}

resource "aws_nat_gateway" "app_ngw" {
  subnet_id     = aws_subnet.public.id
  allocation_id = aws_eip.app_eip.id
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.app_vpc.id
}

resource "aws_route" "public" {
  route_table_id         = aws_route_table.public.id
  gateway_id             = aws_internet_gateway.app_igw.id
  destination_cidr_block = "0.0.0.0/0"
}

resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

###########################################################

resource "aws_key_pair" "warpgate" {
  key_name   = "warpgate-key"
  public_key = "chave pública na aws da VPC"
}

resource "aws_security_group" "seguranca_total" {
  name   = "seguranca_total"
  vpc_id = aws_vpc.app_vpc.id

  ingress {
    cidr_blocks = ["0.0.0.0/0"]
    from_port   = 22
    protocol    = "tcp"
    to_port     = 22
  }

  ingress {
    cidr_blocks = ["0.0.0.0/0"]
    from_port   = 80
    protocol    = "tcp"
    to_port     = 80
  }

  egress {
    cidr_blocks = ["0.0.0.0/0"]
    from_port   = 0
    protocol    = -1
    to_port     = 0
  }
}

resource "aws_ecs_cluster" "app_cluster" {
  name = "app_cluster"
}

resource "aws_ecs_cluster_capacity_providers" "app_cluster" {
  cluster_name = aws_ecs_cluster.app_cluster.name

  capacity_providers = ["FARGATE"]

  default_capacity_provider_strategy {
    base              = 1
    weight            = 100
    capacity_provider = "FARGATE"
  }
}

resource "aws_ecs_task_definition" "app_docker_image" {
  family                   = "service"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = 1024
  memory                   = 2048
  container_definitions = jsonencode([
    {
      name      = "fast-api"
      image     = "ghcr.io/kalkrop/fast-api-terraform:latest"
      cpu       = 1024
      memory    = 2048
      essential = true
      portMappings = [
        {
          containerPort = 80
          hostPort      = 80
        }
      ]
    }
  ])
}

resource "aws_ecs_service" "app" {
  name            = "app"
  cluster         = aws_ecs_cluster.app_cluster.id
  task_definition = aws_ecs_task_definition.app_docker_image.arn
  desired_count   = 1

  network_configuration {
    security_groups  = [aws_security_group.seguranca_total.id]
    subnets          = [aws_subnet.public.id]
    assign_public_ip = true
  }
}

resource "aws_instance" "app_server" {
  ami                         = "ami-04b70fa74e45c3917"
  instance_type               = "t2.micro"
  key_name                    = aws_key_pair.warpgate.key_name
  associate_public_ip_address = true
  vpc_security_group_ids      = [aws_security_group.seguranca_total.id]
  subnet_id                   = aws_subnet.public.id

  tags = {
    Name = "ExampleAppServerInstance"
  }
}

# DEPLOY PERMISSIONS ######################################

data "aws_caller_identity" "current" {}

locals {
  iam_task_role_arn      = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/${aws_ecs_task_definition.app_docker_image.task_role_arn}"
  iam_execution_role_arn = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/${aws_ecs_task_definition.app_docker_image.execution_role_arn}"
  ecs_service_arn        = "arn:aws:ecs:us-east-1:${data.aws_caller_identity.current.account_id}:service/${aws_ecs_cluster.app_cluster.name}/${aws_ecs_service.app.name}"
}

data "aws_iam_policy_document" "minimum_required_deploy_permissions" {
  statement {
    sid       = "RegisterTaskDefinition"
    effect    = "Allow"
    actions   = ["ecs:RegisterTaskDefinition"]
    resources = ["*"]
  }

  statement {
    sid       = "DescribeTaskDefinition"
    effect    = "Allow"
    actions   = ["ecs:DescribeTaskDefinition"]
    resources = ["*"]
  }

  statement {
    sid       = "PassRolesInTaskDefinition"
    effect    = "Allow"
    actions   = ["iam:PassRole"]
    resources = [local.iam_task_role_arn, local.iam_execution_role_arn]
  }

  statement {
    sid       = "DeployService"
    effect    = "Allow"
    actions   = ["ecs:UpdateService", "ecs:DescribeServices"]
    resources = [local.ecs_service_arn]
  }
}

resource "aws_iam_policy" "ecs_deploy_task_definition" {
  name        = "ecs_deploy_task_definition"
  description = "Taken from Action: Amazon ECS 'Deploy Task Definition' Action for GitHub Actions"
  policy      = data.aws_iam_policy_document.minimum_required_deploy_permissions.json

}

resource "aws_iam_user" "github_actions" {
  name = "github_actions"
}

###########################################################
```










###### Link: https://www.youtube.com/watch?v=DDL1CsiUAzM&t