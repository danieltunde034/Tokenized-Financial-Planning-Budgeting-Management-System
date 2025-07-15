# Tokenized Financial Planning Budgeting Management System

A comprehensive blockchain-based budgeting system built on Stacks using Clarity smart contracts. This system provides decentralized financial planning, budget creation, allocation management, variance tracking, and adjustment coordination.

## System Overview

The system consists of five interconnected smart contracts that work together to provide a complete budgeting solution:

### 1. Budget Planner Verification (`budget-planner-verification.clar`)
- Validates and manages budget planner credentials
- Handles planner registration and verification
- Maintains planner reputation scores
- Provides access control for budget operations

### 2. Budget Creation (`budget-creation.clar`)
- Creates and manages organizational budgets
- Defines budget categories and limits
- Sets budget periods and timeframes
- Handles budget approval workflows

### 3. Allocation Management (`allocation-management.clar`)
- Manages budget allocations across categories
- Tracks allocation requests and approvals
- Handles fund distribution
- Maintains allocation history

### 4. Variance Tracking (`variance-tracking.clar`)
- Monitors actual vs budgeted amounts
- Calculates variance percentages
- Generates variance reports
- Triggers alerts for significant deviations

### 5. Adjustment Coordination (`adjustment-coordination.clar`)
- Coordinates budget adjustments and modifications
- Handles reallocation requests
- Manages emergency budget changes
- Maintains audit trail of all adjustments

## Key Features

- **Decentralized Budget Management**: All budget operations are recorded on-chain
- **Multi-level Authorization**: Different permission levels for planners, approvers, and administrators
- **Real-time Variance Tracking**: Continuous monitoring of budget performance
- **Transparent Audit Trail**: Complete history of all budget operations
- **Automated Compliance**: Built-in validation and approval workflows

## Data Structures

### Budget Structure
- Budget ID (unique identifier)
- Organization details
- Budget period (start/end dates)
- Total budget amount
- Category allocations
- Status (draft, approved, active, closed)

### Allocation Structure
- Allocation ID
- Budget reference
- Category information
- Allocated amount
- Spent amount
- Remaining balance

### Variance Structure
- Variance ID
- Budget and allocation references
- Actual vs budgeted amounts
- Variance percentage
- Variance type (favorable/unfavorable)

## Error Codes

- `ERR-NOT-AUTHORIZED (u100)`: Insufficient permissions
- `ERR-INVALID-INPUT (u101)`: Invalid input parameters
- `ERR-NOT-FOUND (u102)`: Resource not found
- `ERR-ALREADY-EXISTS (u103)`: Resource already exists
- `ERR-INSUFFICIENT-FUNDS (u104)`: Insufficient budget allocation
- `ERR-BUDGET-LOCKED (u105)`: Budget is locked for modifications
- `ERR-INVALID-PERIOD (u106)`: Invalid budget period
- `ERR-VARIANCE-THRESHOLD (u107)`: Variance exceeds threshold

## Usage Flow

1. **Planner Registration**: Budget planners register and get verified
2. **Budget Creation**: Create organizational budgets with categories
3. **Allocation Setup**: Allocate funds to different budget categories
4. **Spending Tracking**: Record actual spending against allocations
5. **Variance Monitoring**: System tracks and reports variances
6. **Budget Adjustments**: Make necessary adjustments based on performance

## Security Features

- Multi-signature requirements for large transactions
- Role-based access control
- Immutable audit trails
- Automated compliance checks
- Emergency pause functionality

## Testing

The system includes comprehensive tests using Vitest covering:
- Contract deployment and initialization
- Budget creation and management
- Allocation and spending workflows
- Variance calculation and reporting
- Adjustment coordination
- Error handling and edge cases

## Deployment

1. Install dependencies: `npm install`
2. Run tests: `npm test`
3. Deploy contracts using Clarinet: `clarinet deploy`

## License

MIT License - see LICENSE file for details
