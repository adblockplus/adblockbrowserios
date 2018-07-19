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

import {IBaseKittInterface} from "./baseKittInterface"

/**
 Fulltext search
 */
// HTML element to wrap the matches in
const matchElementName = "kitt-find"
// "Current" : the selected/highlighted match
// "Normal" : (all other) non-selected match(es)
const matchClassNormal = "fulltext"
const matchClassCurrent = matchClassNormal + "-current"
// id prefix applied on the above element
const matchElementIdPrefix = "match-nr-"
let matchStyleReset = "display: inline !important; visibility: visible !important; position: static !important"
// Needed for sites which declare css asterisk selector with some font size
// and then override it for the text where a match is found. Our inserted custom tag then by
// uses this asterisk declaration over the immediate parent declaration
// Example: https://adblockplus.org/main/main.css
// Generally: http://stackoverflow.com/a/1714210
matchStyleReset += "; font-size:inherit"
const matchStyleNormal = "background:#ffff00;" + matchStyleReset
// style differentiator for current selection
const matchStyleCurrent = "background:#ff7f00;" + matchStyleReset
// XSLT selectors
// All matches, normal and current
const matchSelectorAll = matchElementName + "[class^=\"" + matchClassNormal + "\"]"
// Non selected matches
const matchSelectorNormal = matchElementName + "[class=\"" + matchClassNormal + "\"]"
// The current (highlighted) match
const matchSelectorCurrent = matchElementName + "[class=\"" + matchClassCurrent + "\"]"

// nodes with potential TEXT subnodes to be ignored
/*
'noscript' explanation: There can be a legitimately searchable element inside <noscript> indeed.
But the problem with such searching is two fold:
1. Matches are counted and attempted to be scrolled in focus, but invisible. Scripts are working,
   so the content isn't used. If scripts really weren't working, the fulltext search won't happen
   at all in the first place.
2. Even if the matches were visible somehow, the DOM parser can't recognize what to parse
   in <noscript>. It's all just plaintext. So it matches on element attributes, URLs, anything.
*/
const ignorableNodes = ["script", "style", "canvas", "svg", "noscript"]

/**
 Descends recursively from starting node. Searches text nodes for regex
 and inserts new elements at match places.
 @param node the root node to start searching in (expectably document)
 @param visitor visit every matching child
 */
function visitTextNodes(node: HTMLElement, visitor: (x: HTMLElement, y: HTMLElement) => void) {
  for (let child: any = node.firstChild; child; child = child.nextSibling) {
    if (child.nodeType === 1 && // ELEMENT type
       ignorableNodes.indexOf(child.tagName.toLowerCase()) === -1 &&
       // During tree walking, stop only on irreversibly invisible nodes
       isElementInheritablyVisible(child)
       ) {
      // descend if not ignorable
      visitTextNodes(child, visitor)
    } else if (
              child.nodeType === 3 && // TEXT type
              child.data.trim().length > 0 && // skip CR/LF virtual nodes
              // Test the immediate parent because that's what have a direct
              // influence on the newly created text nodes visibility
              isElementVisible(node)
              ) {
      child = visitor(child, node)
    }
  }
}

/**
 Counts the matching elements
 @param regex RegEx search query
 @param node the root node to start searching in (expectably document)
 @return number of matching elements
 */
function countMatches(regex: RegExp, node: HTMLElement) {
  let count = 0
  visitTextNodes(node, function (child: any) {
    count += (child.data.match(regex) || []).length
    return child
  })
  return count
}

/**
Marks the elements with sequential id
for later matching and removal.
@param regex RegEx search query
@param node the root node to start searching in (expectably document)
@return Array of clientRects with appended matches on this level
*/
function markMatches(regex: RegExp, node: HTMLElement) {
  const clientRects: ClientRect[] = []
  visitTextNodes(node, function (child: any, parent: any) {
    /* jshint loopfunc: true */
    child.data.replace(regex, function(matchStr: string, offset: number, totalStr: string) {
      // make two new text nodes, second starting at match
      const nextText = child.splitText(offset)
      // strip the match text from the beginning of the second node
      nextText.data = nextText.data.substr(matchStr.length)
      // make a new element with text of the match
      const newText = document.createElement(matchElementName)
      newText.className = matchClassNormal
      newText.textContent = matchStr
      // insert between
      parent.insertBefore(newText, nextText)
      // remember the rectangle
      clientRects.push(newText.getBoundingClientRect())
      // tag for later lookup
      newText.id = matchElementIdPrefix + (clientRects.length)
      // the iteration will continue with the second new split text node
      child = newText
      return "" // probably cleaner than no return (undefined)
    })
    return child
  })
  return clientRects
}

/**
Enumerates all previously created match elements.
Groups elements with the same parent.
Replaces the match elements with basic text nodes.
Normalize()s the sibling text nodes back to one.
*/
function unmarkMatches() {
  // array of arrays of mark elements with the same parent
  const groupByParent: any[] = []
  let currentGroup: any[] | null = null
  const matchNodes = document.querySelectorAll(matchSelectorAll) // depth first
  for (let i = 0; i < matchNodes.length; i++) { // noprotect
    const matchNode = matchNodes[i]
    if (!currentGroup || currentGroup[0].parentNode !== matchNode.parentNode) {
      currentGroup = null // find a new one
      for (let group of groupByParent) {
        if (group[0].parentNode === matchNode.parentNode) {
          currentGroup = group
          break
        }
      }
    }
    if (!currentGroup) {
      currentGroup = []
      groupByParent.push(currentGroup)
    }
    currentGroup.push(matchNode)
  }
  groupByParent.forEach(function(group) {
    const parentNode = group[0].parentNode
    group.forEach(function(node: any) {
      const newNode = document.createTextNode(node.textContent)
      parentNode.replaceChild(newNode, node)
    })
    parentNode.normalize()
  })
}

/**
Finds previously selected match node (if any) and removes selection style.
Finds the new match node by index and applies the selection style.
@return bounding rect of the new match node
@return nil if the match node is not found. Can happen if the match was previously found
and marked in a dynamic text - such that was changed by page JS after the matching, hence
deleting the match node.
*/
function makeCurrent(index: number) {
  let matchNode: Element | HTMLElement | null = document.querySelector(matchSelectorCurrent)
  if (matchNode) {
    matchNode.className = matchClassNormal
  }
  matchNode = document.getElementById(matchElementIdPrefix + index)
  if (matchNode) {
    matchNode.className = matchClassCurrent
    return matchNode.getBoundingClientRect()
  }
  return
}

let styleInjected = false

/**
Creates programmatically a style for selected match node.
Other non-selected match nodes use the default style.
*/
function addMarkingStyle() {
  if (styleInjected) {
    return
  }
  styleInjected = true
  const styleElem = document.createElement("style")
  // Apparently some version of Safari needs the following line? I dunno.
  styleElem.appendChild(document.createTextNode(""))
  // PZ: ^^^ Mozilla said so
  document.head.appendChild(styleElem);
  (<any>styleElem.sheet).insertRule(matchSelectorNormal + "{" + matchStyleNormal + "}", 0);
  (<any>styleElem.sheet).insertRule(matchSelectorCurrent + "{" + matchStyleCurrent + "}", 0)
}

// Checks element visibility on CSS properties which cannot be overridden in children
// @return false if element is invisible, non-reversibly for its children
function isElementInheritablyVisible(element: HTMLElement, style: CSSStyleDeclaration | undefined = undefined) {
  style = style || window.getComputedStyle(element)
  function isOverflown(element: HTMLElement, indentValue: string) {
    const indentMatch = /(\-?[0-9.]+)([a-z]+|%)/.exec(indentValue)
    if (!indentMatch) {
      return false // cannot match
    }
    const number = Number(indentMatch[1])
    if (!number || isNaN(number)) {
      return false // didn't recognize number
    }
    // Assuming that absolute indent value (non %) will be in px
    // (boundingClientRect result unit). Other metrics are used rarely.
    const maxIndent = (indentMatch[2] === "%") ? 100 : element.getBoundingClientRect().width
    return Math.abs(number) > maxIndent
  }

  return(
    style.visibility !== "hidden" &&
    style.display !== "none" &&
    style.opacity !== "0" &&
    (style.overflow !== "hidden" || !isOverflown(element, style.textIndent || ""))
  )
}

function isElementVisible(element: HTMLElement) {
  const rect = element.getBoundingClientRect()
  const scrollLeft = document.body.scrollLeft
  const scrollTop = document.body.scrollTop
  const style = window.getComputedStyle(element)
  return (
    isElementInheritablyVisible(element, style) &&
    element.style.visibility !== "hidden" &&
    rect.width > 0 && rect.height > 0 &&
    rect.left + scrollLeft >= 0 &&
    rect.right + scrollLeft <= document.body.scrollWidth &&
    rect.top + scrollTop >= 0 &&
    rect.bottom + scrollTop <= document.body.scrollHeight
  )
}

// JS bridge is returning just the center points to minimize amount of
// transferred data
function centerPointFromClientRect(rect: ClientRect): [number, number] {
  return [
    Math.round(rect.left + rect.width / 2),
    Math.round(rect.top + rect.height / 2)
  ]
}

// Transforms the array of location coordinates to a return object
// with the current viewport size
function viewportWithLocations(locations: [number, number][]) {
  return {
    viewport: [
      window.innerWidth,
      window.innerHeight
    ],
    locations: locations
  }
}

export default {
  init: function(api: IBaseKittInterface) {
    api.addListener("fulltext.countMatches", {}, function(message) {
      const phrase = message.data.phrase
      if (!phrase) {
        return [0]
      }
      // regex global (all occurences) and case insensitive
      const regex = new RegExp(phrase, "gi")
      return [countMatches(regex, document.body)]
    })
    api.addListener("fulltext.markMatches", {}, function(message) {
      addMarkingStyle()
      unmarkMatches() // possible previous matches
      const phrase = message.data.phrase
      if (!phrase) {
        return viewportWithLocations([])
      }
      // just case insensitive, "global" is achieved by recursed subdivision
      const regex = new RegExp(phrase, "i")
      const clientRects = markMatches(regex, document.body)
      return viewportWithLocations(clientRects.map(centerPointFromClientRect) || [])
    })
    api.addListener("fulltext.unmarkMatches", {}, function(message) {
      unmarkMatches()
    })
    api.addListener("fulltext.makeCurrent", {}, function(message) {
      addMarkingStyle()
      const index = message.data.index
      if (typeof index === "undefined") {
        return null
      }
      // API index starts at 0 but match element ids start at 1.
      // It's more natural in DOM as an ordinal number of n-th match.
      const rect = makeCurrent(index + 1)
      // If there is no rect returned (match is gone), return empty array
      // to distinguish from a plain malfunction
      return rect ? viewportWithLocations([centerPointFromClientRect(rect)]) : []
    })
  }
}
