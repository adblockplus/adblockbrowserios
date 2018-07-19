/*
 * This file is part of Adblock Plus <https://adblockplus.org/>,
 * Copyright (C) 2006-present eyeo GmbH
 *
 * Adblock Plus is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License version 3 as
 * published by the Free Software Foundation.
 *
 * Adblock Plus is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with Adblock Plus.  If not, see <http://www.gnu.org/licenses/>.
 */

import Foundation

typealias AutofillFormValues = [String: Any]
typealias AutofillFormData = [String: Any]
typealias AutofillFormFieldData = [String: Any]

class FormAutofiller {
    init(regexConstants: AutofillRegexConstants) {
        fieldTypeDetector = FieldTypeDetector(regexConstants: regexConstants)
    }

    func fill(_ form: AutofillFormData) -> AutofillFormValues? {
        guard let formFields = (form["fields"] as? [AutofillFormFieldData]) else {
            return nil
        }

        guard let formName = form["name"] else {
            return nil
        }

        var filledForm = AutofillFormValues()
        filledForm["formName"] = formName
        var fields = [String: String]()

        for field in formFields {

            guard let fieldName = field["name"] as? String else {
                Log.error("There is no 'name' in form field data, or it is not string")
                continue
            }
            let fieldType = fieldTypeDetector.detectType(field)
            if fieldType != AutofillFieldType.unknown {
                fields[fieldName] = fieldType.rawValue
            }
        }
        filledForm["fields"] = fields

        return filledForm
    }

    fileprivate var fieldTypeDetector: FieldTypeDetector
}

class FieldTypeDetector {
    init(regexConstants: AutofillRegexConstants) {
        self.regexConstants = regexConstants
    }

    func didFindPattern(_ pattern: String, string: String) -> Bool {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else {
            return false
        }
        let numberOfMatches = regex.numberOfMatches(in: string, options: NSRegularExpression.MatchingOptions(),
                                                    range: NSRange(location: 0, length: string.count))
        return numberOfMatches > 0
    }

    func validateField(_ field: AutofillFormFieldData, wantedRegex: String, unwantedRegex: String = "") -> Bool {
        // check name and label
        guard let name = field["name"] as? String, let label = field["label"] as? String else {
            return false
        }

        let nameLabel = name + label
        return didFindPattern(wantedRegex, string: nameLabel) && !didFindPattern(unwantedRegex, string: nameLabel)
    }

    // swiftlint:disable:next cyclomatic_complexity
    func detectType(_ extractedField: AutofillFormFieldData) -> AutofillFieldType {
        guard let formControlType = extractedField["form_control_type"] as? String else {
            return .unknown
        }

        if !["text", "textarea", "email", "number"].contains(formControlType) {
            return .unknown
        }

        guard let shouldAutocomplete = extractedField["should_autocomplete"] as? Bool, shouldAutocomplete else {
            return .unknown
        }

        // email
        if formControlType == "email" {
            return .email
        }

        if validateField(extractedField, wantedRegex: regexConstants.kEmailRe) {
            return .email
        }
        if validateField(extractedField, wantedRegex: regexConstants.kNameRe, unwantedRegex: regexConstants.kNameIgnoredRe) {
            return .name
        }
        if validateField(extractedField, wantedRegex: regexConstants.kCompanyRe) {
            return .organization
        }

        if validateField(extractedField, wantedRegex: regexConstants.kAddressLine1Re, unwantedRegex: regexConstants.kAddressNameIgnoredRe) {
            return .streetAddress
        }
        if validateField(extractedField, wantedRegex: regexConstants.kAddressLine1LabelRe) {
            return .streetAddress
        }

        if validateField(extractedField, wantedRegex: regexConstants.kCityRe) {
            return .city
        }
        if validateField(extractedField, wantedRegex: regexConstants.kCountryRe) {
            return .countryRegion
        }
        if validateField(extractedField, wantedRegex: regexConstants.kPhoneRe) {
            return .phone
        }
        if validateField(extractedField, wantedRegex: regexConstants.kZipCodeRe) {
            return .postalCode
        }

        return .unknown
    }

    fileprivate var regexConstants: AutofillRegexConstants
}
