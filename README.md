# Alpino API versie 0.2

Een API voor een Alpino-server.

Deze API wordt onder andere gebruikt door [PaQu](https://github.com/rug-compling/paqu).

## Status

Deze API is nog in ontwikkeling. Meedenkers zijn welkom.

TODO:

 * Dit vertalen in het Engels? Beoogde gebruikers begrijpen Nederlands.

Zie ook TODO's hieronder.

## Motivatie

Er waren al wel enkele Alpino-servers, maar geen met een publieke API.
De functionaliteit van die servers is beperkt. De een geeft op een
POST-request met een tekst de geparste zinnen direct terug in de
response. Dat is alleen geschikt voor zeer kleine teksten. Een andere
server verwerkt de toegestuurde tekst geheel offline, en het resultaat
kan pas gedownload worden als de verwerking is afgerond. Beiden zijn
niet geschikt voor een toepassing als
[PaQu](https://github.com/rug-compling/paqu).

De uitgangspunten van de huidige API zijn:

 * Een API met duidelijk beschreven opties en verwacht gedrag.
 * Geschikt voor de verwerking van kleine en zeer grote teksten, waarbij
   ook met grote teksten de resultaten vanaf het begin incrementeel
   opgevraagd kunnen worden, niet per se in de juiste volgorde.
 * Een API voor een server waarachter teksten in parallel verwerkt
   kunnen worden, door meerdere werkers, mogelijk verdeeld over meerdere
   machines. Op het moment dat er maar één tekst verwerkt wordt wordt
   het werk verdeeld over alle werkers.
 * Flexibel, toepasbaar voor meerdere soorten tekst, zoals doorlopende
   tekst, tekst die al is opgedeeld in een zin per regel, wel of niet
   getokeniseerd.

## Over de tokenizer en de parser

Alpino interpreteert bepaalde tekens op een speciale manier. Zie:
[Alpino User Guide: Special symbols in the input](http://www.let.rug.nl/vannoord/alp/Alpino/AlpinoUserGuide.html#_special_symbols_in_the_input)

Voor deze API is het van belang wat te doen met rechte haken. Wanneer je
de tekst laat tokeniseren door de Alpino-server, dan worden er escapes
gebruikt voor deze tokens:

invoer   | uitvoer   | interpretatie door de parser
---------|-----------|-----------------------------
`[`      | `\[`      | `[`
`]`      | `\]`      | `]`
`\[`     | `\\[`     | `\[`
`\]`     | `\\]`     | `\]`

Er is dus geen manier om een token door de parser te laten interpreteren
als `\\[` of `\\]`.

Wanneer je tekst uploadt naar de server die je zelf getokeniseerd hebt
gelden er andere regels. Zie onder, bij **Request: parse**.

## Request en result

Deze API beschrijft hoe je met json via http kunt communiceren met een
server die Alpino gebruikt om tekst te parsen.

Elke verzoek aan de server bestaat uit een json-object. Daarna kan nog
data volgen als platte tekst. Alle verzoeken dienen met methode POST te
worden gegaan.

Elk verzoek bevat een element `request` die aangeeft wat de opdracht aan
de server is.

request    | omschrijving
-----------| ------------
`parse`    | verzoek om tekst te parsen, zonodig eerst tokeniseren
`tokenize` | verzoek om tekst te tokeniseren
`output`   | verzoek om (een deel van) de resultaten van een parse terug te sturen
`cancel`   | verzoek om een parse te annuleren
`info`     | verzoek om informatie over de server

Elk resultaat verstuurd door de server is een json-object, type
`application/json`, met tenminste de elementen `code` en `status`.
Uitzondering: de uitvoer van `tokenize` is, als er geen fout is
opgetreden, platte tekst, type `text/plain`.

element   | type
----------|-------
`code`    | number
`status`  | string

Wanneer er een fout is opgetreden, een code groter dan 299, dan is er
ook een element `message`, dat nadere informatie kan bevatten.

element   | type
----------|-------
`message` | string

Er worden onderstaande codes gebruikt. Dit zijn standaard
http-statuscodes. Bij sommige fouten kan het zijn dat de server geen
json terug stuurt, maar alleen een http-statuscode in de headers.

code | status                  | omschrijving
-----|-------------------------|----------------------------------
200  | `OK`                    |
202  | `Accepted`              | na succesvolle upload van tekst
400  | `Bad Request`           | fout van gebruiker
403  | `Forbidden`             | bijvoorbeeld: ip-adres geblokkeerd vanwege misbruik
429  | `Too Many Requests`     | toegang geweigerd vanwege te veel teksten tegelijk
500  | `Internal Server Error` | er ging iets fout in de server, wat niet fout zou mogen gaan
501  | `Not Implemented`       | er wordt een optie gevraagd die niet is geïmplementeerd
503  | `Service Unavailable`   | server is overbelast, probeer later opnieuw

De API definieert geen *back-off policy* voor status 503.

## Lijst van requests

### Request: parse

Doel: Zend een tekst naar de server om te laten parsen, zonodig eerst
tokeniseren. De tekst **moet** gecodeerd zijn in **UTF-8**, zonder BOM.

Parameters, allen optioneel:

element      | type   | default    | omschrijving
-------------|--------|------------|------------------------
`data_type`  | string | `text doc` | soort data: zie onder
`timeout`    | int    | `0`        | timeout in seconden voor parsen van één zin
`parser`     | string | `""`       | gebruik alternatieve parser
`max_tokens` | int    | `0`        | skip zinnen die meer dan dit aantal tokens hebben

Wat `data_type` betreft:

Dit is een type-aanduiding, eventueel gevolgd door een of meer opties,
alles gesplitst door spaties.

type    | omschrijving
--------|--------------------------------------------------------
`text`  | de data bestaat uit doorlopende tekst
`lines` | de data bestaat één zin per regel, met of zonder labels

Naast de types `text` en `lines` kan een server andere types
ondersteunen. Deze types moeten vermeld zijn in `extra_types` als
resultaat van een `info`-request.

Voor `data_type` is `text`:

 * Kan gevolgd worden door de tekst prefix die gebruikt wordt als begin
   van gegenereerde labels. Default: `doc`
 * TODO: specificatie voor exact gedrag van `partok`: opties `-i` en `-t`

Voor `data_type` is `lines`:

 * Een regel die met een `%` begint wordt beschouwd als commentaarregel,
   en genegeerd.
 * Als een regel (zonder `%` aan het begin) een `|` bevat, dan wordt dat
   geïnterpreteerd als scheidingsteken tussen label en zin.
 * De optie `tokens` geeft aan dat de zinnen al gesplitst zijn in
   tokens. Default: de zinnen zijn nog niet getokeniseerd.
 * In combinatie met de optie `tokens` kan als optie een escape-level
   meegegeven worden. Dit is een van `none`, `half` en `full`. Default:
   `half`

In onderstaande tabel staat hoe bepaalde tokens (eerste kolom) worden
geïnterpreteerd voor verschillende escape-levels.

token  | `none`   | `half` | `full`
-------|----------|--------|-------
`[`    | speciaal | `[`    | `[`
`]`    | speciaal | `]`    | `]`
`\[`   | `[`      | `[`    | `\[`
`\]`   | `]`      | `]`    | `\]`
`\\[`  | `\[`     | `\[`   | `\[`
`\\]`  | `\]`     | `\]`   | `\]`
`\\\[` | `\\\[`   | `\\\[` | `\\\[`
`\\\]` | `\\\]`   | `\\\]` | `\\\]`

Wat `timeout` betreft:

 * De server kan verschillende timeouts bieden. Als de exacte waarde er
   niet bij zit, wordt de dichtsbijzijnde gebruikt.
 * Waarde 0 betekent dat de server zijn default timeout moet gebruiken.

Wat `parser` betreft:

 * Er is bijvoorbeeld een alternatieve parser speciaal voor vraagzinnen.
 * Een onbekende waarde geeft een `501 Not Implemented`. (TODO: Of `400 Bad Request`?)
 * Waarde "" betekent dat de server de standaardparser moet gebruiken.

Wat `max_tokens` betreft:

 * De waarde 0 betekent geen limiet.
 * Als de waarde groter is dan de limiet die de server heeft ingesteld,
   dan geldt de limiet van de server.

Voorbeeld aanroep, tekst volgt na json-object:

```json
{
    "request": "parse",
    "data_type": "lines tokens none"
}
doc.1.p.1.s.1|Ik besta .
doc.1.p.1.s.2|Jij bestaat .
```

Bij succes krijg je deze elementen terug:

element           | type   |  omschrijving
------------------|--------|----------
`code`            | int    |`202`
`status`          | string | `Accepted`
`id`              | string | id van job
`interval`        | int    | tijd in seconden waarbinnen output opgevraagd moet worden voordat job wordt gecanceld
`number_of_lines` | int    | aantal zinnen, eventueel na splitsen van lopende tekst in zinnen
`timeout`         | int    | door parser gebruikte timeout in seconden per zin
`max_tokens`      | int    | door parser gebruikt maximum aantal tokens per zin

De waarde van `interval` is bij benadering. Als je ietsje over de tijd
heen zit voordat je uitvoer opvraagd, dan is er niets aan de hand, maar
als je ruim over de tijd heen gaat, dan wordt de job op de server
gecanceld.

Je mag ook eerder resultaten opvragen, bijvoorbeeld als je maar een of
twee zinnen laat parsen. Een goede strategie is om de eerste batch snel
op te vragen, en de wachttijd voor elke volgende batch te verlengen tot
je aan de waarde van `interval` zit.

Wat betreft `number_of_lines`, `timeout` en `max_tokes`: de waarde `-1`
geeft aan dat de werkelijke waarde om een of andere reden niet gegeven
kan worden.

Voorbeeld uitvoer:

```json
{
    "code": 202,
    "status": "Accepted",
    "id": "118587257602604880",
    "interval": 300,
    "number_of_lines": 2,
    "timeout": 60,
    "max_tokens": 100
}
```

### Request: tokenize

Doel: Zend een tekst naar de server om te laten tokeniseren. De tekst
**moet** gecodeerd zijn in **UTF-8**, zonder BOM.

Parameter, optioneel:

element      | type   | default    | omschrijving
-------------|--------|------------|------------------------
`data_type`  | string | `text doc` | soort data: zie onder

Soort data is een type-aanduiding, eventueel gevolgd door een of meer
opties, alles gesplitst door spaties.

type    | omschrijving
--------|--------------------------------------------------------
`text`  | de data bestaat uit doorlopende tekst
`lines` | de data bestaat één zin per regel, met of zonder labels

Naast de types `text` en `lines` kan een server andere types
ondersteunen. Deze types moeten vermeld zijn in `extra_types` als
resultaat van een `info`-request.

Voor `data_type` is `text`:

 * Kan gevolgd worden door de tekst prefix die gebruikt wordt als begin
   van gegenereerde labels. Default: `doc`
 * TODO: specificatie voor exact gedrag van `partok`: opties `-i` en `-t`

Voor `data_type` is `lines`:

 * Een regel die met een `%` begint wordt beschouwd als
   commentaarregel, en wordt gekopieerd naar de uitvoer zonder
   tokenisatie.
 * Als een regel (zonder `%` aan het begin) een `|` bevat dan wordt dat
   geïnterpreteerd als scheidingsteken tussen label en zin. Alleen het
   deel na de eerste `|` wordt getokeniseerd.

In beide gevallen kun je een `|` aan het begin van de regel toevoegen om
de speciale interpretatie van verdere `|` en `%` te voorkomen.

Voorbeeld aanroep, tekst volgt na json-object:

```json
{
    "request": "tokenize",
    "data_type": "text demo"
}
Ik besta. Jij bestaat.
```

Bij succes krijg je platte tekst terug, type `text/plain`.

Voorbeeld uitvoer:

```
demo.p.1.s.1|Ik besta .
demo.p.1.s.2|Jij bestaat .
```

### Request: output

Doel: Opvragen van (deel van) de uitvoer van een job, momenteel alleen
jobs van type `parse`.

Parameter, verplicht:

element   | type   | omschrijving
----------|--------|-------------
`id`      | string | id van de job

Voorbeeld aanroep:

```json
{
    "request": "output",
    "id": "118587257602604880"
}
```

Resultaat als er geen fout is opgetreden:

element    | type   | omschrijving
-----------|--------|-----------
`code`     | int    | `200`
`status`   | string | `OK`
`finished` | bool   | `true` als parsen van alle zinnen is voltooid
`batch`    | array van items | de zinnen geparst tot nu toe sinds laatste aanroep

De zinnen in batch hoeven niet aansluitend te zijn, en de volgorde is niet
gedefinieerd.

Wanneer `finished` false is, dan dien je weer binnen de timeout de
volgende batch op te vragen.

Elementen in een item in `batch`:

element          | type   | voorwaarde | omschrijving
-----------------|--------|------------|-------------
`error`          | int    |            | `0`, `1` of `2`
`line_number`    | int    |            | zinnummer: eerste is nummer 1
`label`          | string | indien aanwezig | label van de zin
`sentence`       | string |            | de getokeniseerde zin
`alpino_ds`      | string | error: 0   | de parse van de zin
`log`            | string |            | error-uitvoer van de parser, of van een andere fout
`parser_build`   | string | optioneel  | indien bekend, en anders dan is vermeld door een `info`-request

TODO: iets anders verzinnen voor `error`

Waardes voor `error`:

waarde | betekenis
-------|----------
0      | alles OK
1      | zin overgeslagen
2      | interne serverfout / zin kon niet geparst worden

Voorbeeld uitvoer:

```json
{
    "code": 200,
    "status": "OK",
    "finished": true,
    "batch": [
{"error":0,"lineno":2,"label":"doc.1.p.1.s.2","sentence":"jij bestaat","xml":"<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n<alpino_ds version=\"1.5\">\n  <node begin=\"0\" cat=\"top\" end=\"2\" id=\"0\" rel=\"top\">\n    <node begin=\"0\" cat=\"smain\" end=\"2\" id=\"1\" rel=\"--\">\n      <node begin=\"0\" case=\"nom\" def=\"def\" end=\"1\" frame=\"pronoun(nwh,je,sg,de,nom,def)\" gen=\"de\" getal=\"ev\" id=\"2\" lcat=\"np\" lemma=\"jij\" naamval=\"nomin\" num=\"sg\" pdtype=\"pron\" per=\"je\" persoon=\"2v\" pos=\"pron\" postag=\"VNW(pers,pron,nomin,vol,2v,ev)\" pt=\"vnw\" rel=\"su\" rnum=\"sg\" root=\"jij\" sense=\"jij\" status=\"vol\" vwtype=\"pers\" wh=\"nwh\" word=\"jij\"/>\n      <node begin=\"1\" end=\"2\" frame=\"verb(hebben,sg3,intransitive)\" id=\"3\" infl=\"sg3\" lcat=\"smain\" lemma=\"bestaan\" pos=\"verb\" postag=\"WW(pv,tgw,met-t)\" pt=\"ww\" pvagr=\"met-t\" pvtijd=\"tgw\" rel=\"hd\" root=\"besta\" sc=\"intransitive\" sense=\"besta\" stype=\"declarative\" tense=\"present\" word=\"bestaat\" wvorm=\"pv\"/>\n    </node>\n  </node>\n  <sentence sentid=\"82.161.115.144\">jij bestaat</sentence>\n</alpino_ds>\n","log":""},
{"error":0,"lineno":1,"label":"doc.1.p.1.s.1","sentence":"ik besta","xml":"<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n<alpino_ds version=\"1.5\">\n  <node begin=\"0\" cat=\"top\" end=\"2\" id=\"0\" rel=\"top\">\n    <node begin=\"0\" cat=\"smain\" end=\"2\" id=\"1\" rel=\"--\">\n      <node begin=\"0\" case=\"nom\" def=\"def\" end=\"1\" frame=\"pronoun(nwh,fir,sg,de,nom,def)\" gen=\"de\" getal=\"ev\" id=\"2\" lcat=\"np\" lemma=\"ik\" naamval=\"nomin\" num=\"sg\" pdtype=\"pron\" per=\"fir\" persoon=\"1\" pos=\"pron\" postag=\"VNW(pers,pron,nomin,vol,1,ev)\" pt=\"vnw\" rel=\"su\" rnum=\"sg\" root=\"ik\" sense=\"ik\" status=\"vol\" vwtype=\"pers\" wh=\"nwh\" word=\"ik\"/>\n      <node begin=\"1\" end=\"2\" frame=\"verb(hebben,sg1,intransitive)\" id=\"3\" infl=\"sg1\" lcat=\"smain\" lemma=\"bestaan\" pos=\"verb\" postag=\"WW(pv,tgw,ev)\" pt=\"ww\" pvagr=\"ev\" pvtijd=\"tgw\" rel=\"hd\" root=\"besta\" sc=\"intransitive\" sense=\"besta\" stype=\"declarative\" tense=\"present\" word=\"besta\" wvorm=\"pv\"/>\n    </node>\n  </node>\n  <sentence sentid=\"82.161.115.144\">ik besta</sentence>\n</alpino_ds>\n","log":""}
    ]
}
```

### Request: cancel

Doel: Een lopende job afbreken.

Jobs worden ook afgebroken als de timeout is verstreken.

Parameter, verplicht:

element   | type   | omschrijving
----------|--------|-------------
`id`      | string | id van job

Voorbeeld aanroep:

```json
{
    "request": "cancel",
    "id": "118587257602604880"
}
```

Voorbeeld uitvoer:

```json
{
    "code": 200,
    "status": "OK"
}
```

### Request: info

Doel: Details over de huidige status van de server opvragen.

Geen parameters

Voorbeeld aanroep:

```json
{
    "request": "info"
}
```

Resultaat:

element              | type           |           | omschrijving
---------------------|----------------|-----------|------------------
`api_major`          | int            |           | API major version number
`api_minor`          | int            |           | API minor version number
`parser_build`       | string         | optioneel | Alpino-versie van de parser
`tokenizer_build`    | string         | optioneel | Alpino-versie van de tokenizer
`about`              | string         | optioneel | vrije tekst, beschrijving, contact-info, etc.
`workers`            | int            | optioneel | aantal werkers op dit moment, bezig of wachtend
`total_running_jobs` | int            | optioneel | totaal aantal jobs (parse) die op dit moment verwerkt worden
`timeout_default`    | int            | optioneel | default timeout in seconden voor parsen van één zin
`timeout_max`        | int            | optioneel | de maximale timeout in seconden voor parsen van één zin
`timeout_values`     | [ int ... ]    | optioneel | ondersteunde timeouts voor parsen van één zin
`parsers`            | [ string ... ] | optioneel | lijst met alternatieve parsers
`max_jobs`           | int            |           | maximum aantal gelijktijdige jobs per IP-adres
`max_tokens`         | int            | optioneel | maximum lengte van een zin in tokens, 0 is geen limiet
`extra_types`        | [ string ... ] | optioneel | extra types voor `data_type`

Voorbeeld uitvoer:

```json
{
    "code": 200,
    "status": "OK",
    "api_major": 0,
    "api_minor": 1,
	"parser_build": "Alpino-x86_64-Linux-glibc-2.19-20973-sicstus",
	"tokenizer_build": "Alpino-x86_64-Linux-glibc-2.19-20973-sicstus",
    "about": "Experimentele server om de API te testen.\nNiet voor productiedoeleinden.\nContact: Peter Kleiweg <p.c.j.kleiweg@rug.nl>",
    "workers": 10,
    "total_running_jobs": 45,
    "timeout_default": 60,
    "timeout_max": 600,
    "timeout_values": [ 20, 60, 180, 600 ],
    "parsers": [ "qa" ],
    "max_jobs": 6,
    "maxtokens": 100,
    "extra_types": [ ]
}
```

Wat `parser_build` en `tokenizer_build` betreft:

 * Dit is de tekst uit het bestand `$ALPINO_HOME/version`. 
 * Parsen en tokeniseren hoeft niet op dezelfde machine te gebeuren,
   vandaar dat ze apart worden gegeven.
 * Parsen kan op meerdere machines gebeuren, met verschillende versies
   van Alpino. Afwijken versies kunnen vermeld worden per zin in een
   `batch`.

Wat `max_jobs` betreft:

 * Overschrijding van de limiet kan leiden tot een ban van het IP-adres van de
   client.

Wat `max_tokens` betreft:

 * De limiet kan door de client lager worden gezet, maar niet hoger.
 * Zinnen die te lang zijn resulteren in zins-status `skipped`.
