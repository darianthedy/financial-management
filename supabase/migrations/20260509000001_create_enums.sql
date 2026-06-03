CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

CREATE TYPE account_type AS ENUM (
  'bank_account',
  'credit_card',
  'digital_wallet',
  'cash',
  'other'
);

CREATE TYPE transaction_type AS ENUM (
  'income',
  'expense',
  'transfer'
);

CREATE TYPE transaction_status AS ENUM (
  'confirmed',
  'pending',
  'dismissed'
);

CREATE TYPE recurrence_type AS ENUM (
  'monthly'
);
