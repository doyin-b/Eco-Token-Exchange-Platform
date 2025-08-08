# Eco Token Exchange Platform

A comprehensive smart contract for issuing, verifying, and trading environmental tokens on the Stacks blockchain. This platform enables transparent tracking of environmental initiatives and facilitates the creation of tokenized environmental assets.

## Overview

The Eco Token Exchange Platform provides a complete ecosystem for environmental token management, supporting the full lifecycle from initiative registration to token retirement. Built on Clarity (Stacks blockchain), it ensures transparency, immutability, and secure trading of environmental assets.

## Core Features

### 🌱 Initiative Management
- **Registration**: Environmental project managers can register new initiatives
- **Validation**: Approved validators verify initiatives and issue tokens
- **Tracking**: Complete lifecycle tracking from registration to completion

### 🪙 Token Operations
- **Lot Creation**: Managers create tradeable token lots with vintage years
- **Purchasing**: Users buy tokens using STX payments
- **Transfers**: Peer-to-peer token transfers between users
- **Withdrawal**: Permanent token retirement with certificate generation

### 👥 Role-Based Access
- **Administrators**: Manage validator approvals and certificates
- **Validators**: Verify initiatives and authorize token issuance
- **Managers**: Control their registered initiatives
- **Users**: Buy, hold, transfer, and withdraw tokens

## Supported Initiative Categories

- Renewable Energy Projects
- Reforestation Programs  
- Methane Capture Systems
- Energy Efficiency Improvements
- Carbon Capture Technologies

## Key Data Structures

### Environmental Initiatives
```clarity
{
  title: string,
  details: string,
  region: string,
  manager: principal,
  category: string,
  launch-date: uint,
  completion-date: uint,
  total-tokens: uint,
  available-tokens: uint,
  retired-tokens: uint,
  validated: bool,
  state: string  // pending, active, completed, suspended
}
```

### Token Lots
```clarity
{
  initiative-id: uint,
  vintage: uint,
  amount: uint,
  available: uint,
  unit-price: uint,
  lot-state: string  // available, sold, retired
}
```

## Main Functions

### Public Functions

**Initiative Management:**
- `register-initiative()` - Register new environmental initiative
- `validate-initiative()` - Validate initiative and issue tokens
- `approve-validator()` - Authorize new validators (admin only)

**Token Operations:**
- `create-token-lot()` - Create tradeable token lots
- `buy-eco-tokens()` - Purchase tokens from available lots
- `transfer-tokens()` - Transfer tokens between users
- `withdraw-tokens()` - Permanently retire tokens
- `generate-withdrawal-certificate()` - Issue retirement certificates (admin only)

### Read-Only Functions

- `get-initiative-details()` - Retrieve initiative information
- `get-lot-details()` - Get token lot information
- `get-token-holding()` - Check user token balances
- `get-withdrawal-details()` - View retirement records

## Usage Examples

### Registering an Initiative
```clarity
(register-initiative 
  "Solar Farm Project" 
  "100MW solar installation in renewable energy zone"
  "California, USA"
  "renewable-energy"
  u1640995200  ;; launch date
  u1672531200  ;; completion date  
  "https://registry.example.com/project/123")
```

### Buying Tokens
```clarity
(buy-eco-tokens u1 u100)  ;; Buy 100 tokens from lot #1
```

### Withdrawing Tokens
```clarity
(withdraw-tokens 
  u0          ;; initiative ID
  u2024       ;; vintage year
  u50         ;; amount to withdraw
  "Corporate sustainability offset"
  none)       ;; no beneficiary
```

## Security Features

- **Role-based access control** with admin and validator permissions
- **Input validation** on all parameters
- **State verification** before operations
- **STX payment integration** with automatic transfers
- **Immutable record keeping** of all transactions

## Token Economics

- Tokens are issued only after initiative validation
- Pricing is set by initiative managers per lot
- STX payments go directly to initiative managers
- Withdrawn tokens are permanently removed from circulation
- Complete audit trail maintained for regulatory compliance

## Integration Notes

- Compatible with SIP-010 fungible token standard
- No external dependencies (self-contained trait definition)
- Memory-based storage (no browser storage APIs)
- Built for Stacks blockchain deployment

## Development Status

This contract is designed for development and testing purposes. For production deployment, additional considerations include:
- Enhanced admin role management
- External oracle integration for validation data
- Advanced pricing mechanisms
- Batch operations for efficiency
- Integration with carbon registries
