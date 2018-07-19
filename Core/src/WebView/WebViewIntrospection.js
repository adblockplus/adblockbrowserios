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

function com_kitt_SearchElementsPropertiesAtPoint(x,y)
{
    var ELEMS_INTEREST = ['A', 'IMG'];
    var PROPS_INTEREST = ['src', 'href', 'alt'];
    function descendDocumentAtPoint(aDocument, x, y, elems)
    {
        var elem = aDocument.elementFromPoint(x, y);
        while (elem) {
            if (ELEMS_INTEREST.indexOf(elem.tagName) !== -1) {
                var elemProps = {};
                PROPS_INTEREST.forEach(function(prop) {
                                       elemProps[prop] = elem[prop];
                                       });
                elems[elem.tagName] = elemProps;
            }
            elem = elem.parentNode;
        }
        return elems;
    }
    var elems = {};
    var spread = 0; // 0, 1, -1, 2, -2, 3, -3, ... 20
    while ((Object.keys(elems).length === 0) && (spread < 20)) {
        elems = descendDocumentAtPoint(document, x, y+spread, elems);
        spread = -spread;
        if(spread >= 0) {
            spread++;
        }
    }
    return JSON.stringify(elems);
}
