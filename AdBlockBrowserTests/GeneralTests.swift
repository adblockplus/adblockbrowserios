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

@testable import AdblockBrowser
import AttributedMarkdown
import XCTest

class GeneralTests: XCTestCase {
    func testMarkdownParser() {
        let testCases = [
            (
                input: "*další možnosti blokování* vycházejí z tzv. **filterlistů**",
                output:"další možnosti blokování vycházejí z tzv. filterlistů",
                italicRange: NSRange(location: 0, length: "další možnosti blokování".count),
                boldRange: NSRange(location: "další možnosti blokování vycházejí z tzv. ".count, length: "filterlistů".count)
            )
        ]

        // create a font attributes
        let emFont = UIFont.italicSystemFont(ofSize: 15)
        let strongFont = UIFont.boldSystemFont(ofSize: 18)

        // create a dictionary to hold your custom attributes for any Markdown types
        let attributes = [
            NSNumber(value: EMPH.rawValue): [NSAttributedStringKey.font: emFont],
            NSNumber(value: STRONG.rawValue): [NSAttributedStringKey.font: strongFont]
        ]

        for testCase in testCases {

            // parse the markdown
            guard let prettyText = attributedStringFromMarkdown(testCase.input, attributes: attributes) else {
                XCTFail("Markdown Parsing Failed")
                continue
            }

            // From unknown reaser, parser is putting new line on the end of the string.
            let result = prettyText.string

            XCTAssert(testCase.output == result, "texts should be equal")

            var range = NSRange()
            var font = prettyText.attribute(NSAttributedStringKey.font,
                                            at: testCase.italicRange.location,
                                            effectiveRange: &range) as? UIFont

            XCTAssert(font == emFont && range.length == testCase.italicRange.length,
                      "texts should use italic font")

            font = prettyText.attribute(NSAttributedStringKey.font,
                                        at: testCase.boldRange.location,
                                        effectiveRange: &range) as? UIFont

            XCTAssert(font == strongFont && range.length == testCase.boldRange.length,
                      "texts should use bold font")
        }
    }

    func testLCS() {
        let testCases = [
            (
                input: ("", ""),
                output: 0
            ),
            (
                input: ("abc", "aabbcc"),
                output: 3
            ),
            (
                input: ("abcd", "eeabeecdee"),
                output: 4
            ),
            (
                input: ("abcd", "abcde"),
                output: 4
            ),
            (
                input: ("abcd", "efghij"),
                output: 0
            )
        ]

        for testCase in testCases {
            let input1 = testCase.input.0.map { String($0) }
            let input2 = testCase.input.1.map { String($0) }

            let sequence = longestCommonSubsequence(input1, input2)
            XCTAssert(sequence.count == testCase.output)

            for (index1, index2) in sequence {
                XCTAssert(input1[index1] == input2[index2])
            }
        }
    }

    func testLCSGenerated() {
        for length in 0..<64 {

            var input1 = (0..<length).map { $0 }
            var input2 = input1

            for _ in 0..<arc4random_uniform(64) {
                input1.insert(
                    Int(arc4random_uniform(1000) + 1000),
                    at: Int(arc4random_uniform(UInt32(input1.count + 1)))
                )
            }

            for _ in 0..<arc4random_uniform(64) {
                input2.insert(
                    Int(arc4random_uniform(1000) + 2000),
                    at: Int(arc4random_uniform(UInt32(input2.count + 1)))
                )
            }

            let sequence = longestCommonSubsequence(input1, input2)
            XCTAssert(sequence.count == length)

            for (index1, index2) in sequence {
                XCTAssert(input1[index1] == input2[index2])
            }
        }
    }
}

class ArrayDataSource: NSObject, UITableViewDataSource {
    var model = [AnyObject]()

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return model.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        return tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath)
    }
}
