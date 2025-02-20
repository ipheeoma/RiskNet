# RiskNet Smart Contract

A decentralized insurance protocol for protection against service failures, built on the Stacks blockchain.

## Overview

RiskNet is a decentralized insurance pool that allows members to contribute funds, report incidents related to service failures, and collectively vote on claim resolutions. The contract manages the entire lifecycle of insurance claims in a transparent and secure manner.

## Key Features

- **Pool-based Insurance Model**: Members deposit STX to gain protection coverage
- **Decentralized Governance**: Claims are approved through member voting
- **Time-bound Coverage**: Protection is active for a limited period after joining
- **Democratic Claims Resolution**: All members participate in claim validation

## Contract Constants

| Constant | Description |
|----------|-------------|
| `DECISION_WINDOW` | Voting period duration (~24 hours) |
| `COVERAGE_DURATION` | Period of active coverage (~10 days) |
| `MAX_COMPENSATION_AMOUNT` | Maximum compensation limit |

## Core Functions

### For Members

#### `deposit_funds`
Join the insurance pool by depositing STX tokens.
```clarity
(deposit_funds (payment_amount uint))
```
- **Parameters**: `payment_amount` - Amount of STX to deposit
- **Returns**: `(ok true)` on success
- **Errors**:
  - `ERR_INVALID_INPUT` - Invalid input values
  - `ERR_FUNDING_REQUIRED` - Zero amount not allowed
  - STX transfer failures

#### `report_incident`
File a claim for a service failure incident.
```clarity
(report_incident (affected_service principal) (compensation_amount uint))
```
- **Parameters**: 
  - `affected_service` - Principal of the failed service
  - `compensation_amount` - Requested compensation amount
- **Returns**: `(ok incident_id)` with the new incident ID
- **Errors**:
  - `ERR_ACCESS_DENIED` - Caller not an active member
  - `ERR_INVALID_INPUT` - Invalid service principal
  - `ERR_ZERO_AMOUNT` - Invalid compensation amount
  - `ERR_DEADLINE_PASSED` - Coverage period expired

#### `submit_decision`
Vote on a pending claim.
```clarity
(submit_decision (incident_id uint) (approve bool))
```
- **Parameters**:
  - `incident_id` - ID of the incident to vote on
  - `approve` - Boolean indicating approval/rejection
- **Returns**: `(ok true)` on successful vote
- **Errors**:
  - `ERR_ID_NOT_FOUND` - Invalid incident ID
  - `ERR_ACCESS_DENIED` - Caller not a member
  - `ERR_DEADLINE_PASSED` - Voting period closed
  - `ERR_PREVIOUS_PARTICIPATION` - Already voted

### System Functions

#### `increment_ledger_position`
Updates the system's block height tracker.
```clarity
(increment_ledger_position)
```
- **Returns**: `(ok updated_position)` with the new ledger position
- **Errors**:
  - `ERR_SEQUENTIAL_UPDATE` - Repeated calls from same principal

#### `fetch_chain_position`
Read-only function to check the current ledger position.
```clarity
(fetch_chain_position)
```
- **Returns**: Current ledger position value

## Error Codes

| Code | Description |
|------|-------------|
| `ERR_ACCESS_DENIED (u1)` | Caller lacks necessary permissions |
| `ERR_FUNDING_REQUIRED (u2)` | Insufficient funds provided |
| `ERR_INVALID_REQUEST (u3)` | Request parameters are invalid |
| `ERR_PREVIOUS_PARTICIPATION (u4)` | Already participated in this action |
| `ERR_DEADLINE_PASSED (u5)` | Action timeframe has expired |
| `ERR_SEQUENTIAL_UPDATE (u6)` | Sequential updates from same principal not allowed |
| `ERR_INVALID_INPUT (u7)` | Input validation failed |
| `ERR_ZERO_AMOUNT (u8)` | Zero amount not permitted |
| `ERR_ID_NOT_FOUND (u9)` | Referenced ID doesn't exist |

## Implementation Details

### Data Structures

The contract uses three primary data maps:
1. `protection_pool` - Tracks member deposits and coverage status
2. `incident_log` - Stores details about each reported incident
3. `ballot_record` - Records voting activity per member per incident

### Security Considerations

- Sequential update protection prevents manipulation of the ledger position
- Comprehensive input validation for all public functions
- Protection against duplicate voting
- Time-bound actions with deadline enforcement

## Usage Example

1. Become a member:
```clarity
;; Deposit 100 STX to join the pool
(contract-call? .risknet deposit_funds u100000000)
```

2. Report a service incident:
```clarity
;; Report an incident with service SP123... requesting 50 STX compensation
(contract-call? .risknet report_incident 'SP123456789ABCDEFGHJKL u50000000)
```

3. Vote on a claim:
```clarity
;; Approve incident #5
(contract-call? .risknet submit_decision u5 true)
```

4. Check current ledger position:
```clarity
(contract-call? .risknet fetch_chain_position)
```
