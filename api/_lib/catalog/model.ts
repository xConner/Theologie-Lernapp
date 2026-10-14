// Normalisiertes Datenmodell des Veranstaltungskatalogs, unabhängig vom
// Quellsystem (UnivIS, später HISinOne). Die App und künftige Endpunkte
// kennen nur diese Typen; alles Systemspezifische steckt im Adapter
// (`univis/`). Überblick: docs/univis-integration-feasibility.md.
//
// Grundsätze:
// * Jede Entität behält ihre Quellkennung(en) (`source`), damit spätere
//   Abrufe Einträge wiederfinden und persönliche Stundenpläne zuordnen.
// * Eine Veranstaltung (`Course`) hat Terminregeln (`SessionRule`, so wie
//   die Quelle sie angibt) und daraus aufgelöste Einzeltermine
//   (`Occurrence`, konkrete Zeitintervalle). Unklare Regeln erzeugen keine
//   Termine, sondern `ScheduleIssue`s.
// * Von Personen nur Anzeigename (Titel, Vor-, Nachname) – keine Kontaktdaten.
//   Freitextfelder der Quelle (Anmeldehinweise u. a.) werden nicht übernommen.

/** Datum ohne Uhrzeit, `YYYY-MM-DD`. */
export type IsoDate = string;
/** Uhrzeit, `HH:MM` (24 h). */
export type LocalTime = string;
/** Zeitpunkt mit Offset, z. B. `2026-10-15T16:15:00+02:00`. */
export type IsoDateTime = string;

/** Herkunft eines Datensatzes. */
export interface SourceRef {
    /** Konfigurierte Quelle, z. B. `cau-univis`. */
    sourceId: string;
    /** Kennung im Quellsystem, z. B. UnivIS-`key`. */
    key: string;
}

/** Ein Abruf: woher, wann, wie groß. */
export interface Provenance {
    sourceId: string;
    system: 'univis' | 'hisinone' | 'other';
    institution: string;
    /** Abgefragte Adresse ohne Zugangsdaten. */
    url: string | null;
    fetchedAt: IsoDateTime;
    /** SHA-256 der Rohantwort, zur Erkennung unveränderter Abrufe. */
    contentHash: string | null;
}

/** Semester mit den für die Terminauflösung nötigen Zeiträumen. */
export interface Semester {
    /** Systemneutral, z. B. `2026w`, `2027s`. */
    id: string;
    label: string;
    /** Gesamtes Semester (für Einzeltermine außerhalb der Vorlesungszeit). */
    start: IsoDate;
    end: IsoDate;
    /** Vorlesungszeit: Rahmen für wiederkehrende Termine. */
    lectureStart: IsoDate;
    lectureEnd: IsoDate;
    /** Unterrichtsfreie Zeiträume (inklusive), z. B. Weihnachtspause. */
    breaks: { start: IsoDate; end: IsoDate; label: string }[];
    timeZone: 'Europe/Berlin';
    /** Beleg für die Daten (offizielle Seite). */
    reference: string;
}

export interface Person {
    id: string;
    source: SourceRef;
    /** „Prof. Dr. Erika Musterfrau“; null, wenn die Quelle keinen Namen liefert. */
    displayName: string | null;
}

export interface Room {
    id: string;
    source: SourceRef;
    shortName: string | null;
    name: string | null;
    /** „Online-Veranstaltung“ u. Ä. als Raum der Quelle. */
    online: boolean;
}

export type RepeatKind = 'weekly' | 'single' | 'block' | 'unknown';

/** Eine Terminangabe so, wie die Quelle sie macht (noch keine Daten). */
export interface SessionRule {
    /** Stabil aus Inhalt abgeleitet (Quelle liefert keine Terminkennung). */
    id: string;
    kind: RepeatKind;
    /** Bei `weekly`: 1 = jede Woche, 2 = 14-täglich. */
    intervalWeeks: number | null;
    /** ISO-Wochentage 1 = Montag … 7 = Sonntag. */
    weekdays: number[];
    startTime: LocalTime | null;
    endTime: LocalTime | null;
    startDate: IsoDate | null;
    endDate: IsoDate | null;
    excludedDates: IsoDate[];
    /** Ausschluss-Kennzeichen der Quelle, die kein Datum sind (Kiel: dreibuchstabig). */
    excludeCodes: string[];
    roomId: string | null;
    /** Rohwert der Quelle (z. B. `w1 4`), für Nachvollziehbarkeit. */
    raw: string | null;
}

export type IssueCode =
    | 'missing-time'
    | 'invalid-time'
    | 'missing-date'
    | 'unknown-pattern'
    | 'biweekly-phase-unknown'
    | 'block-pattern-unclear'
    | 'outside-semester'
    | 'exclude-not-matching'
    | 'block-continuous'
    | 'exclude-code-unknown'
    | 'nonexistent-local-time'
    | 'no-rules';

export interface ScheduleIssue {
    courseId: string;
    ruleId: string | null;
    code: IssueCode;
    /** `warning`: Termine fehlen oder sind unsicher; `info`: nur Hinweis. */
    severity: 'warning' | 'info';
    detail: string;
}

export type OccurrenceStatus = 'scheduled' | 'cancelled';

/** Ein konkreter Termin. Intervalle sind halboffen: [start, end). */
export interface Occurrence {
    /** `<ruleId>@<Datum>`: stabil, solange Regel und Datum gleich bleiben. */
    id: string;
    courseId: string;
    ruleId: string;
    date: IsoDate;
    start: IsoDateTime;
    end: IsoDateTime;
    roomId: string | null;
    /** `cancelled`: in der Quelle als Ausfall eingetragen (`exclude`). */
    status: OccurrenceStatus;
}

export interface Course {
    /** `<sourceId>:<semesterId>:<Quellkennung>` der Hauptfassung. */
    id: string;
    semesterId: string;
    /** Alle Quellkennungen, auch zusammengeführter Dubletten. */
    sources: SourceRef[];
    /** Veranstaltungsnummer der Quelle (Kiel: sechsstellig). */
    number: string | null;
    title: string;
    /** Modulkürzel, in Kiel aus der Klammer am Titelende. */
    moduleCodes: string[];
    /** Kürzel der Quelle, z. B. `V`, `S`, `UE`. */
    type: string | null;
    sws: number | null;
    ects: number | null;
    /** Anbietende Einrichtung(en), bei Dubletten mehrere. */
    organizations: string[];
    /**
     * Einrichtungshierarchie der Hauptfassung, oberste Ebene zuerst, z. B.
     * `["Theologische Fakultät", "Institut für …", "Abteilung …"]`
     * (UnivIS `orgunits`). Die erste Ebene ist in Kiel die Fakultät oder eine
     * fakultätsübergreifende Einrichtung.
     */
    organizationPath: string[];
    /** Gliederungspunkte des Vorlesungsverzeichnisses. */
    classification: string[];
    lecturerIds: string[];
    rules: SessionRule[];
    /** Zeitraum der Veranstaltung laut Quelle (falls angegeben). */
    startDate: IsoDate | null;
    endDate: IsoDate | null;
    /** Übernommen aus einer anderen Einrichtung (UnivIS-Import). */
    imported: boolean;
    /** Adresse der Detailseite in der Quelle (für Freitexte, Anmeldung). */
    detailUrl: string | null;
}

/** Ergebnis eines Abrufs nach Normalisierung, Dublettenprüfung und Auflösung. */
export interface CatalogSnapshot {
    provenance: Provenance;
    semester: Semester;
    courses: Course[];
    persons: Person[];
    rooms: Room[];
    occurrences: Occurrence[];
    issues: ScheduleIssue[];
    /** Zusammengeführte Dubletten: Hauptkennung → weitere Kennungen. */
    mergedDuplicates: { courseId: string; mergedKeys: string[]; reason: string }[];
    /** Gleiche Nummer, aber nicht eindeutig gleich – bewusst nicht zusammengeführt. */
    possibleDuplicates: { courseIds: string[]; reason: string }[];
}

/**
 * Veranstaltung, wie ein Adapter sie liefert: noch vor der
 * Dublettenprüfung, mit den Verknüpfungen der Quelle.
 */
export interface SourceCourse extends Course {
    /** Interne Nummer der Quelle (UnivIS `id`). */
    internalId: string | null;
    /** Interne Nummer der Ursprungsveranstaltung bei Importen (UnivIS `import_parent_id`). */
    importParentId: string | null;
}

/** Ergebnis eines Adapters vor Dublettenprüfung und Terminauflösung. */
export interface ParsedCatalog {
    courses: SourceCourse[];
    persons: Person[];
    rooms: Room[];
    /** Strukturprobleme der Antwort (fehlende Pflichtfelder, unbekannte Verweise). */
    warnings: string[];
}
