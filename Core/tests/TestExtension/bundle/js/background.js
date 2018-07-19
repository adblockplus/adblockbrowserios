registerTest("testTabsQuery", async () => {
  const tabs = await invoke(chrome.tabs.query, {})
  assert(tabs.length == 1, "One tab should be open")

  const activeTabs = await invoke(chrome.tabs.query, {active: true})
  assert(tabs.length == 1 && tabs[0].active, "First tab should be active")
})
