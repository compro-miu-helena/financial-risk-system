# Financial Risk System Architecture Analysis

## 1. Architectural Characteristics

The most important architectural characteristics for this system are:

1. Performance and timeliness
2. Availability
3. Security
4. Auditability and traceability
5. Modifiability
6. Reliability and recoverability
7. Scalability
8. Interoperability

## 2. Quality Attribute Scenarios

### 2.1 Performance and Timeliness

Scenario 1:
- Source: Nightly batch scheduler
- Stimulus: The 5pm New York XML exports become available.
- Environment: Normal end-of-day processing.
- Artifact: Ingestion, calculation, and report distribution pipeline.
- Response: The system imports files, calculates exposure, generates the CSV report, and distributes it to authorized users.
- Response measure: The report is available before 9am Singapore time.

Scenario 2:
- Source: Business user
- Stimulus: A user requests an already generated report.
- Environment: Normal business-hours usage.
- Artifact: Web application and report storage.
- Response: The system authenticates the user, checks authorization, and serves the report.
- Response measure: Report download starts within 5 seconds for normal network conditions.

### 2.2 Availability

Scenario 1:
- Source: Business user
- Stimulus: A user accesses the system while no batch is running.
- Environment: Routine operation.
- Artifact: Web application, API, report storage.
- Response: The system allows authenticated users to access available reports.
- Response measure: Report access is available 24x7 with less than 30 minutes planned or unplanned downtime per day.

Scenario 2:
- Source: Infrastructure fault
- Stimulus: The report distribution service fails during nightly processing.
- Environment: Active batch window.
- Artifact: Batch workflow and monitoring components.
- Response: The failure is logged, an SNMP trap is sent for fatal failure, and operators can restart or resume processing.
- Response measure: Either the report is still generated before 9am Singapore, or the monitoring service is alerted immediately.

### 2.3 Security

Scenario 1:
- Source: Unauthorized internal user
- Stimulus: The user attempts to open a risk report.
- Environment: User is connected to the bank network but lacks the required role.
- Artifact: Web application, API, identity integration.
- Response: The system authenticates the user, checks authorization, and denies access.
- Response measure: Unauthorized report access is blocked and logged in the audit trail.

Scenario 2:
- Source: Authorized business user without admin rights
- Stimulus: The user attempts to change risk calculation parameters.
- Environment: Normal operation.
- Artifact: Parameter management component.
- Response: The system rejects the update because the user lacks the admin role.
- Response measure: No parameter change is persisted and the rejected action is logged.

### 2.4 Auditability and Traceability

Scenario 1:
- Source: Auditor or operations analyst
- Stimulus: They need to determine which inputs produced a specific report.
- Environment: Post-processing review.
- Artifact: Audit log, archive storage, report metadata.
- Response: The system shows the report identifier, generation timestamp, parameter version, and exact input files used.
- Response measure: The full lineage of a report can be reconstructed without manual correlation across systems.

Scenario 2:
- Source: Parameter administrator
- Stimulus: A risk calculation parameter is updated.
- Environment: Normal administration.
- Artifact: Parameter management and audit logging.
- Response: The old value, new value, user identity, timestamp, and reason/context are recorded.
- Response measure: Every parameter modification is attributable to a specific authorized user.

### 2.5 Modifiability

Scenario 1:
- Source: Risk team
- Stimulus: A new external parameter is added to the calculation.
- Environment: Planned enhancement.
- Artifact: Parameter store, admin UI, risk engine.
- Response: The new parameter is added with limited change to surrounding components.
- Response measure: The change is implemented without redesigning ingestion, reporting, or authentication components.

Scenario 2:
- Source: Enterprise architecture team
- Stimulus: The current Reference Data System is replaced by the new organization-wide reference system within 3 months.
- Environment: Planned system integration change.
- Artifact: Counterparty ingestion interface.
- Response: The system adapts by replacing or extending the reference-data adapter/parser.
- Response measure: The change is isolated mainly to the ingestion boundary and does not require rewriting the risk engine.

### 2.6 Reliability and Recoverability

Scenario 1:
- Source: Malformed trade or counterparty file
- Stimulus: XML input is missing, corrupted, or invalid.
- Environment: Nightly batch processing.
- Artifact: Ingestion service.
- Response: The system validates the file, logs the error, stops or quarantines invalid input as appropriate, and raises a fatal alert when processing cannot safely continue.
- Response measure: Invalid input never produces a silent wrong report.

Scenario 2:
- Source: Data quality issue
- Stimulus: One counterparty record is missing reference data needed for enrichment.
- Environment: Batch calculation.
- Artifact: Enrichment and risk engine.
- Response: The system logs the per-counterparty error and continues processing other counterparties.
- Response measure: A single bad record does not cause total batch failure unless policy requires full-stop behavior.

### 2.7 Scalability

Scenario 1:
- Source: Business growth
- Stimulus: Trade volume grows from about 5,000 trades to roughly 23,000+ trades over five years.
- Environment: Nightly batch processing.
- Artifact: Ingestion pipeline, database, risk engine.
- Response: The system processes the larger data set within the batch window.
- Response measure: End-to-end processing still completes before 9am Singapore.

Scenario 2:
- Source: Global user base
- Stimulus: 40 to 50 users access reports from London, New York, and Singapore.
- Environment: Peak report-consumption period after report publication.
- Artifact: Web app, API, report storage.
- Response: The system supports concurrent report access without degrading batch execution.
- Response measure: Concurrent access does not delay report availability or cause service instability.

### 2.8 Interoperability

Scenario 1:
- Source: Trade Data System and Reference Data System
- Stimulus: Daily XML exports are delivered in the agreed format.
- Environment: Nightly batch processing.
- Artifact: Ingestion adapters and XML parsers.
- Response: The system reads and validates both XML formats and maps them into the internal model.
- Response measure: Both source feeds are ingested without manual intervention.

Scenario 2:
- Source: Central Monitoring Service
- Stimulus: A fatal processing failure occurs or the report misses the 9am Singapore deadline.
- Environment: Runtime fault condition.
- Artifact: Monitoring and alert component.
- Response: The system emits an SNMP trap with enough context for operations follow-up.
- Response measure: The central monitoring platform receives and can correlate the alert.

## 3. Risks in the Proposed Architecture

### Risk 1: Tight coupling to file formats and source systems

The ingestion design assumes stable XML exports from TDS and the current RDS. The reference system is already known to be changing within three months, so the current design risks expensive rework if format or delivery mechanics change.

Impact:
- Delayed migration to the new reference platform
- Broken nightly batch after source-system change
- Increased maintenance cost around parsers and mapping logic

### Risk 2: Single nightly batch window creates operational concentration risk

The core workflow is batch-oriented and deadline-driven. If ingestion or calculation starts late, fails, or needs rerun, there is limited time before 9am Singapore.

Impact:
- Missed reporting deadline
- Repeated manual intervention by operations
- Higher business risk from stale or unavailable reports

### Risk 3: Single operational database may become a bottleneck

The database is used for imported data, calculated results, report metadata, audit information, and parameter storage. That concentration is simple initially but can turn into contention or recovery complexity.

Impact:
- Slower batch runs
- Contention between report access and nightly processing
- Larger blast radius during database incidents

### Risk 4: Parameter changes can invalidate report consistency

If parameters are updated close to or during batch execution, the system may produce results based on an unclear or partially applied parameter set unless versioning and runtime locking are explicit.

Impact:
- Non-repeatable risk numbers
- Audit disputes over which parameter set was used
- Potentially incorrect business decisions

### Risk 5: Per-record error continuation can hide material data quality problems

Continuing after individual counterparty calculation failures improves resilience, but it also creates a risk that the final report looks complete while excluding important exposures.

Impact:
- Incomplete or misleading risk report
- Hidden data quality issues
- Loss of trust in the system

### Risk 6: Report distribution approach may expose sensitive data

The architecture shows report distribution to users but does not yet define whether reports are downloaded from a secured portal, emailed, copied to shares, or cached locally. Some distribution mechanisms would create unnecessary data leakage risk.

Impact:
- Unauthorized disclosure of risk data
- Difficulty enforcing revocation and least privilege
- Weak auditability of who accessed which report

### Risk 7: Monitoring is reactive but not necessarily diagnostic

SNMP traps for fatal errors and missed deadlines satisfy the requirement, but they may not be enough for fast root-cause analysis without structured batch state, correlation IDs, and richer operational telemetry.

Impact:
- Longer incident resolution time
- Repeated failures due to poor observability
- More manual log inspection by support staff

### Risk 8: Archive retention design may become hard to manage over one year

Input files and generated reports must be retained for one year. Without a clear archival strategy, storage growth, indexing, retrieval, and integrity verification may become operational pain points.

Impact:
- Difficult audits
- Storage inefficiency
- Slow evidence retrieval during investigations

## 4. Risk Mitigation Options

### Mitigations for Risk 1

- Introduce explicit adapter interfaces for trade and counterparty imports.
- Isolate XML parsing from the canonical domain model.
- Version the import schema and support side-by-side parsers during RDS migration.
- Add contract tests using sample source-system files.

### Mitigations for Risk 2

- Persist checkpoint state after each major batch stage.
- Make ingestion, calculation, and report generation restartable and idempotent.
- Start processing as soon as files are available instead of waiting for a single late batch trigger if operationally possible.
- Define runbooks and automated retries for transient failures.

### Mitigations for Risk 3

- Separate logical schemas or storage areas for operational data, audit data, and archived report metadata.
- Add read-optimized access paths or replicas for report retrieval if needed.
- Archive old batch data out of the hot operational store on a scheduled basis.
- Load-test the database against the five-year growth forecast.

### Mitigations for Risk 4

- Version calculation parameters and always bind a batch run to a single immutable parameter version.
- Prevent parameter edits while a batch is running, or defer activation until the next run.
- Record the parameter version in both audit logs and report metadata.
- Support rollback to the previous approved parameter set.

### Mitigations for Risk 5

- Define severity thresholds for data quality failures.
- Mark the report as partial when error counts exceed a threshold.
- Include a data-quality summary in the report metadata and operations dashboard.
- Route high-severity enrichment failures to operations for immediate review.

### Mitigations for Risk 6

- Prefer report access through the authenticated web application instead of broad file or email distribution.
- Enforce role-based authorization at the API and report-download layers.
- Log every report access event with user, report ID, and timestamp.
- Encrypt data at rest and in transit inside the bank network.

### Mitigations for Risk 7

- Add structured application logs with correlation IDs per batch run.
- Track stage-level metrics such as import duration, number of rejected records, calculation duration, and distribution status.
- Provide an operations dashboard for nightly batch status.
- Include actionable context in SNMP alerts, such as batch ID and failing component.

### Mitigations for Risk 8

- Use dedicated archive storage with lifecycle management and immutable retention settings where appropriate.
- Store metadata indexes for fast retrieval of files by report ID, date, and batch ID.
- Periodically verify archive readability and integrity.
- Define purge automation for records older than the one-year retention requirement.

## 5. Recommended Architectural Priorities

If the architecture is refined further, the highest-priority decisions should be:

1. Make batch execution restartable and parameter-versioned.
2. Isolate source-system integration behind explicit adapters because the reference data source is changing soon.
3. Treat report delivery as a secured portal capability, not an uncontrolled file-distribution problem.
4. Strengthen observability beyond basic SNMP traps so missed deadlines can be diagnosed quickly.
