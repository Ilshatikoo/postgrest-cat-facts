# Разбираем PostgREST: инструмент для создания API на PostgreSQL

> Весь материал был создан на основе главной документации PostgREST. Если что можно сверяться с ней [https://postgrest.org/en/v12/index.html](https://postgrest.org/en/v12/index.html).
> 

В мире веб-разработки существует множество инструментов для создания API. Однако, если вы работаете с PostgreSQL, есть одно крутое решение, которое сочетает в себе простоту и мощь - PostgREST.

**Что такое PostgREST?**

PostgREST - это инструмент, который автоматически создает RESTful API на основе вашей базы данных PostgreSQL. Это значит, что вы можете создать полнофункциональное веб-приложение, используя только SQL для определения структуры данных.

**Почему PostgREST?**

- PostgREST предлагает эффективную альтернативу ручному программированию CRUD, решая распространенные проблемы серверов пользовательских API.
- Он устанавливает базу данных как единственный источник истины, избегая дублирования и игнорирования структуры данных.
- Декларативное программирование в PostgREST упрощает запросы к данным, делегируя сложную логику обработки PostgreSQL и улучшая производительность.
- Отсутствие ORM и возможность создания представлений данных напрямую в SQL обеспечивают герметичную абстракцию и позволяют администраторам баз данных создавать API без дополнительного программирования.

Давайте начнем с создания нашего первого API. Наша задача состоит в том, чтобы создать базу данных, содержащую информацию о породах кошек и связанных с ними фактах, а затем реализовать API с методами CRUD для работы с этими данными. Наконец, мы подключим веб-сервер для доступа к API.

## Подготовка

Для работы с материалом вам понадобится база данных PostgreSQL и сам PostgREST. Dockerfile и compose файлы для PostgreSQL можно найти у меня в репозитории. Бинарь PostgREST можно скачать вот [здесь](https://github.com/PostgREST/postgrest/releases).

## Создание базы данных

Давайте начнем с создания базы данных для хранения информации.

### Создание базы данных

```sql
CREATE DATABASE cat_facts;
```

После создания БД убедитесь, что вы переключились на эту базу данных, если ранее работали с другой.

### Создание таблиц

Создадим таблицы в схеме `public`, но вы можете использовать свою собственную схему (например, `api`) и работать с ней.

**Таблица с породами кошек**

```sql
CREATE TABLE IF NOT EXISTS breeds (
    id SERIAL PRIMARY KEY,
    breed VARCHAR(100) NOT NULL,
    country VARCHAR(100) NOT NULL,
    origin VARCHAR(100) NOT NULL,
    coat VARCHAR(100) NOT NULL,
    pattern VARCHAR(100) NOT NULL
);
```

**Таблица с фактами о кошках**

```sql
CREATE TABLE cat_facts (
    id SERIAL PRIMARY KEY,
    fact TEXT
);
```

**Заполним созданные таблицы данными.**

```sql
INSERT INTO breeds (breed, country, origin, coat, pattern) VALUES ('Siamese', 'Thailand', 'Natural', 'Short', 'Colorpoint');
INSERT INTO breeds (breed, country, origin, coat, pattern) VALUES ('Maine Coon', 'United States', 'Natural', 'Long', 'Tabby');
INSERT INTO breeds (breed, country, origin, coat, pattern) VALUES ('Persian', 'Iran', 'Natural', 'Long', 'Solid');

INSERT INTO cat_facts (fact) VALUES ('Кошки могут спать до 16 часов в сутки');
INSERT INTO cat_facts (fact) VALUES ('Кошки способны прыгать в 6 раз длиннее их высоты');
INSERT INTO cat_facts (fact) VALUES ('У кошек бывают до 100 различных звуковых сигналов');
INSERT INTO cat_facts (fact) VALUES ('Кошки могут видеть в темноте на расстояние до 6 раз больше, чем человек');
```

## **Ролевая система в PostgREST**

PostgREST имеет гибкую систему аутентификации и авторизации, которая позволяет контролировать доступ к данным и действиям клиентов. Это достигается за счет использования трех типов ролей:

- **authenticator:** Эта роль используется для подключения к базе данных и обладает ограниченными правами доступа. Она играет роль "хамелеона", который может временно становиться другими пользователями для обслуживания аутентифицированных HTTP-запросов.
- **anon:** Это анонимная роль, присваиваемая клиентам, которые не предоставили JWT токен или не включили утверждение роли в токене.
- **user:** Эта роль представляет собой аутентифицированного пользователя с конкретными правами доступа.

Эти роли создаем и настраиваем мы сами, так что их названия можно и заменить.

При переключении на нужную роль используется команда:

```sql
SET LOCAL ROLE *role_name*;
```

Обратите внимание, что администратор базы данных должен разрешить роли аутентификатора переключиться на этого пользователя, предварительно выполнив

```sql
GRANT *role_name* TO authenticator;
```

Для определения пользователей используются JWT токены, передаваемые в заголовке запроса. Если токен не предоставлен или не содержит утверждения о роли, PostgREST переключается на анонимную роль. Администратор базы данных должен правильно настроить разрешения анонимной роли, чтобы анонимные пользователи не могли видеть или изменять то, что им не следует.

## Создание необходимых ролей

Давайте создадим необходимые нам роли

```sql
CREATE ROLE authenticator LOGIN NOINHERIT NOCREATEDB NOCREATEROLE NOSUPERUSER;
CREATE ROLE anon NOLOGIN;
CREATE ROLE webuser NOLOGIN;

grant anon to authenticator;
grant webuser to authenticator;
```

На рисунке ниже можно увидеть, как сервер обрабатывает аутентификацию: успешная аутентификация приводит к переключению на роль пользователя, указанную в запросе, в противном случае сервер переключается на анонимную роль.

![roles_img](https://github.com/Ilshatikoo/Cat-Facts-postgrest/blob/main/img/roles.png)

## Управление пользователями с помощью SQL

PostgREST дает хороший функционал по управлению пользователями используя SQL, но для начала её нужно настроить.

Первое что нужно сделать это создать схему basic_auth, в которой будет находиться вся логика по работе с пользователями. Эту схему ни в коем случае нельзя публиковать в api.

Создадим схему basic_auth

```sql
create schema if not exists basic_auth;
```

Создадим таблицу, в которой будем хранить наших юзеров.

```sql
create table if not exists
basic_auth.users (
  email    text primary key check ( email ~* '^.+@.+\..+$' ),
  pass     text not null check (length(pass) < 512),
  role     name not null check (length(role) < 512)
);
```

Поле role будет соответствовать ролям с доступом, которые мы ранее создали (например, anon и webuser).

Создадим хранимую процедуру, которая будет проверять существование роли в базе данных, а также триггер, который будет вызывать эту процедуру.

```sql
create or replace function
basic_auth.check_role_exists() returns trigger as $$
begin
  if not exists (select 1 from pg_roles as r where r.rolname = new.role) then
    raise foreign_key_violation using message =
      'unknown database role: ' || new.role;
    return null;
  end if;
  return new;
end
$$ language plpgsql;

drop trigger if exists ensure_user_role_exists on basic_auth.users;
create constraint trigger ensure_user_role_exists
  after insert or update on basic_auth.users
  for each row
  execute procedure basic_auth.check_role_exists();
```

Далее создадим хранимую процедуру и триггер для шифрования паролей с использованием расширения pgcrypto.

```sql
create extension if not exists pgcrypto;

create or replace function
basic_auth.encrypt_pass() returns trigger as $$
begin
  if tg_op = 'INSERT' or new.pass <> old.pass then
    new.pass = crypt(new.pass, gen_salt('bf'));
  end if;
  return new;
end
$$ language plpgsql;

drop trigger if exists encrypt_pass on basic_auth.users;
create trigger encrypt_pass
  before insert or update on basic_auth.users
  for each row
  execute procedure basic_auth.encrypt_pass();
```

Теперь создадим хранимую процедуру, которая будет возвращать роль базы данных для пользователя, если указанный email и пароль будут верны.

```sql
create or replace function
basic_auth.user_role(email text, pass text) returns name
  language plpgsql
  as $$
begin
  return (
  select role from basic_auth.users
   where users.email = user_role.email
     and users.pass = crypt(user_role.pass, users.pass)
  );
end;
$$;
```

## Точка входа в систему

У нас уже есть наши роли для сопоставления с нашими юзерами, теперь нам нужно дать возможность получать jwt токены для работы с нашим api.

Создадим свойство БД, в котором будем хранить наш сикрет, который будет использоваться для создания jwt токена. "reallyreallyreallyreallyverysafe" используется в качестве примера. Вам нужно будет придумать своё кодовое слово для генерации токена

```sql
ALTER DATABASE cat_facts SET "app.jwt_secret" TO 'reallyreallyreallyreallyverysafe';
```

Теперь создадим хранимую процедуру, которая будет вызываться через api и  возвращать токен пользователю. В следующем коде будет использоваться расширение pgjwt, которого по дефолту нет в postgres. Вам нужно будет его доставить самим по инструкции вот [здесь](https://github.com/michelp/pgjwt). Если для изучения материала вы используете postgres в контейнере, то вы можете воспользоваться моим докер файлом в папке build, в котором я уже всё подготовил.

```sql
CREATE EXTENSION if not exists pgjwt WITH SCHEMA public;

CREATE TYPE basic_auth.jwt_token AS (
  token text
);

create or replace function
login(email text, pass text) returns basic_auth.jwt_token as $$
declare
  _role name;
  result basic_auth.jwt_token;
begin
  -- check email and password
  select basic_auth.user_role(email, pass) into _role;
  if _role is null then
    raise invalid_password using message = 'invalid user or password';
  end if;
  select sign(
      row_to_json(r), current_setting('app.jwt_secret')
    ) as token
    from (
      select _role as role, login.email as email,
         extract(epoch from now())::integer + 60*60 as exp
    ) r
    into result;
  return result;
end;
$$ language plpgsql security definer;

grant execute on function login(text,text) to anon;
```

Теперь давайте выдадим разрешение для роли anon на использование схемы и получения данных, а для роли webuser право на создание сущностей в таблице breeds.

```sql
grant usage on schema public to anon;
grant select on public.breeds to anon;

grant usage on schema public to webuser;
grant all on public.breeds to webuser;
grant usage, select on sequence public.breeds_id_seq to webuser;
```

Мы сделали так чтобы любой не авторизованный пользователь или пользователь с ролью anon мог получать данные с таблицы breeds, а пользователи с ролью webuser могли получать и создавать сущности.

Теперь мы можем можно создать пользователя и получить токен для работы с api. Для добавления пользователя используется следующий запрос.

```sql
INSERT INTO basic_auth.users (email, pass, role) VALUES ('fooo@bar.com', 'sdfsdf', 'anon')
```

## Запуск сервера

Для запуска **PostgREST** используется файл конфигурации. Создайте файл postgrest.conf со следующим содержимым

```
db-uri = "postgres://user:password@localhost:5432/cat_facts"
db-schemas = "public"
db-anon-role = "anon"
jwt-secret = "reallyreallyreallyreallyverysafe"
openapi-mode = "ignore-privileges"
```

Запуск производится следующей командой

```bash
./postgrest postgrest.conf
```

## API

Теперь у нас появилась возможность получения информации через api.

### Получение сущностей

Чтобы получить данные о породах кошек из таблицы breeds, используйте следующий запрос:

```bash
curl --location 'http://localhost:3000/breeds' \
--header 'Content-Type: application/json'
```

В ответ получим следующее

```json
[
    {
        "id": 1,
        "breed": "Siamese",
        "country": "Thailand",
        "origin": "Natural",
        "coat": "Short",
        "pattern": "Colorpoint"
    },
    {
        "id": 2,
        "breed": "Maine Coon",
        "country": "United States",
        "origin": "Natural",
        "coat": "Long",
        "pattern": "Tabby"
    },
    {
        "id": 3,
        "breed": "Persian",
        "country": "Iran",
        "origin": "Natural",
        "coat": "Long",
        "pattern": "Solid"
    }
]
```

### Получение JWT токена

Для выполнения запросов от имени пользователя необходимо получить JWT токен. Это можно сделать, отправив запрос на эндпоинт /rpc/login:

```bash
curl --location 'http://localhost:3000/rpc/login' \
--header 'Content-Type: application/json' \
--data-raw '{ "email": "fooo@bar.com", "pass": "sdfsdf" }'
```

В ответ получим нужный нам токен

```json
{"token":"eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJyb2xlIjoiYW5vbiIsImVtYWlsIjoiZm9vQGJhci5jb20iLCJleHAiOjE3MTU5NjE5MjF9.yRIXGWgCH3xMfEaakF0Gg4uNOUo2nVpZfIXWw5-ahss"}
```

### Отправка запросов с JWT токеном

После получения JWT токена, отправляйте запросы с этим токеном в заголовке Authorization. Например:

```bash
curl --location 'http://localhost:3000/breeds' \
--header 'Content-Type: application/json' \
--header 'Authorization: Bearer token'
```

### Создание новой сущности

UPD. Тут и далее не забудьте создать пользователя с правами на создание/редактирование сущностей и получить его jwt токен

Чтобы создать новую запись о породе кошек, используйте следующий запрос:

```bash
curl --location 'http://localhost:3000/breeds' \
--header 'Authorization: Bearer token' \
--header 'Content-Type: application/json' \
--data '{
    "breed": "test",
    "country": "test",
    "origin": "test",
    "coat": "test",
    "pattern": "test"
}'
```

В ответ на успешное создание записи вы получите пустой ответ с кодом 201.

### Получение определенной сущности

Чтобы получить информацию о конкретной породе кошек, используйте запрос с соответствующим фильтром:

```bash
curl --location 'http://localhost:3000/breeds?breed=eq.Siamese' \
--header 'Content-Type: application/json' \
--header 'Authorization: Bearer token'
```

Оператор `eq` означает "равно". Другие операторы можно найти в [документации](https://postgrest.org/en/v12/references/api/tables_views.html).

## Использование хранимых процедур

В postgres хранимые процедуры представляют собой набор инструкций SQL, собранных вместе для выполнения какой-либо конкретной задачи. Хранимые процедуры сильно упрощают работу с данными.

### Создание хранимой процедуры

В качестве примера создадим хранимую процедуру, которая будет возвращать случайную породу кошек.

```sql
CREATE OR REPLACE FUNCTION get_random_breed()
RETURNS SETOF breeds AS
$$
DECLARE
    random_row breeds;
BEGIN
    SELECT * INTO random_row
    FROM breeds
    OFFSET floor(random() * (SELECT count(*) FROM breeds))
    LIMIT 1;

    RETURN NEXT random_row;
END;
$$
LANGUAGE plpgsql;
```

Процедуру можно вызвать прямо из SQL запроса:

```sql
SELECT * FROM get_random_breed();
```

### Вызов хранимой процедуры через API

Чтобы вызвать хранимую процедуру через API, используйте префикс `/rpc/` и название процедуры:

```bash
curl --location --request GET 'http://localhost:3000/rpc/get_random_breed' \
--header 'Content-Type: application/json' \
--header 'Authorization: Bearer token' \
--data-raw '{ "email": "foo@bar.com", "pass": "foobar" }'
```

В ответ получим случайную породу

```json
[
    {
        "id": 2,
        "breed": "Maine Coon",
        "country": "United States",
        "origin": "Natural",
        "coat": "Long",
        "pattern": "Tabby"
    }
]
```

## Вывод
В общем и целом, эта статья представляет руководство по созданию и использованию API на основе PostgreSQL с помощью PostgREST, обеспечивая все необходимые инструменты для эффективной работы с данными через API.
