// Copyright 2015 The Chromium Authors. All rights reserved.
//
// Redistribution and use in source and binary forms, with or without
// modification, are permitted provided that the following conditions are
// met:
//
//    * Redistributions of source code must retain the above copyright
// notice, this list of conditions and the following disclaimer.
//    * Redistributions in binary form must reproduce the above
// copyright notice, this list of conditions and the following disclaimer
// in the documentation and/or other materials provided with the
// distribution.
//    * Neither the name of Google Inc. nor the names of its
// contributors may be used to endorse or promote products derived from
// this software without specific prior written permission.
//
// THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
// "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
// LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
// A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT
// OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
// SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
// LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
// DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
// THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
// (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
// OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

// obtained from https://code.google.com/p/chromium/codesearch#chromium/src/components/autofill/core/browser/autofill_regex_constants.cc

import Foundation

// swiftlint:disable:next type_body_length
struct AutofillRegexConstants {
    /////////////////////////////////////////////////////////////////////////////
    // address_field.cc
    /////////////////////////////////////////////////////////////////////////////
    let kAttentionIgnoredRe = "attention|attn"
    let kRegionIgnoredRe =
        "province|region|other" +
            "|provincia" + // es
    "|bairro|suburb"  // pt-BR, pt-PT
    let kAddressNameIgnoredRe = "address.*nickname|address.*label"
    let kCompanyRe =
        "company|business|organization|organisation" +
            "|firma|firmenname" + // de-DE
            "|empresa" + // es
            "|societe|société" + // fr-FR
            "|ragione.?sociale" + // it-IT
            "|会社" + // ja-JP
            "|название.?компании" + // ru
            "|单位|公司" + // zh-CN
    "|회사|직장"  // ko-KR
    let kAddressLine1Re =
        "^address$|address[_-]?line(one)?|address1|addr1|street" +
            "|(?:shipping|billing)address$" +
            "|strasse|straße|hausnummer|housenumber" + // de-DE
            "|house.?name" + // en-GB
            "|direccion|dirección" + // es
            "|adresse" + // fr-FR
            "|indirizzo" + // it-IT
            "|^住所$|住所1" + // ja-JP
            "|morada|endereço" + // pt-BR, pt-PT
            "|Адрес" + // ru
            "|地址" + // zh-CN
    "|^주소.?$|주소.?1"  // ko-KR
    let kAddressLine1LabelRe =
        "address" +
            "|adresse" + // fr-FR
            "|indirizzo" + // it-IT
            "|住所" + // ja-JP
            "|地址" + // zh-CN
    "|주소"  // ko-KR
    let kAddressLine2Re =
        "address[_-]?line(2|two)|address2|addr2|street|suite|unit" +
            "|adresszusatz|ergänzende.?angaben" + // de-DE
            "|direccion2|colonia|adicional" + // es
            "|addresssuppl|complementnom|appartement" + // fr-FR
            "|indirizzo2" + // it-IT
            "|住所2" + // ja-JP
            "|complemento|addrcomplement" + // pt-BR, pt-PT
            "|Улица" + // ru
            "|地址2" + // zh-CN
    "|주소.?2"  // ko-KR
    let kAddressLine2LabelRe =
        "address|line" +
            "|adresse" + // fr-FR
            "|indirizzo" + // it-IT
            "|地址" + // zh-CN
    "|주소"  // ko-KR
    let kAddressLinesExtraRe =
        "address.*line[3-9]|address[3-9]|addr[3-9]|street|line[3-9]" +
            "|municipio" + // es
            "|batiment|residence" + // fr-FR
    "|indirizzo[3-9]"  // it-IT
    let kAddressLookupRe =
    "lookup"
    let kCountryRe =
        "country|countries" +
            "|país|pais" + // es
            "|国" + // ja-JP
            "|国家" + // zh-CN
    "|국가|나라"  // ko-KR
    let kCountryLocationRe =
    "location"
    let kZipCodeRe =
        "zip|postal|post.*cod e|pcode" +
            "|pin.?code" + // en-IN
            "|postleitzahl" + // de-DE
            "|\\bcp\\b" + // es
            "|\\bcdp\\b" + // fr-FR
            "|\\bcap\\b" + // it-IT
            "|郵便番号" + // ja-JP
            "|codigo|codpos|\\bcep\\b" + // pt-BR, pt-PT
            "|Почтовый.?Индекс" + // ru
            "|邮政编码|邮编" + // zh-CN
            "|郵遞區號" + // zh-TW
    "|우편.?번호"  // ko-KR
    let kZip4Re =
        "zip|^-$|post2" +
    "|codpos2"  // pt-BR, pt-PT
    let kCityRe =
        "city|town" +
            "|\\bort\\b|stadt" + // de-DE
            "|suburb" + // en-AU
            "|ciudad|provincia|localidad|poblacion" + // es
            "|ville|commune" + // fr-FR
            "|localita" + // it-IT
            "|市区町村" + // ja-JP
            "|cidade" + // pt-BR, pt-PT
            "|Город" + // ru
            "|市" + // zh-CN
            "|分區" + // zh-TW
    "|^시[^도·・]|시[·・]?군[·・]?구"  // ko-KR
    let kStateRe =
        "(?<!united )state|county|region|province" +
            "|land" + // de-DE
            "|county|principality" + // en-UK
            "|都道府県" + // ja-JP
            "|estado|provincia" + // pt-BR, pt-PT
            "|область" + // ru
            "|省" + // zh-CN
            "|地區" + // zh-TW
    "|^시[·・]?도"  // ko-KR

    /////////////////////////////////////////////////////////////////////////////
    // credit_card_field.cc
    /////////////////////////////////////////////////////////////////////////////
    let kNameOnCardRe =
        "card.?(?:holder|owner)|name.*(\\b)?on(\\b)?.*card" +
            "|(?:card|cc).?name|cc.?full.?name" +
            "|karteninhaber" +                   // de-DE
            "|nombre.*tarjeta" +                // es
            "|nom.*carte" +                      // fr-FR
            "|nome.*cart" +                     // it-IT
            "|名前" +                            // ja-JP
            "|Имя.*карты" +                      // ru
            "|信用卡开户名|开户名|持卡人姓名" + // zh-CN
    "|持卡人姓名"                     // zh-TW
    let kNameOnCardContextualRe =
    "name"
    let kCardNumberRe =
        "(add)?(?:card|cc|acct).?(?:number|#|no|num|field)" +
            "|nummer" + // de-DE
            "|credito|numero|número" + // es
            "|numéro" + // fr-FR
            "|カード番号" + // ja-JP
            "|Номер.*карты" + // ru
            "|信用卡号|信用卡号码" + // zh-CN
            "|信用卡卡號" + // zh-TW
    "|카드"  // ko-KR
    let kCardCvcRe =
        "verification|card.?identification|security.?code|card.?code" +
            "|security.?number|card.?pin|c-v-v" +
            "|(cvn|cvv|cvc|csc|cvd|cid|ccv)(field)?" +
    "|\\bcid\\b"

    // "Expiration date" is the most common label here, but some pages have
    // "Expires", "exp. date" or "exp. month" and "exp. year".  We also look
    // for the field names ccmonth and ccyear, which appear on at least 4 of
    // our test pages.

    // On at least one page (The China Shop2.html) we find only the labels
    // "month" and "year".  So for now we match these words directly we'll
    // see if this turns out to be too general.

    // Toolbar Bug 51451: indeed, simply matching "month" is too general for
    //   https://rps.fidelity.com/ftgw/rps/RtlCust/CreatePIN/Init.
    // Instead, we match only words beginning with "month".
    let kExpirationMonthRe =
        "expir|exp.*mo|exp.*date|ccmonth|cardmonth|addmonth" +
            "|gueltig|gültig|monat" + // de-DE
            "|fecha" + // es
            "|date.*exp" + // fr-FR
            "|scadenza" + // it-IT
            "|有効期限" + // ja-JP
            "|validade" + // pt-BR, pt-PT
            "|Срок действия карты" + // ru
    "|月"  // zh-CN
    let kExpirationYearRe =
        "exp|^/|(add)?year" +
            "|ablaufdatum|gueltig|gültig|jahr" + // de-DE
            "|fecha" + // es
            "|scadenza" + // it-IT
            "|有効期限" + // ja-JP
            "|validade" + // pt-BR, pt-PT
            "|Срок действия карты" + // ru
    "|年|有效期"  // zh-CN

    // The "yy" portion of the regex is just looking for two adjacent y's.
    let kExpirationDate2DigitYearRe =
    "(?:exp.*date.*|mm\\s*[-/]\\s*)[^y]yy([^y]|$)"
    let kExpirationDate4DigitYearRe =
    "^mm\\s*[-/]\\syyyy$"
    let kExpirationDateRe =
        "expir|exp.*date|^expfield$" +
            "|gueltig|gültig" + // de-DE
            "|fecha" + // es
            "|date.*exp" + // fr-FR
            "|scadenza" + // it-IT
            "|有効期限" + // ja-JP
            "|validade" + // pt-BR, pt-PT
    "|Срок действия карты"  // ru
    let kGiftCardRe =
    "gift.?card"
    let kDebitGiftCardRe =
    "(?:visa|mastercard|discover|amex|american express).*gift.?card"
    let kDebitCardRe =
    "debit.*card"

    /////////////////////////////////////////////////////////////////////////////
    // email_field.cc
    /////////////////////////////////////////////////////////////////////////////
    let kEmailRe =
        "e.?mail"  +
            "|courriel" + // fr
            "|メールアドレス" + // ja-JP
            "|Электронной.?Почты" + // ru
            "|邮件|邮箱" + // zh-CN
            "|電郵地址" + // zh-TW
    "|(?:이메일|전자.?우편|[Ee]-?mail)(.?주소)?"  // ko-KR

    /////////////////////////////////////////////////////////////////////////////
    // name_field.cc
    /////////////////////////////////////////////////////////////////////////////
    let kNameIgnoredRe =
        "user.?name|user.?id|nickname|maiden name|title|prefix|suffix" +
            "|vollständiger.?name" + // de-DE
            "|用户名" + // zh-CN
    "|(?:사용자.?)?아이디|사용자.?ID"  // ko-KR
    let kNameRe =
        "^name|full.?name|your.?name|customer.?name|bill.?name|ship.?name" +
            "|name.*first.*last|firstandlastname" +
            "|nombre.*y.*apellidos" + // es
            "|^nom" + // fr-FR
            "|お名前|氏名" + // ja-JP
            "|^nome" + // pt-BR, pt-PT
            "|姓名" + // zh-CN
    "|성명"  // ko-KR
    let kNameSpecificRe =
        "^name" +
            "|^nom" + // fr-FR
    "|^nome"  // pt-BR, pt-PT
    let kFirstNameRe =
        "first.*name|initials|fname|first$|given.*name" +
            "|vorname" + // de-DE
            "|nombre" + // es
            "|forename|prénom|prenom" + // fr-FR
            "|名" + // ja-JP
            "|nome" + // pt-BR, pt-PT
            "|Имя" + // ru
    "|이름"  // ko-KR
    let kMiddleInitialRe = "middle.*initial|m\\.i\\.|mi$|\\bmi\\b"
    let kMiddleNameRe =
        "middle.*name|mname|middle$" +
    "|apellido.?materno|lastlastname"  // es
    let kLastNameRe =
        "last.*name|lname|surname|last$|secondname|family.*name" +
            "|nachname" + // de-DE
            "|apellido" + // es
            "|famille|^nom" + // fr-FR
            "|cognome" + // it-IT
            "|姓" + // ja-JP
            "|morada|apelidos|surename|sobrenome" + // pt-BR, pt-PT
            "|Фамилия" + // ru
    "|성[^명]?"  // ko-KR

    /////////////////////////////////////////////////////////////////////////////
    // phone_field.cc
    /////////////////////////////////////////////////////////////////////////////
    let kPhoneRe =
        "phone|mobile|contact.?number" +
            "|telefonnummer" +                               // de-DE
            "|telefono|teléfono" +                           // es
            "|telfixe" +                                      // fr-FR
            "|電話" +                                        // ja-JP
            "|telefone|telemovel" +                          // pt-BR, pt-PT
            "|телефон" +                                     // ru
            "|电话" +                                         // zh-CN
    "|(?:전화|핸드폰|휴대폰|휴대전화)(?:.?번호)?"  // ko-KR
    let kCountryCodeRe =
    "country.*code|ccode|_cc"
    let kAreaCodeNotextRe =
    "^\\($"
    let kAreaCodeRe =
        "area.*code|acode|area" +
    "|지역.?번호"  // ko-KR
    let kPhonePrefixSeparatorRe =
    "^-$|^\\)$"
    let kPhoneSuffixSeparatorRe =
    "^-$"
    let kPhonePrefixRe =
        "prefix|exchange" +
            "|preselection" + // fr-FR
    "|ddd"  // pt-BR, pt-PT
    let kPhoneSuffixRe =
    "suffix"
    let kPhoneExtensionRe =
        "\\bext|ext\\b|extension" +
    "|ramal"  // pt-BR, pt-PT
}
