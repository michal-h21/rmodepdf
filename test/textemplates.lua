--- @module 'busted'
local textemplates = require "rmodepdf-textemplates"

local expand = textemplates.expand
describe("Basic expansion should work", function()
  it("Should expand content", function()
    assert.same(expand("hello %s", "world"), "hello world")
  end)
  it("Should expand parameters", function()
    assert.same(expand("hello @{test}", "", {test="world"}), "hello world")
  end)
  it("Should ignore empty parameter", function ()
    assert.same(expand("hello @{}"), "hello @{}")
  end)
end)
