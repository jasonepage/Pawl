# 27. Review of Pawl's first 60 seconds

Reviewed against `docs/26_First_60_Seconds.md` on 2026-11-02.

## Diagnosis in one sentence

Pawl explains too much before it proves its value, asks the person to label and quantify their problem before earning trust, and lets them turn on protection before they have a working way to unlock it.

The strongest idea is already present: unblocking requires a physical key or a trusted person, followed by a 15-minute wait. That should be the first promise, not information the person assembles across later screens.

## Walk 1: 24 years old, deleted TikTok for the third time

### Where I would bail

I would start losing patience on Screen 1. I already know TikTok is the problem. Seven categories, fourteen descriptive lines, multi-select behavior, and a two-column grid feel like a survey before the app has done anything. I would choose Social media, but I would wonder why Pawl needs to know my reason instead of simply letting me choose TikTok.

I would probably bail on Screen 2 at "What it costs you." The title feels like a lecture. The hours slider asks me to confess a number I do not know, then turns it into 30 lost days. I downloaded the app because I already feel bad about this. The calculation adds guilt but does not help me get protected.

If I continued, "I don't have a key yet" would look like the fastest path. I would tap it without fully understanding that I was about to turn on blocks that nothing could unlock. That is not a shortcut to setup. It is a trap created by the setup.

### Words I did not understand

- "Anonymous tokens" sounds technical and evasive. I do not know what a token is or what Pawl can infer from one.
- "Website categories" sounds like a browser setting, not something that affects TikTok.
- "Security key" could mean a password, passkey, recovery key, or a physical object. The picture helps, but the first plain definition arrives too late.
- "Lifting the shield" is branded language where I need literal language.
- "Hard lock" sounds important, but it appears in a paragraph immediately before activation and is deferred to Settings.
- "PawlReport target" appears on Home in the ground-truth description. If any version of that reaches a person, it is internal language and meaningless.

### What I expected that did not happen

- After choosing Social media, I expected to pick TikTok immediately. Instead I got an impact calculator.
- I expected a quick explanation of what the physical key actually does. Instead I learned about the key in pieces.
- I expected Pawl to prevent me from creating a lock with no working unlock method.
- After setup, I expected a simple confirmation that TikTok was blocked and exactly how I could reopen it. The Home dashboard led with hours and days instead.

## Walk 2: 50 years old, father trying to stop sports betting

### Where I would bail

I would not necessarily bail on Screen 1, because the Gambling card speaks directly to my problem. I might still hesitate at "crypto apps and sites." That broadens the category and makes me wonder what Pawl believes gambling includes.

My highest-risk bail is Screen 3. The system asks for Screen Time permission, while Pawl says it sees "anonymous tokens." I am deciding whether to trust an unfamiliar app with a powerful permission. Technical reassurance is weaker than a plain statement of what stays on my phone and what leaves it.

I would also stop at Screen 5 if I do not already own a security key. "Get a USB-C security key" does not tell me what to buy, whether it works with my iPhone, or whether I can safely continue today. The ally option sounds promising, but "Pawl Pro" appears before price or purchase context, and "Needs iCloud on both phones" raises setup questions. I would worry that my wife needs the app, an account, or access to my activity.

### Words I did not understand

- "Anonymous tokens" does not explain the privacy boundary.
- "Apple's adult-site filter" is unrelated to my goal and makes the flow feel generic.
- "Crypto apps and sites" is too broad in a gambling preset unless the exact list is visible.
- "Ally" is friendly but not self-explanatory. "Trusted person" is clearer on first use.
- "They see almost nothing" is vague. I want the exact answer: what do they see?
- "Hard lock" and "Screen Time passcode" introduce a second protection model at the last moment.

### What I expected that did not happen

- After choosing Gambling, I expected Pawl to show me which betting apps and sites would be blocked.
- I expected the app to tell me, before permission, that my selections and usage data stay on my phone.
- I expected to connect my trusted person before any block became active.
- I expected a direct statement that my trusted person cannot see which apps or sites I blocked.
- I expected an emergency explanation. Pawl should not offer a bypass, but it should plainly say there is no phone-only bypass before I activate it.

## Walk 3: product designer who has shipped onboarding at a top consumer app

### Where I would bail

I would flag Screen 1 before testing. It asks for segmentation, supports multi-select, stores a "main focus," and contains roughly a hundred words, but the choice barely changes the core setup. This is taxonomy work imposed on the user. The app needs a block list, not a declared identity.

Screen 2 is the clearest cut. It adds a five-step progress model after a screen that was not counted, asks for speculative input, defaults that input to two hours, calculates an annualized loss, and uses the estimate later as if it were meaningful. It delays the first necessary action and risks shame.

Screen 5 contains the most serious product flaw. Three states satisfy Continue: a paired key, an unpaired promise to buy a key, or merely selecting ally. Those states are not equivalent. The flow treats intent as readiness and can produce an active block with no working unlock path.

Screen 6 introduces "Turning off Screen Time still removes protection" and "Hard lock in Settings" at the commitment moment. That is a material limitation and a second setup task. It should be disclosed earlier or removed from the first-run promise. It should not be buried in dense copy beside the activation button.

### Words I did not understand

- "Role picker" is internal framing, not user value.
- "Anonymous tokens" is implementation language.
- "First tap is the main focus" creates hidden state with no obvious benefit.
- "Where you keep it is the trick" is cute but underspecified for a security decision.
- "They see almost nothing" is noncommittal privacy copy.
- "Lifting the shield" replaces a familiar verb with a metaphor.
- "Protected" overclaims if disabling Screen Time can remove protection and no Screen Time passcode is set.

### What I expected that did not happen

- I expected the first screen to state the differentiated mechanism and outcome.
- I expected permission to be requested in context, immediately before the feature that needs it.
- I expected the flow to branch cleanly by unlock method and verify that method before activation.
- I expected the app picker to be the first meaningful interaction.
- I expected the completion screen to confirm what is blocked and rehearse the unlock model.
- I expected the progress indicator to count every onboarding screen consistently.

## Problems shared by all three walks

1. **The value proposition is late.** The best promise is scattered across Screen 2, Screen 5, and Screen 6.
2. **The flow begins with diagnosis instead of action.** Category selection and the cost slider ask the person to explain their struggle before Pawl helps.
3. **The privacy copy uses technical language.** "Anonymous tokens" is less trustworthy than a precise statement about what stays on the device.
4. **Readiness is not enforced.** A person can activate blocks without a paired key or connected ally.
5. **The 15-minute wait is not taught as a simple sequence.** The mental model should be: request with key or ally, wait 15 minutes, apps open.
6. **The final commitment contains surprises.** Screen Time limitations and Hard lock appear when the person is trying to finish.
7. **Completion emphasizes a dashboard instead of certainty.** The first post-setup job is to confirm that the selected items are blocked and explain how reopening works.

## Single best version of the first minute

This version removes the role picker and the cost calculator. It does not ask the person to estimate usage. It requires a working key or connected ally before blocks can turn on. It never offers a phone-only unlock or a skipped wait.

### Screen 1: Welcome

Art: calm tabby sitting behind the green security key.

Every word:

- Title: **"Make distracting apps harder to reopen"**
- Body: **"Pawl blocks the apps and sites you choose. To reopen them, use your security key or ask your trusted person, then wait 15 minutes."**
- Privacy line: **"No account. Your choices stay on this iPhone."**
- Primary button: **"Set up Pawl"**

Tap: **Set up Pawl**.

Why this is first: it states the outcome, both allowed unlock methods, the unavoidable wait, and the privacy boundary before asking for permission or effort.

### Screen 2: Allow Screen Time

Art: cat holding up one paw.

Every word:

- Progress: **"1 of 4"**
- Title: **"Allow Screen Time"**
- Body: **"Pawl uses Apple's Screen Time to block what you choose."**
- Privacy line: **"Your app and website choices stay on this iPhone. Pawl does not collect them."**
- Primary button before permission: **"Allow Screen Time"**
- Status after permission: **"Screen Time allowed"**
- Primary button after permission: **"Continue"**

Taps: **Allow Screen Time**, approve Apple's system sheet, then **Continue**.

The Apple permission sheet is system-owned. Pawl should not paraphrase or compete with it while it is visible.

### Screen 3: Choose what to block

Art: cat tapping one of three blank tiles.

Every word:

- Progress: **"2 of 4"**
- Title: **"Choose what to block"**
- Body: **"Add at least one app, website, or website category."**
- Section title: **"Apps"**
- Empty state: **"No apps selected"**
- Button: **"Choose apps"**
- Section title: **"Websites"**
- Field label: **"Website address"**
- Field placeholder: **"example.com"**
- Button beside field: **"Add website"**
- Section title: **"Website categories"**
- Row: **"Gambling sites"**
- Supporting line: **"Blocks Pawl's list of sportsbook and casino sites."**
- Row: **"Adult sites"**
- Supporting line: **"Uses Apple's adult website filter."**
- Footer before a selection: **"Choose something to continue."**
- Primary button: **"Continue"**

After apps are selected, replace "No apps selected" with **"1 app selected"** or **"[number] apps selected"**. Do not show app names outside Apple's picker if the system API does not provide them.

Taps for the shortest app path: **Choose apps**, choose one app in Apple's picker, **Done**, then **Continue**.

Why the presets moved here: the person's goal is expressed by what they block. Pawl does not need a separate identity question to infer it.

### Screen 4: Choose how you will unlock

Art: key on the left, sleeping cat with a second key on the right. The ally choice should use ally-specific art when selected rather than implying that the sleeping cat is the ally mechanism.

Every word before a choice:

- Progress: **"3 of 4"**
- Title: **"Choose how you will unlock"**
- Body: **"You need one working method before blocks turn on."**
- Card title: **"Security key"**
- Card body: **"Use a compatible USB-C security key, then wait 15 minutes."**
- Card title: **"Trusted person"**
- Card body: **"They approve from their iPhone, then you wait 15 minutes."**
- Footer: **"The 15-minute wait cannot be skipped."**

There is no "I don't have a key yet" activation path. A person without a key can go back, connect a trusted person, or leave setup without turning blocks on.

#### Screen 4A: Security key selected

Every word:

- Title: **"Pair your security key"**
- Body: **"Plug in your compatible USB-C security key and follow the prompt."**
- Callout title: **"How unlocking works"**
- Callout body: **"Use this key to request access. Pawl starts a 15-minute wait. When the wait ends, your blocked apps open."**
- Warning: **"There is no unlock from this iPhone without the key."**
- Primary button before pairing: **"Pair security key"**
- Status after pairing: **"Security key paired"**
- Primary button after pairing: **"Continue"**
- Secondary button: **"Use a trusted person instead"**

Taps: **Security key**, **Pair security key**, complete the key prompt, then **Continue**.

#### Screen 4B: Trusted person selected

Every word:

- Title: **"Connect a trusted person"**
- Body: **"They can approve an unlock request from their iPhone. They cannot see which apps or sites you block."**
- Requirement: **"Requires Pawl Pro and iCloud on both iPhones."**
- Callout title: **"How unlocking works"**
- Callout body: **"Your trusted person approves. Pawl starts a 15-minute wait. When the wait ends, your blocked apps open."**
- Warning: **"There is no unlock from this iPhone without their approval."**
- Primary button: **"Invite trusted person"**
- Waiting status: **"Waiting for [name] to join"**
- Connected status: **"[name] is connected"**
- Primary button after connection: **"Continue"**
- Secondary button: **"Use a security key instead"**

Taps: **Trusted person**, **Invite trusted person**, share the invitation, wait for the person to join, then **Continue**.

Blocks do not turn on while the invitation is pending. This path may take longer than one minute because another person must act. That is honest. Speed is not worth activating a lock with no working release method.

### Screen 5: Turn on blocks

Art: cat lying down with the key under its chin.

Every word:

- Progress: **"4 of 4"**
- Title: **"Ready to turn on blocks"**
- Summary row: **"Apps"** with **"1 selected"** or **"[number] selected"**
- Summary row when present: **"Websites"** with the count
- Summary row when present: **"Website categories"** with the selected category names
- Summary row: **"Unlock with"** and either **"Security key"** or **"[name], your trusted person"**
- Body: **"To reopen blocked apps and sites, use your security key or ask your trusted person. Then wait 15 minutes. The wait cannot be skipped."**
- Limitation: **"Turning off Screen Time can remove these blocks. For stronger protection, a trusted person can set a Screen Time passcode after setup."**
- Primary button: **"Turn on blocks"**
- Working state: **"Turning on blocks..."**

Tap: **Turn on blocks**.

The button is enabled only when Screen Time is allowed, at least one item is selected, and either a security key is paired or a trusted person is connected.

### Screen 6: Confirmation

Every word:

- Title: **"Blocks are on"**
- Body: **"Your selected apps and sites are blocked."**
- Method line for key: **"To reopen them, use your security key and wait 15 minutes."**
- Method line for ally: **"To reopen them, ask [name] and wait 15 minutes."**
- Primary button: **"Go to Home"**

Tap: **Go to Home**.

Home should lead with **"Protected"**, the number of blocked items, and the configured unlock method. Time-saved estimates, streaks, reports, and notes can appear later, after Pawl has recorded real activity.

## Taps to get blocks on

### Security key path

1. Set up Pawl
2. Allow Screen Time
3. Approve Apple's system sheet
4. Continue
5. Choose apps
6. Choose one app
7. Done
8. Continue
9. Security key
10. Pair security key
11. Complete the key prompt
12. Continue
13. Turn on blocks

That is about 13 taps plus two system surfaces. It is one tap shorter than the current shortest path, but the larger improvement is that every tap is necessary and the person finishes with a working unlock method.

### Trusted person path

1. Set up Pawl
2. Allow Screen Time
3. Approve Apple's system sheet
4. Continue
5. Choose apps
6. Choose one app
7. Done
8. Continue
9. Trusted person
10. Invite trusted person
11. Share the invitation
12. Wait for the trusted person to join
13. Continue
14. Turn on blocks

The ally path is intentionally not promised as a 60-second completion. Pawl can complete its own setup in the first minute, then wait safely for the trusted person. Protection starts only after the person is connected.

## Current lines and replacements

| Current line | Replacement | Reason |
|---|---|---|
| "Welcome to Pawl" | "Make distracting apps harder to reopen" | Leads with the outcome instead of the brand. |
| "What do you want to block?" | Remove this separate role question. Start setup, then ask the person to choose the actual apps and sites. | Removes redundant segmentation. |
| "Pick one or more. You can change this later." | "Add at least one app, website, or website category." | Makes the required action literal. |
| "Instagram, TikTok, X, Reddit, whatever keeps pulling you back." | Remove. | The Apple picker lets the person choose without being labeled or nudged by examples. |
| "What it costs you" | Remove the entire screen. | Avoids shame, speculation, and delay. |
| "A quick, private look." | "No account. Your choices stay on this iPhone." | Gives a concrete privacy promise. |
| "How many hours a day does this take?" | Remove. | Pawl should measure real outcomes later instead of asking for a guess. |
| "2 hours a day is about 730 hours a year, or 30 full days." | Remove. | The annualized loss is guilt-inducing and based on an arbitrary default. |
| "This is how Pawl blocks apps." | "Pawl uses Apple's Screen Time to block what you choose." | Names the mechanism in one plain sentence. |
| "Pawl only ever sees anonymous tokens, never which apps you chose." | "Your app and website choices stay on this iPhone. Pawl does not collect them." | Replaces implementation language with the actual privacy boundary. |
| "Add the social apps you keep opening. Website categories are optional." | "Add at least one app, website, or website category." | Works for every person without a prior role choice. |
| "Sportsbook, casino, and crypto sites we keep a list of." | "Blocks Pawl's list of sportsbook and casino sites." | States who owns the list and avoids treating all crypto as gambling. |
| "Pick a category, add an app, or type a site, so Pawl protects something." | "Choose something to continue." | Shorter and more direct. |
| "How will you unlock?" | "Choose how you will unlock" | Removes the conversational question and makes the action clear. |
| "Pick one. You can add the other later." | "You need one working method before blocks turn on." | Establishes the safety requirement. |
| "A small USB-C key you keep out of reach." | "Use a compatible USB-C security key, then wait 15 minutes." | Explains the mechanism and wait. |
| "Someone you trust says yes from their phone. Pawl Pro." | "They approve from their iPhone, then you wait 15 minutes." | Makes the sequence explicit. Show the Pro and iCloud requirement inside the selected path. |
| "Where you keep it is the trick" | Remove. | It is advice, not required setup, and "trick" weakens a serious decision. |
| "I don't have a key yet" | Remove as an activation path. Offer "Use a trusted person instead." | Prevents active blocks with no working unlock method. |
| "No key yet? That's OK." | "You need a paired key or connected trusted person before blocks turn on." | Kind but accurate. |
| "Your blocks turn on now" | "Blocks turn on after your trusted person is connected." | Does not confuse selecting a method with configuring it. |
| "They see almost nothing" | "They cannot see which apps or sites you block." | Gives the exact privacy fact the person cares about. |
| "Lock it in" | "Ready to turn on blocks" | Uses a literal commitment title. |
| "Here's what you're turning on." | Remove. | The new title and summary already say this. |
| "From here, lifting the shield needs your key or a yes from your ally, plus the wait." | "To reopen blocked apps and sites, use your security key or ask your trusted person. Then wait 15 minutes. The wait cannot be skipped." | Replaces metaphor and names the duration and sequence. |
| "Turning off Screen Time still removes protection." | "Turning off Screen Time can remove these blocks." | Plain, precise limitation. |
| "For a full lock, someone you trust can set a Screen Time passcode for you. That's Hard lock in Settings." | "For stronger protection, a trusted person can set a Screen Time passcode after setup." | Removes feature naming and explains the next action without sending the person hunting through Settings. |
| "Lock it in" button | "Turn on blocks" | The button says exactly what happens. |
| "Activating…" | "Turning on blocks..." | Plain working-state language and no ellipsis character. |
| "About 4 hr back, this week" | Do not show an estimate at first completion. Show "Protected" and the number of blocked items. | Do not present inferred benefit before real activity exists. |
| "Pair your security key: Your blocks are on, but nothing can unlock them yet." | This state should not exist. | A blocking product should not knowingly create an active configuration with no working unlock method. |

## Final recommendation

Cut the role picker and the cost calculator. Put the product promise on the first screen. Ask for Screen Time in context. Let the person choose the actual things they want blocked. Require a paired key or connected trusted person. State the unlock sequence the same way every time: use the key or ask the trusted person, wait 15 minutes, then access opens. Confirm protection before showing a dashboard.

This makes Pawl feel less like a behavior-change questionnaire and more like a dependable tool.
