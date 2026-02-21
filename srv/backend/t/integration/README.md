# Integration Tests

This directory contains integration tests for the Wordwank game backend, focusing on WebSocket functionality, chat, and end-to-end game flows.

## Overview

Unlike unit tests that mock dependencies, these integration tests connect to a real running instance of the application to verify:

- WebSocket connections work correctly
- Chat messages broadcast properly to all players
- Game flow (join, play, disconnect) functions as expected
- Multi-player scenarios and game isolation

## Test Files

- **00-setup.t** - Verifies the test environment is ready
- **01-websocket-chat.t** - Tests WebSocket chat functionality with single and multiple players
- **02-game-flow.t** - Tests end-to-end game flow including joining, playing words, and language selection
- **03-multi-player.t** - Tests multi-player scenarios, game isolation, and disconnection handling

## Prerequisites

### Required Perl Modules

Install test dependencies:

```bash
cd srv/backend
cpanm --installdeps .
```

This will install:

- `Test::More` - Core testing framework
- `Test::MockModule` - For mocking when needed
- `Test::Mojo` - Mojolicious testing framework with WebSocket support
- `DBD::SQLite` - SQLite database driver for in-memory test database

### Database

**No external database required!** The integration tests use an **in-memory SQLite database** that is automatically created when tests run.

The schema is automatically generated from your **DBIx::Class Result classes** using the `deploy()` method. This means:

- ✅ No PostgreSQL installation needed
- ✅ No database configuration required
- ✅ **No duplicate schema files to maintain**
- ✅ Schema is always in sync with your DBIx::Class models
- ✅ Tests are completely self-contained
- ✅ Fast test execution
- ✅ Clean slate for every test run

The `TestHelper::get_test_mojo()` function automatically:

1. Sets `DATABASE_URL` to use an in-memory SQLite database
2. Instantiates the application
3. Calls `$schema->deploy()` to create all tables from your Result classes

If you want to run tests against a real PostgreSQL database (for example, to test PostgreSQL-specific features), you can set environment variables before running tests:

```bash
export DATABASE_URL="dbi:Pg:dbname=wordwank_test;host=localhost"
export DB_USER="wordwank_test"
export DB_PASS="test_password"
```

### Test Server

The integration tests use `Test::Mojo` which automatically starts a test instance of the application. No separate server process is needed.

## Running the Tests

### Run All Integration Tests

```bash
cd srv/backend
prove -lv t/integration/
```

### Run Specific Test

```bash
cd srv/backend
prove -lv t/integration/01-websocket-chat.t
```

### Verbose Output

For detailed output including diagnostic messages:

```bash
prove -lvv t/integration/
```

## Test Structure

### TestHelper Module

The `t/lib/TestHelper.pm` module provides utilities for integration testing:

- `get_test_mojo()` - Returns a Test::Mojo instance with the app loaded
- `create_ws_client(%args)` - Creates a WebSocket client and performs initial handshake
- `wait_for_message($t, $type, $timeout)` - Waits for a specific message type
- `cleanup_test_games($t)` - Cleans up test data from the database

### Example Usage

```perl
use lib 'lib', 't/lib';
use TestHelper qw(get_test_mojo create_ws_client);

my $t = get_test_mojo();

# Create two WebSocket clients
my ($ws1, $player1) = create_ws_client(
    test_mojo => $t,
    nickname => 'Alice',
);

my ($ws2, $player2) = create_ws_client(
    test_mojo => $t,
    nickname => 'Bob',
);

# Test chat between players
my $chat_msg = encode_json({
    type => 'chat',
    payload => { text => 'Hello!' }
});

$ws1->send_ok($chat_msg);
$ws2->message_ok('Bob received message');
```

## Troubleshooting

### Connection Refused

If tests fail with "connection refused" for WebSocket, this indicates an issue with the Test::Mojo test server, not the database (which is in-memory SQLite). Check the test output for errors in app startup.

### Module Not Found

Run `cpanm --installdeps .` in `srv/backend` to install all dependencies including `DBD::SQLite`.

### Tests Hang

WebSocket tests may hang if the server doesn't respond. Check that:

- All test dependencies are installed
- There are no syntax errors in the test files
- The `wordd` service is properly mocked (tests shouldn't require external services)

### SQLite Schema Issues

If you see errors about missing tables or columns:

- The schema is automatically generated from DBIx::Class Result classes
- Check that all Result classes in `lib/Wordwank/Schema/Result/` are valid
- Verify that `DBD::SQLite` is installed
- The schema is deployed via `$schema->deploy()` in `TestHelper::get_test_mojo()`
- Check for errors in the test output about schema deployment

### Want to Use PostgreSQL Instead?

Set these environment variables before running tests:

```bash
export DATABASE_URL="dbi:Pg:dbname=wordwank_test;host=localhost"
export DB_USER="wordwank_test"
export DB_PASS="test_password"
```

## CI/CD Integration

These tests are ready for CI/CD integration and require no external database setup! Example GitHub Actions:

```yaml
- name: Install Perl Dependencies
  run: |
    cpanm --installdeps srv/backend

- name: Run Integration Tests
  run: |
    cd srv/backend
    prove -lv t/integration/
```

That's it! No PostgreSQL container needed. If you want to test against PostgreSQL in CI:

```yaml
- name: Setup PostgreSQL
  run: |
    docker run -d -p 5432:5432 \
      -e POSTGRES_DB=wordwank_test \
      -e POSTGRES_USER=wordwank_test \
      -e POSTGRES_PASSWORD=test_password \
      postgres:16

- name: Run Integration Tests with PostgreSQL
  env:
    DATABASE_URL: "dbi:Pg:dbname=wordwank_test;host=localhost"
    DB_USER: "wordwank_test"
    DB_PASS: "test_password"
  run: |
    cd srv/backend
    prove -lv t/integration/
```

## Notes

- Integration tests use an **in-memory SQLite database** by default - no external database needed!
- Tests create real WebSocket connections using `Test::Mojo`'s built-in support
- The SQLite schema is **automatically generated from DBIx::Class Result classes** using `deploy()`
- No duplicate schema files to maintain - schema comes directly from your models
- Database is destroyed after tests complete (in-memory)
- For PostgreSQL-specific testing, override `DATABASE_URL` environment variable
- The `cleanup_test_games()` helper clears test data but isn't strictly necessary with in-memory databases
