const postMessage = (message) => {
  window.webkit.messageHandlers.testSymbol.postMessage(message)
}

const invoke = (func, ...rest) => {
  return new Promise((resolve, reject) => {
    func.call(this, ...rest, (result) => {
      if (chrome.runtime.lastError) {
        reject(chrome.runtime.lastError)
      } else {
        resolve(result)
      }
     })
  })
}

const assert = (expression, message) => {
  if (!expression) {
    throw Error(message)
  }
}

const tests = {}
const registerTest = async (testName, testFunc) => {
  tests[testName] = testFunc
}

// invoked by the native side
window.executeTest = async (testName) => {
  const testFunc = tests[testName]
  try {
    await testFunc()
    postMessage({[testName]: {testPassed: `Function ${testName} succeeded`}})
  } catch (e) {
    postMessage({[testName]: {testFailed: e.toString(), stack: e.stack}})
  }
}

postMessage({backgroundScriptReady: true})
