/**
 * Gmail -> Financial Management bank-email ingest.
 *
 * Runs on a time-driven trigger, finds unprocessed bank notification emails,
 * and POSTs them to the `ingest-bank-email` Supabase edge function, which does
 * the parsing and creates the pending transaction.
 *
 * This script deliberately does NOT parse amounts/merchants. Bank templates
 * change often, and redeploying an edge function is far easier than editing
 * Apps Script. Here we only do transport, de-duplication and retry.
 *
 * Setup: see README.md. All config lives in Script Properties, never in code,
 * because this file is committed to git.
 */

// ---------------------------------------------------------------------------
// Config
// ---------------------------------------------------------------------------

var DEFAULTS = {
  // Gmail search fragment identifying bank notification mail. This is the
  // sender BCA credit card alerts actually come from (verified against real
  // samples); it is NOT the same as BCA's other notification senders.
  SENDER_QUERY: 'from:(KartuKreditBCA@klikbca.com)',
  // How far back to look. Bounds both the search and the retry window: a
  // message older than this is never retried, so one permanently-failing email
  // cannot spam the endpoint forever.
  LOOKBACK_DAYS: '3',
  // Cosmetic Gmail labels so you can see the outcome in the inbox. These are
  // NOT used for de-duplication -- see findUnprocessedMessages_ for why.
  PROCESSED_LABEL: 'fm-ingested',
  FAILED_LABEL: 'fm-ingest-failed',
  MAX_ATTEMPTS: '3',
  // Cap per run to stay well inside the Apps Script execution time limit.
  MAX_MESSAGES_PER_RUN: '25',
  // Real BCA alerts are ~26k chars of HTML (inline styles + tracking markup),
  // so this must stay comfortably above that or the payload loses the fields.
  MAX_BODY_CHARS: '100000',
  TRIGGER_MINUTES: '5',
};

function config_(key) {
  var value = PropertiesService.getScriptProperties().getProperty(key);
  if (value === null || value === '') {
    if (Object.prototype.hasOwnProperty.call(DEFAULTS, key)) return DEFAULTS[key];
    throw new Error(
      'Missing required Script Property "' + key + '". See README.md > Setup.'
    );
  }
  return value;
}

function intConfig_(key) {
  var parsed = parseInt(config_(key), 10);
  if (isNaN(parsed)) throw new Error('Script Property "' + key + '" must be a number.');
  return parsed;
}

// ---------------------------------------------------------------------------
// Entry point (this is the function the trigger calls)
// ---------------------------------------------------------------------------

function ingestBankEmails() {
  // Runs every few minutes; overlapping executions would double-POST a message
  // that is mid-flight but not yet recorded as done.
  var lock = LockService.getScriptLock();
  if (!lock.tryLock(5000)) {
    console.log('Another run is in progress; skipping this tick.');
    return;
  }

  try {
    pruneState_();

    var messages = findUnprocessedMessages_();
    if (messages.length === 0) {
      console.log('No new bank emails.');
      return;
    }

    console.log('Found ' + messages.length + ' unprocessed message(s).');

    var processedLabel = getOrCreateLabel_(config_('PROCESSED_LABEL'));
    var failedLabel = getOrCreateLabel_(config_('FAILED_LABEL'));
    var maxAttempts = intConfig_('MAX_ATTEMPTS');
    var sent = 0;
    var failed = 0;

    for (var i = 0; i < messages.length; i++) {
      var message = messages[i];
      var id = message.getId();
      var result = postMessage_(message);

      if (result.ok) {
        setState_(id, 'done', 0);
        message.getThread().addLabel(processedLabel);
        sent++;
        continue;
      }

      failed++;
      var attempts = (getState_(id).attempts || 0) + 1;
      console.error(
        'Ingest failed for message ' + id +
        ' (attempt ' + attempts + '/' + maxAttempts + '): ' + result.error
      );

      if (attempts >= maxAttempts) {
        setState_(id, 'failed', attempts);
        message.getThread().addLabel(failedLabel);
        console.error('Giving up on message ' + id + '.');
      } else {
        setState_(id, 'retry', attempts);
      }
    }

    console.log('Done. sent=' + sent + ' failed=' + failed);
  } finally {
    lock.releaseLock();
  }
}

// ---------------------------------------------------------------------------
// Gmail
// ---------------------------------------------------------------------------

function buildQuery_() {
  return [
    config_('SENDER_QUERY'),
    'newer_than:' + intConfig_('LOOKBACK_DAYS') + 'd',
  ].join(' ');
}

/**
 * Returns individual messages that have not been handled yet.
 *
 * De-duplication is keyed on the Gmail message id held in Script Properties,
 * NOT on a Gmail label. Labels in Gmail apply to an entire thread, and banks
 * routinely reply into an existing notification thread -- excluding labelled
 * threads from the search would permanently hide every alert after the first
 * one in that thread. The labels applied elsewhere are purely for visibility.
 */
function findUnprocessedMessages_() {
  var limit = intConfig_('MAX_MESSAGES_PER_RUN');
  var cutoff = new Date(Date.now() - intConfig_('LOOKBACK_DAYS') * 86400000);
  // Search threads generously: a thread matches if any message in it matches,
  // and we want the unprocessed siblings of already-processed messages.
  var threads = GmailApp.search(buildQuery_(), 0, limit);
  var messages = [];

  for (var t = 0; t < threads.length; t++) {
    var threadMessages = threads[t].getMessages();
    for (var m = 0; m < threadMessages.length; m++) {
      var message = threadMessages[m];
      if (message.getDate() < cutoff) continue;

      var state = getState_(message.getId()).state;
      if (state === 'done' || state === 'failed') continue;

      messages.push(message);
    }
  }

  // Oldest first, so transactions land in chronological order.
  messages.sort(function (a, b) { return a.getDate() - b.getDate(); });
  return messages.slice(0, limit);
}

function getOrCreateLabel_(name) {
  return GmailApp.getUserLabelByName(name) || GmailApp.createLabel(name);
}

// ---------------------------------------------------------------------------
// Ingest endpoint
// ---------------------------------------------------------------------------

function buildPayload_(message) {
  var maxBody = intConfig_('MAX_BODY_CHARS');
  // The HTML part is the only one worth sending: BCA's alerts ship a
  // text/plain part containing a single "-" and put every field (merchant,
  // amount, timestamp) in the HTML table. getPlainBody() returns that "-", so
  // parsing it would silently yield nothing. plainBody is included anyway, for
  // senders that do populate it.
  var htmlBody = message.getBody() || '';
  var plainBody = message.getPlainBody() || '';

  return {
    source: 'gmail-apps-script',
    version: 1,
    // Gmail's immutable message id. The endpoint uses this as the idempotency
    // key, so a retry after an ambiguous failure cannot double-insert.
    messageId: message.getId(),
    threadId: message.getThread().getId(),
    from: message.getFrom(),
    to: message.getTo(),
    subject: message.getSubject(),
    receivedAt: message.getDate().toISOString(),
    bodyTruncated: htmlBody.length > maxBody,
    htmlBody: htmlBody.slice(0, maxBody),
    plainBody: plainBody.slice(0, maxBody),
  };
}

function postMessage_(message) {
  var response;
  try {
    response = UrlFetchApp.fetch(config_('INGEST_URL'), {
      method: 'post',
      contentType: 'application/json',
      headers: { 'X-Ingest-Secret': config_('INGEST_SECRET') },
      payload: JSON.stringify(buildPayload_(message)),
      muteHttpExceptions: true,
      followRedirects: false,
    });
  } catch (err) {
    // Network-level failure (DNS, timeout). Retryable.
    return { ok: false, error: String(err) };
  }

  var code = response.getResponseCode();
  if (code >= 200 && code < 300) return { ok: true };

  return {
    ok: false,
    error: 'HTTP ' + code + ': ' + response.getContentText().slice(0, 500),
  };
}

// ---------------------------------------------------------------------------
// Per-message state, stored as Script Properties keyed by Gmail message id
// ---------------------------------------------------------------------------

function stateKey_(messageId) {
  return 'st:' + messageId;
}

function getState_(messageId) {
  var raw = PropertiesService.getScriptProperties().getProperty(stateKey_(messageId));
  if (!raw) return {};
  try {
    return JSON.parse(raw);
  } catch (err) {
    return {};
  }
}

function setState_(messageId, state, attempts) {
  PropertiesService.getScriptProperties().setProperty(
    stateKey_(messageId),
    JSON.stringify({ state: state, attempts: attempts, at: Date.now() })
  );
}

/**
 * Drops state for messages older than twice the lookback window. They can no
 * longer be returned by the search, so their entries are dead weight and would
 * otherwise grow into the 500KB Script Properties limit.
 */
function pruneState_() {
  var props = PropertiesService.getScriptProperties();
  var all = props.getProperties();
  var horizon = Date.now() - intConfig_('LOOKBACK_DAYS') * 2 * 86400000;
  var removed = 0;

  for (var key in all) {
    if (key.indexOf('st:') !== 0) continue;
    var at = 0;
    try {
      at = JSON.parse(all[key]).at || 0;
    } catch (err) {
      at = 0; // Unparseable entry: treat as ancient and drop it.
    }
    if (at < horizon) {
      props.deleteProperty(key);
      removed++;
    }
  }

  if (removed > 0) console.log('Pruned ' + removed + ' stale state entries.');
}

// ---------------------------------------------------------------------------
// Setup helpers (run these by hand from the Apps Script editor)
// ---------------------------------------------------------------------------

/** Creates the time-driven trigger. Safe to re-run; replaces the old one. */
function installTrigger() {
  removeTrigger();

  var minutes = intConfig_('TRIGGER_MINUTES');
  ScriptApp.newTrigger('ingestBankEmails')
    .timeBased()
    .everyMinutes(minutes)
    .create();

  console.log('Trigger installed: ingestBankEmails every ' + minutes + ' minutes.');
}

function removeTrigger() {
  var triggers = ScriptApp.getProjectTriggers();
  for (var i = 0; i < triggers.length; i++) {
    if (triggers[i].getHandlerFunction() === 'ingestBankEmails') {
      ScriptApp.deleteTrigger(triggers[i]);
    }
  }
}

/**
 * Logs what would be sent without POSTing, labelling or recording state.
 * Use this to sanity-check SENDER_QUERY before installing the trigger.
 */
function dryRun() {
  console.log('Query: ' + buildQuery_());
  var messages = findUnprocessedMessages_();
  console.log('Matched ' + messages.length + ' unprocessed message(s).');
  for (var i = 0; i < messages.length; i++) {
    console.log(JSON.stringify(buildPayload_(messages[i]), null, 2));
  }
}

/** POSTs the single most recent matching email. Verifies the endpoint end to end. */
function sendMostRecentForTesting() {
  var messages = findUnprocessedMessages_();
  if (messages.length === 0) {
    console.log('Nothing unprocessed matched ' + buildQuery_());
    return;
  }
  var message = messages[messages.length - 1];
  var result = postMessage_(message);
  console.log(result.ok ? 'OK' : 'FAILED: ' + result.error);
  console.log('Note: no state was recorded, so the trigger will send this again.');
}

/** Clears all per-message state, making every email in the window eligible again. */
function resetState() {
  var props = PropertiesService.getScriptProperties();
  var all = props.getProperties();
  var removed = 0;
  for (var key in all) {
    if (key.indexOf('st:') === 0) {
      props.deleteProperty(key);
      removed++;
    }
  }
  console.log('Cleared ' + removed + ' state entries. Config properties kept.');
}
