SET FOREIGN_KEY_CHECKS=0;

DROP DATABASE IF EXISTS world;

CREATE DATABASE world
    CHARACTER SET utf8mb4
    COLLATE utf8mb4_0900_ai_ci;

USE world;

CREATE TABLE country (
    Code CHAR(3) NOT NULL DEFAULT '',
    Name CHAR(52) NOT NULL DEFAULT '',
    Continent ENUM(
        'Asia',
        'Europe',
        'North America',
        'Africa',
        'Oceania',
        'Antarctica',
        'South America'
    ) NOT NULL DEFAULT 'Asia',
    Region CHAR(26) NOT NULL DEFAULT '',
    SurfaceArea DECIMAL(10,2) NOT NULL DEFAULT '0.00',
    IndepYear SMALLINT DEFAULT NULL,
    Population INT NOT NULL DEFAULT '0',
    LifeExpectancy DECIMAL(3,1) DEFAULT NULL,
    GNP DECIMAL(10,2) DEFAULT NULL,
    GNPOld DECIMAL(10,2) DEFAULT NULL,
    LocalName CHAR(45) NOT NULL DEFAULT '',
    GovernmentForm CHAR(45) NOT NULL DEFAULT '',
    HeadOfState CHAR(60) DEFAULT NULL,
    Capital INT DEFAULT NULL,
    Code2 CHAR(2) NOT NULL DEFAULT '',
    PRIMARY KEY (Code)
) ENGINE=InnoDB
  DEFAULT CHARSET=utf8mb4
  COLLATE=utf8mb4_0900_ai_ci
  ROW_FORMAT=DYNAMIC;

CREATE TABLE city (
    ID INT NOT NULL AUTO_INCREMENT,
    Name CHAR(35) NOT NULL DEFAULT '',
    CountryCode CHAR(3) NOT NULL DEFAULT '',
    District CHAR(20) NOT NULL DEFAULT '',
    Population INT NOT NULL DEFAULT '0',
    PRIMARY KEY (ID),
    KEY CountryCode (CountryCode),
    CONSTRAINT city_ibfk_1
        FOREIGN KEY (CountryCode)
        REFERENCES country (Code)
) ENGINE=InnoDB
  DEFAULT CHARSET=utf8mb4
  COLLATE=utf8mb4_0900_ai_ci
  ROW_FORMAT=DYNAMIC;

CREATE TABLE countrylanguage (
    CountryCode CHAR(3) NOT NULL DEFAULT '',
    Language CHAR(30) NOT NULL DEFAULT '',
    IsOfficial ENUM('T','F') NOT NULL DEFAULT 'F',
    Percentage DECIMAL(4,1) NOT NULL DEFAULT '0.0',
    PRIMARY KEY (CountryCode, Language),
    KEY CountryCode (CountryCode),
    CONSTRAINT countryLanguage_ibfk_1
        FOREIGN KEY (CountryCode)
        REFERENCES country (Code)
) ENGINE=InnoDB
  DEFAULT CHARSET=utf8mb4
  COLLATE=utf8mb4_0900_ai_ci
  ROW_FORMAT=DYNAMIC;

SET FOREIGN_KEY_CHECKS=1;
