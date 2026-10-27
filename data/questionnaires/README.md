# questionnaires/

Pre-scan thought ratings and trait questionnaires. **Available on request.**

| File | Contents |
|---|---|
| Pre-scan thought ratings | per-thought ratings of repetitiveness, intrusiveness and uncontrollability; the dyscontrol composite is their mean |
| Baseline questionnaire | PTQ, PSWQ, and other trait measures |

Both are Qualtrics exports. `mvpa/questionnaire_loader.py` parses them.

The pre-scan export includes each participant's nominated thought topics as
free text. Copies supplied on request have these replaced with opaque
per-subject identifiers (`thought_01` ... `thought_09`), which is sufficient
for every analysis in the paper: the merge only needs thoughts to be matched
consistently between the pre-scan and in-scanner files, not to be readable.
