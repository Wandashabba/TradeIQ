import json, collections, io, sys

EN = 'app/lib/l10n/app_en.arb'
AF = 'app/lib/l10n/app_af.arb'

# key -> (english, afrikaans, description, placeholders)
NEW = [
    # ── My work ──────────────────────────────────────────────────────────
    ('myWorkSendNow', 'Send now', 'Stuur nou',
     'The action inside the My work summary block. A ghost by default — the queue sends itself — and the screen’s one amber block only when something is stuck.', None),
    ('myWorkSendNowBlocked', 'Nothing is waiting to send.', 'Niks wag om gestuur te word nie.',
     'Why "Send now" is off. A disabled primary always names what is missing.', None),
    ('myWorkSignedOutTitle',
     '{count, plural, =1{You’re signed out. Sign in and your 1 held capture will send.} other{You’re signed out. Sign in and your {count} held captures will send.}}',
     '{count, plural, =1{Jy is afgemeld. Meld aan en jou 1 gehoue vaslegging sal stuur.} other{Jy is afgemeld. Meld aan en jou {count} gehoue vasleggings sal stuur.}}',
     'The signed-out block above the My work summary. The only state where the amber moves off "Send now".', {'count': 'int'}),
    ('myWorkSignIn', 'Sign in', 'Meld aan',
     'The signed-out block’s action.', None),
    ('myWorkShowOlder', 'Show older', 'Wys ouer',
     'Ghost action under the capped Sent list.', None),
    ('myWorkSentCapped',
     'Showing the {shown} most recently sent of {total}',
     'Wys die {shown} mees onlangs gestuurdes van {total}',
     'The Sent group is capped so a long outbox does not become a scroll. Says what it is showing and out of how many.',
     {'shown': 'int', 'total': 'int'}),
    ('myWorkEmptyBody',
     'Everything you capture in a store shows up here until the server has it.',
     'Alles wat jy in ’n winkel vaslê, verskyn hier totdat die bediener dit het.',
     'The empty My work screen. Says what the screen is for rather than apologising.', None),
    ('myWorkLoadErrorBody',
     'Your work is still on this phone. Nothing is lost.',
     'Jou werk is steeds op hierdie foon. Niks is verlore nie.',
     'Body of the My work load-error state. The outbox failing to READ is not the outbox failing to hold.', None),

    # ── The outbox row ───────────────────────────────────────────────────
    ('outboxWaiting', 'Waiting', 'Wag',
     'Outbox row state word: queued, waiting for signal. Never an error.', None),
    ('outboxSending', 'Sending', 'Stuur tans',
     'Outbox row state word: bytes are moving.', None),
    ('outboxRetrying', 'Retrying', 'Probeer weer',
     'Outbox row state word: a failed attempt that will clear itself.', None),
    ('outboxSent', 'Sent', 'Gestuur',
     'Outbox row state word: the server has it.', None),
    ('outboxNeedsYou', 'Needs you', 'Het jou nodig',
     'Outbox row state word for the one severity-bearing state, and the severity in words beside the crimson bar.', None),
    ('outboxWaitingTurn', 'Waiting its turn', 'Wag sy beurt',
     'Outbox row state word: blocked on the visit above it. An ordering dependency, explicitly not a fault.', None),
    ('outboxWaitingSentence', 'Waiting for signal', 'Wag vir sein',
     'The queued state as a sentence.', None),
    ('outboxSendingSentence', 'Going up now', 'Gaan nou op',
     'The sending state as a sentence.', None),
    ('outboxSentSentence', 'The server has it', 'Die bediener het dit',
     'The sent state as a sentence.', None),
    ('outboxQueuedAt', 'queued {time}', 'in ry {time}',
     'The age line on a queued outbox row. {time} is a clock time.', {'time': 'String'}),
    ('outboxSentAt', 'sent {time}', 'gestuur {time}',
     'The age line on a sent outbox row.', {'time': 'String'}),
    ('outboxLastTriedAt', 'last tried {time}', 'laas probeer {time}',
     'The age line on a retrying or stuck outbox row. The real last attempt, never an invented next-try time.', {'time': 'String'}),

    # ── The outbox item sheet (#376) ─────────────────────────────────────
    ('outboxAttempts',
     '{count, plural, =0{Not tried yet} =1{Tried once} other{Tried {count} times}}',
     '{count, plural, =0{Nog nie probeer nie} =1{Een keer probeer} other{{count} keer probeer}}',
     'How many send attempts this capture has had, in the sheet’s identifier block.', {'count': 'int'}),
    ('outboxSendThisNow', 'Send this one now', 'Stuur hierdie een nou',
     'The sheet action that flushes exactly this capture and nothing else.', None),
    ('outboxDiscard', 'Discard this capture', 'Gooi hierdie vaslegging weg',
     'The sheet action that throws a stuck capture away. Always behind a second step.', None),
    ('outboxDiscardConfirm', 'Yes, discard it', 'Ja, gooi dit weg',
     'The confirming press on the discard sheet.', None),
    ('outboxDiscardKeep', 'Keep it', 'Hou dit',
     'The way out of the discard confirm.', None),
    ('outboxDiscardWhatIsLost',
     'This {item} has not reached the server. Discard it and it is gone from this phone — there is no copy anywhere else.',
     'Hierdie {item} het nie die bediener bereik nie. Gooi dit weg en dit is van hierdie foon af weg — daar is nie ’n kopie enige plek anders nie.',
     'Said plainly before anything is thrown away (#376). {item} is the capture’s own name, e.g. "Stock count".', {'item': 'String'}),
    ('outboxNothingToDo', 'Nothing to do — the server has it.', 'Niks om te doen nie — die bediener het dit.',
     'The sent state’s sheet. A sent row is still tappable, and it says so.', None),
    ('outboxRejectedNote',
     'The server refused this exactly as it is, so sending it again unchanged will fail the same way. Nothing has been altered for you.',
     'Die bediener het dit net so geweier, so om dit onveranderd weer te stuur sal net so misluk. Niks is vir jou verander nie.',
     'Shown on a rejected or too-large capture. The app never repairs a rejected payload behind the agent’s back (#376).', None),
    ('outboxWaitingTurnNote',
     'This sends itself as soon as the visit above it does. Nothing is wrong.',
     'Hierdie stuur vanself sodra die besoek bo dit stuur. Niks is verkeerd nie.',
     'The ordering dependency, said in the sheet so it is never read as a fault.', None),
    ('outboxSignedOutNote',
     'Your session ended. Sign in and this sends itself.',
     'Jou sessie het geëindig. Meld aan en hierdie stuur vanself.',
     'The one stuck state whose fix has nothing to do with the capture.', None),
    ('outboxItemId', 'Capture {id} · {type}', 'Vaslegging {id} · {type}',
     'The identifier block in the outbox sheet, in mono. For a support call.', {'id': 'int', 'type': 'String'}),

    # ── The outlet picker ────────────────────────────────────────────────
    ('pickerEmptyTitle', 'No stores here', 'Geen winkels hier nie',
     'The picker with an empty list.', None),
    ('pickerEmptyBodyMine',
     'Nothing is filed under your territories yet. Switch to all stores, or add the one you are standing in.',
     'Niks is nog onder jou gebiede geliasseer nie. Skakel oor na alle winkels, of voeg die een by waar jy staan.',
     'The picker’s empty state while it is narrowed. Names both ways out.', None),
    ('pickerEmptyBodyAll',
     'This client has no stores on the server yet. Add the one you are standing in.',
     'Hierdie kliënt het nog geen winkels op die bediener nie. Voeg die een by waar jy staan.',
     'The picker’s empty state with the widest scope. The list is genuinely empty, not filtered.', None),
    ('pickerLoadErrorBody',
     'Your stores are fetched from the server. Nothing you have captured is affected.',
     'Jou winkels word van die bediener af gehaal. Niks wat jy vasgelê het, word geraak nie.',
     'Body of the picker’s load-error state. A list that will not load is not work that is lost.', None),
    ('pickerScopeHeading', 'Which stores', 'Watter winkels',
     'Section rule above the picker’s scope control.', None),
    ('pickerStoresHeading', 'Stores', 'Winkels',
     'Section rule above the picker’s list.', None),

    # ── The sync banner (one component, two forms) ───────────────────────
    ('syncBannerOpen', 'tap to open your work', 'tik om jou werk oop te maak',
     'The trailing half of the held banner’s screen-reader label.', None),
]

RENAMED = {
    'myWorkTitle': ('My work', 'My werk'),
    'myWorkSubtitle': ('Everything you’ve captured', 'Alles wat jy vasgelê het'),
}


def load(path):
    with io.open(path, encoding='utf-8') as f:
        return json.load(f, object_pairs_hook=collections.OrderedDict)


def dump(path, data):
    with io.open(path, 'w', encoding='utf-8') as f:
        json.dump(data, f, ensure_ascii=False, indent=2)
        f.write('\n')


en = load(EN)
af = load(AF)

for key, (e, a) in RENAMED.items():
    assert key in en, key
    en[key] = e
    af[key] = a

for key, e, a, desc, ph in NEW:
    assert key not in en, 'already there: %s' % key
    en[key] = e
    meta = collections.OrderedDict()
    meta['description'] = desc
    if ph:
        meta['placeholders'] = collections.OrderedDict(
            (name, collections.OrderedDict([('type', t)])) for name, t in ph.items()
        )
    en['@' + key] = meta
    af[key] = a

dump(EN, en)
dump(AF, af)
print('en keys', len([k for k in en if not k.startswith('@')]))
print('af keys', len([k for k in af if not k.startswith('@')]))
