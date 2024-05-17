CREATE DATABASE cat_facts;

create table if not exists breeds (
    id SERIAL PRIMARY KEY,
    breed VARCHAR(100) NOT NULL,
    country VARCHAR(100) NOT NULL,
    origin VARCHAR(100) NOT NULL,
    coat VARCHAR(100) NOT NULL,
    pattern VARCHAR(100) NOT NULL
);

CREATE TABLE cat_facts (
    id SERIAL PRIMARY KEY,
    fact TEXT
);

INSERT INTO breeds (breed, country, origin, coat, pattern)
VALUES ('Siamese', 'Thailand', 'Natural', 'Short', 'Colorpoint');
INSERT INTO breeds (breed, country, origin, coat, pattern)
VALUES ('Maine Coon', 'United States', 'Natural', 'Long', 'Tabby');
INSERT INTO breeds (breed, country, origin, coat, pattern)
VALUES ('Persian', 'Iran', 'Natural', 'Long', 'Solid');

INSERT INTO cat_facts (fact) VALUES ('Кошки могут спать до 16 часов в сутки');
INSERT INTO cat_facts (fact) VALUES ('Кошки способны прыгать в 6 раз длиннее их высоты');
INSERT INTO cat_facts (fact) VALUES ('У кошек бывают до 100 различных звуковых сигналов');
INSERT INTO cat_facts (fact) VALUES ('Кошки могут видеть в темноте на расстояние до 6 раз больше, чем человек');