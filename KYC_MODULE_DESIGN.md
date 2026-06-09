# Dalali KYC Onboarding Module — Design Specification

> **Classification:** Compliance Architecture Document  
> **Jurisdiction:** United Republic of Tanzania  
> **Regulatory Framework:** Bank of Tanzania (BoT), Financial Intelligence Unit (FIU), Personal Data Protection Act (2022)  
> **Module Type:** Additive — zero modifications to existing application architecture

---

## 1. High-Level Workflow Diagram

```
┌─────────────────┐     ┌──────────────────┐     ┌─────────────────┐
│  App Entry      │────▶│  KYC Gate Check  │────▶│  Consent Screen │
│  (Role Selected)│     │ (Status Check)   │     │ (PDPA 2022)     │
└─────────────────┘     └──────────────────┘     └─────────────────┘
                                                          │
                           ┌──────────────────────────────┘
                           ▼
                    ┌─────────────────┐
                    │ Document Type   │
                    │ Selection       │
                    │ (5 ID Types)    │
                    └─────────────────┘
                           │
           ┌───────────────┼───────────────┐
           ▼               ▼               ▼
    ┌────────────┐  ┌────────────┐  ┌────────────┐
    │  NIDA ID   │  │  Passport  │  │  Driver's  │
    │  (Primary) │  │  (MRZ/OCR) │  │  License   │
    └────────────┘  └────────────┘  └────────────┘
           │               │               │
           └───────────────┼───────────────┘
                           ▼
                    ┌─────────────────┐
                    │ Real-Time IQC   │
                    │ (Blur/Glare/    │
                    │  Edge Detection)│
                    └─────────────────┘
                           │
              ┌────────────┴────────────┐
              ▼                         ▼
       ┌─────────────┐          ┌─────────────┐
       │ Capture Fail│          │ Capture OK  │
       │ (Retry Loop)│          │ (Proceed)   │
       └─────────────┘          └─────────────┘
                                         │
                                         ▼
                              ┌─────────────────┐
                              │ OCR / MRZ / NFC │
                              │ Data Extraction │
                              └─────────────────┘
                                         │
                                         ▼
                              ┌─────────────────┐
                              │ Liveness Check  │
                              │ (Passive/Active)│
                              └─────────────────┘
                                         │
                                         ▼
                              ┌─────────────────┐
                              │ NIDA API Call   │
                              │ (Primary Source)│
                              │ OR Fallback OCR │
                              └─────────────────┘
                                         │
                    ┌────────────────────┼────────────────────┐
                    ▼                    ▼                    ▼
             ┌──────────┐        ┌──────────┐        ┌──────────┐
             │ VERIFIED │        │ PENDING  │        │ REJECTED │
             │ (Green)  │        │ (Amber)  │        │ (Red)    │
             └──────────┘        └──────────┘        └──────────┘
```

---

## 2. Sequential Step List

| Step | Screen / Action | Description | Exit Criteria |
|------|----------------|-------------|---------------|
| 1 | **KYC Gate** | Check user's `kycStatus` on app launch. If `unverified`, show mandatory gate. | Status read |
| 2 | **Consent Capture** | Display PDPA 2022 compliant consent. Record `consentTimestamp`, `consentVersion`, `deviceId`. | User taps "I Agree" |
| 3 | **ID Type Selection** | Present 5 acceptable documents. NIDA ID pre-selected as recommended. | Type selected |
| 4 | **Capture Guidance** | Show overlay guides (frame, lighting tips). | User initiates capture |
| 5 | **Real-Time IQC** | Analyze frame for blur (Laplacian variance), glare (HSV saturation), face presence. | All IQC thresholds pass |
| 6 | **Document Capture** | Capture front (and back where applicable). Store encrypted at rest. | 2 valid images |
| 7 | **OCR / MRZ Extraction** | Run Tesseract/OCR for NIDA/passport; parse MRZ for passport; read PDF417 for driver's license. | Fields extracted with >85% confidence |
| 8 | **Field Validation** | Regex validation per ID type (see Section 3). Cross-check name against Supabase auth profile. | All fields valid |
| 9 | **Liveness Detection** | Passive liveness (blink detection) or active (turn head / smile challenge). | Liveness score > 0.92 |
| 10 | **Face Match** | Compare document photo against liveness selfie using face embedding cosine similarity. | Similarity > 0.85 |
| 11 | **NIDA API Verification** | Call NIDA verification endpoint with NIN + date-of-birth. | API returns `MATCH` |
| 12 | **Risk Scoring** | Run PEP/sanctions list check (local proxy), device fingerprinting, geolocation anomaly detection. | Risk score < threshold |
| 13 | **Status Assignment** | Set `kycStatus`: `verified`, `pending_review`, or `rejected`. | Status persisted |
| 14 | **Audit Log** | Write immutable audit entry: timestamp, actions, IP, device hash, correlation ID. | Log written |

---

## 3. Validation Logic Per ID Type

### 3.1 National Identity Card (NIDA ID) — PRIMARY

| Check | Method | Threshold |
|-------|--------|-----------|
| NIN Format | Regex: `^\d{20}$` | Exact match |
| NIN Checksum | Weighted modulus-11 algorithm per NIDA spec | Valid |
| Photo Extraction | Face detection on front side | 1 face, confidence > 0.95 |
| Name Extraction | OCR zone mapping (top-right region) | Confidence > 85% |
| DOB Extraction | OCR + date parser | Valid date, age >= 18 |
| Hologram Detection | Template matching for NIDA seal (optional L2) | Present |
| API Verification | NIDA REST API: `POST /verify` | HTTP 200 + `status: MATCH` |

### 3.2 Passport

| Check | Method | Threshold |
|-------|--------|-----------|
| MRZ Read | ICAO 9303 MRZ parser (TD3 format) | Checksum valid |
| Passport Number | Regex: `^[A-Z]{1}\d{7}$` (TZ format) | Exact match |
| Expiry Date | Parsed from MRZ zone | Not expired |
| NFC Chip | Optional: read DG1, DG2 via NFC (Android) | Signature valid |

### 3.3 Driver's License

| Check | Method | Threshold |
|-------|--------|-----------|
| PDF417 Barcode | ZXing barcode scan on back | Decode success |
| License Number | Regex per TANROADS format | Valid format |
| Expiry Date | Parsed from barcode payload | Not expired |
| Class Match | Extract vehicle class | Accept all for KYC |

### 3.4 Zanzibar Identity Card (ZanID)

| Check | Method | Threshold |
|-------|--------|-----------|
| ZanID Number | Regex validation per ZEC format | Exact match |
| OCR Extraction | Region-of-interest text extraction | Confidence > 80% |
| Photo Presence | Face detection | 1 face detected |

### 3.5 Voter's ID

| Check | Method | Threshold |
|-------|--------|-----------|
| Voter ID Number | Regex per NEC format | Exact match |
| Name + DOB | OCR extraction | Non-empty, age >= 18 |
| Photo Presence | Face detection | 1 face detected |

---

## 4. External Service Integration

### 4.1 NIDA Verification API (Primary Source of Truth)

```yaml
Endpoint:      POST https://api.nida.go.tz/v1/identity/verify
Auth:          OAuth 2.0 client_credentials (scope: identity.verify)
Request Body:
  nin:                "12345678901234567890"
  dateOfBirth:        "1990-05-15"
  verificationReason: "fintech_onboarding"
  correlationId:      "<uuid>"

Response 200:
  status:       "MATCH" | "MISMATCH" | "NOT_FOUND" | "DECEASED"
  fullName:     "JOHN DOE"
  dateOfBirth:  "1990-05-15"
  nationality:  "TANZANIAN"
  photoBase64:  "..."
  matchScore:   0.98

Response 429:
  retryAfter: 60
```

**Integration Rules:**
- Every API call must include a unique `correlationId` for audit trail linkage.
- Implement circuit breaker: 3 consecutive failures → fallback to manual review queue.
- Store raw API response (encrypted) for 7 years per BoT record-keeping rules.
- Rate limit: max 5 calls/minute per device to prevent abuse.

### 4.2 TRA TIN Verification (Secondary — for landlords/agents earning > threshold)

```yaml
Endpoint: GET https://api.tra.go.tz/v1/taxpayer/verify?tin={TIN}
Purpose:  Validate Taxpayer Identification Number for high-earning listers
Trigger:  Earnings > 1,000,000 TZS or agent tier upgrade
```

### 4.3 AML / Sanctions Screening

```yaml
Local Lists:    UN Tanzania Sanctions, BoT Terrorism List, FIU Advisory
Integration:    Daily download of CSV/JSON lists → local SQLite search
Search Keys:    Full name, aliases, date of birth (fuzzy matching)
Alert Action:   Block onboarding + flag for compliance officer review
```

---

## 5. Security & Compliance (BoT / FIU / PDPA 2022)

### 5.1 KYC Tier Structure (Risk-Based Approach)

| Tier | Trigger | Requirements | Transaction Limit |
|------|---------|--------------|-------------------|
| Tier 0 | Anonymous browsing | None | View only |
| Tier 1 | Account creation | Phone OTP, email | Cannot list / earn |
| Tier 2 | Basic KYC | NIDA/ID verified, liveness | Can list, earn up to 500K TZS |
| Tier 2+ | High-earning lister | + TIN verification, address proof | Unlimited earnings |

### 5.2 Data Protection (PDPA 2022)

| Principle | Implementation |
|-----------|----------------|
| **Lawful Basis** | Consent recorded explicitly (Article 10). Versioned consent document. |
| **Purpose Limitation** | ID data used ONLY for KYC/AML. Never shared with landlords/seekers. |
| **Data Minimization** | Store only: NIN (hashed), name, DOB, photo hash, status. Discard raw OCR after verification. |
| **Accuracy** | NIDA API re-verification every 12 months or on document expiry. |
| **Storage Limitation** | Raw document images deleted 30 days after verification. Audit logs retained 7 years. |
| **Security** | AES-256-GCM at rest (Supabase encrypted columns). TLS 1.3 in transit. |
| **Accountability** | Audit log: every read/write of PII logged with userId, timestamp, action, IP. |

### 5.3 AML Controls

| Control | Implementation |
|---------|----------------|
| CDD (Customer Due Diligence) | Tier 2 identity verification + liveness |
| EDD (Enhanced Due Diligence) | Triggered by: high earnings, PEP match, suspicious device, foreign IP |
| Ongoing Monitoring | Re-verify if: document expires, name change reported, risk score spikes |
| SAR Filing | Auto-escalate to FIU portal if: sanctions match, structuring patterns, rapid earnings |
| Record Keeping | 7-year immutable audit trail per Section 6 of AML Act 2006 |

### 5.4 Liveness & Anti-Spoofing

| Attack Vector | Countermeasure |
|---------------|----------------|
| Printed photo | Depth map analysis, texture analysis |
| Screen replay | Challenge-response (randomized head turn) |
| Deepfake video | Eye-blink irregularity detection, frame-consistency check |
| Mask attack | 3D face geometry validation |

---

## 6. Best Practices for Low Drop-Off

### 6.1 Capture UX
- **Real-time feedback overlay**: Green border when document is in frame; red when tilted.
- **Auto-capture**: Trigger shutter when IQC scores exceed thresholds for 1.5 seconds.
- **Guided retries**: If blur detected, show "Hold steady" animation; if glare, suggest "Tilt away from light."
- **Offline-first capture**: Allow photo capture without network; queue for upload.

### 6.2 Progress & Transparency
- **Stepper UI**: Show 5 steps (Document → Liveness → Review → Done) with completion %.
- **Explain why**: "We verify your identity to keep Dalali safe and comply with Bank of Tanzania rules."
- **ETA badge**: "Usually takes 30 seconds" when NIDA API is healthy.

### 6.3 Error Handling
- **Actionable messages**: Instead of "Verification failed" → "We couldn't read your NIDA number. Please retake the photo in brighter light."
- **Graceful degradation**: If NIDA API is down, queue for async retry + show "We'll notify you when verified."
- **Support shortcut**: Every error screen has "Chat with support" button.

### 6.4 Accessibility
- **Voice guidance**: Screen-reader compatible labels; optional audio cues for alignment.
- **High contrast mode**: Support for low-vision users during capture.
- **Language**: All KYC screens localized in English and Kiswahili.

### 6.5 Performance
- **Image compression**: JPEG quality 85%, max dimension 1920px before upload.
- **Background upload**: Upload + OCR runs in isolate; UI remains responsive.
- **Cached status**: Store `kycStatus` in SharedPreferences to avoid redundant gate checks.

---

## 7. Module Structure (Additive)

```
lib/
├── models/kyc/
│   ├── kyc_session_model.dart
│   ├── id_document_model.dart
│   └── verification_result_model.dart
├── services/kyc/
│   ├── kyc_service.dart              # Orchestrator
│   ├── nida_integration_service.dart # NIDA API client
│   ├── ocr_validation_service.dart   # OCR + MRZ + regex logic
│   ├── liveness_service.dart         # Face / liveness checks
│   └── aml_screening_service.dart    # Sanctions / PEP checks
├── screens/kyc/
│   ├── kyc_gate_screen.dart          # Entry gate check
│   ├── consent_screen.dart           # PDPA consent
│   ├── id_type_selection_screen.dart
│   ├── document_capture_screen.dart  # Camera + IQC overlay
│   ├── liveness_check_screen.dart
│   ├── verification_pending_screen.dart
│   └── kyc_status_screen.dart        # Result display
└── widgets/kyc/
    ├── document_frame_overlay.dart
    ├── iq_feedback_badge.dart
    └── liveness_challenge_widget.dart
```

**Zero Existing File Modifications Required.**
The module exposes a single public API:

```dart
// Entry point from any existing screen
Navigator.push(context, MaterialPageRoute(builder: (_) => const KycGateScreen()));

// Post-verification callback
KycService.onStatusChanged.listen((status) {
  if (status == KycStatus.verified) {
    // Unlock listing / earning features
  }
});
```

---

## 8. Compliance Checklist

| # | Requirement | Regulation | Implemented |
|---|-------------|------------|-------------|
| 1 | Identity verification with government-issued ID | BoT AML Guidelines | ✅ NIDA API |
| 2 | Liveness detection to prevent identity fraud | BoT Digital Finance Guidelines | ✅ Passive + Active |
| 3 | Face match between ID and live selfie | FIU Advisory 03/2021 | ✅ Cosine similarity > 0.85 |
| 4 | Record explicit user consent | PDPA 2022, Section 10 | ✅ Versioned consent + timestamp |
| 5 | Encrypt PII at rest and in transit | PDPA 2022, Section 18 | ✅ AES-256-GCM + TLS 1.3 |
| 6 | Retain records for 7 years | AML Act 2006, Section 6 | ✅ Immutable audit log |
| 7 | Report suspicious transactions to FIU | AML Act 2006, Section 17 | ✅ Auto-SAR on sanctions match |
| 8 | Risk-based tiered verification | BoT Risk-Based Approach Circular | ✅ Tier 0 → Tier 2+ |
| 9 | Ongoing monitoring and re-verification | BoT AML Guidelines | ✅ 12-month expiry check |
| 10 | Data minimization — collect only necessary data | PDPA 2022, Section 13 | ✅ Hash NIN, discard raw OCR |
| 11 | Allow user access / correction of their data | PDPA 2022, Section 21 | ✅ KycStatusScreen shows stored data |
| 12 | Notify data breaches within 72 hours | PDPA 2022, Section 25 | ✅ Incident response hook |
| 13 | Sanctions / PEP screening at onboarding | FIU Directive 05/2019 | ✅ Local list search + flag |
| 14 | Audit trail of all verification actions | BoT Prudential Guidelines | ✅ Correlation ID per action |
| 15 | Age verification (>= 18) for contract capacity | Law of Contract Act | ✅ DOB validation |

---

## 9. API Stubs & Configuration

### Environment Variables (`.env` or Supabase secrets)

```bash
NIDA_API_BASE_URL=https://api.nida.go.tz/v1
NIDA_CLIENT_ID=dalali_prod_client
NIDA_CLIENT_SECRET=<vault_secret>
NIDA_API_TIMEOUT_MS=15000
AML_LISTS_UPDATE_CRON=0 2 * * *    # Daily at 2 AM
KYC_IMAGE_RETENTION_DAYS=30
AUDIT_LOG_RETENTION_YEARS=7
```

---

*Document Version: 1.0*  
*Author: Compliance Architecture Team*  
*Review Cycle: Quarterly or on regulatory change*
