-- ======================================================================
-- TP3 - Advanced Databases - Object-Relational model - pgAdmin 4
-- Database: tp3   (create it first, see the steps)
-- HOW TO RUN: select a block with the mouse, then press F5.
--             NEVER press F5 with nothing selected (it runs the whole file
--             and stops at the first error demo).
-- Run the exercises in order: 1, 2, 3, 4 (Exercise 4 uses the type adresse).
-- Lines marked "ERROR ON PURPOSE" must be run alone: the error shows in the
-- "Messages" tab, take your screenshot there.
-- ======================================================================


-- ######################################################################
-- EXERCISE 1 - Cinema network
-- ######################################################################

-- ---------- 1.1 SETUP (select this whole block, F5) ----------
CREATE TYPE adresse AS (
  rue   VARCHAR(60),
  ville VARCHAR(30),
  cp    VARCHAR(6));

CREATE TABLE cinema (
  id_cine INT PRIMARY KEY,
  nom     VARCHAR(50) NOT NULL,
  adr     adresse,
  salles  INT[]);

CREATE TABLE film (
  id_film   INT PRIMARY KEY,
  titre     VARCHAR(80) NOT NULL,
  annee     SMALLINT,
  duree_min SMALLINT CHECK (duree_min > 0),
  genres    TEXT[],
  acteurs   TEXT[]);

CREATE TABLE seance (
  id_seance   INT PRIMARY KEY,
  id_film     INT NOT NULL REFERENCES film(id_film),
  id_cine     INT NOT NULL REFERENCES cinema(id_cine),
  num_salle   SMALLINT NOT NULL,
  jour        DATE NOT NULL,
  heure       TIME NOT NULL,
  tarif       NUMERIC(6,2) CHECK (tarif >= 0),
  spectateurs INT DEFAULT 0 CHECK (spectateurs >= 0));

INSERT INTO cinema VALUES
 (1,'Cine Tassili',ROW('Rue de l Independance','Illizi','33000'),
    ARRAY[120,80]),
 (2,'Cine Hoggar',ROW('Avenue Emir Abdelkader','Djanet','11001'),
    ARRAY[200,150,60]),
 (3,'Cine Oasis',ROW('Rue 1er Novembre','Ouargla','30000'),
    ARRAY[100]);

INSERT INTO film VALUES
 (1,'Le Vent de Sable',2023,112,ARRAY['drame','aventure'],
    ARRAY['Samir Brahimi','Nadia Kaci','Omar Zidane']),
 (2,'Tassili',2021,95,ARRAY['documentaire'],
    ARRAY['Amine Ben']),
 (3,'Code 404',2024,105,ARRAY['science-fiction','thriller'],
    ARRAY['Lina Hadj','Karim Zed','Sara Kaci','Omar Zidane']),
 (4,'Le Dernier Caravanier',2022,130,ARRAY['drame','histoire'],
    ARRAY['Samir Brahimi','Omar Zidane']);

INSERT INTO seance VALUES
 (1,1,1,1,'2025-03-10','18:00',600,95),
 (2,1,2,2,'2025-03-10','20:30',700,140),
 (3,3,2,1,'2025-03-11','21:00',800,190),
 (4,3,1,2,'2025-03-11','19:00',600,60),
 (5,2,3,1,'2025-03-12','17:00',500,35),
 (6,4,1,1,'2025-03-12','20:00',600,110),
 (7,4,2,3,'2025-03-13','18:30',700,45);

-- ---------- STRUCTURE (replaces \d cinema and \d film) ----------
-- columns: data_type = ARRAY for arrays, USER-DEFINED for the composite type
SELECT table_name, column_name, data_type, udt_name
FROM information_schema.columns
WHERE table_name IN ('cinema','film')
ORDER BY table_name, ordinal_position;

-- constraints of the tables
SELECT conrelid::regclass AS table_name, conname, pg_get_constraintdef(oid) AS definition
FROM pg_constraint
WHERE conrelid IN ('cinema'::regclass, 'film'::regclass, 'seance'::regclass)
ORDER BY 1, 2;

-- fields of the composite type adresse
SELECT a.attname AS champ, format_type(a.atttypid, a.atttypmod) AS type
FROM pg_type t JOIN pg_attribute a ON a.attrelid = t.typrelid
WHERE t.typname = 'adresse' AND a.attnum > 0
ORDER BY a.attnum;

-- ---------- 1.3 QUESTIONS (select one query, F5) ----------
-- Q1 Cinemas of a city
SELECT nom, (adr).rue
FROM cinema
WHERE (adr).ville = 'Illizi';

-- Q2 Total capacity per cinema
SELECT c.nom, SUM(s) AS capacite_totale
FROM cinema c, unnest(c.salles) AS s
GROUP BY c.id_cine, c.nom
ORDER BY c.id_cine;

-- Q3 Big cinemas (more than two rooms)
SELECT nom
FROM cinema
WHERE cardinality(salles) > 2;

-- Q4 Drama films
SELECT titre
FROM film
WHERE 'drame' = ANY(genres);

-- Q5 Films that are both drame and histoire
SELECT titre
FROM film
WHERE genres @> ARRAY['drame','histoire'];

-- Q6 Lead actors
SELECT titre, acteurs[1] AS acteur_principal
FROM film
ORDER BY id_film;

-- Q7 Genre popularity
SELECT g AS genre, COUNT(*) AS nb_films
FROM film, unnest(genres) AS g
GROUP BY g
ORDER BY nb_films DESC, g;

-- Q8 Busy actors (at least two films)
SELECT a AS acteur, COUNT(*) AS nb_films
FROM film, unnest(acteurs) AS a
GROUP BY a
HAVING COUNT(*) >= 2
ORDER BY nb_films DESC, a;

-- Q9 Fill rate of every screening
SELECT s.id_seance, f.titre, c.nom AS cinema,
       ROUND(100.0 * s.spectateurs / c.salles[s.num_salle], 1) AS taux_remplissage_pct
FROM seance s
JOIN film f   ON f.id_film = s.id_film
JOIN cinema c ON c.id_cine = s.id_cine
ORDER BY s.id_seance;

-- Q10 Updates (run a, b, c one by one, then the checks)
UPDATE film   SET genres  = array_append(genres, 'comedie')       WHERE id_film = 2;
UPDATE film   SET acteurs = array_remove(acteurs, 'Omar Zidane')  WHERE id_film = 4;
UPDATE cinema SET salles  = salles || 90                          WHERE id_cine = 3;

SELECT id_film, genres FROM film WHERE id_film = 2;
SELECT id_film, acteurs FROM film WHERE id_film = 4;
SELECT id_cine, salles FROM cinema WHERE id_cine = 3;

-- ---------- ERROR ON PURPOSE (run alone) ----------
-- parentheses are required: adr.ville is read as table "adr", column "ville"
SELECT adr.ville FROM cinema;
-- correct version
SELECT (adr).ville FROM cinema;


-- ######################################################################
-- EXERCISE 2 - Vehicle rental agency (inheritance)
-- ######################################################################

-- ---------- 2.1 SETUP (select this whole block, F5) ----------
CREATE TABLE vehicule (
  immat      VARCHAR(12) PRIMARY KEY,
  marque     VARCHAR(30) NOT NULL,
  modele     VARCHAR(30),
  annee      SMALLINT,
  km         INT DEFAULT 0 CHECK (km >= 0),
  tarif_jour NUMERIC(8,2));

CREATE TABLE voiture (
  nb_places     SMALLINT,
  climatisation BOOLEAN DEFAULT true) INHERITS (vehicule);

CREATE TABLE camion (
  charge_max_kg INT,
  nb_essieux    SMALLINT) INHERITS (vehicule);

CREATE TABLE camion_electrique (
  autonomie_km          INT,
  capacite_batterie_kwh NUMERIC(5,1)) INHERITS (camion);

CREATE TABLE client (
  id_client INT PRIMARY KEY,
  nom       VARCHAR(50) NOT NULL,
  tel       VARCHAR(15)[]);

CREATE TABLE location (
  id_loc     INT PRIMARY KEY,
  immat      VARCHAR(12) NOT NULL,
  id_client  INT NOT NULL REFERENCES client(id_client),
  date_debut DATE NOT NULL,
  date_fin   DATE,
  CHECK (date_fin IS NULL OR date_fin >= date_debut));

INSERT INTO vehicule VALUES
 ('00101-116-16','Renault','Master',2019,85000,6000);

INSERT INTO voiture VALUES
 ('12345-120-33','Toyota','Hilux',2021,40000,9000,5,true),
 ('23456-121-33','Dacia','Logan',2020,60000,4500,5,false),
 ('34567-122-11','Hyundai','Accent',2022,22000,5000,5,true);

INSERT INTO camion VALUES
 ('45678-118-33','Mercedes','Actros',2018,210000,15000,18000,3),
 ('56789-119-30','Volvo','FH',2020,150000,16000,25000,3);

INSERT INTO camion_electrique VALUES
 ('67890-123-33','Volvo','FH Electric',2023,30000,22000,
  16000,2,300,540.0);

INSERT INTO client VALUES
 (1,'Amine Ben',ARRAY['0555111222']),
 (2,'Sara Kaci',ARRAY['0666222333','0777333444']),
 (3,'Karim Zed',ARRAY['0550000000']);

INSERT INTO location VALUES
 (1,'12345-120-33',1,'2025-03-01','2025-03-05'),
 (2,'45678-118-33',2,'2025-03-02','2025-03-09'),
 (3,'67890-123-33',2,'2025-03-10','2025-03-12'),
 (4,'12345-120-33',3,'2025-03-08','2025-03-10'),
 (5,'23456-121-33',1,'2025-03-15',NULL);

-- ---------- STRUCTURE (replaces \d vehicule and \d camion_electrique) ----------
-- who inherits from whom ("Inherits" / "Child tables")
SELECT c.relname AS child, p.relname AS parent
FROM pg_inherits i
JOIN pg_class c ON c.oid = i.inhrelid
JOIN pg_class p ON p.oid = i.inhparent
ORDER BY p.relname, c.relname;

-- columns of the two tables (inherited columns come first)
SELECT table_name, ordinal_position, column_name, data_type
FROM information_schema.columns
WHERE table_name IN ('vehicule','camion_electrique')
ORDER BY table_name, ordinal_position;

-- constraints (see which ones exist on the parent and on the children)
SELECT conrelid::regclass AS table_name, conname, pg_get_constraintdef(oid) AS definition
FROM pg_constraint
WHERE conrelid IN ('vehicule'::regclass, 'voiture'::regclass, 'camion'::regclass, 'camion_electrique'::regclass)
ORDER BY 1, 2;

-- ---------- 2.3 QUESTIONS ----------
-- Q1 All vehicles (parent + all children)
SELECT immat, marque, modele, tarif_jour
FROM vehicule
ORDER BY immat;

-- Q2 Only the parent
SELECT immat, marque, modele, tarif_jour
FROM ONLY vehicule;

-- Q3 Where is each row stored?
SELECT immat, tableoid::regclass AS type_vehicule
FROM vehicule
ORDER BY type_vehicule, immat;

-- Q4 Census per table
SELECT tableoid::regclass AS type_vehicule, COUNT(*) AS nb
FROM vehicule
GROUP BY tableoid::regclass
ORDER BY type_vehicule;

-- Q5 Vehicles made before 2021
SELECT immat, marque, annee, tableoid::regclass AS type_vehicule
FROM vehicule
WHERE annee < 2021
ORDER BY annee;

-- Q6 Green heavy trucks
SELECT immat, marque, modele, autonomie_km, charge_max_kg
FROM camion_electrique
WHERE autonomie_km > 250 AND charge_max_kg > 10000;

-- Q7 Average rate per kind
SELECT tableoid::regclass AS type_vehicule, ROUND(AVG(tarif_jour), 2) AS tarif_moyen
FROM vehicule
GROUP BY tableoid::regclass
ORDER BY type_vehicule;

-- Q8a Revenue of every finished rental
SELECT l.id_loc, v.immat, v.marque,
       (l.date_fin - l.date_debut) * v.tarif_jour AS revenu
FROM location l
JOIN vehicule v ON v.immat = l.immat
WHERE l.date_fin IS NOT NULL
ORDER BY l.id_loc;

-- Q8b Total per vehicle
SELECT v.immat, v.marque,
       SUM((l.date_fin - l.date_debut) * v.tarif_jour) AS revenu_total
FROM location l
JOIN vehicule v ON v.immat = l.immat
WHERE l.date_fin IS NOT NULL
GROUP BY v.immat, v.marque
ORDER BY revenu_total DESC;

-- Q9 Raise by 10% the rate of vehicles made before 2020 (through the parent)
UPDATE vehicule
SET tarif_jour = tarif_jour * 1.10
WHERE annee < 2020;

-- Q9 check: which child tables were modified?
SELECT tableoid::regclass AS type_vehicule, immat, annee, tarif_jour
FROM vehicule
ORDER BY annee;

-- Q10 Clients without rental (0 rows with this data: all 3 clients rented)
SELECT c.nom, c.tel[1] AS premier_tel
FROM client c
WHERE NOT EXISTS (SELECT 1 FROM location l WHERE l.id_client = c.id_client);

-- ---------- 2.4 EXPERIMENTS (run in this order, one by one) ----------
-- (a) is the primary key inherited? the duplicate is ACCEPTED
INSERT INTO voiture VALUES
 ('00101-116-16','Peugeot','208',2020,10000,4000,5,true);
SELECT tableoid::regclass AS table_reelle, immat, marque
FROM vehicule WHERE immat = '00101-116-16';

-- partial repair, then the duplicate inside voiture is refused
-- (but the same immat in voiture AND camion is still possible)
ALTER TABLE voiture ADD PRIMARY KEY (immat);
-- ERROR ON PURPOSE (duplicate inside voiture):
INSERT INTO voiture VALUES
 ('12345-120-33','Kia','Rio',2022,5000,4000,5,true);
-- cleanup of experiment (a)
DELETE FROM voiture WHERE marque = 'Peugeot';

-- (b) are CHECK / NOT NULL inherited?  ERROR ON PURPOSE (km = -5)
INSERT INTO camion VALUES
 ('99999-124-33','MAN','TGX',2022,-5,17000,20000,3);

-- (c) is a new column propagated to the children?
ALTER TABLE vehicule ADD COLUMN couleur VARCHAR(15);
SELECT immat, couleur FROM camion_electrique;

-- ---------- Integrity for location.immat (trigger instead of a foreign key) ----------
CREATE FUNCTION verifier_immat() RETURNS trigger AS $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM vehicule WHERE immat = NEW.immat) THEN
    RAISE EXCEPTION 'Unknown registration number: %', NEW.immat;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_verifier_immat
BEFORE INSERT OR UPDATE ON location
FOR EACH ROW EXECUTE FUNCTION verifier_immat();

-- ERROR ON PURPOSE (unknown vehicle)
INSERT INTO location VALUES (6,'00000-000-00',1,'2025-04-01',NULL);
-- accepted (vehicle stored in voiture)
INSERT INTO location VALUES (6,'34567-122-11',1,'2025-04-01',NULL);


-- ######################################################################
-- EXERCISE 3 - Football tournament (array of composite type)
-- ######################################################################

-- ---------- 3.1 SETUP (select this whole block, F5) ----------
CREATE TYPE joueur AS (
  nom    VARCHAR(40),
  numero SMALLINT,
  poste  VARCHAR(12),
  age    SMALLINT);

CREATE TABLE equipe (
  id_eq    INT PRIMARY KEY,
  nom      VARCHAR(40) NOT NULL,
  ville    VARCHAR(30),
  effectif joueur[]);

CREATE TABLE rencontre (
  id_match   INT PRIMARY KEY,
  dom        INT NOT NULL REFERENCES equipe(id_eq),
  ext        INT NOT NULL REFERENCES equipe(id_eq),
  date_match DATE NOT NULL,
  score      INT[2],
  CHECK (dom <> ext));

INSERT INTO equipe VALUES
 (1,'JS Saoura','Bechar',
  ARRAY[ROW('Yacine Brahimi',10,'milieu',28)::joueur,
        ROW('Omar Zidane',9,'attaquant',24)::joueur,
        ROW('Karim Zed',1,'gardien',31)::joueur]),
 (2,'CR Belouizdad','Alger',
  ARRAY[ROW('Amine Ben',7,'attaquant',22)::joueur,
        ROW('Sofiane Hadj',4,'defenseur',27)::joueur,
        ROW('Nabil Saadi',1,'gardien',35)::joueur,
        ROW('Rayan Kaci',8,'milieu',20)::joueur]),
 (3,'MC Alger','Alger',
  ARRAY[ROW('Walid Ali',9,'attaquant',26)::joueur,
        ROW('Hamza Cherif',5,'defenseur',29)::joueur]);

INSERT INTO rencontre VALUES
 (1,1,2,'2025-04-01',ARRAY[2,1]),
 (2,2,3,'2025-04-08',ARRAY[0,0]),
 (3,3,1,'2025-04-15',ARRAY[1,3]),
 (4,2,1,'2025-04-22',ARRAY[2,2]),
 (5,3,2,'2025-04-29',ARRAY[0,2]);

-- ---------- STRUCTURE (replaces \d equipe and \d joueur) ----------
SELECT table_name, column_name, data_type, udt_name
FROM information_schema.columns
WHERE table_name IN ('equipe','rencontre')
ORDER BY table_name, ordinal_position;

-- fields of the composite type joueur
SELECT a.attname AS champ, format_type(a.atttypid, a.atttypmod) AS type
FROM pg_type t JOIN pg_attribute a ON a.attrelid = t.typrelid
WHERE t.typname = 'joueur' AND a.attnum > 0
ORDER BY a.attnum;

-- ---------- 3.3 QUESTIONS ----------
-- Q1 Squad of JS Saoura, one player per row
SELECT j.nom, j.poste, j.age
FROM equipe e, unnest(e.effectif) AS j
WHERE e.nom = 'JS Saoura';

-- Q2 Squad size
SELECT nom, cardinality(effectif) AS nb_joueurs
FROM equipe
ORDER BY id_eq;

-- Q3 Goalkeepers
SELECT e.nom AS equipe, j.nom AS gardien
FROM equipe e, unnest(e.effectif) AS j
WHERE j.poste = 'gardien'
ORDER BY e.id_eq;

-- Q4a Average age per team
SELECT e.nom, ROUND(AVG(j.age), 1) AS age_moyen
FROM equipe e, unnest(e.effectif) AS j
GROUP BY e.id_eq, e.nom
ORDER BY e.id_eq;

-- Q4b Oldest player of the league
SELECT j.nom, j.age, e.nom AS equipe
FROM equipe e, unnest(e.effectif) AS j
ORDER BY j.age DESC
LIMIT 1;

-- Q5 Teams with an attacker under 25
SELECT DISTINCT e.nom
FROM equipe e, unnest(e.effectif) AS j
WHERE j.poste = 'attaquant' AND j.age < 25
ORDER BY e.nom;

-- Q6 Goals scored and conceded per team
WITH m AS (
  SELECT dom AS eq, score[1] AS pour, score[2] AS contre FROM rencontre
  UNION ALL
  SELECT ext,       score[2],         score[1]           FROM rencontre)
SELECT e.nom, SUM(m.pour) AS buts_marques, SUM(m.contre) AS buts_encaisses
FROM equipe e JOIN m ON m.eq = e.id_eq
GROUP BY e.id_eq, e.nom
ORDER BY e.id_eq;

-- Q7 League table
WITH m AS (
  SELECT dom AS eq, score[1] AS pour, score[2] AS contre FROM rencontre
  UNION ALL
  SELECT ext,       score[2],         score[1]           FROM rencontre)
SELECT e.nom AS equipe,
       COUNT(*)                                        AS joues,
       COUNT(*) FILTER (WHERE m.pour >  m.contre)      AS gagnes,
       COUNT(*) FILTER (WHERE m.pour =  m.contre)      AS nuls,
       COUNT(*) FILTER (WHERE m.pour <  m.contre)      AS perdus,
       3 * COUNT(*) FILTER (WHERE m.pour > m.contre)
         + COUNT(*) FILTER (WHERE m.pour = m.contre)   AS points,
       SUM(m.pour) - SUM(m.contre)                     AS diff
FROM equipe e JOIN m ON m.eq = e.id_eq
GROUP BY e.id_eq, e.nom
ORDER BY points DESC, diff DESC;

-- Q8 Transfers (a, b, c one by one, then the checks)
UPDATE equipe
SET effectif = effectif || ROW('Ilyes Boudiaf',11,'milieu',23)::joueur
WHERE nom = 'MC Alger';

UPDATE equipe
SET effectif[2] = ROW('Omar Zidane',19,'attaquant',24)::joueur
WHERE nom = 'JS Saoura';

UPDATE equipe
SET effectif = array_remove(effectif, ROW('Rayan Kaci',8,'milieu',20)::joueur)
WHERE nom = 'CR Belouizdad';

SELECT e.nom AS equipe, j.nom, j.numero, j.poste, j.age
FROM equipe e, unnest(e.effectif) AS j
ORDER BY e.id_eq, j.numero;

-- Q9 Flat view for BI tools, then query only the view
CREATE VIEW joueurs_flat AS
SELECT e.nom AS equipe, j.nom, j.numero, j.poste, j.age
FROM equipe e, unnest(e.effectif) AS j;

SELECT * FROM joueurs_flat WHERE age >= 25 ORDER BY equipe, nom;

-- ---------- ERRORS / EXPERIMENTS (run one by one) ----------
-- ERROR ON PURPOSE: without the cast ::joueur
INSERT INTO equipe VALUES
 (9,'Test FC','Test', ARRAY[ROW('Test',1,'gardien',20)]);

-- the bound [2] is not enforced: this is ACCEPTED (danger)
INSERT INTO rencontre VALUES (6,1,3,'2025-05-01',ARRAY[1,2,3]);
SELECT id_match, score, cardinality(score) AS taille FROM rencontre WHERE id_match = 6;
DELETE FROM rencontre WHERE id_match = 6;


-- ######################################################################
-- EXERCISE 4 - Research laboratory (flat -> object-relational)
-- ######################################################################

-- ---------- 4.1 SETUP (select this whole block, F5) ----------
CREATE TYPE chercheur_t AS (
  id_ch INT,
  nom   VARCHAR(50),
  grade VARCHAR(20),
  adr   adresse,
  tel   VARCHAR(15)[]);

CREATE TABLE chercheur OF chercheur_t (
  id_ch WITH OPTIONS PRIMARY KEY,
  nom   WITH OPTIONS NOT NULL);

CREATE TABLE publication (
  id_pub INT PRIMARY KEY,
  titre  VARCHAR(150) NOT NULL,
  annee  SMALLINT,
  revue  VARCHAR(80),
  mots   TEXT[]);

CREATE TABLE auteur_pub (
  id_pub INT REFERENCES publication(id_pub) ON DELETE CASCADE,
  id_ch  INT REFERENCES chercheur(id_ch),
  rang   SMALLINT CHECK (rang >= 1),
  PRIMARY KEY (id_pub, id_ch));

CREATE FUNCTION nb_publications(c chercheur) RETURNS BIGINT
  AS $$ SELECT count(*) FROM auteur_pub WHERE id_ch = c.id_ch $$
  LANGUAGE SQL STABLE;

INSERT INTO chercheur VALUES
 (1,'Dr Rahmani','Professeur',
    ROW('Cite 1000 logts','Illizi','33000'),
    ARRAY['0555123456','0666123456']),
 (2,'Dr Mansouri','MCA',
    ROW('Rue Didouche','Alger','16000'),
    ARRAY['0770111222']),
 (3,'Dr Ould Ali','MCB',
    ROW('Centre ville','Djanet','11001'),
    ARRAY['0550987654']),
 (4,'Sara Kaci','Doctorante',
    ROW('Cite Universitaire','Illizi','33000'),
    ARRAY['0661000111','0771000222','0551000333']),
 (5,'Omar Zidane','Doctorant',
    ROW('Rue des Palmiers','Ouargla','30000'),
    ARRAY['0555999888']);

INSERT INTO publication VALUES
 (1,'Indexation des bases objet-relationnelles',2022,'JDB',
    ARRAY['index','objet','SQL']),
 (2,'Fouille de donnees sahariennes',2023,'IJDS',
    ARRAY['donnees','fouille','Sahara','IA']),
 (3,'Apprentissage profond et bases de donnees',2024,'JDB',
    ARRAY['IA','SQL','deep learning']),
 (4,'Modelisation NoSQL',2021,'RIA',
    ARRAY['NoSQL','objet']);

INSERT INTO auteur_pub VALUES
 (1,1,1),(1,4,2),
 (2,2,1),(2,1,2),(2,3,3),
 (3,4,1),(3,1,2),
 (4,2,1);

-- ---------- STRUCTURE (replaces \d chercheur) ----------
-- "Typed table of type ..." : the table is built from the composite type chercheur_t
SELECT c.relname AS table_name, t.typname AS typed_table_of_type
FROM pg_class c JOIN pg_type t ON t.oid = c.reloftype
WHERE c.relname = 'chercheur';

SELECT column_name, data_type, udt_name
FROM information_schema.columns
WHERE table_name = 'chercheur'
ORDER BY ordinal_position;

-- ---------- 4.3 QUESTIONS ----------
-- Q1 Local researchers (Illizi) with their first phone
SELECT nom, tel[1] AS premier_tel
FROM chercheur
WHERE (adr).ville = 'Illizi'
ORDER BY id_ch;

-- Q2 Researchers with at least two phone numbers
SELECT nom, cardinality(tel) AS nb_tel
FROM chercheur
WHERE cardinality(tel) >= 2
ORDER BY id_ch;

-- Q3a Publications with the keyword SQL
SELECT titre
FROM publication
WHERE 'SQL' = ANY(mots)
ORDER BY id_pub;

-- Q3b Publications with both SQL and objet
SELECT titre
FROM publication
WHERE mots @> ARRAY['SQL','objet'];

-- Q4 Keyword frequency
SELECT m AS mot, COUNT(*) AS nb_publications
FROM publication, unnest(mots) AS m
GROUP BY m
ORDER BY nb_publications DESC, m;

-- Q5 Authors in order, one string per publication
SELECT p.titre,
       string_agg(c.nom, ', ' ORDER BY ap.rang) AS auteurs
FROM publication p
JOIN auteur_pub ap ON ap.id_pub = p.id_pub
JOIN chercheur c   ON c.id_ch = ap.id_ch
GROUP BY p.id_pub, p.titre
ORDER BY p.id_pub;

-- Q6 Authorships per city
SELECT (c.adr).ville AS ville, COUNT(*) AS nb_auteurs
FROM auteur_pub ap
JOIN chercheur c ON c.id_ch = ap.id_ch
GROUP BY (c.adr).ville
ORDER BY nb_auteurs DESC, ville;

-- Q7 Silent researchers, phones one per row
SELECT c.nom, t AS telephone
FROM chercheur c, unnest(c.tel) AS t
WHERE NOT EXISTS (SELECT 1 FROM auteur_pub ap WHERE ap.id_ch = c.id_ch);

-- Q8a Function notation
SELECT c.nom, nb_publications(c) AS nb
FROM chercheur c
ORDER BY nb DESC, c.nom;

-- Q8b Attribute notation
SELECT c.nom, c.nb_publications AS nb
FROM chercheur c
ORDER BY nb DESC, c.nom;

-- Q9 Flat view, then query it like a BI tool
CREATE VIEW chercheur_flat AS
SELECT id_ch, nom, grade,
       (adr).rue AS rue, (adr).ville AS ville, (adr).cp AS cp,
       tel[1] AS tel1
FROM chercheur;

SELECT ville, COUNT(*) AS nb_chercheurs
FROM chercheur_flat
GROUP BY ville
ORDER BY nb_chercheurs DESC, ville;

-- Q10 Updates (a, b, c one by one, then the checks)
UPDATE chercheur SET tel = array_append(tel, '0777001122') WHERE id_ch = 2;
UPDATE publication SET mots = array_remove(mots, 'objet') WHERE id_pub = 1;
UPDATE chercheur SET adr = ROW((adr).rue, 'Illizi', (adr).cp) WHERE id_ch = 5;

SELECT id_ch, nom, tel FROM chercheur WHERE id_ch = 2;
SELECT id_pub, mots FROM publication WHERE id_pub = 1;
SELECT id_ch, nom, adr FROM chercheur WHERE id_ch = 5;
