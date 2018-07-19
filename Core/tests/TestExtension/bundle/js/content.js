chrome.runtime.onMessage.addListener((request, sender, sendResponse) => {
  request = request || {}
  request.passedExtensionJavascript = true
  sendResponse(request)
});
