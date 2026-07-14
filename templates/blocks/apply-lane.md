6. When findings exist, offer the next step as a selectable choice (AskUserQuestion):
   Apply all / Apply critical+high only / Report only{{applyExtraBlock}}. On an apply
   pick, dispatch the finding list down the static chain {{workerChain}} — never leave
   the user to retype findings as instructions. In a headless or non-interactive run,
   report only and print the apply command instead of dispatching.

You may close by recommending an ultra-assess re-run when the change was large or
high-risk — recommend it only, never self-execute it.