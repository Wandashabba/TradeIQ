# Afrikaans review sheet — field-agent app

For a native Afrikaans speaker who has worked a trade-marketing round. Part of
[#40](https://github.com/Wandashabba/TradeIQ/issues/40).

The audience is a **field agent at work, on a phone**: plain, direct, everyday
Afrikaans. Not officialese, not English word order, and short enough for a
button or a tooltip.

Everything lives in `app/lib/l10n/app_af.arb`. `app_en.arb` is the template and
is never changed here. The manager console stays English.

**Read the open questions first** — they are the only things that need your
decision. The table after them records what was already changed, so you can skim
it and say "fine" or "no".

---

## 1. Open questions (please answer these first)

| # | Key | English | Currently in the app | The question |
|---|---|---|---|---|
| Q1 | `visitStillRequired` | `{count} still required` | `Nog {count} verpligtend` | A pill on the visit hub. Bare *verpligtend* after a number reads oddly to me — "nog 3 verpligtend". Better as **`Nog {count} nodig`** (which would also match the short REQ pill, *NODIG*)? Or is the current form fine as pill shorthand? |
| Q2 | `locationStopConfirm` / `locationStopCancel` | `Stop sharing` / `Keep sharing` | now **`Hou op deel`** / **`Bly deel`** (was *Hou op om te deel* / *Hou aan om te deel*) | Changed because the old pair differed by one small word on two buttons side by side — easy to mis-tap. Is `Hou op deel` / `Bly deel` right, or do you prefer `Hou op met deel` / `Hou aan met deel`? |
| Q3 | `s2Rrp` | `RRP {price}` | `AKP {price}` | *AKP* = aanbevole kleinhandelprys. Do agents on the floor actually say AKP, or do they say RRP? (Raised in #297 and never answered.) |
| Q4 | `s34BrandingWobbler`, `s6PosmHint` | `Wobbler` | `Wiebelkaart` | Same question: is the POS wobbler called a *wiebelkaart* in the trade, or is "wobbler" left in English? |
| Q5 | `s34FacingsLabel`, `s6FacingsLabel` | `Facings count`, `Facings on shelf` | `Aantal fronte`, `Fronte op die rak` | Is *fronte* the word merchandisers use for facings, or is "facings" left in English? Whichever it is, both keys must match. |
| Q6 | `s7TrainingMerchandising` | `Merchandising` | `Uitstalwerk` | Translate, or leave "Merchandising"? (Note `s7TrainingPosSystems` already leaves *POS* alone.) |
| Q7 | `outcomeRatingBand` | `Amber` | `Oranje` | The middle traffic-light band on a scorecard. *Oranje*, or *Amber*? (#297) |
| Q8 | `s1Geofence` | `Geofence` | `Geoheining` | Coined compound. Does it read, or should it stay "geofence"? (#297) |
| Q9 | `notificationsSlaLabel` / `notificationsSlaHelp` | `Overdue tasks` / `When one of your tasks passes its deadline` | `Agterstallige take` / `Wanneer een van jou take sy sperdatum oorskry` | *Agterstallig* is mostly a money word (arrears), and *oorskry* is fairly formal for a phone. Plainer: `Take wat laat is` / `Wanneer een van jou take verby sy sperdatum is`. Better, or is the current pair normal enough? |
| Q10 | `s8FlagTypeLabel` | `Flag type` | `Soort vlag` | *Vlag* is a literal flag (the cloth kind). The app's verb for flagging is **merk** everywhere else. Is `Soort vlag` understood here, or should it be `Soort risiko` (slight meaning shift) or something else? |
| Q11 | `contestsSubtitle` | `Earn points, climb the standings` | `Verdien punte, klim op die ranglys` | *klim op die ranglys* could be read as climbing onto the list. Is it fine, or `klim in die ranglys op`? |
| Q12 | `contestPrizeLabel` | `Prize` | `Prys` | Afrikaans *prys* is both price and prize, and the app already uses *Pryse* for "Pricing". On a contest card it should be unambiguous — is it, or would `Beloning` be safer? |
| Q13 | — (convention) | `check in` vs `sign in` | `aanmeld` for arriving at a store, `inteken` for the account | A deliberate split (see conventions below). *Aanmeld* often means "log in" in other software. Does the split hold up for agents, or does it need a different word for the store check-in? |
| Q14 | `submitAccusation` | `You are telling the manager one thing is wrong in this store…` | `Jy sê vir die bestuurder een ding is verkeerd in hierdie winkel…` | Written without *dat*, so the clause keeps main-clause word order. Fine as spoken Afrikaans, or should it be `…dat een ding in hierdie winkel verkeerd is`? |
| Q15 | `syncErrorRejected` | `Rejected by the server ({status})` | `Deur die bediener geweier ({status})` | *geweier* or *verwerp*? (#319) |

---

## 2. Conventions this file already follows

New strings must match these rather than introduce a synonym. Where a word is
still open, the question number is given.

| English | Afrikaans | Notes |
|---|---|---|
| sign in / sign out (the account) | **teken in / teken uit**, *ingeteken*, *uitgeteken* | `loginSignIn`, `agentLogOutTooltip`, `syncErrorSignedOut`, `locationNoticeBody` |
| check in (arriving at a store) | **meld aan**, *aangemeld*, *aanmelding* | Deliberately a different word from sign-in — Q13. `todayCheckInHere`, `s1CheckedIn`, `syncItemCheckIn`, `s1Title` |
| visit (noun and verb) | **besoek** | Never *besoeking*. `visitTitle`, `todayVisitAnotherStore` |
| outlet / store | **winkel** | English uses both words; Afrikaans uses one. `pickerTitle`, `visitOutletNotFound` |
| task | **taak / take** | `s9AddButton`, `notificationsTasksLabel` |
| raise (a task) | **skep** | "this raises a task" → *dit skep ’n taak*. `s2OutOfStockRaisesTask`, `submitWillRaiseHeading` |
| flag (a risk) | **merk**, *gemerk* | `s8AddButton`, `taskRiskTitle`, `progressNoRisks` |
| score (noun) | **telling** | `syncItemScore`, `visitSectionScore` |
| scorecard | **telkaart** (pl. *telkaarte*) | `s10Finalize`, `s10Queued`, `contestEventScorecard` |
| scored | **getel** | Follows *telling*. `outcomeHowScored`, `outcomeScoredWhenSends` |
| send / sync | **stuur** | Never *sinkroniseer*. `myWorkSyncNow`, `syncAllSentTitle` |
| queued for sync | **wag om gestuur te word** | The standard tail on every save confirmation — 10 keys. Not *wag om te stuur* |
| sends itself / automatically | **stuur vanself** | `myWorkFooter`, `syncHeldSubtitle`, `submitOfflineNote` |
| capture (a queued item) | **vaslegging**; captured → **vasgelê** | `syncSendingTitle`, `photoFieldCaptured` |
| required | **verpligtend** (predicative) / **verplig-te** (attributive) | *Verpligtend om in te dien*; *nog 1 verpligte vraag*. Short pill is *NODIG* |
| complete / finish | **voltooi** | `submitSectionsComplete`, `visitFinishToSubmit` |
| template | **sjabloon** | `visitTemplateNoQuestions` |
| client questions | **kliëntvrae** | `visitTemplateSectionKicker` |
| manager | **bestuurder** | Never *manager* |
| phone / signal | **foon** / **sein** | Not *selfoon*, not *seine* |
| Try again | **Probeer weer** | All four retry buttons |
| Could not … | **Kon nie … nie** | Every error title |
| contest | **kompetisie**; standings → **ranglys** | `contestsTitle`, `contestStandingsHeading` |
| notification | **kennisgewing** | `notificationsTitle` |

Mechanical house style, also worth keeping:

- **Typographic apostrophe `’`** throughout — `’n`, `Risiko’s`, `SKU’s`, `foto’s`.
- **Em dash `—` and middle dot `·`** are carried over from the English exactly.
- **Hyphenated compounds** where one half is a loanword or the compound gets
  long: *Winkel-aanmelding*, *Handelsmerk-elemente*, *Planogram-nakoming*,
  *Kommunikasie-gradering*, *kennisgewing-instellings*.
- **Product terms, SKU codes and units are not translated**: TradeIQ, SKU, POS,
  POSM, SLA, m, %.
- **Leading and trailing spaces in fragments are kept** —
  `todayStoresOfTotal` and `visitProgressOfSections` both start with a space
  because a number is drawn immediately before them.
- **Every `{placeholder}` from the English survives**, enforced by
  `test/l10n/arb_completeness_test.dart`.

---

## 3. What was changed

Eight strings. Each is a grammar, voice or consistency fix, not a preference.

| Key | English | Was | Now | Why |
|---|---|---|---|---|
| `locationSharingNoFixSubtitle` | Sharing is on, but this phone isn’t giving TradeIQ a location | Deel is aan, maar hierdie foon gee nie ’n ligging aan TradeIQ nie | **Dit is aan, maar hierdie foon gee nie vir TradeIQ ’n ligging nie** | *Deel* is not a noun for "sharing" in Afrikaans (it means "part"). The line sits directly under *Jou ligging word met jou bestuurder gedeel*, so *Dit* is unambiguous. Also fixes English object order — Afrikaans puts the recipient first: *gee vir TradeIQ ’n ligging*. |
| `locationStopConfirm` | Stop sharing | Hou op om te deel | **Hou op deel** | Two dialog buttons that differed only by *op* / *aan* sat next to each other — a mis-tap risk on a phone, and the English pair is visually distinct. Shorter also suits a button. See Q2. |
| `locationStopCancel` | Keep sharing | Hou aan om te deel | **Bly deel** | As above. *bly* + verb ("bly deel", "bly praat") is the ordinary way to say "keep doing". |
| `outcomeHeldBodyUnreachable` | …it will send itself the moment you have signal | …dit sal **self** stuur… | …dit sal **vanself** stuur… | *self stuur* reads as "send it yourself" — the opposite of the promise being made. *stuur vanself* is the phrase the app already uses in five other places. |
| `outcomeHeldBodyNoSignal` | (same sentence) | …dit sal **self** stuur… | …dit sal **vanself** stuur… | Same fix, same sentence. |
| `myWorkWaitingHeading` | Waiting to send | Wag om te stuur | **Wag om gestuur te word** | Wrong voice: the items are waiting to *be* sent, not waiting to send something. *wag om gestuur te word* is the file's own phrase (10 other keys). |
| `s8FlagTypeHint` | What was flagged | Wat uitgewys is | **Wat gemerk is** | The app's verb for flagging a risk is *merk* everywhere else — the button right above says *Merk ’n risiko*, and the resulting task says *gemerk*. |
| `submitNothingToRaise` | You found no stockouts and flagged no risks | Jy het **niks uit voorraad gekry nie** en geen risiko’s gemerk nie | **Niks was uit voorraad nie** en jy het geen risiko’s gemerk nie | *uit voorraad kry* is not idiomatic for finding a stockout. Splitting it into two clauses keeps each *nie … nie* pair correct and reads plainly. |

---

## 4. Checked and left alone

These were flagged as uncertain but are correct as they stand. Listed so the
review does not have to re-derive them.

| Key | Afrikaans | Verdict |
|---|---|---|
| `contestEventTaskClosed` | Afgehandelde take | *Afgehandel* is the ordinary trade word for a task that is closed out, and the "What counts" list reads consistently: *Alle punte · Ingediende besoeke · Afgehandelde take · Telkaarte*. |
| `contestEventScorecard` | Telkaarte | Correct plural of *telkaart*, and *telkaart* is already the S10 word. Consistent. |
| `contestYourRank` | Jou posisie: {rank} van {total} | *Posisie* is right (*rang* would be a military rank). Both placeholders present. |
| `contestsRunningHint` | {count, plural, =1{1 kompetisie loop nou} other{{count} kompetisies loop nou}} | Correct ICU, correct plural, and *loop* matches the heading *Loop nou*. A tooltip, so length is fine. |
| `visitTemplateSectionKicker` and the rest of the template block | Kliëntvrae, sjabloon, Nog 1 verpligte vraag, Verpligtend | All correct. *Verpligte* is the right attributive form of *verplig*; the plural branch (*verpligte vrae*) agrees. *Sjabloon* is the standard word for a template. |
| `visitTemplatePhotoUnsupported` | Fotovrae kan nog nie in die app beantwoord word nie | Correct passive with a modal, verb cluster final, *nie … nie* correct. |
| the `notifications*` block | Kennisgewings, Take wat aan jou toegewys is, Kennisgewings is nog nie aangeskakel nie, … | Grammatically clean throughout: correct verb-final subordinate clauses, correct double negation, correct passives. Only the two SLA lines are worth a second opinion (Q9). |
| `locationNoticeBody` | Terwyl TradeIQ oop is en jy ingeteken is, stuur dit … | The POPIA notice. V2 inversion after the fronted clause is right, the ICU plural on `{minutes}` is right, *toemaak of uitteken* are both correctly verb-final. |
| `locationSharingOffSubtitle` | Tik om dit te verander | Correct and exactly as vague as the English, deliberately — tapping re-opens the notice rather than switching anything on. |
| `agoDays`, `progressCompetitors` | ICU plurals where the English has none | The English says "{days}d ago" and "{items} competitor(s)"; Afrikaans spells the plural properly. An improvement, not a drift. |
