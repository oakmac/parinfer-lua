const indentModeCases = require('./test-cases/indent-mode.json')
const parenModeCases = require('./test-cases/paren-mode.json')
const smartModeCases = require('./test-cases/smart-mode.json')

let id = 3000

let casesWithId = []

smartModeCases.forEach((testCase) => {  
  testCase.id = id
  casesWithId.push(testCase)
  
  id = id + 5
})

console.log(JSON.stringify(casesWithId, null, 2))