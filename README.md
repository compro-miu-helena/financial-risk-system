# Financial Risk System

## Overview
The Financial Risk System imports end-of-day trade and counterparty data, enriches the data, calculates exposure by counterparty, generates an Excel-compatible risk report, distributes it to authorized business users before 9am Singapore time, and allows privileged users to maintain the calculation parameters.

## Key Assumptions
- The Trade Data System and Reference Data System provide XML files as scheduled end-of-day exports.
- The report is distributed as a CSV file so it can be imported into Microsoft Excel.
- Authentication and authorization are handled centrally through the bank identity platform.
- Monitoring alerts are sent to the Central Monitoring Service through SNMP traps.
- Input files and report-generation metadata are retained for one year for audit and traceability.

## A. Use Case Diagram
```mermaid
flowchart LR
    BU[Business User]
    AU[Authorized Parameter Admin]
    TDS[Trade Data System]
    RDS[Reference Data System]
    IDP[Identity Provider]
    CMS[Central Monitoring Service]

    subgraph FRS[Financial Risk System]
        UC1((Authenticate User))
        UC2((Import Trade Data))
        UC3((Import Counterparty Data))
        UC4((Generate Risk Report))
        UC5((Download or Receive Risk Report))
        UC6((Maintain Risk Parameters))
        UC7((View Audit Trail))
        UC8((Send Monitoring Alert))
    end

    BU --> UC1
    BU --> UC5
    BU --> UC7
    AU --> UC1
    AU --> UC6
    TDS --> UC2
    RDS --> UC3
    IDP --> UC1
    UC4 --> UC2
    UC4 --> UC3
    UC4 --> UC8
    UC8 --> CMS
```

## B. Activity Diagram: Create Risk Report
```mermaid
flowchart TD
    A([Start]) --> B[Receive scheduled trade XML and counterparty XML]
    B --> C[Validate file availability and format]
    C -->|Invalid or missing| D[Log error and raise fatal alert]
    D --> E([End])
    C -->|Valid| F[Load trade data]
    F --> G[Load counterparty data]
    G --> H[Load active risk parameters]
    H --> I[Join trades with counterparties]
    I --> J{More counterparties to process?}
    J -->|Yes| K[Calculate counterparty risk]
    K --> L{Calculation successful?}
    L -->|Yes| M[Store result in report dataset]
    L -->|No| N[Log calculation error and continue]
    M --> J
    N --> J
    J -->|No| O[Generate CSV risk report]
    O --> P[Store report and input-file references for audit]
    P --> Q[Distribute report to authorized users]
    Q --> R{Completed before 9am Singapore?}
    R -->|Yes| S[Log successful report generation]
    R -->|No| T[Log breach and send SNMP alert]
    S --> U([End])
    T --> U
```

## C. Context Diagram
```mermaid
flowchart LR
    TDS[Trade Data System\nXML export of trades]
    RDS[Reference Data System\nXML export of counterparties]
    IDP[Bank Identity Provider\nAuthentication and authorization]
    CMS[Central Monitoring Service\nSNMP trap receiver]
    USERS[Business Users\nView risk reports]
    ADMINS[Parameter Admins\nMaintain calculation parameters]

    FRS[Financial Risk System]

    TDS -->|Daily trade XML| FRS
    RDS -->|Daily counterparty XML| FRS
    IDP <--> |Login, roles| FRS
    FRS -->|CSV risk report| USERS
    ADMINS <--> |Parameter maintenance| FRS
    FRS -->|SNMP traps| CMS
```

## D. Container Diagram
```mermaid
flowchart LR
    subgraph Ext[External Systems]
        TDS[Trade Data System]
        RDS[Reference Data System]
        IDP[Identity Provider]
        CMS[Central Monitoring Service]
        USERS[Business Users]
    end

    subgraph FRS[Financial Risk System]
        UI[Web Application\nReport access and parameter admin]
        API[Risk API\nAuthentication, orchestration, audit]
        ING[Ingestion Service\nXML import and validation]
        CALC[Risk Calculation Service\nEnrichment and exposure calculation]
        DIST[Report Distribution Service\nCSV generation and delivery]
        SCHED[Scheduler / Batch Runner\nNightly processing]
        DB[(Operational Database)]
        FILES[(Archive Storage\nInput files and reports)]
    end

    TDS --> ING
    RDS --> ING
    IDP <--> UI
    IDP <--> API
    USERS <--> UI
    UI <--> API
    SCHED --> ING
    SCHED --> CALC
    SCHED --> DIST
    ING --> DB
    ING --> FILES
    CALC <--> DB
    DIST <--> DB
    DIST --> FILES
    DIST --> USERS
    API <--> DB
    API <--> FILES
    API --> CMS
    SCHED --> CMS
```

## E. Component Diagram
```mermaid
flowchart TD
    subgraph RiskAPI[Risk API / Processing Components]
        AUTH[Auth Controller]
        PARAM[Parameter Management Component]
        IMPORT[Import Orchestrator]
        TRADE[Trade XML Parser]
        CP[Counterparty XML Parser]
        JOIN[Data Enrichment Component]
        ENGINE[Risk Engine]
        REPORT[Report Builder]
        AUDIT[Audit Logger]
        ALERT[Monitoring and Alert Component]
        REPO[Repositories]
    end

    AUTH --> REPO
    PARAM --> REPO
    PARAM --> AUDIT
    IMPORT --> TRADE
    IMPORT --> CP
    TRADE --> REPO
    CP --> REPO
    IMPORT --> AUDIT
    JOIN --> REPO
    ENGINE --> JOIN
    ENGINE --> REPO
    ENGINE --> AUDIT
    REPORT --> ENGINE
    REPORT --> REPO
    REPORT --> AUDIT
    REPORT --> ALERT
    ALERT --> AUDIT
```

## F. Sequence Diagram: Create Risk Report
```mermaid
sequenceDiagram
    autonumber
    participant SCH as Scheduler
    participant ING as Ingestion Service
    participant TDS as Trade Data System
    participant RDS as Reference Data System
    participant DB as Operational Database
    participant CALC as Risk Calculation Service
    participant PST as Parameter Store
    participant REP as Report Distribution Service
    participant AUD as Audit Log
    participant CMS as Central Monitoring Service
    participant USR as Authorized Business Users

    SCH->>ING: Start nightly batch
    ING->>TDS: Read trade XML export
    TDS-->>ING: Trade XML
    ING->>RDS: Read counterparty XML export
    RDS-->>ING: Counterparty XML
    ING->>ING: Validate and parse files
    ING->>DB: Store imported trades and counterparties
    ING->>AUD: Log import status and retained input references

    SCH->>CALC: Start risk calculation
    CALC->>DB: Load imported trades and counterparties
    CALC->>PST: Load active calculation parameters
    PST-->>CALC: Parameter set
    CALC->>CALC: Enrich trades and calculate exposure by counterparty
    CALC->>AUD: Log calculation results and per-counterparty errors
    CALC-->>REP: Risk results dataset

    REP->>REP: Generate CSV report
    REP->>DB: Store report metadata
    REP->>AUD: Log report generation
    REP->>USR: Distribute report

    alt Report not generated before 9am Singapore
        REP->>CMS: Send SNMP trap
    else Fatal processing error
        CALC->>CMS: Send SNMP trap
    end
```

## Notes
- Counterparty calculation failures are logged individually so the overall batch can continue.
- Audit records should include the exact input files, parameter version, generation timestamp, and report identifier.
- Archive storage retains input XML files and generated reports for one year.
