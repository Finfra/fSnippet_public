# fSnippetCli Official Build License Terms

Version 1.2 — applies to Official Builds published on or after 2026-09-27.
Builds published before that date remain under the terms they shipped with.

## 0. Summary (for information; the operative terms are set out below)

* The **source code** is Apache-2.0. Build it yourself and use it without any limit.
* **Official Builds** (the packages Finfra builds and ships) are free for personal use,
  education, non-profits, open-source projects, and any other organization on up to
  **250 concurrent copies**. Beyond that, or for resale / bundling / hosting, you need
  a commercial license (COMMERCIAL.md).

## 1. Definitions

* **"Licensor"** means Finfra Co., Ltd. (https://finfra.kr).
* **"Source Code"** means the fSnippetCli source code that the Licensor publishes under
  the Apache License, Version 2.0 (see LICENSE).
* **"Official Build"** means a binary, package or installer that the Licensor compiles
  (or causes to be built) and distributes through its official channels
  (Homebrew tap finfra/tap, GitHub Releases), signed and notarized where the target platform supports it. An
  Official Build is licensed and provided as an integrated package consisting of
  (a) object code compiled from the Source Code, and (b) the **Official Build
  Components**: the Licensor's brand assets embedded in the build (product names, icons,
  logos, banners, about/version text), the Licensor's proprietary build configuration
  that is not included in the public source repository, its code signature and
  notarization, and any other material the Licensor includes that is not part of the
  Source Code. The Official Build Components are proprietary to the Licensor and are
  **not** licensed under the Apache License.
* **"Organization"** means a legal entity together with its Affiliates. **"Affiliate"**
  means any entity that controls, is controlled by, or is under common control with
  that entity, where "control" means ownership of more than 50 % of the voting
  interests **or** the power, by contract or otherwise, to direct the management and
  policies of the entity.
* **"Non-Profit"** means an entity recognized as non-profit, charitable or
  public-benefit under the law of its jurisdiction. **"Educational Institution"** means
  a school, college or university, including its staff and students acting in that
  capacity.
* **"Open-Source Project"** means a project whose source code is publicly available
  under a license approved by the Open Source Initiative. Internal or private projects
  are not Open-Source Projects, whatever their internal policy.
* **"Copy"** means one installed or running instance of an Official Build on one
  physical device, virtual machine, container or other execution environment. Copies
  are counted **concurrently**. For ephemeral environments (CI runners, temporary
  containers, serverless functions), the number of Copies is the maximum number of
  instances running at the same time during any 24-hour period.

## 2. Relationship to the Apache License

Nothing in these terms limits any right you have under the Apache License 2.0 in the
Source Code, or in object code that you or any third party compile from it. You may
also extract the Apache-licensed object code from an Official Build and use it under
the Apache License; the result is **not** an Official Build, must not include the
Official Build Components and must not use the Licensor's marks (TRADEMARK.md).

These terms govern the use of the Official Build **as the integrated package** the
Licensor provides. If you do not accept these terms, do not use Official Builds —
build fSnippetCli from the Source Code instead.

## 3. License for Official Builds — free use

Subject to these terms, the Licensor grants you a non-exclusive, royalty-free license
to download, install and use Official Builds:

* as an **individual for personal purposes**, on devices that are not managed by, and
  not used for the business of, an Organization — without limit;
* within an **Educational Institution** or a **Non-Profit** — without limit;
* for an **Open-Source Project** — without limit;
* within any other **Organization** (including by its employees and contractors on
  any device used for its business) — on up to **250 Copies** at the same time.

The license is not transferable to another Organization. Distribution inside your own
Organization under §5 is not a transfer.

## 4. Uses that require a commercial license

Regardless of the number of Copies, a separate commercial license from the Licensor is
required to:

* install or run Official Builds on more than 250 Copies within one Organization;
* **resell** Official Builds, or **bundle or integrate** them with any product, paid
  service or consulting deliverable that is sold or paid for;
* offer fSnippetCli as a **hosted or managed service** using Official Builds to third
  parties (hosting for your own Affiliates is internal use and every running instance
  counts toward 250);
* remove, hide, alter or circumvent any copyright, trademark, license or attribution
  notice contained in an Official Build.

See COMMERCIAL.md for how to obtain a commercial license.

## 5. Redistribution of Official Builds

You may redistribute **unmodified** Official Builds free of charge, including through an
internal package mirror inside your Organization, provided these terms and all notices
accompany them and recipients are bound by these terms. Anything other than an
unmodified Official Build is governed by §2 (Apache License for the object code, no
Official Build Components, no marks).

## 6. Acceptance and notice

By downloading, installing or using an Official Build you accept these terms. The
Licensor presents these terms before installation (repository README, above the
install command), at installation (package manager caveats), on the release page and
inside the package.

## 7. Trademarks

These terms grant no trademark rights. See TRADEMARK.md.

## 8. No warranty; limitation of liability

Official Builds are provided "AS IS", without warranty of any kind, express or implied,
to the extent permitted by applicable law. To the same extent, the Licensor is not
liable for any indirect, incidental or consequential damages arising from the use of
Official Builds. Nothing in these terms excludes liability that cannot be excluded under
applicable law (for example liability for wilful misconduct or gross negligence).

## 9. Termination

Your license under these terms terminates automatically if you breach them. It is
reinstated once if you cure the breach within 30 days of becoming aware of it or
receiving notice from the Licensor. A further breach within 12 months after a
reinstatement terminates the license permanently unless the Licensor agrees otherwise
in writing. Termination does not affect your rights under the Apache License.

## 10. Governing law and venue

These terms are governed by the laws of the Republic of Korea. Disputes are subject to
the jurisdiction of the Seoul Central District Court as the court of first instance.
For individuals residing in the Republic of Korea, venue follows the Civil Procedure
Act and the Korean translation has equal effect. For others, mandatory law of the
place of residence applies where it cannot be excluded; otherwise the English text is
binding and any translation is for reference only.

## 11. Changes

The Licensor may publish revised terms with future Official Builds. Revised terms apply
only to builds released after the revision; builds you already have remain under the
terms they shipped with.

## 12. Miscellaneous

If any provision of these terms is held unenforceable, the remaining provisions stay in
effect. These terms are the entire agreement between you and the Licensor concerning
Official Builds; they do not modify the Apache License for the Source Code.

Contact: finfra@gmail.com · Copyright (c) 2026 Finfra Co., Ltd. (https://finfra.kr)
