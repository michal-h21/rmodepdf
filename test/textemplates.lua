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
  it("Should be OK with longer texts", function ()
    local test = 
    [[\usepackage[@{lang}]{babel}
    \setmainfont{Literata}
    \usepackage[@{geometry}]{geometry}
    \pagestyle{@{pagestyle}}]]
    print(expand(test, "", {lang="czech"}))

  end)
end)

describe("Dot separated values should be find in subtables", function()
  local test_table = {
    hello = "world,",
    subtable = {
      second = "here we are",
      another = {
        third = "even here"
      }
    }
  }
  it("Should find values in subtables", function()
    assert.same(expand("where we are? @{subtable.second}","", test_table), "where we are? here we are")
    assert.same(expand("where we are? @{subtable.another.third}","", test_table), "where we are? even here")
  end)
end)

describe("Conditional templates should work", function ()
  local test_table = {
    hello = "world"
  }
  it("Should expand basic conditions", function ()
    assert.same(expand("hello ?{hello}{exists}{doesn't exist}", "", test_table), "hello exists")
    assert.same(expand("nothello ?{nothello}{exists}{doesn't exist}", "", test_table), "nothello doesn't exist")
  end)
  it("Should handle TeX code", function()
    assert.same(expand("hello ?{hello}{\\textit{exists}}{doesn't exist}", "", test_table), "hello \\textit{exists}")
  end)
  it("Should expand variables in conditions", function ()
    assert.same(expand("what? ?{hello}{@{hello} exists}{doesn't exist}", "", test_table), "what? world exists")

  end)
end)
