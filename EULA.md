# AgentNet Alpha — End-User Licence Agreement

**Version:** Alpha 0.1 · **Publisher:** Alp Bingol ("the Publisher", "we")
**Contact:** alp.bingol+AgentNet@gmail.com

By installing or using AgentNet Alpha ("the Software") you accept this agreement. If you do not accept it, do not
install or use the Software.

## 1. What the Software is

AgentNet is a daemon and desktop app that runs and coordinates Claude Code agents. The Alpha is **pre-release
software**: it may be incomplete, change without notice, lose data or stop working.

## 2. Licence

1. We grant you a **free, non-exclusive, non-transferable, revocable licence** to install and use the Software for
   **personal and commercial purposes** during the Alpha.
2. The licence is **per node**. A node is one AgentNet instance or daemon, that is, each separate `--home`
   (data folder). Linked AgentNets are separate nodes.
3. During the Alpha the node licence costs nothing. **Later versions (for example a Beta) may need a paid node
   licence.** We may charge for later versions, and we may end the Alpha (see section 8). The Alpha licence gives you
   no right to any later version at no cost.
4. The Software is licensed, not sold. We keep all rights not expressly granted. The source code is not published.

## 3. What you may not do

Unless the law allows it despite this clause, you may not:

- copy or **redistribute** the Software, or give, lend, rent, **sell** or sublicense it to others;
- **reverse engineer, decompile or disassemble** it, or try to get its source code;
- **modify** it or make derivative works, including **disabling, bypassing or patching** the admin block, the
  protected areas, the shutdown check (section 4), or any other protection or licence check;
- remove copyright or licence notices.

**Your rights under mandatory law stay.** Under EU law (Directive 2009/24/EC, and the national law that implements it)
you may, without our consent: make a backup copy you need; observe, study and test how the Software works while you
use it as allowed; and **decompile it to the extent needed for interoperability** with another program you
develop, if we have not made that information available to you and you meet the legal conditions. Information you get
this way may be used only for that purpose. Nothing here limits the rights you cannot give up as a consumer.

## 4. Remote shutdown

1. We may **shut down all Alpha installs remotely.** We do this with a **signed shutdown message**. The Software
   checks for it by fetching a public file from our **public GitHub releases repository**, and passes it on to
   **linked AgentNets**. The Software only accepts a message with our valid signature.
2. When it receives a valid message the Software stops working (or stops starting) as the message says.
3. **Running agents:** All running agents will be wound down, their last work saved and will be unable to launch or resume.
4. **Undo:** Global shutdown can be reversed using a similar method by the publisher.
5. Reasons might include a serious security or safety problem, the end of the Alpha, or a legal requirement. We will
   try to announce a planned end of the Alpha in the releases repository first.
6. Your own files, code and data stay on your machine. A shutdown does not delete them.

## 5. Data and privacy

- **No telemetry.** The Software does not send usage data, analytics or crash reports to us.
- **Two network requests of ours,** both plain downloads of public files from our GitHub releases repository: the
  shutdown file (section 4, about hourly) and the update check (once a day, for a newer signed release; you can turn it
  off in Settings → Updates). GitHub can see these requests (for example your IP address) under its own privacy
  policy. We receive nothing from them.
- **Feedback** is sent **only by you**, through GitHub (issues) or email. What you write, and anything you attach,
  is visible to us (and on GitHub, to the public). Please do not include secrets or personal data of others.
- **Anonymous usage heartbeat.** A later update might add an anonymous heartbeat (for example to count
  active installs). If so, it will come with a **privacy notice** (what is sent, why, legal basis, how long it is kept,
  your rights under the GDPR, and how to turn it off if that is possible), and we will not turn it on silently.
- Where we handle personal data, the controller is the Publisher at the contact address above.

## 6. Third-party software

- **Claude Code.** AgentNet runs on Claude Code, which you install and sign in to **yourself**. It is Anthropic's
  product under **Anthropic's terms**. You pay for your own usage. We are not Anthropic, we do not resell access,
  and Anthropic's terms apply to your use of Claude.
- **Other programs.** Beads, Agent Mail, nats-server and bubblewrap are **separate programs under their own
  licences**. They are listed in `THIRD-PARTY-NOTICES.md`. Those licences apply to those programs; this agreement does
  not change them. Agent Mail is used under its licence and the written permission of its author Jeffrey.

## 7. Your content

- **You own your code**, your projects, your data and your themes. We claim no rights over them. You give us no
  licence to them.
- You are responsible for **what you put into custom themes**, including logos, images and names. Do not use
  trademarks or copyrighted material you have no right to use. We are not responsible for it.
- You are responsible for what your agents do on your machines and with your accounts, and for reviewing their work.

## 8. Changes, ending the Alpha, termination

- We may update the Software, charge for later versions, or end the Alpha, as set out in sections 2 and 4.
- You may stop at any time by uninstalling the Software.
- We may end your licence if you seriously breach this agreement. Then you must stop using and delete the Software.
- Sections that by their nature should continue (for example 3, 7, 9, 10) continue after the end.

## 9. No warranty; limit of liability

The Alpha is free pre-release software, provided **"as is" and "as available"**, with **no warranty** of any
kind, to the extent the law allows. We do not promise that it works, is secure, is free of errors, or suits your
purpose. AI agents can make mistakes, change or delete files and run commands; **back up your work.**

To the extent the law allows, we are **not liable** for indirect or consequential loss, lost profit, lost data or
business interruption, and our total liability for anything arising from the Alpha is limited to 0.

**This does not limit liability that cannot be excluded by law**, including liability for intent or gross negligence,
for injury to life, body or health, under product liability law, and any mandatory consumer rights you have.

## 10. Governing law, disputes

This agreement is governed by the law of **Finland**. If you are a consumer in the EU, you also keep the
protection of the mandatory consumer law of the country where you live, and you may bring a claim in the courts of
that country.

## 11. General

If a part of this agreement is invalid, the rest stays valid. We may change this agreement for future versions; we
will tell you before the change applies, and by continuing to use a version you accept its terms. This is the whole
agreement between us about the Alpha.

## 12. Contact

alp.bingol+AgentNet@gmail.com · Feedback and bug reports: see `README.md`.
